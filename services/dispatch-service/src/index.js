const { registerDriverProposals, withdrawDriverProposal } = require("./driver-proposals");
const Fastify = require("fastify");
const cors = require("@fastify/cors");
const axios = require("axios");
const crypto = require("crypto");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3004);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);
const OFFER_TTL_SECONDS = Number(process.env.DISPATCH_OFFER_TTL_SECONDS || 600);

const searchSchema = z.object({
  tripId: z.string().uuid(),
  pickupLat: z.number(),
  pickupLng: z.number(),
  dispatchMode: z.enum(["broadcast", "nearby"]).default("broadcast"),
  preferredDriverId: z.string().uuid().optional()
});

const acceptSchema = z.object({
  tripId: z.string().uuid(),
  driverId: z.string().uuid(),
  expectedFare: z.number().min(0).max(99999999.99).optional(),
  counterFare: z.number().min(0).max(99999999.99).multipleOf(0.01).optional()
});

const rejectSchema = z.object({
  tripId: z.string().uuid(),
  driverId: z.string().uuid()
});

const nearbySchema = z.object({
  lat: z.coerce.number(),
  lng: z.coerce.number(),
  radiusMeters: z.coerce.number().int().positive().max(50000).default(50000),
  limit: z.coerce.number().int().positive().max(300).default(200)
});

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

function rejectAuthenticatedExternalCall(request, reply) {
  if (request.headers.authorization) {
    reply.code(403).send({ message: "Ruta interna de despacho" });
    return true;
  }
  return false;
}

async function clearTripOffers(tripId) {
  const offeredDriversKey = `trip:${tripId}:offered_drivers`;
  const offeredDriverIds = await redis.smembers(offeredDriversKey);
  if (offeredDriverIds.length) {
    for (const offeredDriverId of offeredDriverIds) {
      await redis.srem(`driver:${offeredDriverId}:offers`, tripId);
      await redis.hdel(`driver:${offeredDriverId}:offer_expires_at`, tripId);
    }
  }
  await redis.del(
    offeredDriversKey,
    `trip:${tripId}:candidate_count`,
    `trip:${tripId}:dispatch_stage`,
    `trip:${tripId}:dispatch_run`,
    `trip:${tripId}:broadcast_timer`,
    `trip:${tripId}:nearby_queue`,
    `trip:${tripId}:active_offer_driver`,
    `trip:${tripId}:active_offer_token`,
    `trip:${tripId}:rejected_drivers`
  );
}

async function findCandidateDrivers({
  pickupLat,
  pickupLng,
  preferredDriverId = null,
  radiusMeters = null,
  limit = null,
  excludeDriverIds = []
}) {
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
            v.vehicle_type,
            v.brand,
            v.model,
            v.color,
            v.plate,
            ST_Distance(
              ll.location,
              ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
            ) AS distance_meters
     FROM drivers d
     LEFT JOIN latest_locations ll ON ll.driver_id = d.id
     LEFT JOIN vehicles v ON v.driver_id = d.id
     WHERE d.is_available = TRUE
       AND d.status = 'available'
       AND d.current_trip_id IS NULL
       AND d.accepts_transport_requests = TRUE
       AND ($3::uuid IS NULL OR d.id = $3)
       AND NOT (d.id = ANY($4::uuid[]))
       AND NOT EXISTS (
         SELECT 1
         FROM trips active_trip
         WHERE active_trip.driver_id = d.id
           AND active_trip.status IN ('accepted', 'arriving', 'at_pickup', 'in_progress')
       )
       AND (
         $5::int IS NULL OR ST_DWithin(
           ll.location,
           ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
           $5
         )
       )
     ORDER BY distance_meters ASC
     LIMIT $6`,
    [pickupLng, pickupLat, preferredDriverId, excludeDriverIds, radiusMeters, limit]
  );

  return result.rows;
}

function buildOfferPayload(tripId, candidate, stage) {
  return {
    tripId,
    driverId: candidate.driver_id,
    stage,
    distanceMeters: Number(candidate.distance_meters),
    vehicle: {
      type: candidate.vehicle_type,
      brand: candidate.brand,
      model: candidate.model,
      color: candidate.color,
      plate: candidate.plate
    }
  };
}

async function offerTripToCandidates(tripId, candidates, stage) {
  for (const candidate of candidates) {
    const payload = buildOfferPayload(tripId, candidate, stage);
    await redis.sadd(`driver:${candidate.driver_id}:offers`, tripId);
    await redis.expire(`driver:${candidate.driver_id}:offers`, OFFER_TTL_SECONDS);
    await redis.hdel(`driver:${candidate.driver_id}:offer_expires_at`, tripId);
    await redis.sadd(`trip:${tripId}:offered_drivers`, candidate.driver_id);
    await redis.expire(`trip:${tripId}:offered_drivers`, OFFER_TTL_SECONDS);
    await publish("dispatch.trip.offer", payload);
    await emitRealtime("driver:trip_offer", `driver:${candidate.driver_id}`, payload);
  }
}

async function isCandidateStillAvailable(driverId) {
  const result = await pool.query(
    `SELECT d.id
     FROM drivers d
     WHERE d.id = $1
       AND d.is_available = TRUE
       AND d.status = 'available'
       AND d.current_trip_id IS NULL
       AND d.accepts_transport_requests = TRUE
       AND NOT EXISTS (
         SELECT 1
         FROM trips active_trip
         WHERE active_trip.driver_id = d.id
           AND active_trip.status IN ('accepted', 'arriving', 'at_pickup', 'in_progress')
       )
     LIMIT 1`,
    [driverId]
  );
  return result.rows.length > 0;
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  await pool.query(`
    ALTER TABLE drivers
      ADD COLUMN IF NOT EXISTS accepts_transport_requests BOOLEAN NOT NULL DEFAULT TRUE,
      ADD COLUMN IF NOT EXISTS accepts_delivery_requests BOOLEAN NOT NULL DEFAULT FALSE
  `);

  await pool.query(`ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS counter_offer_amount NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS counter_offer_status VARCHAR(16)`);

  await pool.query(`CREATE TABLE IF NOT EXISTS trip_driver_offers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id),
  amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  trip_revision TIMESTAMPTZ NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','accepted','ignored','unavailable')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (trip_id, driver_id)
);`);

  app.get("/health", async () => ({ status: "ok", service: "dispatch-service" }));

  app.post("/search", async (request, reply) => {
    if (rejectAuthenticatedExternalCall(request, reply)) {
      return;
    }

    const { tripId, pickupLat, pickupLng, dispatchMode, preferredDriverId } = searchSchema.parse(request.body);
    const directedDriverId = dispatchMode === "broadcast" ? null : preferredDriverId;
    const initialStage = directedDriverId ? "directed" : "broadcast";
    const initialRadiusMeters = null;
    const initialLimit = directedDriverId ? 1 : null;
    const runId = crypto.randomUUID();
    await clearTripOffers(tripId);
    await redis.set(`trip:${tripId}:dispatch_run`, runId, "EX", OFFER_TTL_SECONDS);
    await pool.query(
      `UPDATE trips
       SET status = 'searching', updated_at = NOW()
       WHERE id = $1 AND status = 'requested'`,
      [tripId]
    );

    const candidates = await findCandidateDrivers({
      pickupLat,
      pickupLng,
      preferredDriverId: directedDriverId ?? null,
      radiusMeters: initialRadiusMeters,
      limit: initialLimit
    });
    await redis.set(`trip:${tripId}:candidate_count`, String(candidates.length), "EX", OFFER_TTL_SECONDS);
    await redis.set(`trip:${tripId}:dispatch_stage`, initialStage, "EX", OFFER_TTL_SECONDS);
    await publish("dispatch.search.completed", {
      tripId,
      dispatchMode,
      stage: initialStage,
      radiusMeters: initialRadiusMeters,
      candidates: candidates.length
    });

    const fallbackInMs = 0;
    await offerTripToCandidates(tripId, candidates, initialStage);

    return {
      tripId,
      stage: initialStage,
      fallbackInMs,
      candidates
    };
  });

  app.get("/offers/:driverId", async (request, reply) => {
    const { driverId } = request.params;
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    if (!(await isCandidateStillAvailable(driverId))) return { offers: [] };

    const result = await pool.query(
      `SELECT t.id,
              t.status,
              t.dispatch_mode,
              t.preferred_driver_id,
              t.pickup_address,
              t.destination_address,
              t.requested_at,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng,
              t.fare_amount,
              proposal.amount AS my_offer_amount,
              CASE WHEN proposal.status = 'pending' AND proposal.trip_revision <> t.updated_at
                THEN 'outdated' ELSE proposal.status END AS my_offer_status,
              t.payment_method,
              t.promotional_trip,
              u.full_name AS passenger_name,
              u.phone AS passenger_phone
       FROM trips t
       LEFT JOIN users u ON u.id = t.passenger_id
       LEFT JOIN trip_driver_offers proposal ON proposal.trip_id = t.id AND proposal.driver_id = $1
       WHERE (t.dispatch_mode = 'broadcast' OR t.preferred_driver_id IS NULL OR t.preferred_driver_id = $1)
         AND t.status IN ('requested', 'searching')
       ORDER BY t.requested_at DESC`,
      [driverId]
    );

    const offers = [];
    for (const row of result.rows) {
      if (!await redis.sismember(`trip:${row.id}:rejected_drivers`, driverId)) {
        offers.push({ ...row, offer_expires_at: null });
      }
    }
    return { offers };
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
              v.vehicle_type,
              v.brand,
              v.model,
              v.color,
              v.plate,
              ST_Y(ll.location::geometry) AS lat,
              ST_X(ll.location::geometry) AS lng,
              ST_Distance(
                ll.location,
                ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
              ) AS distance_meters
       FROM drivers d
       INNER JOIN latest_locations ll ON ll.driver_id = d.id
       LEFT JOIN vehicles v ON v.driver_id = d.id
       WHERE d.is_available = TRUE
         AND d.status = 'available'
         AND d.current_trip_id IS NULL
         AND d.accepts_transport_requests = TRUE
         AND ll.recorded_at >= NOW() - INTERVAL '5 minutes'
         AND NOT EXISTS (
           SELECT 1
           FROM trips active_trip
           WHERE active_trip.driver_id = d.id
             AND active_trip.status IN ('accepted', 'arriving', 'at_pickup', 'in_progress')
         )
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

  registerDriverProposals(app, { pool, requireOwnDriverId, emitRealtime, redis, publish, schema: acceptSchema });

  app.post("/reject", async (request, reply) => {
    const { tripId, driverId } = rejectSchema.parse(request.body);
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    if (!await withdrawDriverProposal(pool, driverId, tripId)) {
      return reply.code(409).send({ message: 'La solicitud ya fue atendida o cancelada. Actualiza tus viajes.' });
    }
    await emitRealtime('trip:offers_changed', `trip:${tripId}`, { tripId });
    await redis.srem(`driver:${driverId}:offers`, tripId);
    await redis.hdel(`driver:${driverId}:offer_expires_at`, tripId);
    await redis.sadd(`trip:${tripId}:rejected_drivers`, driverId);
    await emitRealtime("driver:trip_rejected", `driver:${driverId}`, {
      tripId,
      driverId
    });
    reply.send({ ok: true });
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
