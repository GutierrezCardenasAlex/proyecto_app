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
  destinationLat: z.number().optional().nullable(),
  destinationLng: z.number().optional().nullable(),
  estimatedDistanceMeters: z.number().int().positive(),
  estimatedDurationSeconds: z.number().int().positive(),
  fareAmount: z.number().positive(),
  dispatchMode: z.enum(["broadcast", "nearby"]).default("broadcast"),
  preferredDriverId: z.string().uuid().optional()
});

const statusSchema = z.object({
  status: z.enum(["arriving", "at_pickup", "in_progress", "completed", "cancelled"])
});

const destinationUpdateSchema = z.object({
  destinationAddress: z.string().min(3),
  destinationLat: z.number(),
  destinationLng: z.number()
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
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS completed_trip_count INTEGER NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS promo_progress_count INTEGER NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS free_trip_credits INTEGER NOT NULL DEFAULT 0
  `);
  await pool.query(`
    ALTER TABLE trips
      ADD COLUMN IF NOT EXISTS promotional_trip BOOLEAN NOT NULL DEFAULT FALSE
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
  await pool.query(`
    CREATE TABLE IF NOT EXISTS promo_settings (
      id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
      enabled BOOLEAN NOT NULL DEFAULT TRUE,
      cycle_length INTEGER NOT NULL DEFAULT 5,
      reward_credits INTEGER NOT NULL DEFAULT 1,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    INSERT INTO promo_settings (id, enabled, cycle_length, reward_credits)
    VALUES (1, TRUE, 5, 1)
    ON CONFLICT (id) DO NOTHING
  `);
}

async function getPromoSettings(client = pool) {
  const result = await client.query(
    `SELECT enabled, cycle_length, reward_credits
     FROM promo_settings
     WHERE id = 1
     LIMIT 1`
  );
  return {
    enabled: result.rows[0]?.enabled !== false,
    cycleLength: Number(result.rows[0]?.cycle_length || 5),
    rewardCredits: Number(result.rows[0]?.reward_credits || 1)
  };
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
    driver_lat: row.driver_lat == null ? null : Number(row.driver_lat),
    driver_lng: row.driver_lng == null ? null : Number(row.driver_lng),
    fare_amount: row.fare_amount == null ? null : Number(row.fare_amount),
    eta_minutes: row.eta_minutes == null ? null : Number(row.eta_minutes)
  };
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await ensureSchema();

  app.get("/health", async () => ({ status: "ok", service: "trip-service" }));

  app.post("/", async (request, reply) => {
    const input = tripSchema.parse(request.body);
    const locations = [[input.pickupLat, input.pickupLng]];
    if (typeof input.destinationLat === "number" && typeof input.destinationLng === "number") {
      locations.push([input.destinationLat, input.destinationLng]);
    }

    if (!locations.every(([lat, lng]) => isInsidePotosi(lat, lng))) {
      return reply.code(400).send({
        message: "Trips are restricted to Potosi, Bolivia within a 15 km radius"
      });
    }

    const client = await pool.connect();
    let trip;
    let rewardApplied = false;
    let shouldTriggerDispatch = false;
    try {
      await client.query("BEGIN");
      const existingTripResult = await client.query(
        `SELECT id, status, promotional_trip, fare_amount
         FROM trips
         WHERE passenger_id = $1
           AND status IN ('requested', 'searching', 'accepted', 'arriving', 'at_pickup', 'in_progress')
         ORDER BY updated_at DESC
         LIMIT 1
         FOR UPDATE`,
        [input.passengerId]
      );

      if (existingTripResult.rows.length) {
        const existingTrip = existingTripResult.rows[0];
        if (["requested", "searching"].includes(existingTrip.status)) {
          trip = existingTrip;
          rewardApplied = existingTrip.promotional_trip === true;
          shouldTriggerDispatch = true;
          await client.query("COMMIT");
        } else {
          await client.query("ROLLBACK");
          return reply.code(409).send({
            message: "Ya tienes un pedido activo. Debes finalizarlo o cancelarlo antes de solicitar otro.",
            activeTripId: existingTrip.id,
            activeTripStatus: existingTrip.status
          });
        }
      }

      if (!trip) {
        shouldTriggerDispatch = true;
        let effectiveFare = input.fareAmount;
        const promoSettings = await getPromoSettings(client);
        const creditsResult = await client.query(
          `SELECT free_trip_credits
           FROM users
           WHERE id = $1
           FOR UPDATE`,
          [input.passengerId]
        );
        const credits = Number(creditsResult.rows[0]?.free_trip_credits || 0);
        if (promoSettings.enabled && credits > 0) {
          rewardApplied = true;
          effectiveFare = 0;
          await client.query(
            `UPDATE users
             SET free_trip_credits = GREATEST(free_trip_credits - 1, 0),
                 updated_at = NOW()
             WHERE id = $1`,
            [input.passengerId]
          );
        }

        const result = await client.query(
          `INSERT INTO trips (
           passenger_id,
           pickup_address,
           destination_address,
           pickup_location,
           destination_location,
           estimated_distance_meters,
           estimated_duration_seconds,
           fare_amount,
           promotional_trip,
           status
         ) VALUES (
           $1, $2, $3,
           ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
           CASE
             WHEN $6::double precision IS NULL OR $7::double precision IS NULL THEN NULL
             ELSE ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography
           END,
          $8, $9, $10, $11, 'requested'
         )
         RETURNING *`,
          [
            input.passengerId,
            input.pickupAddress,
            input.destinationAddress,
            input.pickupLng,
            input.pickupLat,
            input.destinationLng ?? null,
            input.destinationLat ?? null,
            input.estimatedDistanceMeters,
            input.estimatedDurationSeconds,
            effectiveFare,
            rewardApplied
          ]
        );
        trip = result.rows[0];
        await client.query("COMMIT");
      }
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }

    await redis.set(`trip:${trip.id}:status`, trip.status, "EX", 3600);
    if (trip.status === "requested") {
      await publish("trip.requested", { tripId: trip.id, passengerId: input.passengerId });
    }

    if (shouldTriggerDispatch) {
      try {
        await axios.post(`${process.env.DISPATCH_SERVICE_URL}/search`, {
          tripId: trip.id,
          pickupLat: input.pickupLat,
          pickupLng: input.pickupLng,
          dispatchMode: input.dispatchMode,
          preferredDriverId: input.preferredDriverId
        });
      } catch (error) {
        app.log.warn({ err: error, tripId: trip.id }, "dispatch search failed after trip creation");
      }
    }

    reply.code(201).send({
      ...trip,
      reward_applied: rewardApplied
    });
  });

  app.get("/history/:passengerId", async (request) => {
    const { passengerId } = request.params;
    const result = await pool.query(
      `SELECT t.*,
              v.vehicle_type,
              v.brand AS vehicle_brand,
              v.model AS vehicle_model,
              v.color AS vehicle_color,
              v.plate AS vehicle_plate,
              du.full_name AS driver_name,
              du.phone AS driver_phone,
              t.promotional_trip
       FROM trips t
       LEFT JOIN vehicles v ON v.driver_id = t.driver_id
       LEFT JOIN drivers d ON d.id = t.driver_id
       LEFT JOIN users du ON du.id = d.user_id
       WHERE t.passenger_id = $1
       ORDER BY COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at) DESC
       LIMIT 50`,
      [passengerId]
    );
    return result.rows;
  });

  app.get("/history/driver/:driverId", async (request) => {
    const { driverId } = request.params;
    const result = await pool.query(
      `SELECT t.*,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng,
              v.vehicle_type,
              v.brand AS vehicle_brand,
              v.model AS vehicle_model,
              v.color AS vehicle_color,
              v.plate AS vehicle_plate,
              pu.full_name AS passenger_name,
              pu.phone AS passenger_phone,
              t.promotional_trip
       FROM trips t
       LEFT JOIN vehicles v ON v.driver_id = t.driver_id
       LEFT JOIN users pu ON pu.id = t.passenger_id
       WHERE t.driver_id = $1
       ORDER BY COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at) DESC
       LIMIT 50`,
      [driverId]
    );

    return result.rows.map(mapTrip);
  });

  app.get("/active/passenger/:passengerId", async (request) => {
    const { passengerId } = request.params;
    const result = await pool.query(
      `WITH latest_location AS (
         SELECT DISTINCT ON (dl.driver_id)
           dl.driver_id,
           dl.location,
           ST_Y(dl.location::geometry) AS driver_lat,
           ST_X(dl.location::geometry) AS driver_lng
         FROM driver_locations dl
         ORDER BY dl.driver_id, dl.recorded_at DESC
       )
       SELECT t.*,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng,
              v.vehicle_type,
              v.brand AS vehicle_brand,
              v.model AS vehicle_model,
              v.color AS vehicle_color,
              v.plate AS vehicle_plate,
              du.full_name AS driver_name,
              du.phone AS driver_phone,
              ll.driver_lat,
              ll.driver_lng,
              t.promotional_trip,
              CASE
                WHEN ll.location IS NULL THEN NULL
                ELSE GREATEST(
                  2,
                  ROUND(ST_Distance(ll.location, t.pickup_location) / 350.0)::int
                )
              END AS eta_minutes
       FROM trips t
       LEFT JOIN drivers d ON d.id = t.driver_id
       LEFT JOIN users du ON du.id = d.user_id
       LEFT JOIN vehicles v ON v.driver_id = t.driver_id
       LEFT JOIN latest_location ll ON ll.driver_id = t.driver_id
       WHERE t.passenger_id = $1
         AND t.status IN ('requested', 'searching', 'accepted', 'arriving', 'at_pickup', 'in_progress')
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
              ST_X(t.destination_location::geometry) AS destination_lng,
              v.vehicle_type,
              v.brand AS vehicle_brand,
              v.model AS vehicle_model,
              v.color AS vehicle_color,
              v.plate AS vehicle_plate,
              pu.full_name AS passenger_name,
              pu.phone AS passenger_phone,
              t.promotional_trip
       FROM trips t
       LEFT JOIN users pu ON pu.id = t.passenger_id
       LEFT JOIN vehicles v ON v.driver_id = t.driver_id
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
    if (status === "in_progress") {
      const destinationCheck = await pool.query(
        `SELECT destination_address,
                ST_Y(destination_location::geometry) AS destination_lat,
                ST_X(destination_location::geometry) AS destination_lng
         FROM trips
         WHERE id = $1`,
        [tripId]
      );
      if (!destinationCheck.rows.length) {
        return reply.code(404).send({ message: "Trip not found" });
      }
      const currentTrip = destinationCheck.rows[0];
      const destinationAddress = (currentTrip.destination_address || "").toString().trim().toLowerCase();
      if (
        currentTrip.destination_lat == null ||
        currentTrip.destination_lng == null ||
        !destinationAddress ||
        destinationAddress === "destino no esta marcado" ||
        destinationAddress === "destino por confirmar" ||
        destinationAddress === "abordaje inmediato"
      ) {
        return reply.code(409).send({
          message: "El pasajero aun no guardo el destino final del viaje"
        });
      }
    }
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

    if (status === "completed" && trip.passenger_id) {
      const promoSettings = await getPromoSettings();
      await pool.query(
        `UPDATE users
         SET completed_trip_count = completed_trip_count + 1,
             promo_progress_count = CASE
               WHEN NOT $3 THEN promo_progress_count
               WHEN $2 THEN promo_progress_count
               WHEN promo_progress_count + 1 >= $4 THEN 0
               ELSE promo_progress_count + 1
             END,
             free_trip_credits = free_trip_credits +
               CASE WHEN $3 AND NOT $2 AND promo_progress_count + 1 >= $4 THEN $5 ELSE 0 END,
             updated_at = NOW()
         WHERE id = $1`,
        [
          trip.passenger_id,
          trip.promotional_trip === true,
          promoSettings.enabled,
          promoSettings.cycleLength,
          promoSettings.rewardCredits
        ]
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

  app.patch("/:tripId/destination", async (request, reply) => {
    const { tripId } = request.params;
    const input = destinationUpdateSchema.parse(request.body);

    if (!isInsidePotosi(input.destinationLat, input.destinationLng)) {
      return reply.code(400).send({
        message: "El destino debe quedar dentro del area operativa de Potosi"
      });
    }

    const currentTripResult = await pool.query(
      `SELECT id, status, driver_id, passenger_id
       FROM trips
       WHERE id = $1`,
      [tripId]
    );

    if (!currentTripResult.rows.length) {
      return reply.code(404).send({ message: "Trip not found" });
    }

    const currentTrip = currentTripResult.rows[0];
    if (!["requested", "searching", "accepted", "arriving", "at_pickup"].includes(currentTrip.status)) {
      return reply.code(409).send({
        message: "Ya no se puede cambiar el destino cuando el viaje esta en curso o finalizado"
      });
    }

    const result = await pool.query(
      `UPDATE trips
       SET destination_address = $2,
           destination_location = ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
           updated_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [tripId, input.destinationAddress, input.destinationLng, input.destinationLat]
    );

    const trip = result.rows[0];

    await pool.query(
      `INSERT INTO trip_events (trip_id, event_type, payload)
       VALUES ($1, $2, $3::jsonb)`,
      [
        tripId,
        "destination_updated",
        JSON.stringify({
          destinationAddress: input.destinationAddress,
          destinationLat: input.destinationLat,
          destinationLng: input.destinationLng
        })
      ]
    );

    await publish("trip.destination_updated", {
      tripId,
      destinationAddress: input.destinationAddress,
      destinationLat: input.destinationLat,
      destinationLng: input.destinationLng
    });
    await emitRealtime("trip:destination_updated", `trip:${tripId}`, {
      tripId,
      driverId: currentTrip.driver_id,
      passengerId: currentTrip.passenger_id,
      destinationAddress: input.destinationAddress,
      destinationLat: input.destinationLat,
      destinationLng: input.destinationLng
    });
    if (currentTrip.driver_id) {
      await emitRealtime("driver:trip_destination_updated", `driver:${currentTrip.driver_id}`, {
        tripId,
        destinationAddress: input.destinationAddress,
        destinationLat: input.destinationLat,
        destinationLng: input.destinationLng
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
