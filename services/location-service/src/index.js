const Fastify = require("fastify");
const cors = require("@fastify/cors");
const axios = require("axios");
const crypto = require("crypto");
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
  tripId: z.string().uuid().nullable().optional(),
  lat: z.number(),
  lng: z.number(),
  heading: z.number().optional(),
  speedKph: z.number().optional()
});

const nearbySchema = z.object({
  lat: z.coerce.number(),
  lng: z.coerce.number(),
  radiusMeters: z.coerce.number().int().positive().max(50000).default(50000),
  limit: z.coerce.number().int().positive().max(300).default(200)
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

async function emitRealtime(event, room, data) {
  try {
    await axios.post(process.env.WEBSOCKET_EMIT_URL, {
      event,
      room,
      data
    });
  } catch (error) {
    app.log.warn({ err: error, event, room }, "websocket emit failed");
  }
}

function base64UrlDecode(value) {
  return Buffer.from(String(value).replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

function verifyJwtFromRequest(request, reply) {
  const authorization = String(request.headers.authorization || "");
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  if (!token) {
    reply.code(401).send({ message: "No autorizado" });
    return null;
  }

  const [encodedHeader, encodedPayload, signature] = token.split(".");
  if (!encodedHeader || !encodedPayload || !signature) {
    reply.code(401).send({ message: "Token invalido" });
    return null;
  }

  const expectedSignature = crypto
    .createHmac("sha256", process.env.JWT_SECRET || "super-secret")
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest("base64url");

  const received = Buffer.from(signature);
  const expected = Buffer.from(expectedSignature);
  if (received.length !== expected.length || !crypto.timingSafeEqual(received, expected)) {
    reply.code(401).send({ message: "Token invalido" });
    return null;
  }

  try {
    const payload = JSON.parse(base64UrlDecode(encodedPayload).toString("utf8"));
    if (payload.exp && Date.now() >= payload.exp * 1000) {
      reply.code(401).send({ message: "Token vencido" });
      return null;
    }
    return payload;
  } catch (error) {
    reply.code(401).send({ message: "Token invalido" });
    return null;
  }
}

async function requireOwnDriverId(request, reply, driverId) {
  const user = verifyJwtFromRequest(request, reply);
  if (!user) {
    return null;
  }
  if (user.accountType !== "user" || user.role !== "driver") {
    reply.code(403).send({ message: "Acceso solo para conductores" });
    return null;
  }

  const result = await pool.query(
    "SELECT id FROM drivers WHERE id = $1 AND user_id = $2 LIMIT 1",
    [driverId, user.sub]
  );
  if (!result.rows.length) {
    reply.code(403).send({ message: "No puedes operar con otro conductor" });
    return null;
  }

  request.user = user;
  return user;
}

async function requireOwnActiveTrip(reply, driverId, tripId) {
  const result = await pool.query(
    `SELECT id
     FROM trips
     WHERE id = $1
       AND driver_id = $2
       AND status IN ('accepted', 'arriving', 'at_pickup', 'in_progress')
     LIMIT 1`,
    [tripId, driverId]
  );
  if (!result.rows.length) {
    reply.code(403).send({ message: "No puedes enviar ubicacion para otro viaje" });
    return false;
  }
  return true;
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "location-service" }));

  app.post("/drivers", async (request, reply) => {
    const payload = locationSchema.parse(request.body);
    const user = await requireOwnDriverId(request, reply, payload.driverId);
    if (!user) return;

    if (payload.tripId) {
      const ownsTrip = await requireOwnActiveTrip(reply, payload.driverId, payload.tripId);
      if (!ownsTrip) return;
    }

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

    await emitRealtime("driver:location", `driver:${payload.driverId}`, cachePayload);
    await emitRealtime("driver:location", "drivers:live", cachePayload);

    if (payload.tripId) {
      await emitRealtime("trip:tracking", `trip:${payload.tripId}`, cachePayload);
    }

    reply.send({ success: true });
  });

  app.get("/drivers/:driverId", async (request, reply) => {
    const { driverId } = request.params;
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    return redis.hgetall(`driver:last_location:${driverId}`);
  });

  app.get("/nearby", async (request, reply) => {
    const parsed = nearbySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ message: "Invalid nearby query" });
    }

    const { lat, lng, radiusMeters, limit } = parsed.data;
    if (!isInsidePotosi(lat, lng)) {
      return reply.code(400).send({ message: "Location is outside Potosi service radius" });
    }

    const result = await pool.query(
      `WITH latest_locations AS (
         SELECT DISTINCT ON (dl.driver_id)
           dl.driver_id,
           dl.location,
           dl.heading,
           dl.speed_kph,
           dl.recorded_at
         FROM driver_locations dl
         ORDER BY dl.driver_id, dl.recorded_at DESC
       )
       SELECT d.id AS driver_id,
              d.rating,
              ST_Y(ll.location::geometry) AS lat,
              ST_X(ll.location::geometry) AS lng,
              ll.heading,
              ll.speed_kph,
              ll.recorded_at,
              ST_Distance(
                ll.location,
                ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
              ) AS distance_meters
       FROM drivers d
       INNER JOIN latest_locations ll ON ll.driver_id = d.id
       WHERE d.is_available = TRUE
         AND d.status = 'available'
         AND ll.recorded_at >= NOW() - INTERVAL '5 minutes'
         AND ST_DWithin(
           ll.location,
           ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
           $3
         )
       ORDER BY distance_meters ASC
       LIMIT $4`,
      [lng, lat, radiusMeters, limit]
    );

    return { drivers: result.rows };
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
