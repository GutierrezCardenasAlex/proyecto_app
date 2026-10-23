const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const Fastify = require('fastify');
const { Pool } = require('pg');
const { z } = require('zod');
const { registerDriverOfferRoutes } = require('../src/driver-offers');
const { registerDriverProposals, withdrawDriverProposal } = require('../../dispatch-service/src/driver-proposals');

// Only run against an explicitly supplied disposable PostgreSQL instance.
test('driver offer marketplace with real PostgreSQL transactions', {
  skip: !process.env.OFFER_TEST_DATABASE_URL
}, async (t) => {
  const schema = `offers_test_${crypto.randomBytes(6).toString('hex')}`;
  const admin = new Pool({ connectionString: process.env.OFFER_TEST_DATABASE_URL });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const pool = new Pool({ connectionString: process.env.OFFER_TEST_DATABASE_URL,
    options: `-c search_path=${schema},public`, max: 10 });
  const app = Fastify();
  t.after(async () => {
    await app.close();
    await pool.end();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  await pool.query(`
    CREATE FUNCTION uuid_generate_v4() RETURNS uuid LANGUAGE SQL AS 'SELECT gen_random_uuid()';
    CREATE TYPE trip_status AS ENUM ('requested','searching','accepted','arriving','at_pickup','in_progress','completed','cancelled');
    CREATE TABLE users (id uuid PRIMARY KEY, full_name text);
    CREATE TABLE drivers (id uuid PRIMARY KEY, user_id uuid REFERENCES users,
      rating numeric DEFAULT 4.8, status text DEFAULT 'available', is_available boolean DEFAULT true,
      accepts_transport_requests boolean DEFAULT true, current_trip_id uuid, updated_at timestamptz DEFAULT NOW());
    CREATE TABLE vehicles (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), driver_id uuid REFERENCES drivers,
      vehicle_type text, brand text, model text, plate text, color text);
    CREATE TABLE trips (id uuid PRIMARY KEY, passenger_id uuid REFERENCES users,
      driver_id uuid REFERENCES drivers, status trip_status DEFAULT 'searching', dispatch_mode text DEFAULT 'broadcast',
      preferred_driver_id uuid, fare_amount numeric(10,2) DEFAULT 10, promotional_trip boolean DEFAULT false,
      accepted_at timestamptz, updated_at timestamptz DEFAULT NOW());
    CREATE TABLE trip_events (trip_id uuid, event_type text, payload jsonb);
  `);
  const source = fs.readFileSync(path.resolve(__dirname, '../../../infra/postgres/schema.sql'), 'utf8');
  const offersDdl = source.match(/CREATE TABLE IF NOT EXISTS trip_driver_offers \([\s\S]*?\);/)[0];
  await pool.query(offersDdl);
  const emitRealtime = async () => {};
  registerDriverProposals(app, { pool, emitRealtime,
    schema: z.object({ tripId: z.string().uuid(), driverId: z.string().uuid(),
      counterFare: z.number().min(0).max(99999999.99).multipleOf(0.01).optional() }),
    requireOwnDriverId: async (req, reply, id) => {
      if (req.headers['x-driver-id'] !== id) { reply.code(403).send({}); return null; }
      return { sub: id };
    }
  });
  registerDriverOfferRoutes(app, { pool, emitRealtime, redis: { set: async () => {} }, publish: async () => {},
    requireTripAccess: async (req, reply, id) => {
      const result = await pool.query('SELECT * FROM trips WHERE id=$1', [id]);
      if (result.rows[0]?.passenger_id !== req.headers['x-passenger-id']) {
        reply.code(403).send({}); return null;
      }
      return { user: { role: 'passenger', sub: req.headers['x-passenger-id'] } };
    }
  });
  await app.ready();
  async function fixture() {
    await pool.query('TRUNCATE users, drivers, vehicles, trips, trip_events, trip_driver_offers CASCADE');
    const passenger = crypto.randomUUID(), driver1 = crypto.randomUUID(), driver2 = crypto.randomUUID();
    const trip1 = crypto.randomUUID(), trip2 = crypto.randomUUID();
    for (const [id, name] of [[passenger, 'Pasajero'], [driver1, 'Conductor uno'], [driver2, 'Conductor dos']]) {
      await pool.query('INSERT INTO users VALUES ($1,$2)', [id, name]);
    }
    for (const id of [driver1, driver2]) await pool.query('INSERT INTO drivers(id,user_id) VALUES ($1,$1)', [id]);
    for (const id of [trip1, trip2]) await pool.query('INSERT INTO trips(id,passenger_id) VALUES ($1,$2)', [id, passenger]);
    return { passenger, driver1, driver2, trip1, trip2 };
  }
  const bid = (driverId, tripId, amount) => app.inject({ method: 'POST', url: '/accept',
    headers: { 'x-driver-id': driverId }, payload: { driverId, tripId, counterFare: amount } });
  const decide = (f, tripId, offer, accept = true, amount = Number(offer.amount)) => app.inject({
    method: 'POST', url: `/${tripId}/offers/${offer.id}/response`,
    headers: { 'x-passenger-id': f.passenger }, payload: { accept, expectedAmount: amount } });

  for (const mode of ['broadcast', 'nearby']) {
    await t.test(`${mode}: accepting without a new price preserves Bs 10`, async () => {
      const f = await fixture();
      await pool.query('UPDATE trips SET dispatch_mode=$2, preferred_driver_id=$3 WHERE id=$1',
        [f.trip1, mode, mode === 'nearby' ? f.driver1 : null]);
      const response = await bid(f.driver1, f.trip1);
      assert.equal(response.statusCode, 200);
      const offer = response.json().proposal;
      assert.equal(Number(offer.amount), 10);
      assert.equal((await decide(f, f.trip1, offer)).statusCode, 200);
      const trip = (await pool.query('SELECT * FROM trips WHERE id=$1', [f.trip1])).rows[0];
      assert.equal(Number(trip.fare_amount), 10);
      assert.equal(trip.driver_id, f.driver1);
    });

    await t.test(`${mode}: Bs 15 stays pending until the passenger accepts`, async () => {
      const f = await fixture();
      await pool.query('UPDATE trips SET dispatch_mode=$2, preferred_driver_id=$3 WHERE id=$1',
        [f.trip1, mode, mode === 'nearby' ? f.driver1 : null]);
      const offer = (await bid(f.driver1, f.trip1, 15)).json().proposal;
      await pool.query("UPDATE trip_driver_offers SET created_at=NOW()-INTERVAL '1 hour' WHERE id=$1", [offer.id]);
      const list = await app.inject({ url: `/${f.trip1}/offers`, headers: { 'x-passenger-id': f.passenger } });
      assert.equal(Number(list.json().offers[0].amount), 15);
      const pending = (await pool.query('SELECT * FROM trips WHERE id=$1', [f.trip1])).rows[0];
      assert.equal(pending.driver_id, null);
      assert.equal(Number(pending.fare_amount), 10);
      assert.equal((await decide(f, f.trip1, offer)).statusCode, 200);
      assert.equal(Number((await pool.query('SELECT fare_amount FROM trips WHERE id=$1', [f.trip1])).rows[0].fare_amount), 15);
    });
  }

  await t.test('multiple drivers bid without reservation; ignoring preserves the request', async () => {
    const f = await fixture();
    const a = (await bid(f.driver1, f.trip1, 15)).json().proposal;
    const b = (await bid(f.driver2, f.trip1, 12)).json().proposal;
    assert.ok(a && b);
    assert.equal((await pool.query('SELECT driver_id FROM trips WHERE id=$1', [f.trip1])).rows[0].driver_id, null);
    assert.equal((await pool.query('SELECT COUNT(*)::int AS n FROM drivers WHERE is_available')).rows[0].n, 2);
    const list = await app.inject({ url: `/${f.trip1}/offers`, headers: { 'x-passenger-id': f.passenger } });
    assert.deepEqual(list.json().offers.map(o => Number(o.amount)), [12, 15]);
    assert.equal((await decide(f, f.trip1, a, false)).statusCode, 200);
    assert.equal((await pool.query('SELECT status FROM trips WHERE id=$1', [f.trip1])).rows[0].status, 'searching');
    assert.equal((await bid(f.driver1, f.trip1, 14)).statusCode, 409);
    assert.equal((await decide(f, f.trip1, b)).statusCode, 200);
    const trip = (await pool.query('SELECT * FROM trips WHERE id=$1', [f.trip1])).rows[0];
    assert.equal(trip.status, 'arriving');
    assert.equal(Number(trip.fare_amount), 12);
    assert.equal(trip.driver_id, f.driver2);
  });

  await t.test('simultaneous choices for one trip assign exactly one driver', async () => {
    const f = await fixture();
    const a = (await bid(f.driver1, f.trip1, 15)).json().proposal;
    const b = (await bid(f.driver2, f.trip1, 12)).json().proposal;
    const responses = await Promise.all([decide(f, f.trip1, a), decide(f, f.trip1, b)]);
    assert.deepEqual(responses.map(r => r.statusCode).sort(), [200, 409]);
    assert.equal((await pool.query("SELECT COUNT(*)::int AS n FROM drivers WHERE status='busy'")).rows[0].n, 1);
  });

  await t.test('one driver cannot be assigned to two trips concurrently', async () => {
    const f = await fixture();
    const a = (await bid(f.driver1, f.trip1, 15)).json().proposal;
    const b = (await bid(f.driver1, f.trip2, 14)).json().proposal;
    const responses = await Promise.all([decide(f, f.trip1, a), decide(f, f.trip2, b)]);
    assert.deepEqual(responses.map(r => r.statusCode).sort(), [200, 409]);
    assert.equal((await pool.query("SELECT COUNT(*)::int AS n FROM trips WHERE status='arriving'")).rows[0].n, 1);
  });

  await t.test('stale price or changed route cannot be silently accepted', async () => {
    const f = await fixture();
    const a = (await bid(f.driver1, f.trip1, 15)).json().proposal;
    await bid(f.driver1, f.trip1, 16);
    assert.equal((await decide(f, f.trip1, a)).statusCode, 409);
    await pool.query("UPDATE trips SET updated_at=updated_at + INTERVAL '1 microsecond' WHERE id=$1", [f.trip1]);
    assert.equal((await decide(f, f.trip1, a, true, 16)).statusCode, 409);
    const list = await app.inject({ url: `/${f.trip1}/offers`, headers: { 'x-passenger-id': f.passenger } });
    assert.equal(list.json().offers.length, 0);
    const refreshed = (await bid(f.driver1, f.trip1, 16)).json().proposal;
    assert.equal((await decide(f, f.trip1, refreshed)).statusCode, 200);
  });

  await t.test('cancelled requests, invalid prices and another passenger are rejected', async () => {
    const f = await fixture();
    assert.equal((await bid(f.driver1, f.trip1, -1)).statusCode, 400);
    const a = (await bid(f.driver1, f.trip1, 15)).json().proposal;
    const other = await app.inject({ method: 'POST', url: `/${f.trip1}/offers/${a.id}/response`,
      headers: { 'x-passenger-id': f.driver2 }, payload: { accept: true, expectedAmount: 15 } });
    assert.equal(other.statusCode, 403);
    await pool.query("UPDATE trips SET status='cancelled' WHERE id=$1", [f.trip1]);
    assert.equal((await decide(f, f.trip1, a)).statusCode, 409);
    assert.equal((await bid(f.driver2, f.trip1, 12)).statusCode, 409);
  });

  await t.test('Tomar taxi directed requests only permit the selected driver', async () => {
    const f = await fixture();
    await pool.query("UPDATE trips SET dispatch_mode='nearby', preferred_driver_id=$2 WHERE id=$1", [f.trip1, f.driver1]);
    assert.equal((await bid(f.driver2, f.trip1, 12)).statusCode, 409);
    const a = (await bid(f.driver1, f.trip1, 11)).json().proposal;
    assert.equal((await decide(f, f.trip1, a, false)).statusCode, 200);
    assert.equal((await pool.query('SELECT status FROM trips WHERE id=$1', [f.trip1])).rows[0].status, 'searching');
  });

  await t.test('withdrawing a proposal cannot silently erase a concurrently confirmed trip', async () => {
    const f = await fixture();
    const a = (await bid(f.driver1, f.trip1, 15)).json().proposal;
    const [withdrawn, decision] = await Promise.all([
      withdrawDriverProposal(pool, f.driver1, f.trip1), decide(f, f.trip1, a)
    ]);
    assert.equal(decision.statusCode, withdrawn ? 409 : 200);
    const row = (await pool.query('SELECT * FROM trips WHERE id=$1', [f.trip1])).rows[0];
    assert.equal(row.status, withdrawn ? 'searching' : 'arriving');
    assert.equal(row.driver_id, withdrawn ? null : f.driver1);
  });
});
