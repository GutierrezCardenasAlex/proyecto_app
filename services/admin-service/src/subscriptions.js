const { z } = require('zod');

const planSchema = z.object({
  code: z.string().regex(/^[a-z0-9_-]{2,40}$/),
  name: z.string().trim().min(2).max(80),
  amount: z.number().finite().min(0).max(100000).multipleOf(0.01),
  durationDays: z.number().int().min(1).max(365),
  enabled: z.boolean(),
});
const grantSchema = z.object({
  driverId: z.uuid(),
  planCode: planSchema.shape.code,
  reference: z.string().trim().min(4).max(120),
});

async function registerSubscriptions(app, { pool, ensureAdmin, ensureUser }) {
  await pool.query(`CREATE TABLE IF NOT EXISTS subscription_plans (
    code VARCHAR(40) PRIMARY KEY, name VARCHAR(80) NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    duration_days INTEGER NOT NULL CHECK (duration_days BETWEEN 1 AND 365),
    enabled BOOLEAN NOT NULL DEFAULT FALSE, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`);
  await pool.query(`CREATE TABLE IF NOT EXISTS driver_subscriptions (
    id BIGSERIAL PRIMARY KEY, driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    plan_code VARCHAR(40) NOT NULL REFERENCES subscription_plans(code),
    plan_name VARCHAR(80) NOT NULL, amount NUMERIC(12,2) NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL, expires_at TIMESTAMPTZ NOT NULL,
    reference VARCHAR(120) NOT NULL UNIQUE, created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), CHECK (expires_at > starts_at)
  )`);
  await pool.query('CREATE INDEX IF NOT EXISTS driver_subscriptions_expiry ON driver_subscriptions(driver_id, expires_at DESC)');

  app.get('/subscriptions/plans', { preHandler: ensureAdmin }, async () => {
    return (await pool.query('SELECT * FROM subscription_plans ORDER BY duration_days, code')).rows;
  });
  app.put('/subscriptions/plans', { preHandler: ensureAdmin }, async (request, reply) => {
    const parsed = planSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ message: 'Revisa código, nombre, precio y duración del plan.' });
    const p = parsed.data;
    return (await pool.query(`INSERT INTO subscription_plans(code,name,amount,duration_days,enabled)
      VALUES ($1,$2,$3,$4,$5) ON CONFLICT(code) DO UPDATE SET name=$2, amount=$3,
      duration_days=$4, enabled=$5, updated_at=NOW() RETURNING *`,
    [p.code, p.name, p.amount, p.durationDays, p.enabled])).rows[0];
  });
  app.get('/subscriptions/grants', { preHandler: ensureAdmin }, async () => {
    return (await pool.query(`SELECT s.*, u.full_name, u.phone FROM driver_subscriptions s
      JOIN drivers d ON d.id=s.driver_id JOIN users u ON u.id=d.user_id
      ORDER BY s.created_at DESC LIMIT 200`)).rows;
  });
  app.get('/subscriptions/drivers', { preHandler: ensureAdmin }, async () => {
    return (await pool.query(`SELECT d.id, u.full_name, u.phone FROM drivers d
      JOIN users u ON u.id=d.user_id ORDER BY u.full_name, u.phone`)).rows;
  });
  app.post('/subscriptions/grants', { preHandler: ensureAdmin }, async (request, reply) => {
    const parsed = grantSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ message: 'Selecciona conductor, plan y referencia única de autorización.' });
    const { driverId, planCode, reference } = parsed.data;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      // Serialize renewals for this driver; retain paid terms when a plan changes.
      const driver = await client.query('SELECT id FROM drivers WHERE id=$1 FOR UPDATE', [driverId]);
      if (!driver.rows.length) { await client.query('ROLLBACK'); return reply.code(404).send({ message: 'Conductor no encontrado.' }); }
      const duplicate = await client.query('SELECT * FROM driver_subscriptions WHERE reference=$1', [reference]);
      if (duplicate.rows.length) {
        await client.query('ROLLBACK');
        if (duplicate.rows[0].driver_id === driverId && duplicate.rows[0].plan_code === planCode) return duplicate.rows[0];
        return reply.code(409).send({ message: 'La referencia ya se utilizó en otra autorización.' });
      }
      const plan = (await client.query('SELECT * FROM subscription_plans WHERE code=$1 AND enabled=TRUE FOR SHARE', [planCode])).rows[0];
      if (!plan) { await client.query('ROLLBACK'); return reply.code(409).send({ message: 'El plan no está activo.' }); }
      const result = await client.query(`INSERT INTO driver_subscriptions
        (driver_id,plan_code,plan_name,amount,starts_at,expires_at,reference,created_by)
        SELECT $1,$2,$3,$4,base,base+($5 * INTERVAL '1 day'),$6,$7
        FROM (SELECT GREATEST(NOW(), COALESCE(MAX(expires_at),NOW())) AS base
              FROM driver_subscriptions WHERE driver_id=$1) validity RETURNING *`,
      [driverId, planCode, plan.name, plan.amount, plan.duration_days, reference, request.user.sub]);
      await client.query('COMMIT');
      return reply.code(201).send(result.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      if (error.code === '23505') return reply.code(409).send({ message: 'Referencia ya registrada. Actualiza el listado antes de reintentar.' });
      throw error;
    } finally { client.release(); }
  });
  app.get('/subscriptions/me', { preHandler: ensureUser }, async (request, reply) => {
    if (request.user.role !== 'driver') return reply.code(403).send({ message: 'Solo para conductores.' });
    const result = await pool.query(`SELECT s.*, NOW() AS server_time,
      (s.starts_at <= NOW() AND s.expires_at > NOW()) AS active
      FROM driver_subscriptions s JOIN drivers d ON d.id=s.driver_id
      WHERE d.user_id=$1 ORDER BY s.expires_at DESC`, [request.user.sub]);
    const active = result.rows.find((row) => row.active) || null;
    return { subscription: active, history: result.rows.slice(0, 30), managedBy: 'central' };
  });
  app.get('/drivers/me/statistics', { preHandler: ensureUser }, async (request, reply) => {
    if (request.user.role !== 'driver') return reply.code(403).send({ message: 'Solo para conductores.' });
    const range = request.query?.range || 'day';
    const starts = {
      day: "date_trunc('day', NOW() AT TIME ZONE 'America/La_Paz')",
      week: "date_trunc('day', NOW() AT TIME ZONE 'America/La_Paz') - INTERVAL '6 days'",
      month: "date_trunc('month', NOW() AT TIME ZONE 'America/La_Paz')",
    };
    if (!Object.hasOwn(starts, range)) return reply.code(400).send({ message: 'Periodo inválido.' });
    const result = await pool.query(`WITH own_driver AS (
      SELECT id FROM drivers WHERE user_id=$1
    ), period AS (
      SELECT t.* FROM trips t JOIN own_driver d ON d.id=t.driver_id
      WHERE COALESCE(t.completed_at,t.requested_at) >= (${starts[range]}) AT TIME ZONE 'America/La_Paz'
        AND COALESCE(t.completed_at,t.requested_at) <= NOW()
    ) SELECT COUNT(*) FILTER (WHERE status='completed')::int AS completed,
      COUNT(*) FILTER (WHERE status='completed' AND promotional_trip=TRUE)::int AS promotional,
      COALESCE(SUM(fare_amount) FILTER (WHERE status='completed' AND fare_amount>=0),0) AS revenue,
      (SELECT COUNT(*)::int FROM trips t JOIN own_driver d ON d.id=t.driver_id WHERE status='completed') AS total_completed,
      (SELECT ROUND(AVG(score)::numeric,2) FROM trip_ratings r JOIN own_driver d ON d.id=r.to_driver_id) AS rating,
      (SELECT COUNT(*)::int FROM trip_ratings r JOIN own_driver d ON d.id=r.to_driver_id) AS rating_count
      FROM period`, [request.user.sub]);
    return result.rows[0];
  });
}

module.exports = { registerSubscriptions, planSchema, grantSchema };
