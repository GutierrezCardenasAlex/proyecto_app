const Fastify = require("fastify");
const cors = require("@fastify/cors");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const axios = require("axios");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3003);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const POTOSI_CENTER = { lat: -19.5836, lng: -65.7531 };
const POTOSI_RADIUS_KM = 15;

const tripSchema = z.object({
  passengerId: z.string().uuid(),
  pickupAddress: z.string().min(3),
  destinationAddress: z.string().min(3),
  pickupLat: z.number(),
  pickupLng: z.number(),
  destinationLat: z.number(),
  destinationLng: z.number(),
  estimatedDistanceMeters: z.number().int().positive(),
  estimatedDurationSeconds: z.number().int().positive(),
  fareAmount: z.number().positive()
});

const statusSchema = z.object({
  status: z.enum(["arriving", "in_progress", "completed", "cancelled"])
});

function toRadians(value) {
  return (value * Math.PI) / 180;
}

function isInsidePotosi(lat, lng) {
  const earthRadiusKm = 6371;
  const dLat = toRadians(lat - POTOSI_CENTER.lat);
  const dLng = toRadians(lng - POTOSI_CENTER.lng);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(POTOSI_CENTER.lat)) *
      Math.cos(toRadians(lat)) *
      Math.sin(dLng / 2) ** 2;
  const distance = 2 * earthRadiusKm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return distance <= POTOSI_RADIUS_KM;
}

async function publish(routingKey, payload) {
  const connection = await amqp.connect(process.env.RABBITMQ_URL);
  const channel = await connection.createChannel();
  await channel.assertExchange("taxiya.events", "topic", { durable: true });
  channel.publish("taxiya.events", routingKey, Buffer.from(JSON.stringify(payload)));
  setTimeout(() => connection.close(), 250);
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "trip-service" }));

  app.post("/", async (request, reply) => {
    const input = tripSchema.parse(request.body);
    const locations = [
      [input.pickupLat, input.pickupLng],
      [input.destinationLat, input.destinationLng]
    ];

    if (!locations.every(([lat, lng]) => isInsidePotosi(lat, lng))) {
      return reply.code(400).send({
        message: "Trips are restricted to Potosi, Bolivia within a 15 km radius"
      });
    }

    const result = await pool.query(
      `INSERT INTO trips (
         passenger_id,
         pickup_address,
         destination_address,
         pickup_location,
         destination_location,
         estimated_distance_meters,
         estimated_duration_seconds,
         fare_amount,
         status
       ) VALUES (
         $1, $2, $3,
         ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
         ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography,
         $8, $9, $10, 'requested'
       )
       RETURNING *`,
      [
        input.passengerId,
        input.pickupAddress,
        input.destinationAddress,
        input.pickupLng,
        input.pickupLat,
        input.destinationLng,
        input.destinationLat,
        input.estimatedDistanceMeters,
        input.estimatedDurationSeconds,
        input.fareAmount
      ]
    );

    const trip = result.rows[0];
    await redis.set(`trip:${trip.id}:status`, trip.status, "EX", 3600);
    await publish("trip.requested", { tripId: trip.id, passengerId: input.passengerId });

    await axios.post(`${process.env.DISPATCH_SERVICE_URL}/search`, {
      tripId: trip.id,
      pickupLat: input.pickupLat,
      pickupLng: input.pickupLng
    });

    reply.code(201).send(trip);
  });

  app.get("/history/:passengerId", async (request) => {
    const { passengerId } = request.params;
    const result = await pool.query(
      `SELECT *
       FROM trips
       WHERE passenger_id = $1
       ORDER BY requested_at DESC
       LIMIT 50`,
      [passengerId]
    );
    return result.rows;
  });

  app.get("/:tripId", async (request, reply) => {
    const { tripId } = request.params;
    const result = await pool.query("SELECT * FROM trips WHERE id = $1", [tripId]);
    if (!result.rows.length) {
      return reply.code(404).send({ message: "Trip not found" });
    }
    reply.send(result.rows[0]);
  });

  app.patch("/:tripId/status", async (request, reply) => {
    const { tripId } = request.params;
    const { status } = statusSchema.parse(request.body);
    const timestampField = {
      arriving: null,
      in_progress: "started_at",
      completed: "completed_at",
      cancelled: "cancelled_at"
    }[status];

    const query = timestampField
      ? `UPDATE trips SET status = $2, ${timestampField} = NOW(), updated_at = NOW() WHERE id = $1 RETURNING *`
      : `UPDATE trips SET status = $2, updated_at = NOW() WHERE id = $1 RETURNING *`;

    const result = await pool.query(query, [tripId, status]);
    if (!result.rows.length) {
      return reply.code(404).send({ message: "Trip not found" });
    }

    await redis.set(`trip:${tripId}:status`, status, "EX", 3600);
    await publish(`trip.${status}`, { tripId, status });
    reply.send(result.rows[0]);
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
