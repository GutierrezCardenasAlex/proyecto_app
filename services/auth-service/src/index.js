const Fastify = require("fastify");
const cors = require("@fastify/cors");
const jwt = require("@fastify/jwt");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const bcrypt = require("bcryptjs");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3001);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const phoneRegex = /^\+591\d{8}$/;
const passwordRegex = /^(?=.*[A-Za-z])(?=.*\d).{8,}$/;

const registerRequestSchema = z.object({
  phone: z.string().min(8),
  role: z.enum(["passenger", "driver"]).default("passenger"),
  firstName: z.string().min(2)
});

const registerVerifySchema = z.object({
  phone: z.string().min(8),
  otp: z.string().length(6),
  password: z.string().min(8),
  role: z.enum(["passenger", "driver"]).default("passenger"),
  firstName: z.string().min(2),
  deviceIdentifier: z.string().min(3),
  deviceName: z.string().min(2).optional(),
  platform: z.string().min(2).optional()
});

const loginSchema = z.object({
  phone: z.string().min(8),
  password: z.string().min(8),
  deviceIdentifier: z.string().min(3),
  deviceName: z.string().min(2).optional(),
  platform: z.string().min(2).optional()
});

const completeProfileSchema = z.object({
  firstName: z.string().min(2),
  lastName: z.string().min(2),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().min(4).optional().or(z.literal("")),
  markCompleted: z.boolean().optional()
});

const adminRequestOtpSchema = z.object({
  phone: z.string().min(8)
});

const adminVerifyOtpSchema = z.object({
  phone: z.string().min(8),
  otp: z.string().length(6)
});

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

function assertValidPhone(phone) {
  if (!phoneRegex.test(phone)) {
    throw new Error("El numero debe tener formato +591 seguido de 8 digitos.");
  }
}

function assertValidPassword(password) {
  if (!passwordRegex.test(password)) {
    throw new Error("La contrasena debe tener al menos 8 caracteres, una letra y un numero.");
  }
}

function getFullName(firstName, lastName, fallback) {
  const merged = [firstName, lastName].filter(Boolean).join(" ").trim();
  return merged || fallback || null;
}

function mapUser(user) {
  return {
    id: user.id,
    phone: user.phone,
    role: user.role,
    fullName: user.full_name || getFullName(user.first_name, user.last_name),
    firstName: user.first_name,
    lastName: user.last_name,
    email: user.email,
    address: user.address,
    profileCompleted: Boolean(user.profile_completed)
  };
}

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
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS first_name VARCHAR(80),
      ADD COLUMN IF NOT EXISTS last_name VARCHAR(80),
      ADD COLUMN IF NOT EXISTS email VARCHAR(160),
      ADD COLUMN IF NOT EXISTS address TEXT,
      ADD COLUMN IF NOT EXISTS password_hash TEXT,
      ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT FALSE
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
       SET device_name = COALESCE($2, device_name),
           platform = COALESCE($3, platform),
           updated_at = NOW(),
           last_login_at = CASE WHEN status = 'AUTORIZADO' THEN NOW() ELSE last_login_at END
       WHERE id = $1`,
      [device.id, deviceName || null, platform || null]
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
  const now = new Date();
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
      firstDevice ? now : null,
      firstDevice ? now : null
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
  app.decorate("authenticate", async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch (error) {
      return reply.code(401).send({ message: "No autorizado" });
    }
  });

  await ensureSchema();

  app.get("/health", async () => ({ status: "ok", service: "auth-service" }));

  app.post("/register/request-otp", async (request, reply) => {
    const { role, firstName } = registerRequestSchema.parse(request.body);
    const phone = normalizePhone(request.body.phone);
    assertValidPhone(phone);
    const existingUser = await pool.query(
      `SELECT id, password_hash FROM users WHERE phone = $1`,
      [phone]
    );

    if (existingUser.rows.length && existingUser.rows[0].password_hash) {
      return reply.code(409).send({ message: "El usuario ya existe. Inicia sesion con tu contrasena." });
    }

    const otp = "123456";
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    const result = await pool.query(
      `INSERT INTO users (phone, role, full_name, first_name, otp_code, otp_expires_at, profile_completed)
       VALUES ($1, $2, $3, $3, $4, $5, FALSE)
       ON CONFLICT (phone)
       DO UPDATE SET role = EXCLUDED.role,
                     full_name = EXCLUDED.full_name,
                     first_name = EXCLUDED.first_name,
                     otp_code = EXCLUDED.otp_code,
                     otp_expires_at = EXCLUDED.otp_expires_at,
                     updated_at = NOW()
       RETURNING id, phone, role`,
      [phone, role, firstName, otp, expiresAt]
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

  app.post("/register/verify", async (request, reply) => {
    const parsed = registerVerifySchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);
    assertValidPassword(parsed.password);

    const userResult = await pool.query(
      `SELECT id, phone, role, full_name, first_name, last_name, email, address,
              otp_code, otp_expires_at, password_hash, profile_completed
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "Primero solicita tu OTP de registro." });
    }

    const user = userResult.rows[0];
    if (user.password_hash) {
      return reply.code(409).send({ message: "El usuario ya existe. Inicia sesion con tu contrasena." });
    }

    const cachedOtp = await redis.get(`otp:${phone}`);
    const validOtp = cachedOtp || user.otp_code;

    if (validOtp !== parsed.otp || !user.otp_expires_at || new Date(user.otp_expires_at) < new Date()) {
      return reply.code(400).send({ message: "OTP invalido o vencido" });
    }

    const passwordHash = await bcrypt.hash(parsed.password, 10);
    const updatedUserResult = await pool.query(
      `UPDATE users
       SET otp_code = NULL,
           otp_expires_at = NULL,
           password_hash = $2,
           role = $3,
           first_name = $4,
           full_name = $5,
           profile_completed = FALSE,
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, phone, role, full_name, first_name, last_name, email, address, profile_completed`,
      [user.id, passwordHash, parsed.role, parsed.firstName, parsed.firstName]
    );
    await redis.del(`otp:${phone}`);

    const device = await resolveDeviceAccess({
      userId: user.id,
      deviceIdentifier: parsed.deviceIdentifier,
      deviceName: parsed.deviceName,
      platform: parsed.platform
    });

    const deniedReply = sendDeviceStatus(reply, device.status);
    if (deniedReply) {
      return deniedReply;
    }

    const updatedUser = updatedUserResult.rows[0];
    const token = await issueUserToken({ ...updatedUser, role: parsed.role });

    reply.send({
      token,
      status: "AUTORIZADO",
      user: mapUser({ ...updatedUser, role: parsed.role })
    });
  });

  app.post("/login", async (request, reply) => {
    const parsed = loginSchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);

    const userResult = await pool.query(
      `SELECT id, phone, role, full_name, first_name, last_name, email, address,
              password_hash, profile_completed
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "El usuario no existe. Registrate primero." });
    }

    const user = userResult.rows[0];
    if (!user.password_hash) {
      return reply.code(400).send({ message: "Esta cuenta aun no tiene contrasena configurada." });
    }

    const passwordValid = await bcrypt.compare(parsed.password, user.password_hash);
    if (!passwordValid) {
      return reply.code(401).send({ message: "Contrasena incorrecta." });
    }

    const device = await resolveDeviceAccess({
      userId: user.id,
      deviceIdentifier: parsed.deviceIdentifier,
      deviceName: parsed.deviceName,
      platform: parsed.platform
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
    reply.send({
      token,
      status: "AUTORIZADO",
      user: mapUser(user)
    });
  });

  app.post("/profile", { preHandler: [app.authenticate] }, async (request, reply) => {
    const payload = completeProfileSchema.parse(request.body);
    const userId = request.user.sub;
    const role = request.user.role;
    const fullName = getFullName(payload.firstName, payload.lastName);
    const markCompleted = payload.markCompleted ?? role === "passenger";

    const result = await pool.query(
      `UPDATE users
       SET first_name = $2,
           last_name = $3,
           full_name = $4,
           email = $5,
           address = $6,
           profile_completed = $7,
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, phone, role, full_name, first_name, last_name, email, address, profile_completed`,
      [
        userId,
        payload.firstName,
        payload.lastName,
        fullName,
        payload.email || null,
        payload.address || null,
        markCompleted
      ]
    );

    reply.send({ user: mapUser(result.rows[0]) });
  });

  app.post("/admin/otp/request", async (request, reply) => {
    const parsed = adminRequestOtpSchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);

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
    const parsed = adminVerifyOtpSchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);

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
      validOtp !== parsed.otp ||
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
