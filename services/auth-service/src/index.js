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
  role: z.enum(["passenger", "driver", "admin"]).default("passenger"),
  fullName: z.string().min(2).optional()
});

const verifyOtpSchema = z.object({
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

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });
  await app.register(jwt, { secret: process.env.JWT_SECRET || "super-secret" });

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
      message: "OTP generated",
      otp,
      expiresAt,
      user: result.rows[0]
    });
  });

  app.post("/otp/verify", async (request, reply) => {
    const { phone, otp } = verifyOtpSchema.parse(request.body);
    const userResult = await pool.query(
      `SELECT id, phone, role, full_name, otp_code, otp_expires_at
       FROM users
       WHERE phone = $1`,
      [phone]
    );

    if (!userResult.rows.length) {
      return reply.code(404).send({ message: "User not found" });
    }

    const user = userResult.rows[0];
    const cachedOtp = await redis.get(`otp:${phone}`);
    const validOtp = cachedOtp || user.otp_code;

    if (validOtp !== otp || !user.otp_expires_at || new Date(user.otp_expires_at) < new Date()) {
      return reply.code(400).send({ message: "Invalid or expired OTP" });
    }

    await pool.query(
      "UPDATE users SET otp_code = NULL, otp_expires_at = NULL, updated_at = NOW() WHERE id = $1",
      [user.id]
    );
    await redis.del(`otp:${phone}`);

    const token = await app.jwt.sign({
      sub: user.id,
      role: user.role,
      phone: user.phone
    });

    await publishEvent("taxiya.events", "auth.otp.verified", {
      userId: user.id,
      role: user.role
    });

    reply.send({
      token,
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        fullName: user.full_name
      }
    });
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
