const Fastify = require("fastify");
const cors = require("@fastify/cors");
const { Pool } = require("pg");
const Redis = require("ioredis");
const amqp = require("amqplib");
const { z } = require("zod");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3002);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

const driverProfileSchema = z.object({
  userId: z.string().uuid(),
  licenseNumber: z.string().min(4),
  vehicle: z.object({
    plate: z.string().min(4),
    brand: z.string().min(2),
    model: z.string().min(1),
    color: z.string().min(2),
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

async function publish(routingKey, payload) {
  const connection = await amqp.connect(process.env.RABBITMQ_URL);
  const channel = await connection.createChannel();
  await channel.assertExchange("taxiya.events", "topic", { durable: true });
  channel.publish("taxiya.events", routingKey, Buffer.from(JSON.stringify(payload)));
  setTimeout(() => connection.close(), 250);
}

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "driver-service" }));

  app.post("/profile", async (request, reply) => {
    const { userId, licenseNumber, vehicle } = driverProfileSchema.parse(request.body);
    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      const driverResult = await client.query(
        `INSERT INTO drivers (user_id, license_number, status, is_available)
         VALUES ($1, $2, 'offline', FALSE)
         ON CONFLICT (user_id)
         DO UPDATE SET license_number = EXCLUDED.license_number, updated_at = NOW()
         RETURNING *`,
        [userId, licenseNumber]
      );

      const driver = driverResult.rows[0];
      await client.query(
        `INSERT INTO vehicles (driver_id, plate, brand, model, color, year)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (driver_id)
         DO UPDATE SET plate = EXCLUDED.plate,
                       brand = EXCLUDED.brand,
                       model = EXCLUDED.model,
                       color = EXCLUDED.color,
                       year = EXCLUDED.year,
                       updated_at = NOW()`,
        [driver.id, vehicle.plate, vehicle.brand, vehicle.model, vehicle.color, vehicle.year || null]
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
    const status = isAvailable ? "available" : "offline";
    const result = await pool.query(
      `UPDATE drivers
       SET is_available = $2, status = $3, updated_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [driverId, isAvailable, status]
    );

    if (!result.rows.length) {
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
        `INSERT INTO drivers (user_id, license_number, status, is_available)
         VALUES ($1, $2, 'offline', FALSE)
         RETURNING *`,
        [userId, `TEMP-${String(userId).slice(0, 8).toUpperCase()}`]
      );

      const driver = driverResult.rows[0];
      const plateSuffix = String(driver.id).slice(0, 4).toUpperCase();
      await client.query(
        `INSERT INTO vehicles (driver_id, plate, brand, model, color, year)
         VALUES ($1, $2, 'Toyota', 'Vitz', 'Blanco', 2020)`,
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

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
