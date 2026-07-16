const Fastify = require("fastify");
const cors = require("@fastify/cors");
const crypto = require("crypto");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3002);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const looseFieldPattern = /^(temp|temporal|pendiente|sin dato|sin datos|n\/a|na|test|prueba)$/i;

function realTextSchema(min, label) {
  return z
    .string()
    .trim()
    .min(min, `${label} es obligatorio.`)
    .refine((value) => !looseFieldPattern.test(value), `${label} no puede ser generico.`);
}

const driverProfileSchema = z.object({
  userId: z.string().uuid(),
  licenseNumber: realTextSchema(4, "La licencia")
    .refine((value) => !value.toUpperCase().startsWith("TEMP-"), "Ingresa una licencia real."),
  licenseCategory: z.string().trim().min(1).max(8).optional().or(z.literal("")),
  licenseIssueDate: z.string().trim().min(4).max(32).optional().or(z.literal("")),
  licenseExpiryDate: z.string().trim().min(4).max(32).optional().or(z.literal("")),
  vehicle: z.object({
    type: z.enum(["taxi", "moto"]).default("taxi"),
    plate: realTextSchema(4, "La placa")
      .refine((value) => !/^POT-[0-9A-F]{4}$/i.test(value), "Ingresa una placa real."),
    brand: realTextSchema(2, "La marca"),
    model: realTextSchema(1, "El modelo"),
    color: realTextSchema(2, "El color"),
    year: z.number().int().min(1990).max(2100).optional()
  })
});

const availabilitySchema = z.object({
  driverId: z.string().uuid(),
  isAvailable: z.boolean()
});

const ensureProfileSchema = z.object({
  userId: z.string().uuid(),
  fullName: z.string().min(2).optional(),
  phone: z.string().min(8).optional()
});

const driverAccessSchema = z.object({
  status: z.enum(["AUTORIZADO", "RECHAZADO"]),
  note: z.string().max(500).optional()
});

async function publish(routingKey, payload) {
  const connection = await amqp.connect(process.env.RABBITMQ_URL);
  const channel = await connection.createChannel();
  await channel.assertExchange("taxiya.events", "topic", { durable: true });
  channel.publish("taxiya.events", routingKey, Buffer.from(JSON.stringify(payload)));
  setTimeout(() => connection.close(), 250);
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

async function requireUserToken(request, reply) {
  const user = verifyJwtFromRequest(request, reply);
  if (!user) {
    return null;
  }
  if (user.accountType !== "user") {
    reply.code(403).send({ message: "Acceso solo para usuarios de la app" });
    return null;
  }
  request.user = user;
  return user;
}

async function requireAdminToken(request, reply) {
  const user = verifyJwtFromRequest(request, reply);
  if (!user) {
    return null;
  }
  if (user.accountType !== "admin" || user.role !== "admin") {
    reply.code(403).send({ message: "Acceso solo para central" });
    return null;
  }
  request.user = user;
  return user;
}

async function requireDriverUser(request, reply) {
  const user = await requireUserToken(request, reply);
  if (!user) {
    return null;
  }
  if (user.role !== "driver") {
    reply.code(403).send({ message: "Acceso solo para conductores" });
    return null;
  }
  return user;
}

async function requireOwnUserId(request, reply, userId) {
  const user = await requireDriverUser(request, reply);
  if (!user) {
    return null;
  }
  if (user.sub !== userId) {
    reply.code(403).send({ message: "No puedes modificar otro conductor" });
    return null;
  }
  return user;
}

async function requireOwnDriverId(request, reply, driverId) {
  const user = await requireDriverUser(request, reply);
  if (!user) {
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

  return user;
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  await pool.query(`
    ALTER TABLE vehicles
    ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(16) NOT NULL DEFAULT 'taxi'
  `);

  await pool.query(`
    ALTER TABLE drivers
      ADD COLUMN IF NOT EXISTS access_status VARCHAR(20) NOT NULL DEFAULT 'AUTORIZADO',
      ADD COLUMN IF NOT EXISTS access_note TEXT,
      ADD COLUMN IF NOT EXISTS access_granted_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS license_category VARCHAR(16),
      ADD COLUMN IF NOT EXISTS license_issue_date VARCHAR(32),
      ADD COLUMN IF NOT EXISTS license_expiry_date VARCHAR(32)
  `);

  app.get("/health", async () => ({ status: "ok", service: "driver-service" }));

  app.post("/profile", async (request, reply) => {
    const { userId, licenseNumber, licenseCategory, licenseIssueDate, licenseExpiryDate, vehicle } = driverProfileSchema.parse(request.body);
    const user = await requireOwnUserId(request, reply, userId);
    if (!user) return;

    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      const driverResult = await client.query(
        `INSERT INTO drivers (user_id, license_number, license_category, license_issue_date, license_expiry_date, status, is_available)
         VALUES ($1, $2, $3, $4, $5, 'offline', FALSE)
         ON CONFLICT (user_id)
         DO UPDATE SET license_number = EXCLUDED.license_number,
                       license_category = COALESCE(EXCLUDED.license_category, drivers.license_category),
                       license_issue_date = COALESCE(EXCLUDED.license_issue_date, drivers.license_issue_date),
                       license_expiry_date = COALESCE(EXCLUDED.license_expiry_date, drivers.license_expiry_date),
                       updated_at = NOW()
         RETURNING *`,
        [userId, licenseNumber, licenseCategory || null, licenseIssueDate || null, licenseExpiryDate || null]
      );

      const driver = driverResult.rows[0];
      await client.query(
        `INSERT INTO vehicles (driver_id, vehicle_type, plate, brand, model, color, year)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (driver_id)
         DO UPDATE SET vehicle_type = EXCLUDED.vehicle_type,
                       plate = EXCLUDED.plate,
                       brand = EXCLUDED.brand,
                       model = EXCLUDED.model,
                       color = EXCLUDED.color,
                       year = EXCLUDED.year,
                       updated_at = NOW()`,
        [
          driver.id,
          vehicle.type,
          vehicle.plate,
          vehicle.brand,
          vehicle.model,
          vehicle.color,
          vehicle.year || null
        ]
      );
      await client.query("COMMIT");

      await publish("driver.profile.updated", { driverId: driver.id, userId });
      reply.send({ driver });
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  });

  app.patch("/availability", async (request, reply) => {
    const { driverId, isAvailable } = availabilitySchema.parse(request.body);
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    const status = isAvailable ? "available" : "offline";
    const result = await pool.query(
      `UPDATE drivers
       SET is_available = $2, status = $3, updated_at = NOW()
       WHERE id = $1
         AND access_status = 'AUTORIZADO'
       RETURNING *`,
      [driverId, isAvailable, status]
    );

    if (!result.rows.length) {
      const accessCheck = await pool.query(
        `SELECT id, access_status FROM drivers WHERE id = $1`,
        [driverId]
      );
      if (accessCheck.rows.length && accessCheck.rows[0].access_status !== "AUTORIZADO") {
        return reply.code(403).send({ message: "Tu cuenta de conductor aun no fue autorizada por central." });
      }
      return reply.code(404).send({ message: "Driver not found" });
    }

    await redis.hset(`driver:${driverId}`, {
      id: driverId,
      status,
      isAvailable: String(isAvailable)
    });
    await publish("driver.availability.changed", { driverId, status, isAvailable });

    reply.send({ driver: result.rows[0] });
  });

  app.post("/ensure-profile", async (request, reply) => {
    const { userId } = ensureProfileSchema.parse(request.body);
    const user = await requireOwnUserId(request, reply, userId);
    if (!user) return;

    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      const existing = await client.query(
        `SELECT d.*, row_to_json(v.*) AS vehicle
         FROM drivers d
         LEFT JOIN vehicles v ON v.driver_id = d.id
         WHERE d.user_id = $1`,
        [userId]
      );

      if (existing.rows.length) {
        await client.query("COMMIT");
        return reply.send({ driver: existing.rows[0] });
      }

      const driverResult = await client.query(
        `INSERT INTO drivers (user_id, license_number, status, is_available, access_status)
         VALUES ($1, $2, 'offline', FALSE, 'PENDIENTE')
         RETURNING *`,
        [userId, `TEMP-${String(userId).slice(0, 8).toUpperCase()}`]
      );

      const driver = driverResult.rows[0];
      const plateSuffix = String(driver.id).slice(0, 4).toUpperCase();
      await client.query(
        `INSERT INTO vehicles (driver_id, vehicle_type, plate, brand, model, color, year)
         VALUES ($1, 'taxi', $2, 'Toyota', 'Vitz', 'Blanco', 2020)`,
        [driver.id, `POT-${plateSuffix}`]
      );

      const result = await client.query(
        `SELECT d.*, row_to_json(v.*) AS vehicle
         FROM drivers d
         LEFT JOIN vehicles v ON v.driver_id = d.id
         WHERE d.id = $1`,
        [driver.id]
      );

      await client.query("COMMIT");
      await publish("driver.profile.updated", { driverId: driver.id, userId });
      reply.code(201).send({ driver: result.rows[0] });
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  });

  app.get("/by-user/:userId", async (request, reply) => {
    const { userId } = request.params;
    const user = await requireOwnUserId(request, reply, userId);
    if (!user) return;

    const result = await pool.query(
      `SELECT d.*, row_to_json(v.*) AS vehicle
       FROM drivers d
       LEFT JOIN vehicles v ON v.driver_id = d.id
       WHERE d.user_id = $1`,
      [userId]
    );

    if (!result.rows.length) {
      return reply.code(404).send({ message: "Driver not found" });
    }

    reply.send(result.rows[0]);
  });

  app.get("/:driverId", async (request, reply) => {
    const { driverId } = request.params;
    const user = await requireOwnDriverId(request, reply, driverId);
    if (!user) return;

    const result = await pool.query(
      `SELECT d.*, row_to_json(v.*) AS vehicle
       FROM drivers d
       LEFT JOIN vehicles v ON v.driver_id = d.id
       WHERE d.id = $1`,
      [driverId]
    );

    if (!result.rows.length) {
      return reply.code(404).send({ message: "Driver not found" });
    }

    reply.send(result.rows[0]);
  });

  app.post("/:driverId/access", async (request, reply) => {
    const admin = await requireAdminToken(request, reply);
    if (!admin) return;

    const { driverId } = request.params;
    const { status, note } = driverAccessSchema.parse(request.body);
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
      return reply.code(404).send({ message: "Driver not found" });
    }

    await publish("driver.access.updated", {
      driverId,
      status,
    });

    reply.send({ driver: result.rows[0] });
  });

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
