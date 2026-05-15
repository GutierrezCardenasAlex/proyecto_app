const Fastify = require("fastify");
const cors = require("@fastify/cors");
const jwt = require("@fastify/jwt");
const { Pool } = require("pg");
const Redis = require("ioredis");
const bcrypt = require("bcryptjs");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3007);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const changeDeviceStatusSchema = z.object({
  status: z.enum(["AUTORIZADO", "RECHAZADO"])
});

const changeDriverAccessSchema = z.object({
  status: z.enum(["AUTORIZADO", "RECHAZADO"]),
  note: z.string().max(500).optional()
});

const changeUserPhoneSchema = z.object({
  phone: z.string().min(8)
});

const adminUserCreateSchema = z.object({
  phone: z.string().min(8),
  role: z.enum(["passenger", "driver"]),
  firstName: z.string().min(2).max(80),
  lastName: z.string().min(2).max(80).optional().or(z.literal("")),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().max(240).optional().or(z.literal("")),
  password: z.string().min(8),
  profileCompleted: z.boolean().optional(),
  licenseNumber: z.string().min(5).max(64).optional().or(z.literal("")),
  accessStatus: z.enum(["PENDIENTE", "AUTORIZADO", "RECHAZADO"]).optional()
});

const adminUserUpdateSchema = z.object({
  phone: z.string().min(8),
  role: z.enum(["passenger", "driver"]),
  firstName: z.string().min(2).max(80),
  lastName: z.string().min(2).max(80).optional().or(z.literal("")),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().max(240).optional().or(z.literal("")),
  password: z.string().min(8).optional().or(z.literal("")),
  profileCompleted: z.boolean().optional(),
  licenseNumber: z.string().min(5).max(64).optional().or(z.literal("")),
  accessStatus: z.enum(["PENDIENTE", "AUTORIZADO", "RECHAZADO"]).optional()
});

const promoSettingsSchema = z.object({
  enabled: z.boolean(),
  cycleLength: z.number().int().min(1).max(20).optional(),
  rewardCredits: z.number().int().min(1).max(10).optional()
});

const supportReportSchema = z.object({
  category: z.string().min(2).max(60),
  message: z.string().min(8).max(1000)
});

const sendNotificationSchema = z.object({
  audience: z.enum(["all", "passengers", "drivers", "user"]),
  phone: z.string().min(8).optional(),
  kind: z.enum(["nuevo", "importante", "sistema"]).default("nuevo"),
  title: z.string().min(3).max(120),
  message: z.string().min(6).max(500)
});

const driverTripsRangeSchema = z.object({
  range: z.enum(["all", "day", "week", "month"]).default("all")
});

const driverPerformanceRangeSchema = z.object({
  range: z.enum(["day", "week", "month"]).default("day")
});

function readOfflineMapStatus() {
  const dedicatedUrlTemplate = String(process.env.MAP_OFFLINE_TILES_URL_TEMPLATE || "").trim();
  const primaryTilesUrlTemplate = String(process.env.MAP_TILES_URL_TEMPLATE || "").trim();
  const primaryLooksLikeOpenStreetMap = primaryTilesUrlTemplate.includes("tile.openstreetmap.org");
  const urlTemplate =
    dedicatedUrlTemplate ||
    (!primaryLooksLikeOpenStreetMap ? primaryTilesUrlTemplate : "");
  const regionName = String(process.env.MAP_OFFLINE_REGION_NAME || "Potosi ciudad").trim();
  let sourceHost = null;

  if (urlTemplate) {
    try {
      sourceHost = new URL(urlTemplate).host;
    } catch (error) {
      sourceHost = null;
    }
  }

  return {
    enabled: urlTemplate.length > 0,
    status: urlTemplate.length > 0 ? "HABILITADO" : "PENDIENTE",
    regionName,
    sourceHost,
    sourceType: urlTemplate.length > 0 ? "tiles-server" : "no-configurado",
    message:
      urlTemplate.length > 0
        ? `Descarga offline lista para ${regionName}.`
        : `La descarga offline de ${regionName} aun no fue habilitada por central.`
  };
}

function normalizePhone(rawPhone) {
  const digits = String(rawPhone || "").replace(/\D/g, "");
  if (digits.length === 8) {
    return `+591${digits}`;
  }
  if (digits.length === 11 && digits.startsWith("591")) {
    return `+${digits}`;
  }
  return String(rawPhone || "").replace(/\s+/g, "");
}

function getRangeSql(range) {
  switch (range) {
    case "week":
      return "NOW() - INTERVAL '7 days'";
    case "month":
      return "NOW() - INTERVAL '30 days'";
    case "day":
    default:
      return "NOW() - INTERVAL '1 day'";
  }
}

async function readAdminUserById(userId, client = pool) {
  const result = await client.query(
    `SELECT u.id AS user_id,
            u.phone,
            u.full_name,
            u.first_name,
            u.last_name,
            u.email,
            u.address,
            u.role,
            u.profile_completed,
            u.created_at,
            u.updated_at,
            d.id AS driver_id,
            d.status AS driver_status,
            d.is_available AS driver_available,
            d.access_status AS driver_access_status,
            d.license_number,
            COALESCE((SELECT COUNT(*) FROM user_devices ud WHERE ud.user_id = u.id), 0)::int AS device_count,
            COALESCE((SELECT COUNT(*) FROM user_devices ud WHERE ud.user_id = u.id AND ud.status = 'AUTORIZADO'), 0)::int AS authorized_devices,
            COALESCE((SELECT COUNT(*) FROM user_devices ud WHERE ud.user_id = u.id AND ud.status = 'PENDIENTE'), 0)::int AS pending_devices,
            COALESCE((SELECT COUNT(*) FROM support_reports sr WHERE sr.user_id = u.id AND sr.status = 'ABIERTO'), 0)::int AS support_open_count,
            COALESCE((
              SELECT COUNT(*)
              FROM trips t
              WHERE t.passenger_id = u.id
                 OR (d.id IS NOT NULL AND t.driver_id = d.id)
            ), 0)::int AS total_trips
     FROM users u
     LEFT JOIN drivers d ON d.user_id = u.id
     WHERE u.id = $1
     LIMIT 1`,
    [userId]
  );

  return result.rows[0] || null;
}

async function ensureAdminSchema() {
  await pool.query(`
    ALTER TABLE drivers
      ADD COLUMN IF NOT EXISTS access_status VARCHAR(20) NOT NULL DEFAULT 'AUTORIZADO',
      ADD COLUMN IF NOT EXISTS access_note TEXT,
      ADD COLUMN IF NOT EXISTS access_granted_at TIMESTAMPTZ
  `);

  await pool.query(`
    ALTER TABLE trips
      ADD COLUMN IF NOT EXISTS promotional_trip BOOLEAN NOT NULL DEFAULT FALSE
  `);

  await pool.query(`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS completed_trip_count INTEGER NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS promo_progress_count INTEGER NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS free_trip_credits INTEGER NOT NULL DEFAULT 0
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

  await pool.query(`
    CREATE TABLE IF NOT EXISTS support_reports (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role VARCHAR(16) NOT NULL,
      phone VARCHAR(32) NOT NULL,
      full_name VARCHAR(140),
      category VARCHAR(60) NOT NULL,
      message TEXT NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'ABIERTO',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS admin_notifications (
      id BIGSERIAL PRIMARY KEY,
      target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      target_role VARCHAR(16),
      kind VARCHAR(16) NOT NULL DEFAULT 'nuevo',
      title VARCHAR(120) NOT NULL,
      message TEXT NOT NULL,
      created_by UUID REFERENCES admin_accounts(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    ALTER TABLE admin_notifications
      ADD COLUMN IF NOT EXISTS kind VARCHAR(16) NOT NULL DEFAULT 'nuevo'
  `);
}

async function ensureAdmin(request, reply) {
  try {
    await request.jwtVerify();
  } catch (error) {
    return reply.code(401).send({ message: "No autorizado" });
  }

  if (request.user?.role !== "admin" || request.user?.accountType !== "admin") {
    return reply.code(403).send({ message: "Acceso solo para central" });
  }

  return null;
}

async function ensureUser(request, reply) {
  try {
    await request.jwtVerify();
  } catch (error) {
    return reply.code(401).send({ message: "No autorizado" });
  }

  if (request.user?.accountType !== "user") {
    return reply.code(403).send({ message: "Acceso solo para usuarios de la app" });
  }

  return null;
}

async function insertUserNotification({ userId, role, title, message, kind = "sistema", createdBy = null }) {
  await pool.query(
    `INSERT INTO admin_notifications (target_user_id, target_role, kind, title, message, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [userId, role, kind, title, message, createdBy]
  );
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await app.register(jwt, { secret: process.env.JWT_SECRET || "super-secret" });
  await ensureAdminSchema();

  app.get("/health", async () => ({ status: "ok", service: "admin-service" }));

  app.get("/dashboard", { preHandler: ensureAdmin }, async () => {
    const [drivers, trips, activeTrips, revenue, pendingDevices] = await Promise.all([
      pool.query("SELECT COUNT(*)::int AS count FROM drivers"),
      pool.query("SELECT COUNT(*)::int AS count FROM trips"),
      pool.query(
        "SELECT COUNT(*)::int AS count FROM trips WHERE status IN ('requested', 'accepted', 'arriving', 'in_progress')"
      ),
      pool.query(
        "SELECT COALESCE(SUM(fare_amount), 0)::numeric(10,2) AS total FROM trips WHERE status = 'completed'"
      ),
      pool.query("SELECT COUNT(*)::int AS count FROM user_devices WHERE status = 'PENDIENTE'")
    ]);

    return {
      drivers: drivers.rows[0].count,
      trips: trips.rows[0].count,
      activeTrips: activeTrips.rows[0].count,
      revenue: revenue.rows[0].total,
      pendingDevices: pendingDevices.rows[0].count
    };
  });

  app.get("/offline/status", { preHandler: ensureAdmin }, async () => {
    return readOfflineMapStatus();
  });

  app.get("/active-trips", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT id, passenger_id, driver_id, status, requested_at, accepted_at,
              ST_Y(pickup_location::geometry) AS pickup_lat,
              ST_X(pickup_location::geometry) AS pickup_lng,
              ST_Y(destination_location::geometry) AS destination_lat,
              ST_X(destination_location::geometry) AS destination_lng
       FROM trips
       WHERE status IN ('requested', 'accepted', 'arriving', 'in_progress')
       ORDER BY requested_at DESC
       LIMIT 100`
    );
    return result.rows;
  });

  app.get("/drivers/live", { preHandler: ensureAdmin }, async () => {
    const drivers = await pool.query(
      `SELECT id, user_id, status, is_available, current_trip_id
       FROM drivers
       ORDER BY updated_at DESC
       LIMIT 500`
    );

    const liveDrivers = await Promise.all(
      drivers.rows.map(async (driver) => ({
        ...driver,
        location: await redis.hgetall(`driver:last_location:${driver.id}`)
      }))
    );

    return liveDrivers;
  });

  app.get("/drivers/performance", { preHandler: ensureAdmin }, async (request) => {
    const { range } = driverPerformanceRangeSchema.parse(request.query || {});
    const fromSql = getRangeSql(range);

    const result = await pool.query(
      `WITH filtered_trips AS (
         SELECT t.*,
                COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at) AS event_at
         FROM trips t
         WHERE t.driver_id IS NOT NULL
           AND COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at) >= ${fromSql}
       )
       SELECT d.id AS driver_id,
              d.status AS driver_status,
              d.is_available,
              COALESCE(d.rating, 0)::numeric(10,2) AS rating,
              u.full_name,
              u.phone,
              COUNT(ft.id)::int AS total_trips,
              COUNT(*) FILTER (WHERE ft.status = 'completed')::int AS completed_trips,
              COUNT(*) FILTER (WHERE ft.status = 'cancelled')::int AS cancelled_trips,
              COUNT(*) FILTER (WHERE ft.promotional_trip = TRUE)::int AS promo_trips,
              COUNT(*) FILTER (
                WHERE COALESCE(ft.completed_at, ft.cancelled_at, ft.updated_at, ft.requested_at) >= NOW() - INTERVAL '7 days'
              )::int AS trips_this_week,
              COALESCE(SUM(CASE WHEN ft.status = 'completed' THEN ft.fare_amount ELSE 0 END), 0)::numeric(10,2) AS revenue,
              COALESCE(ROUND(AVG(CASE WHEN ft.status = 'completed' THEN ft.fare_amount END)::numeric, 2), 0)::numeric(10,2) AS average_fare,
              MAX(ft.event_at) AS last_trip_at
       FROM drivers d
       INNER JOIN users u ON u.id = d.user_id
       LEFT JOIN filtered_trips ft ON ft.driver_id = d.id
       GROUP BY d.id, d.status, d.is_available, d.rating, u.full_name, u.phone
       ORDER BY completed_trips DESC, total_trips DESC, revenue DESC, u.full_name ASC`
    );

    const rows = result.rows.map((row) => ({
      driverId: row.driver_id,
      fullName: row.full_name,
      phone: row.phone,
      driverStatus: row.driver_status,
      isAvailable: row.is_available === true,
      rating: Number(row.rating || 0),
      totalTrips: Number(row.total_trips || 0),
      completedTrips: Number(row.completed_trips || 0),
      cancelledTrips: Number(row.cancelled_trips || 0),
      promoTrips: Number(row.promo_trips || 0),
      tripsThisWeek: Number(row.trips_this_week || 0),
      revenue: Number(row.revenue || 0),
      averageFare: Number(row.average_fare || 0),
      lastTripAt: row.last_trip_at,
    }));

    const summary = rows.reduce(
      (accumulator, row) => {
        accumulator.totalTrips += row.totalTrips;
        accumulator.completedTrips += row.completedTrips;
        accumulator.cancelledTrips += row.cancelledTrips;
        accumulator.promoTrips += row.promoTrips;
        accumulator.revenue += row.revenue;
        return accumulator;
      },
      { totalTrips: 0, completedTrips: 0, cancelledTrips: 0, promoTrips: 0, revenue: 0 }
    );

    return {
      range,
      generatedAt: new Date().toISOString(),
      summary: {
        ...summary,
        activeDrivers: rows.filter((row) => row.totalTrips > 0).length,
      },
      rows
    };
  });

  app.get("/drivers/:driverId/trips", { preHandler: ensureAdmin }, async (request, reply) => {
    const { driverId } = request.params;
    const { range } = driverTripsRangeSchema.parse(request.query || {});
    const fromSql = range === "all" ? null : getRangeSql(range);

    const driverResult = await pool.query(
      `SELECT d.id,
              d.status,
              d.is_available,
              u.full_name,
              u.phone
       FROM drivers d
       INNER JOIN users u ON u.id = d.user_id
       WHERE d.id = $1
       LIMIT 1`,
      [driverId]
    );

    if (!driverResult.rows.length) {
      return reply.code(404).send({ message: "Conductor no encontrado" });
    }

    const tripsResult = await pool.query(
      `SELECT t.id,
              t.status,
              t.requested_at,
              t.accepted_at,
              t.completed_at,
              t.cancelled_at,
              t.promotional_trip,
              t.fare_amount,
              pu.full_name AS passenger_name,
              pu.phone AS passenger_phone,
              ST_Y(t.pickup_location::geometry) AS pickup_lat,
              ST_X(t.pickup_location::geometry) AS pickup_lng,
              ST_Y(t.destination_location::geometry) AS destination_lat,
              ST_X(t.destination_location::geometry) AS destination_lng
       FROM trips t
       LEFT JOIN users pu ON pu.id = t.passenger_id
       WHERE t.driver_id = $1
         AND ($2::text IS NULL OR COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at) >= ${fromSql || "COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at)"})
       ORDER BY COALESCE(t.completed_at, t.cancelled_at, t.updated_at, t.requested_at) DESC
       LIMIT 200`,
      [driverId, fromSql]
    );

    return {
      range,
      driver: {
        id: driverResult.rows[0].id,
        fullName: driverResult.rows[0].full_name,
        phone: driverResult.rows[0].phone,
        status: driverResult.rows[0].status,
        isAvailable: driverResult.rows[0].is_available === true,
      },
      trips: tripsResult.rows.map((row) => ({
        id: row.id,
        status: row.status,
        requestedAt: row.requested_at,
        acceptedAt: row.accepted_at,
        completedAt: row.completed_at,
        cancelledAt: row.cancelled_at,
        promotionalTrip: row.promotional_trip === true,
        fareAmount: row.fare_amount == null ? null : Number(row.fare_amount),
        passengerName: row.passenger_name,
        passengerPhone: row.passenger_phone,
        pickupLat: row.pickup_lat == null ? null : Number(row.pickup_lat),
        pickupLng: row.pickup_lng == null ? null : Number(row.pickup_lng),
        destinationLat: row.destination_lat == null ? null : Number(row.destination_lat),
        destinationLng: row.destination_lng == null ? null : Number(row.destination_lng),
      }))
    };
  });

  app.get("/drivers/pending-access", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT d.id,
              d.user_id,
              d.license_number,
              d.access_status,
              d.access_note,
              d.created_at,
              d.updated_at,
              u.phone,
              u.full_name,
              u.first_name,
              u.last_name
       FROM drivers d
       INNER JOIN users u ON u.id = d.user_id
       WHERE d.access_status = 'PENDIENTE'
       ORDER BY d.created_at ASC`
    );

    return result.rows;
  });

  app.get("/devices/pending", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT ud.id,
              ud.user_id,
              ud.device_identifier,
              ud.device_name,
              ud.platform,
              ud.status,
              ud.created_at,
              u.phone,
              u.full_name,
              u.role
       FROM user_devices ud
       INNER JOIN users u ON u.id = ud.user_id
       WHERE ud.status = 'PENDIENTE'
       ORDER BY ud.created_at ASC`
    );

    return result.rows;
  });

  app.get("/devices", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT ud.id,
              ud.user_id,
              ud.device_identifier,
              ud.device_name,
              ud.platform,
              ud.status,
              ud.created_at,
              ud.updated_at,
              ud.approved_at,
              u.phone,
              u.full_name,
              u.role,
              aa.full_name AS approved_by_name
       FROM user_devices ud
       INNER JOIN users u ON u.id = ud.user_id
       LEFT JOIN admin_accounts aa ON aa.id = ud.approved_by
       ORDER BY ud.updated_at DESC, ud.created_at DESC`
    );

    return result.rows;
  });

  app.get("/users", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT u.id AS user_id,
              u.phone,
              u.full_name,
              u.first_name,
              u.last_name,
              u.email,
              u.address,
              u.role,
              u.profile_completed,
              u.created_at,
              u.updated_at,
              d.id AS driver_id,
              d.status AS driver_status,
              d.is_available AS driver_available,
              d.access_status AS driver_access_status,
              d.license_number,
              COALESCE((SELECT COUNT(*) FROM user_devices ud WHERE ud.user_id = u.id), 0)::int AS device_count,
              COALESCE((SELECT COUNT(*) FROM user_devices ud WHERE ud.user_id = u.id AND ud.status = 'AUTORIZADO'), 0)::int AS authorized_devices,
              COALESCE((SELECT COUNT(*) FROM user_devices ud WHERE ud.user_id = u.id AND ud.status = 'PENDIENTE'), 0)::int AS pending_devices,
              COALESCE((SELECT COUNT(*) FROM support_reports sr WHERE sr.user_id = u.id AND sr.status = 'ABIERTO'), 0)::int AS support_open_count,
              COALESCE((
                SELECT COUNT(*)
                FROM trips t
                WHERE t.passenger_id = u.id
                   OR (d.id IS NOT NULL AND t.driver_id = d.id)
              ), 0)::int AS total_trips
       FROM users u
       LEFT JOIN drivers d ON d.user_id = u.id
       ORDER BY u.updated_at DESC, u.created_at DESC
       LIMIT 500`
    );

    return result.rows;
  });

  app.post("/users", { preHandler: ensureAdmin }, async (request, reply) => {
    const payload = adminUserCreateSchema.parse(request.body);
    const normalizedPhone = normalizePhone(payload.phone);

    if (payload.role === "driver" && !String(payload.licenseNumber || "").trim()) {
      return reply.code(400).send({ message: "La licencia es obligatoria para crear un conductor." });
    }

    const existingUser = await pool.query(`SELECT id FROM users WHERE phone = $1 LIMIT 1`, [normalizedPhone]);
    if (existingUser.rows.length) {
      return reply.code(409).send({ message: "Ya existe una cuenta con ese telefono." });
    }

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const passwordHash = await bcrypt.hash(payload.password, 10);
      const fullName = [payload.firstName, payload.lastName].filter(Boolean).join(" ").trim();

      const userResult = await client.query(
        `INSERT INTO users (phone, full_name, first_name, last_name, email, address, password_hash, profile_completed, role, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::user_role, NOW())
         RETURNING id`,
        [
          normalizedPhone,
          fullName || null,
          payload.firstName,
          payload.lastName || null,
          payload.email || null,
          payload.address || null,
          passwordHash,
          payload.profileCompleted === true,
          payload.role
        ]
      );

      const userId = userResult.rows[0].id;
      if (payload.role === "driver") {
        await client.query(
          `INSERT INTO drivers (user_id, license_number, access_status, access_granted_at)
           VALUES ($1, $2, $3, CASE WHEN $3 = 'AUTORIZADO' THEN NOW() ELSE NULL END)`,
          [userId, String(payload.licenseNumber || "").trim(), payload.accessStatus || "PENDIENTE"]
        );
      }

      await client.query("COMMIT");
      return {
        message: "Usuario creado por central",
        user: await readAdminUserById(userId)
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  });

  app.patch("/users/:userId", { preHandler: ensureAdmin }, async (request, reply) => {
    const { userId } = request.params;
    const payload = adminUserUpdateSchema.parse(request.body);
    const normalizedPhone = normalizePhone(payload.phone);

    const currentUser = await readAdminUserById(userId);
    if (!currentUser) {
      return reply.code(404).send({ message: "Usuario no encontrado" });
    }

    const phoneConflict = await pool.query(
      `SELECT id FROM users WHERE phone = $1 AND id <> $2 LIMIT 1`,
      [normalizedPhone, userId]
    );
    if (phoneConflict.rows.length) {
      return reply.code(409).send({ message: "Ese telefono ya pertenece a otra cuenta." });
    }

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const fullName = [payload.firstName, payload.lastName].filter(Boolean).join(" ").trim();
      let passwordSql = "";
      const queryParams = [
        userId,
        normalizedPhone,
        fullName || null,
        payload.firstName,
        payload.lastName || null,
        payload.email || null,
        payload.address || null,
        payload.profileCompleted === true,
        payload.role
      ];

      if (String(payload.password || "").trim()) {
        const passwordHash = await bcrypt.hash(String(payload.password).trim(), 10);
        queryParams.push(passwordHash);
        passwordSql = `, password_hash = $${queryParams.length}`;
      }

      await client.query(
        `UPDATE users
         SET phone = $2,
             full_name = $3,
             first_name = $4,
             last_name = $5,
             email = $6,
             address = $7,
             profile_completed = $8,
             role = $9::user_role,
             updated_at = NOW()
             ${passwordSql}
         WHERE id = $1`,
        queryParams
      );

      const driverResult = await client.query(`SELECT id FROM drivers WHERE user_id = $1 LIMIT 1`, [userId]);
      const existingDriverId = driverResult.rows[0]?.id || null;

      if (payload.role === "driver") {
        if (!String(payload.licenseNumber || "").trim()) {
          await client.query("ROLLBACK");
          return reply.code(400).send({ message: "La licencia es obligatoria para un usuario conductor." });
        }

        if (existingDriverId) {
          await client.query(
            `UPDATE drivers
             SET license_number = $2,
                 access_status = COALESCE($3, access_status),
                 access_granted_at = CASE WHEN COALESCE($3, access_status) = 'AUTORIZADO' THEN NOW() ELSE access_granted_at END,
                 updated_at = NOW()
             WHERE id = $1`,
            [existingDriverId, String(payload.licenseNumber || "").trim(), payload.accessStatus || null]
          );
        } else {
          await client.query(
            `INSERT INTO drivers (user_id, license_number, access_status, access_granted_at)
             VALUES ($1, $2, $3, CASE WHEN $3 = 'AUTORIZADO' THEN NOW() ELSE NULL END)`,
            [userId, String(payload.licenseNumber || "").trim(), payload.accessStatus || "PENDIENTE"]
          );
        }
      } else if (existingDriverId) {
        const tripConflict = await client.query(
          `SELECT COUNT(*)::int AS count
           FROM trips
           WHERE driver_id = $1`,
          [existingDriverId]
        );

        if (Number(tripConflict.rows[0]?.count || 0) > 0) {
          await client.query("ROLLBACK");
          return reply.code(409).send({ message: "No se puede cambiar a pasajero porque el conductor ya tiene viajes registrados." });
        }

        await client.query(`DELETE FROM drivers WHERE id = $1`, [existingDriverId]);
      }

      await client.query("COMMIT");
      return {
        message: "Usuario actualizado por central",
        user: await readAdminUserById(userId)
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  });

  app.delete("/users/:userId", { preHandler: ensureAdmin }, async (request, reply) => {
    const { userId } = request.params;
    const currentUser = await readAdminUserById(userId);
    if (!currentUser) {
      return reply.code(404).send({ message: "Usuario no encontrado" });
    }

    const tripConflict = await pool.query(
      `SELECT COUNT(*)::int AS count
       FROM trips
       WHERE passenger_id = $1
          OR ($2::uuid IS NOT NULL AND driver_id = $2::uuid)`,
      [userId, currentUser.driver_id || null]
    );

    if (Number(tripConflict.rows[0]?.count || 0) > 0) {
      return reply.code(409).send({ message: "No se puede eliminar un usuario con viajes registrados." });
    }

    await pool.query(`DELETE FROM users WHERE id = $1`, [userId]);
    return { message: "Usuario eliminado por central" };
  });

  app.get("/support/reports", { preHandler: ensureUser }, async (request) => {
    const result = await pool.query(
      `SELECT id, category, message, status, created_at
       FROM support_reports
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [request.user.sub]
    );

    return result.rows;
  });

  app.post("/support/reports", { preHandler: ensureUser }, async (request) => {
    const payload = supportReportSchema.parse(request.body);
    const userResult = await pool.query(
      `SELECT id, role, phone, full_name, first_name, last_name
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [request.user.sub]
    );

    const user = userResult.rows[0];
    const fullName =
      user?.full_name ||
      [user?.first_name, user?.last_name].filter(Boolean).join(" ").trim() ||
      user?.phone ||
      "Usuario Flash Go";

    const result = await pool.query(
      `INSERT INTO support_reports (user_id, role, phone, full_name, category, message)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, category, message, status, created_at`,
      [request.user.sub, user?.role || request.user.role || "passenger", user?.phone || "", fullName, payload.category, payload.message]
    );

    return {
      message: "Reporte enviado a central",
      report: result.rows[0]
    };
  });

  app.get("/support/reports/all", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT id, user_id, role, phone, full_name, category, message, status, created_at
       FROM support_reports
       ORDER BY created_at DESC
       LIMIT 200`
    );

    return result.rows;
  });

  app.get("/notifications/inbox", { preHandler: ensureUser }, async (request) => {
    const userResult = await pool.query(
      `SELECT role
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [request.user.sub]
    );
    const role = userResult.rows[0]?.role || request.user.role || "passenger";

    const result = await pool.query(
      `SELECT id, kind, title, message, created_at
       FROM admin_notifications
       WHERE (target_user_id = $1)
          OR (target_user_id IS NULL AND target_role = $2)
          OR (target_user_id IS NULL AND target_role = 'all')
       ORDER BY created_at DESC
       LIMIT 100`,
      [request.user.sub, role]
    );

    return result.rows;
  });

  app.post("/notifications/send", { preHandler: ensureAdmin }, async (request, reply) => {
    const payload = sendNotificationSchema.parse(request.body);
    const adminId = request.user.sub;

    if (payload.audience === "user") {
      const normalizedPhone = normalizePhone(payload.phone || "");
      const userResult = await pool.query(
        `SELECT id, role
         FROM users
         WHERE phone = $1
         LIMIT 1`,
        [normalizedPhone]
      );

      if (!userResult.rows.length) {
        return reply.code(404).send({ message: "No se encontro un usuario con ese telefono." });
      }

      await pool.query(
        `INSERT INTO admin_notifications (target_user_id, target_role, kind, title, message, created_by)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userResult.rows[0].id, userResult.rows[0].role, payload.kind, payload.title, payload.message, adminId]
      );

      return { message: "Notificacion enviada al usuario" };
    }

    const targetRole =
      payload.audience === "passengers" ? "passenger" : payload.audience === "drivers" ? "driver" : "all";

    await pool.query(
      `INSERT INTO admin_notifications (target_user_id, target_role, kind, title, message, created_by)
       VALUES (NULL, $1, $2, $3, $4, $5)`,
      [targetRole, payload.kind, payload.title, payload.message, adminId]
    );

    return { message: "Notificacion enviada correctamente" };
  });

  app.get("/promotions/settings", { preHandler: ensureAdmin }, async () => {
    const result = await pool.query(
      `SELECT enabled, cycle_length, reward_credits, updated_at
       FROM promo_settings
       WHERE id = 1
       LIMIT 1`
    );

    return {
      enabled: result.rows[0]?.enabled !== false,
      cycleLength: Number(result.rows[0]?.cycle_length || 5),
      rewardCredits: Number(result.rows[0]?.reward_credits || 1),
      updatedAt: result.rows[0]?.updated_at ?? null
    };
  });

  app.post("/promotions/settings", { preHandler: ensureAdmin }, async (request) => {
    const payload = promoSettingsSchema.parse(request.body);
    const result = await pool.query(
      `UPDATE promo_settings
       SET enabled = $1,
           cycle_length = COALESCE($2, cycle_length),
           reward_credits = COALESCE($3, reward_credits),
           updated_at = NOW()
       WHERE id = 1
       RETURNING enabled, cycle_length, reward_credits, updated_at`,
      [payload.enabled, payload.cycleLength ?? null, payload.rewardCredits ?? null]
    );

    return {
      message: payload.enabled ? "Promocion activada" : "Promocion pausada",
      settings: {
        enabled: result.rows[0]?.enabled !== false,
        cycleLength: Number(result.rows[0]?.cycle_length || 5),
        rewardCredits: Number(result.rows[0]?.reward_credits || 1),
        updatedAt: result.rows[0]?.updated_at ?? null
      }
    };
  });

  app.get("/devices/user/:userId/history", { preHandler: ensureAdmin }, async (request) => {
    const { userId } = request.params;
    const result = await pool.query(
      `SELECT ud.id,
              ud.user_id,
              ud.device_identifier,
              ud.device_name,
              ud.platform,
              ud.status,
              ud.created_at,
              ud.updated_at,
              ud.approved_at,
              ud.last_login_at,
              u.phone,
              u.full_name,
              u.role,
              aa.full_name AS approved_by_name
       FROM user_devices ud
       INNER JOIN users u ON u.id = ud.user_id
       LEFT JOIN admin_accounts aa ON aa.id = ud.approved_by
       WHERE ud.user_id = $1
       ORDER BY ud.updated_at DESC, ud.created_at DESC`,
      [userId]
    );

    return result.rows;
  });

  app.post("/devices/:deviceId/status", { preHandler: ensureAdmin }, async (request, reply) => {
    const { deviceId } = request.params;
    const { status } = changeDeviceStatusSchema.parse(request.body);
    const adminId = request.user.sub;

    const result = await pool.query(
      `UPDATE user_devices
       SET status = $2::varchar,
           approved_by = $3,
           approved_at = NOW(),
           updated_at = NOW(),
           last_login_at = CASE WHEN $2::varchar = 'AUTORIZADO' THEN NOW() ELSE last_login_at END
       WHERE id = $1
       RETURNING *`,
      [deviceId, status, adminId]
    );

    if (!result.rows.length) {
      return reply.code(404).send({ message: "Dispositivo no encontrado" });
    }

    const userResult = await pool.query(
      `SELECT id, role
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [result.rows[0].user_id]
    );
    if (userResult.rows.length) {
      await insertUserNotification({
        userId: userResult.rows[0].id,
        role: userResult.rows[0].role,
        kind: "importante",
        title: status === "AUTORIZADO" ? "Equipo autorizado" : "Equipo bloqueado",
        message:
          status === "AUTORIZADO"
            ? "La central autorizo el uso de la aplicacion en este equipo."
            : "La central bloqueo este equipo. Contacta soporte si necesitas ayuda.",
        createdBy: adminId,
      });
    }

    return {
      message: `Dispositivo ${status === "AUTORIZADO" ? "autorizado" : "rechazado"}`,
      device: result.rows[0]
    };
  });

  app.post("/devices/:deviceId/replace", { preHandler: ensureAdmin }, async (request, reply) => {
    const { deviceId } = request.params;
    const adminId = request.user.sub;
    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      const targetResult = await client.query(
        `SELECT id, user_id
         FROM user_devices
         WHERE id = $1
         FOR UPDATE`,
        [deviceId]
      );

      if (!targetResult.rows.length) {
        await client.query("ROLLBACK");
        return reply.code(404).send({ message: "Dispositivo no encontrado" });
      }

      const target = targetResult.rows[0];
      await client.query(
        `UPDATE user_devices
         SET status = 'RECHAZADO',
             approved_by = $2,
             approved_at = NOW(),
             updated_at = NOW()
         WHERE user_id = $1
           AND id <> $3`,
        [target.user_id, adminId, deviceId]
      );

      const updatedResult = await client.query(
        `UPDATE user_devices
         SET status = 'AUTORIZADO',
             approved_by = $2,
             approved_at = NOW(),
             updated_at = NOW(),
             last_login_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [deviceId, adminId]
      );

      await client.query(
        `DELETE FROM user_devices
         WHERE user_id = $1
           AND id <> $2`,
        [target.user_id, deviceId]
      );

      await client.query("COMMIT");
      return {
        message: "Equipo nuevo autorizado y registros anteriores eliminados por central",
        device: updatedResult.rows[0]
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  });

  app.post("/drivers/:driverId/access", { preHandler: ensureAdmin }, async (request, reply) => {
    const { driverId } = request.params;
    const { status, note } = changeDriverAccessSchema.parse(request.body);

    const result = await pool.query(
      `UPDATE drivers
       SET access_status = $2::varchar,
           access_note = $3,
           access_granted_at = CASE WHEN $2::varchar = 'AUTORIZADO' THEN NOW() ELSE access_granted_at END,
           updated_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [driverId, status, note ?? null]
    );

    if (!result.rows.length) {
      return reply.code(404).send({ message: "Conductor no encontrado" });
    }

    const userResult = await pool.query(
      `SELECT u.id, u.role
       FROM drivers d
       INNER JOIN users u ON u.id = d.user_id
       WHERE d.id = $1
       LIMIT 1`,
      [driverId]
    );
    if (userResult.rows.length) {
      await insertUserNotification({
        userId: userResult.rows[0].id,
        role: userResult.rows[0].role,
        kind: status === "AUTORIZADO" ? "nuevo" : "importante",
        title: status === "AUTORIZADO" ? "Acceso de conductor autorizado" : "Acceso de conductor rechazado",
        message:
          status === "AUTORIZADO"
            ? "La central ya autorizo tu acceso como conductor. Ya puedes usar el panel."
            : "La central rechazo o pauso tu acceso como conductor. Revisa con soporte para continuar.",
      });
    }

    return {
      message: status === "AUTORIZADO" ? "Conductor autorizado por central" : "Conductor rechazado por central",
      driver: result.rows[0]
    };
  });

  app.post("/users/:userId/change-phone", { preHandler: ensureAdmin }, async (request, reply) => {
    const { userId } = request.params;
    const parsed = changeUserPhoneSchema.parse(request.body);
    const normalizedPhone = normalizePhone(parsed.phone);

    const conflict = await pool.query(
      `SELECT id, role
       FROM users
       WHERE phone = $1
         AND id <> $2`,
      [normalizedPhone, userId]
    );

    if (conflict.rows.length) {
      return reply.code(409).send({ message: "Ese numero ya pertenece a otra cuenta." });
    }

    const result = await pool.query(
      `UPDATE users
       SET phone = $2,
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, phone, role, full_name`,
      [userId, normalizedPhone]
    );

    if (!result.rows.length) {
      return reply.code(404).send({ message: "Usuario no encontrado" });
    }

    return {
      message: "Telefono actualizado por central",
      user: result.rows[0]
    };
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
