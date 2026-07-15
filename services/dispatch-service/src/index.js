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
const NEARBY_STAGE_RADIUS_METERS = Number(process.env.DISPATCH_NEARBY_STAGE_RADIUS_METERS || 100);
const NEARBY_STAGE_LIMIT = Number(process.env.DISPATCH_NEARBY_STAGE_LIMIT || 2);
const NEARBY_STAGE_TIMEOUT_MS = Number(process.env.DISPATCH_NEARBY_STAGE_TIMEOUT_MS || 25000);
const BROADCAST_STAGE_LIMIT = Number(process.env.DISPATCH_BROADCAST_STAGE_LIMIT || 1000);

const searchSchema = z.object({
  tripId: z.string().uuid(),
  pickupLat: z.number(),
  pickupLng: z.number(),
  dispatchMode: z.enum(["broadcast", "nearby"]).default("broadcast"),
  preferredDriverId: z.string().uuid().optional()
});

const acceptSchema = z.object({
  tripId: z.string().uuid(),
  driverId: z.string().uuid()
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
    }
  }
  await redis.del(
    offeredDriversKey,
    `trip:${tripId}:candidate_count`,
    `trip:${tripId}:dispatch_stage`,
    `trip:${tripId}:dispatch_run`,
    `trip:${tripId}:broadcast_timer`
  );
}

async function notifyTripUnavailable(tripId, acceptedDriverId) {
  const offeredDriverIds = await redis.smembers(`trip:${tripId}:offered_drivers`);
  for (const offeredDriverId of offeredDriverIds) {
    if (offeredDriverId === acceptedDriverId) {
      continue;
    }
    await emitRealtime("driver:trip_unavailable", `driver:${offeredDriverId}`, {
      tripId,
      reason: "accepted"
    });
  }
}

async function findCandidateDrivers({
  pickupLat,
  pickupLng,
  preferredDriverId = null,
  radiusMeters = null,
  limit = BROADCAST_STAGE_LIMIT,
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
     INNER JOIN latest_locations ll ON ll.driver_id = d.id
     LEFT JOIN vehicles v ON v.driver_id = d.id
     WHERE d.is_available = TRUE
       AND d.status = 'available'
       AND ll.recorded_at >= NOW() - INTERVAL '5 minutes'
       AND ($3::uuid IS NULL OR d.id = $3)
       AND NOT (d.id = ANY($4::uuid[]))
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
    await redis.sadd(`trip:${tripId}:offered_drivers`, candidate.driver_id);
    await redis.expire(`trip:${tripId}:offered_drivers`, OFFER_TTL_SECONDS);
    await publish("dispatch.trip.offer", payload);
    await emitRealtime("driver:trip_offer", `driver:${candidate.driver_id}`, payload);
  }
}

async function expandTripOffersToBroadcast({ tripId, pickupLat, pickupLng, reason, runId = null }) {
  if (runId) {
    const currentRunId = await redis.get(`trip:${tripId}:dispatch_run`);
    if (currentRunId !== runId) {
      return { expanded: false, candidates: [] };
    }
  }

  const tripResult = await pool.query(
    "SELECT status FROM trips WHERE id = $1 AND status IN ('requested', 'searching') LIMIT 1",
    [tripId]
  );
  if (!tripResult.rows.length) {
    return { expanded: false, candidates: [] };
  }

  const offeredDriverIds = await redis.smembers(`trip:${tripId}:offered_drivers`);
  const candidates = await findCandidateDrivers({
    pickupLat,
    pickupLng,
    limit: BROADCAST_STAGE_LIMIT,
    excludeDriverIds: offeredDriverIds
  });

  await redis.set(`trip:${tripId}:dispatch_stage`, "broadcast", "EX", OFFER_TTL_SECONDS);
  await redis.set(`trip:${tripId}:candidate_count`, String(offeredDriverIds.length + candidates.length), "EX", OFFER_TTL_SECONDS);
  await offerTripToCandidates(tripId, candidates, "broadcast");
  await publish("dispatch.search.expanded", {
    tripId,
    reason,
    previousCandidates: offeredDriverIds.length,
    candidates: candidates.length
  });

  return { expanded: true, candidates };
}

async function scheduleBroadcastFallback({ tripId, pickupLat, pickupLng, runId }) {
  const timerValue = await redis.set(
    `trip:${tripId}:broadcast_timer`,
    "scheduled",
    "NX",
    "PX",
    NEARBY_STAGE_TIMEOUT_MS + 10000
  );
  if (timerValue !== "OK") {
    return;
  }

  setTimeout(() => {
    expandTripOffersToBroadcast({
      tripId,
      pickupLat,
      pickupLng,
      reason: "nearby_timeout",
      runId
    }).catch((error) => {
      app.log.error({ err: error, tripId }, "failed to expand dispatch offers");
    });
  }, NEARBY_STAGE_TIMEOUT_MS);
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "dispatch-service" }));

  app.post("/search", async (request, reply) => {
    if (rejectAuthenticatedExternalCall(request, reply)) {
      return;
    }

    const { tripId, pickupLat, pickupLng, dispatchMode, preferredDriverId } = searchSchema.parse(request.body);
    const initialStage = preferredDriverId ? "directed" : "nearby";
    const initialRadiusMeters = preferredDriverId ? null : NEARBY_STAGE_RADIUS_METERS;
    const initialLimit = preferredDriverId ? 1 : NEARBY_STAGE_LIMIT;
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
      preferredDriverId: preferredDriverId ?? null,
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
    await offerTripToCandidates(tripId, candidates, initialStage);

    if (candidates.length) {
      await scheduleBroadcastFallback({ tripId, pickupLat, pickupLng, runId });
    } else {
      await expandTripOffersToBroadcast({
        tripId,
        pickupLat,
        pickupLng,
        reason: preferredDriverId ? "preferred_driver_unavailable" : "no_nearby_candidates",
        runId
      });
    }

    return {
      tripId,
      stage: initialStage,
      fallbackInMs: candidates.length ? NEARBY_STAGE_TIMEOUT_MS : 0,
      candidates
    };
  });

  app.get("/offers/:driverId", async (request, reply) => {
    const { driverId } = request.params;
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    const tripIds = await redis.smembers(`driver:${driverId}:offers`);

    if (!tripIds.length) {
      return { offers: [] };
    }

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
              t.promotional_trip,
              u.full_name AS passenger_name,
              u.phone AS passenger_phone
       FROM trips t
       LEFT JOIN users u ON u.id = t.passenger_id
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

    return {
      drivers: result.rows.map((row) => ({
        ...row,
        eta_minutes: Math.max(2, Math.round(Number(row.distance_meters) / 350))
      }))
    };
  });

  app.post("/accept", async (request, reply) => {
    const { tripId, driverId } = acceptSchema.parse(request.body);
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    const wasOffered = await redis.sismember(`driver:${driverId}:offers`, tripId);
    if (!wasOffered) {
      return reply.code(403).send({ message: "Este viaje no fue ofertado a tu conductor" });
    }

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
         WHERE id = $2
           AND status IN ('requested', 'searching')
         RETURNING *`,
        [driverId, tripId]
      );

      if (!tripUpdate.rows.length) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ message: "Trip already taken" });
      }

      const trip = tripUpdate.rows[0];

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
      await notifyTripUnavailable(tripId, driverId);
      await clearTripOffers(tripId);
      const etaResult = await pool.query(
        `WITH latest_location AS (
           SELECT DISTINCT ON (dl.driver_id)
             dl.driver_id,
             dl.location
           FROM driver_locations dl
           WHERE dl.driver_id = $1
           ORDER BY dl.driver_id, dl.recorded_at DESC
         )
         SELECT COALESCE(
           ROUND(
             ST_Distance(
               ll.location,
               t.pickup_location
             ) / 350.0
           )::int,
           2
         ) AS eta_minutes
         FROM trips t
         LEFT JOIN latest_location ll ON ll.driver_id = $1
         WHERE t.id = $2`,
        [driverId, tripId]
      );
      const etaMinutes = Math.max(2, Number(etaResult.rows[0]?.eta_minutes || 2));
      await publish("dispatch.trip.accepted", { tripId, driverId });
      await emitRealtime("trip:accepted", `trip:${tripId}`, {
        tripId,
        driverId,
        status: "accepted",
        etaMinutes
      });
      await emitRealtime("driver:trip_accepted", `driver:${driverId}`, {
        tripId,
        driverId,
        status: "accepted"
      });
      reply.send({
        ...trip,
        eta_minutes: etaMinutes
      });
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
      await redis.del(lockKey);
    }
  });

  app.post("/reject", async (request, reply) => {
    const { tripId, driverId } = rejectSchema.parse(request.body);
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    await redis.srem(`driver:${driverId}:offers`, tripId);
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
