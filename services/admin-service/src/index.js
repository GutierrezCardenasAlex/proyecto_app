const Fastify = require("fastify");
const cors = require("@fastify/cors");
const jwt = require("@fastify/jwt");
const { Pool } = require("pg");
const Redis = require("ioredis");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3007);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const changeDeviceStatusSchema = z.object({
  status: z.enum(["AUTORIZADO", "RECHAZADO"])
});

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

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await app.register(jwt, { secret: process.env.JWT_SECRET || "super-secret" });

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
       SET status = $2,
           approved_by = $3,
           approved_at = NOW(),
           updated_at = NOW(),
           last_login_at = CASE WHEN $2 = 'AUTORIZADO' THEN NOW() ELSE last_login_at END
       WHERE id = $1
       RETURNING *`,
      [deviceId, status, adminId]
    );

    if (!result.rows.length) {
      return reply.code(404).send({ message: "Dispositivo no encontrado" });
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

      await client.query("COMMIT");
      return {
        message: "Equipo reemplazado y autorizado por central",
        device: updatedResult.rows[0]
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
