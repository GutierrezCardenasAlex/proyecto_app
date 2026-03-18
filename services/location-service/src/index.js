const Fastify = require("fastify");
const cors = require("@fastify/cors");
const axios = require("axios");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3005);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const POTOSI_CENTER = { lat: -19.5836, lng: -65.7531 };
const POTOSI_RADIUS_KM = 15;

const locationSchema = z.object({
  driverId: z.string().uuid(),
  tripId: z.string().uuid().optional(),
  lat: z.number(),
  lng: z.number(),
  heading: z.number().optional(),
  speedKph: z.number().optional()
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
  return 2 * earthRadiusKm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) <= POTOSI_RADIUS_KM;
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

  app.get("/health", async () => ({ status: "ok", service: "location-service" }));

  app.post("/drivers", async (request, reply) => {
    const payload = locationSchema.parse(request.body);
    if (!isInsidePotosi(payload.lat, payload.lng)) {
      return reply.code(400).send({
        message: "Driver location rejected outside Potosi service radius"
      });
    }

    await pool.query(
      `INSERT INTO driver_locations (driver_id, location, heading, speed_kph)
       VALUES (
         $1,
         ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
         $4,
         $5
       )`,
      [payload.driverId, payload.lng, payload.lat, payload.heading || null, payload.speedKph || null]
    );

    if (payload.tripId) {
      await pool.query(
        `INSERT INTO trip_tracking (trip_id, driver_id, location)
         VALUES (
           $1, $2,
           ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography
         )`,
        [payload.tripId, payload.driverId, payload.lng, payload.lat]
      );
    }

    const cachePayload = {
      driverId: payload.driverId,
      tripId: payload.tripId || "",
      lat: String(payload.lat),
      lng: String(payload.lng),
      heading: String(payload.heading || 0),
      speedKph: String(payload.speedKph || 0),
      updatedAt: new Date().toISOString()
    };

    await redis.hset(`driver:last_location:${payload.driverId}`, cachePayload);
    await redis.expire(`driver:last_location:${payload.driverId}`, 600);
    await publish("location.driver.updated", cachePayload);

    await axios.post(process.env.WEBSOCKET_EMIT_URL, {
      event: "driver:location",
      room: `driver:${payload.driverId}`,
      data: cachePayload
    });

    if (payload.tripId) {
      await axios.post(process.env.WEBSOCKET_EMIT_URL, {
        event: "trip:tracking",
        room: `trip:${payload.tripId}`,
        data: cachePayload
      });
    }

    reply.send({ success: true });
  });

  app.get("/drivers/:driverId", async (request) => {
    const { driverId } = request.params;
    return redis.hgetall(`driver:last_location:${driverId}`);
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
