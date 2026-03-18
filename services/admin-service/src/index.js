const Fastify = require("fastify");
const cors = require("@fastify/cors");
const { Pool } = require("pg");
const Redis = require("ioredis");

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 3007);
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL);

async function bootstrap() {
  await app.register(cors, { origin: true, credentials: true });

  app.get("/health", async () => ({ status: "ok", service: "admin-service" }));

  app.get("/dashboard", async () => {
    const [drivers, trips, activeTrips, revenue] = await Promise.all([
      pool.query("SELECT COUNT(*)::int AS count FROM drivers"),
      pool.query("SELECT COUNT(*)::int AS count FROM trips"),
      pool.query("SELECT COUNT(*)::int AS count FROM trips WHERE status IN ('requested', 'accepted', 'arriving', 'in_progress')"),
      pool.query("SELECT COALESCE(SUM(fare_amount), 0)::numeric(10,2) AS total FROM trips WHERE status = 'completed'")
    ]);

    return {
      drivers: drivers.rows[0].count,
      trips: trips.rows[0].count,
      activeTrips: activeTrips.rows[0].count,
      revenue: revenue.rows[0].total
    };
  });

  app.get("/active-trips", async () => {
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

  app.get("/drivers/live", async () => {
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

  await app.listen({ port, host: "0.0.0.0" });
}

bootstrap().catch((error) => {
  app.log.error(error);
  process.exit(1);
});
