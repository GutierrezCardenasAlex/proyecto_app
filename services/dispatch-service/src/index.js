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

const nearbySchema = z.object({
  lat: z.coerce.number(),
  lng: z.coerce.number(),
  radiusMeters: z.coerce.number().int().positive().max(5000).default(3000),
  limit: z.coerce.number().int().positive().max(20).default(5)
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
    await pool.query(
      `UPDATE trips
       SET status = 'searching', updated_at = NOW()
       WHERE id = $1 AND status = 'requested'`,
      [tripId]
    );
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
      await redis.sadd(`driver:${candidate.driver_id}:offers`, tripId);
      await redis.expire(`driver:${candidate.driver_id}:offers`, 600);
      await publish("dispatch.trip.offer", {
        tripId,
        driverId: candidate.driver_id,
        distanceMeters: Number(candidate.distance_meters)
      });
    }

    return { tripId, candidates };
  });

  app.get("/offers/:driverId", async (request) => {
    const { driverId } = request.params;
    const tripIds = await redis.smembers(`driver:${driverId}:offers`);

    if (!tripIds.length) {
      return { offers: [] };
    }

    const result = await pool.query(
      `SELECT t.id,
              t.status,
              t.pickup_address,
              t.destination_address,
              t.requested_at,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng,
              t.fare_amount
       FROM trips t
       WHERE t.id = ANY($1::uuid[])
         AND t.status IN ('requested', 'searching')
       ORDER BY t.requested_at DESC`,
      [tripIds]
    );

    return { offers: result.rows };
  });

  app.get("/nearby", async (request, reply) => {
    const parsed = nearbySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ message: "Invalid nearby query" });
    }

    const { lat, lng, radiusMeters, limit } = parsed.data;
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
              d.rating,
              ST_Y(ll.location::geometry) AS lat,
              ST_X(ll.location::geometry) AS lng,
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
           $3
         )
       ORDER BY distance_meters ASC
       LIMIT $4`,
      [lng, lat, radiusMeters, limit]
    );

    return {
      drivers: result.rows.map((row) => ({
        ...row,
        eta_minutes: Math.max(2, Math.round(Number(row.distance_meters) / 350))
      }))
    };
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
         WHERE id = $2 AND status IN ('requested', 'searching')
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
      await redis.del(`driver:${driverId}:offers`);
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
