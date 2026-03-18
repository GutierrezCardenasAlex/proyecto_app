const Fastify = require("fastify");
const cors = require("@fastify/cors");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3004);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const searchSchema = z.object({
  tripId: z.string().uuid(),
  pickupLat: z.number(),
  pickupLng: z.number()
});

const acceptSchema = z.object({
  tripId: z.string().uuid(),
  driverId: z.string().uuid()
});

async function publish(routingKey, payload) {
  const connection = await amqp.connect(process.env.RABBITMQ_URL);
  const channel = await connection.createChannel();
  await channel.assertExchange("taxiya.events", "topic", { durable: true });
  channel.publish("taxiya.events", routingKey, Buffer.from(JSON.stringify(payload)));
  setTimeout(() => connection.close(), 250);
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "dispatch-service" }));

  app.post("/search", async (request) => {
    const { tripId, pickupLat, pickupLng } = searchSchema.parse(request.body);
    const result = await pool.query(
      `WITH latest_locations AS (
         SELECT DISTINCT ON (dl.driver_id)
           dl.driver_id,
           dl.location,
           dl.recorded_at
         FROM driver_locations dl
         ORDER BY dl.driver_id, dl.recorded_at DESC
       )
       SELECT d.id AS driver_id,
              ST_Distance(
                ll.location,
                ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
              ) AS distance_meters
       FROM drivers d
       INNER JOIN latest_locations ll ON ll.driver_id = d.id
       WHERE d.is_available = TRUE
         AND d.status = 'available'
         AND ST_DWithin(
           ll.location,
           ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
           3000
         )
       ORDER BY distance_meters ASC
       LIMIT 5`,
      [pickupLng, pickupLat]
    );

    const candidates = result.rows;
    await redis.set(`trip:${tripId}:candidate_count`, String(candidates.length), "EX", 600);
    await publish("dispatch.search.completed", { tripId, candidates });

    for (const candidate of candidates) {
      await publish("dispatch.trip.offer", {
        tripId,
        driverId: candidate.driver_id,
        distanceMeters: Number(candidate.distance_meters)
      });
    }

    return { tripId, candidates };
  });

  app.post("/accept", async (request, reply) => {
    const { tripId, driverId } = acceptSchema.parse(request.body);
    const lockKey = `trip:${tripId}:accept_lock`;
    const lockValue = await redis.set(lockKey, driverId, "NX", "EX", 15);

    if (lockValue !== "OK") {
      return reply.code(409).send({ message: "Trip is already being processed" });
    }

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const tripUpdate = await client.query(
        `UPDATE trips
         SET driver_id = $1, status = 'accepted', accepted_at = NOW(), updated_at = NOW()
         WHERE id = $2 AND status = 'requested'
         RETURNING *`,
        [driverId, tripId]
      );

      if (!tripUpdate.rows.length) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ message: "Trip already taken" });
      }

      await client.query(
        `UPDATE drivers
         SET status = 'busy', is_available = FALSE, current_trip_id = $2, updated_at = NOW()
         WHERE id = $1`,
        [driverId, tripId]
      );

      await client.query(
        `INSERT INTO trip_events (trip_id, event_type, payload)
         VALUES ($1, 'accepted', $2::jsonb)`,
        [tripId, JSON.stringify({ driverId })]
      );

      await client.query("COMMIT");
      await publish("dispatch.trip.accepted", { tripId, driverId });
      reply.send(tripUpdate.rows[0]);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
      await redis.del(lockKey);
    }
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
