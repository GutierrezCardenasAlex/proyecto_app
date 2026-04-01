const Fastify = require("fastify");
const cors = require("@fastify/cors");
const jwt = require("@fastify/jwt");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3001);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const requestOtpSchema = z.object({
  phone: z.string().min(8),
  role: z.enum(["passenger", "driver"]).default("passenger"),
  fullName: z.string().min(2).optional()
});

const verifyOtpSchema = z.object({
  phone: z.string().min(8),
  otp: z.string().length(6),
  deviceIdentifier: z.string().min(3),
  deviceName: z.string().min(2).optional(),
  platform: z.string().min(2).optional()
});

const adminRequestOtpSchema = z.object({
  phone: z.string().min(8)
});

const adminVerifyOtpSchema = z.object({
  phone: z.string().min(8),
  otp: z.string().length(6)
});

async function publishEvent(exchange, routingKey, payload) {
  const connection = await amqp.connect(process.env.RABBITMQ_URL);
  const mqChannel = await connection.createChannel();
  await mqChannel.assertExchange(exchange, "topic", { durable: true });
  mqChannel.publish(exchange, routingKey, Buffer.from(JSON.stringify(payload)), {
    contentType: "application/json",
    persistent: true
  });
  setTimeout(() => connection.close(), 250);
}

async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS admin_accounts (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      phone VARCHAR(32) UNIQUE NOT NULL,
      full_name VARCHAR(120),
      otp_code VARCHAR(8),
      otp_expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_devices (
      id BIGSERIAL PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_identifier VARCHAR(255) NOT NULL,
      device_name VARCHAR(100),
      platform VARCHAR(32),
      status VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      approved_by UUID REFERENCES admin_accounts(id) ON DELETE SET NULL,
      approved_at TIMESTAMPTZ,
      last_login_at TIMESTAMPTZ,
      CONSTRAINT chk_user_devices_status
        CHECK (status IN ('PENDIENTE', 'AUTORIZADO', 'RECHAZADO'))
    )
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS uq_user_devices_user_identifier
      ON user_devices (user_id, device_identifier)
  `);
}

async function issueUserToken(user) {
  return app.jwt.sign({
    sub: user.id,
    role: user.role,
    phone: user.phone,
    accountType: "user"
  });
}

async function issueAdminToken(adminAccount) {
  return app.jwt.sign({
    sub: adminAccount.id,
    role: "admin",
    phone: adminAccount.phone,
    accountType: "admin"
  });
}

async function resolveDeviceAccess({ userId, deviceIdentifier, deviceName, platform }) {
  const existingDevice = await pool.query(
    `SELECT id, status
     FROM user_devices
     WHERE user_id = $1 AND device_identifier = $2`,
    [userId, deviceIdentifier]
  );

  if (existingDevice.rows.length) {
    const device = existingDevice.rows[0];
    await pool.query(
      `UPDATE user_devices
       SET device_name = COALESCE($3, device_name),
           platform = COALESCE($4, platform),
           updated_at = NOW(),
           last_login_at = CASE WHEN status = 'AUTORIZADO' THEN NOW() ELSE last_login_at END
       WHERE id = $1`,
      [device.id, userId, deviceName || null, platform || null]
    );
    return device;
  }

  const authorizedCountResult = await pool.query(
    `SELECT COUNT(*)::int AS count
     FROM user_devices
     WHERE user_id = $1
       AND status = 'AUTORIZADO'`,
    [userId]
  );

  const firstDevice = Number(authorizedCountResult.rows[0]?.count || 0) === 0;
  const status = firstDevice ? "AUTORIZADO" : "PENDIENTE";
  const insertResult = await pool.query(
    `INSERT INTO user_devices (
       user_id,
       device_identifier,
       device_name,
       platform,
       status,
       approved_at,
       last_login_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (user_id, device_identifier)
     DO UPDATE SET
       device_name = EXCLUDED.device_name,
       platform = EXCLUDED.platform,
       updated_at = NOW()
     RETURNING id, status`,
    [
      userId,
      deviceIdentifier,
      deviceName || null,
      platform || null,
      status,
      firstDevice ? new Date() : null,
      firstDevice ? new Date() : null
    ]
  );

  return insertResult.rows[0];
}

function sendDeviceStatus(reply, status) {
  if (status === "PENDIENTE") {
    return reply.code(202).send({
      status: "PENDIENTE",
      message: "Solicitud pendiente de aprobacion por la central."
    });
  }

  if (status === "RECHAZADO") {
    return reply.code(403).send({
      status: "RECHAZADO",
      message: "Este dispositivo no esta autorizado. La central debe liberarlo."
    });
  }

  return null;
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await app.register(jwt, { secret: process.env.JWT_SECRET || "super-secret" });
  await ensureSchema();

  app.get("/health", async () => ({ status: "ok", service: "auth-service" }));

  app.post("/otp/request", async (request, reply) => {
    const { phone, role, fullName } = requestOtpSchema.parse(request.body);
    const otp = "123456";
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    const result = await pool.query(
      `INSERT INTO users (phone, role, full_name, otp_code, otp_expires_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (phone)
       DO UPDATE SET role = EXCLUDED.role,
                     full_name = COALESCE(EXCLUDED.full_name, users.full_name),
                     otp_code = EXCLUDED.otp_code,
                     otp_expires_at = EXCLUDED.otp_expires_at,
                     updated_at = NOW()
       RETURNING id, phone, role`,
      [phone, role, fullName || null, otp, expiresAt]
    );

    await redis.set(`otp:${phone}`, otp, "EX", 300);
    await publishEvent("taxiya.events", "auth.otp.requested", {
      phone,
      role,
      userId: result.rows[0].id
    });

    reply.send({
      message: "OTP generado",
      otp,
      expiresAt,
      user: result.rows[0]
    });
  });

  app.post("/otp/verify", async (request, reply) => {
    const { phone, otp, deviceIdentifier, deviceName, platform } = verifyOtpSchema.parse(request.body);
    const userResult = await pool.query(
      `SELECT id, phone, role, full_name, otp_code, otp_expires_at
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "Usuario no encontrado" });
    }

    const user = userResult.rows[0];
    const cachedOtp = await redis.get(`otp:${phone}`);
    const validOtp = cachedOtp || user.otp_code;

    if (validOtp !== otp || !user.otp_expires_at || new Date(user.otp_expires_at) < new Date()) {
      return reply.code(400).send({ message: "OTP invalido o vencido" });
    }

    await pool.query(
      "UPDATE users SET otp_code = NULL, otp_expires_at = NULL, updated_at = NOW() WHERE id = $1",
      [user.id]
    );
    await redis.del(`otp:${phone}`);

    const device = await resolveDeviceAccess({
      userId: user.id,
      deviceIdentifier,
      deviceName,
      platform
    });

    const deniedReply = sendDeviceStatus(reply, device.status);
    if (deniedReply) {
      await publishEvent("taxiya.events", "auth.device.status", {
        userId: user.id,
        deviceId: device.id,
        status: device.status
      });
      return deniedReply;
    }

    const token = await issueUserToken(user);
    await publishEvent("taxiya.events", "auth.otp.verified", {
      userId: user.id,
      role: user.role,
      deviceId: device.id
    });

    reply.send({
      token,
      status: "AUTORIZADO",
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        fullName: user.full_name
      }
    });
  });

  app.post("/admin/otp/request", async (request, reply) => {
    const { phone } = adminRequestOtpSchema.parse(request.body);
    const otp = "123456";
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    const adminResult = await pool.query(
      `UPDATE admin_accounts
       SET otp_code = $2,
           otp_expires_at = $3,
           updated_at = NOW()
       WHERE phone = $1
       RETURNING id, phone, full_name`,
      [phone, otp, expiresAt]
    );

    if (!adminResult.rows.length) {
      return reply.code(404).send({ message: "Administrador no encontrado" });
    }

    await redis.set(`admin-otp:${phone}`, otp, "EX", 300);
    reply.send({
      message: "OTP generado",
      otp,
      expiresAt
    });
  });

  app.post("/admin/otp/verify", async (request, reply) => {
    const { phone, otp } = adminVerifyOtpSchema.parse(request.body);
    const adminResult = await pool.query(
      `SELECT id, phone, full_name, otp_code, otp_expires_at
       FROM admin_accounts
       WHERE phone = $1`,
      [phone]
    );

    if (!adminResult.rows.length) {
      return reply.code(404).send({ message: "Administrador no encontrado" });
    }

    const adminAccount = adminResult.rows[0];
    const cachedOtp = await redis.get(`admin-otp:${phone}`);
    const validOtp = cachedOtp || adminAccount.otp_code;

    if (
      validOtp !== otp ||
      !adminAccount.otp_expires_at ||
      new Date(adminAccount.otp_expires_at) < new Date()
    ) {
      return reply.code(400).send({ message: "OTP invalido o vencido" });
    }

    await pool.query(
      `UPDATE admin_accounts
       SET otp_code = NULL,
           otp_expires_at = NULL,
           updated_at = NOW()
       WHERE id = $1`,
      [adminAccount.id]
    );
    await redis.del(`admin-otp:${phone}`);

    const token = await issueAdminToken(adminAccount);
    reply.send({
      token,
      admin: {
        id: adminAccount.id,
        phone: adminAccount.phone,
        fullName: adminAccount.full_name
      }
    });
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
