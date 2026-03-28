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
  fareAmount: z.number().positive(),
  preferredDriverId: z.string().uuid().optional()
});

const statusSchema = z.object({
  status: z.enum(["arriving", "at_pickup", "in_progress", "completed", "cancelled"])
});

const ratingSchema = z.object({
  fromRole: z.enum(["passenger", "driver"]),
  score: z.number().int().min(1).max(5),
  comment: z.string().trim().max(240).optional()
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

async function emitRealtime(event, room, data) {
  if (!process.env.WEBSOCKET_EMIT_URL) {
    return;
  }

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

async function ensureSchema() {
  await pool.query(`
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status') THEN
        ALTER TYPE trip_status ADD VALUE IF NOT EXISTS 'at_pickup';
      END IF;
    END $$;
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS trip_ratings (
      id BIGSERIAL PRIMARY KEY,
      trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
      from_role VARCHAR(16) NOT NULL,
      from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      to_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      to_driver_id UUID REFERENCES drivers(id) ON DELETE CASCADE,
      score SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
      comment VARCHAR(240),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (trip_id, from_role)
    )
  `);
}

function mapTrip(row) {
  if (!row) {
    return null;
  }

  return {
    ...row,
    pickup_lat: row.pickup_lat == null ? null : Number(row.pickup_lat),
    pickup_lng: row.pickup_lng == null ? null : Number(row.pickup_lng),
    destination_lat: row.destination_lat == null ? null : Number(row.destination_lat),
    destination_lng: row.destination_lng == null ? null : Number(row.destination_lng),
    fare_amount: row.fare_amount == null ? null : Number(row.fare_amount)
  };
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await ensureSchema();

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
      pickupLng: input.pickupLng,
      preferredDriverId: input.preferredDriverId
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

  app.get("/active/passenger/:passengerId", async (request) => {
    const { passengerId } = request.params;
    const result = await pool.query(
      `SELECT t.*,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng
       FROM trips t
       WHERE t.passenger_id = $1
         AND t.status IN ('accepted', 'arriving', 'at_pickup', 'in_progress')
       ORDER BY t.updated_at DESC
       LIMIT 1`,
      [passengerId]
    );

    return mapTrip(result.rows[0]) ?? null;
  });

  app.get("/active/driver/:driverId", async (request) => {
    const { driverId } = request.params;
    const result = await pool.query(
      `SELECT t.*,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng
       FROM trips t
       WHERE t.driver_id = $1
         AND t.status IN ('accepted', 'arriving', 'at_pickup', 'in_progress')
       ORDER BY t.updated_at DESC
       LIMIT 1`,
      [driverId]
    );

    return mapTrip(result.rows[0]) ?? null;
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
      at_pickup: null,
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

    const trip = result.rows[0];

    if (trip.driver_id && ["arriving", "at_pickup", "in_progress"].includes(status)) {
      await pool.query(
        `UPDATE drivers
         SET status = 'busy', is_available = FALSE, current_trip_id = $2, updated_at = NOW()
         WHERE id = $1`,
        [trip.driver_id, tripId]
      );
    }

    if (trip.driver_id && ["completed", "cancelled"].includes(status)) {
      await pool.query(
        `UPDATE drivers
         SET status = 'available', is_available = TRUE, current_trip_id = NULL, updated_at = NOW()
         WHERE id = $1`,
        [trip.driver_id]
      );
    }

    await redis.set(`trip:${tripId}:status`, status, "EX", 3600);
    await pool.query(
      `INSERT INTO trip_events (trip_id, event_type, payload)
       VALUES ($1, $2, $3::jsonb)`,
      [tripId, status, JSON.stringify({ status })]
    );
    await publish(`trip.${status}`, { tripId, status });
    await emitRealtime("trip:status_changed", `trip:${tripId}`, {
      tripId,
      driverId: trip.driver_id,
      passengerId: trip.passenger_id,
      status
    });
    if (trip.driver_id) {
      await emitRealtime("driver:trip_status_changed", `driver:${trip.driver_id}`, {
        tripId,
        status
      });
    }
    reply.send(trip);
  });

  app.post("/:tripId/rating", async (request, reply) => {
    const { tripId } = request.params;
    const { fromRole, score, comment } = ratingSchema.parse(request.body);
    const tripResult = await pool.query(
      `SELECT t.id,
              t.passenger_id,
              t.driver_id,
              d.user_id AS driver_user_id
       FROM trips t
       LEFT JOIN drivers d ON d.id = t.driver_id
       WHERE t.id = $1`,
      [tripId]
    );

    if (!tripResult.rows.length) {
      return reply.code(404).send({ message: "Trip not found" });
    }

    const trip = tripResult.rows[0];
    if (!trip.driver_id || !trip.driver_user_id) {
      return reply.code(409).send({ message: "Trip has no driver assigned" });
    }

    const fromUserId = fromRole === "passenger" ? trip.passenger_id : trip.driver_user_id;
    const toUserId = fromRole === "passenger" ? trip.driver_user_id : trip.passenger_id;
    const toDriverId = fromRole === "passenger" ? trip.driver_id : null;

    try {
      await pool.query(
        `INSERT INTO trip_ratings (
           trip_id,
           from_role,
           from_user_id,
           to_user_id,
           to_driver_id,
           score,
           comment
         ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [tripId, fromRole, fromUserId, toUserId, toDriverId, score, comment ?? null]
      );
    } catch (error) {
      if (error.code === "23505") {
        return reply.code(409).send({ message: "Rating already submitted" });
      }
      throw error;
    }

    if (toDriverId) {
      await pool.query(
        `UPDATE drivers d
         SET rating = (
           SELECT ROUND(AVG(score)::numeric, 2)
           FROM trip_ratings
           WHERE to_driver_id = d.id
         ),
         updated_at = NOW()
         WHERE d.id = $1`,
        [toDriverId]
      );
    }

    await publish("trip.rating.created", { tripId, fromRole, score });
    reply.code(201).send({ ok: true });
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
