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
const smsProvider = (process.env.SMS_PROVIDER || "").toLowerCase();
const exposeOtpInResponse = String(process.env.AUTH_EXPOSE_OTP || "true").toLowerCase() === "true";
const defaultAdminPhone = process.env.ADMIN_DEFAULT_PHONE || "+59170000001";
const defaultAdminUsername = (process.env.ADMIN_DEFAULT_USERNAME || "centralflashgo").trim().toLowerCase();
const defaultAdminPasswordHash =
  process.env.ADMIN_DEFAULT_PASSWORD_HASH ||
  "$2b$10$c17Q4cIl8rCYLsBdgwrNP.u.w7RFGViG6Zcmgvfy/dRsYu3fVMDna";
const defaultAdminFullName = process.env.ADMIN_DEFAULT_FULL_NAME || "Central Flash Go";
const superAdminAccessKey = String(process.env.SUPERADMIN_ACCESS_KEY || "superAdmin").trim();
const monitorUsername = String(process.env.MONITOR_USERNAME || "monitoreo").trim().toLowerCase();
const monitorPassword = String(process.env.MONITOR_PASSWORD || "Monitoreo2026").trim();
const monitorDisplayName = String(process.env.MONITOR_DISPLAY_NAME || "Monitoreo Flash Go").trim();

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
  role: z.enum(["passenger", "driver"]).default("passenger"),
  deviceIdentifier: z.string().min(3),
  deviceName: z.string().min(2).optional(),
  platform: z.string().min(2).optional()
});

const resetRequestSchema = z.object({
  phone: z.string().min(8)
});

const resetVerifySchema = z.object({
  phone: z.string().min(8),
  otp: z.string().length(6),
  password: z.string().min(8)
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

const adminLoginSchema = z.object({
  superAdminKey: z.string().min(5),
  username: z.string().min(3),
  password: z.string().min(8)
});

const monitorLoginSchema = z.object({
  username: z.string().min(3),
  password: z.string().min(8)
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

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function sendOtpSms({ phone, otp, contextLabel }) {
  if (smsProvider !== "twilio") {
    app.log.warn({ phone, contextLabel }, "SMS provider not configured. OTP delivery fallback active.");
    return false;
  }

  const accountSid = process.env.SMS_TWILIO_ACCOUNT_SID;
  const authToken = process.env.SMS_TWILIO_AUTH_TOKEN;
  const from = process.env.SMS_TWILIO_FROM;

  if (!accountSid || !authToken || !from) {
    app.log.warn({ phone, contextLabel }, "Twilio credentials missing. OTP delivery fallback active.");
    return false;
  }

  const body = new URLSearchParams({
    To: phone,
    From: from,
    Body: `Taxi Ya: tu codigo de verificacion es ${otp}. No lo compartas con nadie.`,
  });

  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${Buffer.from(`${accountSid}:${authToken}`).toString("base64")}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  }); 

  if (!response.ok) {
    const errorText = await response.text();
    app.log.error({ phone, contextLabel, errorText }, "Twilio SMS delivery failed");
    return false;
  }

  return true;
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
    profileCompleted: Boolean(user.profile_completed),
    completedTripCount: Number(user.completed_trip_count || 0),
    promoProgressCount: Number(user.promo_progress_count || 0),
    freeTripCredits: Number(user.free_trip_credits || 0)
  };
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
      username VARCHAR(80) UNIQUE,
      password_hash TEXT,
      full_name VARCHAR(120),
      otp_code VARCHAR(8),
      otp_expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    ALTER TABLE admin_accounts
      ADD COLUMN IF NOT EXISTS username VARCHAR(80),
      ADD COLUMN IF NOT EXISTS password_hash TEXT
  `);

  await pool.query(
    `INSERT INTO admin_accounts (phone, username, password_hash, full_name)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (phone)
     DO UPDATE SET username = EXCLUDED.username,
                   password_hash = EXCLUDED.password_hash,
                   full_name = EXCLUDED.full_name,
                   updated_at = NOW()`,
    [defaultAdminPhone, defaultAdminUsername, defaultAdminPasswordHash, defaultAdminFullName]
  );

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
      ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN NOT NULL DEFAULT FALSE,
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

async function issueMonitorToken() {
  return app.jwt.sign({
    sub: `monitor:${monitorUsername}`,
    role: "monitor",
    phone: null,
    accountType: "monitor"
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

function roleLabel(role) {
  return role === "driver" ? "conductor" : "pasajero";
}

async function bootstrap() {
  await app.register(cors, {
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  });
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
      `SELECT id, role, password_hash FROM users WHERE phone = $1`,
      [phone]
    );

    if (existingUser.rows.length &&
        existingUser.rows[0].password_hash &&
        existingUser.rows[0].role &&
        existingUser.rows[0].role !== role) {
      return reply.code(409).send({
        message: `Este numero ya pertenece a una cuenta de ${roleLabel(existingUser.rows[0].role)}. Cada telefono solo puede tener un rol.`
      });
    }

    if (existingUser.rows.length &&
        !existingUser.rows[0].password_hash &&
        existingUser.rows[0].role &&
        existingUser.rows[0].role !== role) {
      return reply.code(409).send({
        message: `Este numero ya inicio un registro como ${roleLabel(existingUser.rows[0].role)}.`
      });
    }

    if (existingUser.rows.length && existingUser.rows[0].password_hash) {
      return reply.code(409).send({ message: "El usuario ya existe. Inicia sesion con tu contrasena." });
    }

    const otp = generateOtp();
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

    const smsDelivered = await sendOtpSms({ phone, otp, contextLabel: "register" });

    reply.send({
      message: "OTP generado",
      smsDelivered,
      otp: exposeOtpInResponse && !smsDelivered ? otp : undefined,
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

    if (user.role && user.role !== parsed.role) {
      return reply.code(409).send({
        message: `Este numero ya esta reservado para ${roleLabel(user.role)}. Cada telefono solo puede tener un rol.`
      });
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
       RETURNING id, phone, role, full_name, first_name, last_name, email, address,
                 profile_completed, completed_trip_count, promo_progress_count, free_trip_credits`,
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
    const promo = await getPromoSettings();

    reply.send({
      token,
      status: "AUTORIZADO",
      user: mapUser({ ...updatedUser, role: parsed.role }),
      promo
    });
  });

  app.post("/login", async (request, reply) => {
    const parsed = loginSchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);

    const userResult = await pool.query(
      `SELECT id, phone, role, full_name, first_name, last_name, email, address,
              password_hash, profile_completed, completed_trip_count, promo_progress_count, free_trip_credits
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "El usuario no existe. Registrate primero." });
    }

    const user = userResult.rows[0];
    if (user.role && user.role !== parsed.role) {
      return reply.code(403).send({
        message:
          parsed.role === "driver"
            ? "Esta cuenta pertenece a pasajero y no puede entrar por el acceso de conductor."
            : "Esta cuenta pertenece a conductor y no puede entrar por el acceso de pasajero."
      });
    }
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
    const promo = await getPromoSettings();
    reply.send({
      token,
      status: "AUTORIZADO",
      user: mapUser(user),
      promo
    });
  });

  app.post("/password/request-otp", async (request, reply) => {
    const parsed = resetRequestSchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);

    const userResult = await pool.query(
      `SELECT id, phone FROM users WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "El usuario no existe." });
    }

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    await pool.query(
      `UPDATE users
       SET otp_code = $2,
           otp_expires_at = $3,
           updated_at = NOW()
       WHERE phone = $1`,
      [phone, otp, expiresAt]
    );
    await redis.set(`otp:${phone}`, otp, "EX", 300);

    const smsDelivered = await sendOtpSms({ phone, otp, contextLabel: "password-reset" });

    reply.send({
      message: "OTP de recuperacion generado",
      smsDelivered,
      otp: exposeOtpInResponse && !smsDelivered ? otp : undefined,
      expiresAt
    });
  });

  app.post("/password/reset", async (request, reply) => {
    const parsed = resetVerifySchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);
    assertValidPassword(parsed.password);

    const userResult = await pool.query(
      `SELECT id, otp_code, otp_expires_at
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "El usuario no existe." });
    }

    const user = userResult.rows[0];
    const cachedOtp = await redis.get(`otp:${phone}`);
    const validOtp = cachedOtp || user.otp_code;

    if (validOtp !== parsed.otp || !user.otp_expires_at || new Date(user.otp_expires_at) < new Date()) {
      return reply.code(400).send({ message: "OTP invalido o vencido" });
    }

    const passwordHash = await bcrypt.hash(parsed.password, 10);
    await pool.query(
      `UPDATE users
       SET password_hash = $2,
           otp_code = NULL,
           otp_expires_at = NULL,
           updated_at = NOW()
       WHERE id = $1`,
      [user.id, passwordHash]
    );
    await redis.del(`otp:${phone}`);

    reply.send({ message: "Contrasena actualizada correctamente." });
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
       RETURNING id, phone, role, full_name, first_name, last_name, email, address,
                 profile_completed, completed_trip_count, promo_progress_count, free_trip_credits`,
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

    const promo = await getPromoSettings();
    reply.send({ user: mapUser(result.rows[0]), promo });
  });

  app.get("/session-status", { preHandler: [app.authenticate] }, async (request, reply) => {
    const deviceIdentifier = String(request.query?.deviceIdentifier || "").trim();
    if (!deviceIdentifier) {
      return reply.code(400).send({ message: "deviceIdentifier es obligatorio." });
    }

    const userResult = await pool.query(
      `SELECT id, phone, role, full_name, first_name, last_name, email, address,
              profile_completed, completed_trip_count, promo_progress_count, free_trip_credits
       FROM users
       WHERE id = $1`,
      [request.user.sub]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "Usuario no encontrado." });
    }

    const deviceResult = await pool.query(
      `SELECT id, status, approved_at, updated_at
       FROM user_devices
       WHERE user_id = $1 AND device_identifier = $2
       ORDER BY updated_at DESC
       LIMIT 1`,
      [request.user.sub, deviceIdentifier]
    );

    const device = deviceResult.rows[0] ?? null;
    const promo = await getPromoSettings();
    reply.send({
      user: mapUser(userResult.rows[0]),
      promo,
      deviceStatus: device?.status || "PENDIENTE",
      deviceId: device?.id ?? null,
      approvedAt: device?.approved_at ?? null,
      updatedAt: device?.updated_at ?? null
    });
  });

  app.post("/admin/otp/request", async (request, reply) => {
    const parsed = adminRequestOtpSchema.parse(request.body);
    const phone = normalizePhone(parsed.phone);
    assertValidPhone(phone);

    const otp = generateOtp();
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
    const smsDelivered = await sendOtpSms({ phone, otp, contextLabel: "admin-login" });

    reply.send({
      message: "OTP generado",
      smsDelivered,
      otp: exposeOtpInResponse && !smsDelivered ? otp : undefined,
      expiresAt
    });
  });

  app.post("/admin/login", async (request, reply) => {
    const parsed = adminLoginSchema.parse(request.body);
    if (parsed.superAdminKey.trim() !== superAdminAccessKey) {
      return reply.code(403).send({ message: "Clave superAdmin incorrecta." });
    }

    const username = parsed.username.trim().toLowerCase();

    const adminResult = await pool.query(
      `SELECT id, phone, username, full_name, password_hash
       FROM admin_accounts
       WHERE LOWER(username) = $1`,
      [username]
    );

    if (!adminResult.rows.length) {
      return reply.code(404).send({ message: "Usuario administrativo no encontrado." });
    }

    const adminAccount = adminResult.rows[0];
    if (!adminAccount.password_hash) {
      return reply.code(400).send({ message: "La cuenta administrativa aun no tiene contrasena configurada." });
    }

    const passwordValid = await bcrypt.compare(parsed.password, adminAccount.password_hash);
    if (!passwordValid) {
      return reply.code(401).send({ message: "Contrasena incorrecta." });
    }

    reply.send({
      message: "Credenciales validadas",
      admin: {
        id: adminAccount.id,
        phone: adminAccount.phone,
        username: adminAccount.username,
        fullName: adminAccount.full_name,
        accessLevel: "admin"
      }
    });
  });

  app.post("/admin/monitor/login", async (request, reply) => {
    const parsed = monitorLoginSchema.parse(request.body);
    const username = parsed.username.trim().toLowerCase();

    if (username !== monitorUsername || parsed.password !== monitorPassword) {
      return reply.code(401).send({ message: "Credenciales de monitoreo incorrectas." });
    }

    const token = await issueMonitorToken();
    reply.send({
      token,
      admin: {
        id: "monitoring-access",
        phone: null,
        username: monitorUsername,
        fullName: monitorDisplayName,
        accessLevel: "monitor"
      }
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
        fullName: adminAccount.full_name,
        accessLevel: "admin"
      }
    });
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
