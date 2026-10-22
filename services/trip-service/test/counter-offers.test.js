const test = require('node:test');
const assert = require('node:assert/strict');
const { registerCounterOfferRoutes } = require('../src/counter-offers');

function harness({ role = 'passenger', authorized = true, conflict = false,
  failEvent = false, failNotification = false } = {}) {
  let handler;
  const queries = [];
  const events = [];
  let released = false;
  const client = {
    async query(sql, args) {
      queries.push({ sql, args });
      if (sql.startsWith('UPDATE trips')) {
        // Assert the actual SQL contains the atomic ownership/pending guards.
        assert.match(sql, /passenger_id = \$2 AND status = 'accepted'/);
        assert.match(sql, /counter_offer_status = 'pending'/);
        assert.match(sql, /CASE WHEN \$3 THEN counter_offer_amount ELSE fare_amount END/);
        return { rows: conflict ? [] : [{ id: args[0], passenger_id: args[1],
          driver_id: 'driver', status: args[2] ? 'arriving' : 'cancelled',
          fare_amount: args[2] ? '15.00' : '10.00' }] };
      }
      if (failEvent && sql.includes('INSERT INTO trip_events')) throw new Error('database error');
      return { rows: [] };
    },
    release() { released = true; }
  };
  const reply = { status: 200, code(n) { this.status = n; return this; },
    send(body) { this.body = body; return body; } };
  registerCounterOfferRoutes({ post(path, fn) { handler = fn; }, log: { warn() {} } }, {
    pool: { async connect() { return client; } },
    redis: { async set() { if (failNotification) throw new Error('offline'); } },
    async requireTripAccess() { return authorized ? { user: { role, sub: 'owner' } } : null; },
    async emitRealtime(event, room, payload) { events.push({ event, room, payload }); },
    async publish() {}
  });
  return { queries, events, reply, get released() { return released; },
    run: (accept) => handler({ params: { tripId: 'trip' }, body: { accept } }, reply) };
}

test('accepting Bs 15 commits the agreed fare and notifies both apps', async () => {
  const h = harness();
  const trip = await h.run(true);
  assert.equal(trip.fare_amount, '15.00');
  assert.equal(trip.status, 'arriving');
  assert.ok(h.queries.some(q => q.sql === 'COMMIT'));
  assert.ok(!h.queries.some(q => q.sql.startsWith('UPDATE drivers')));
  assert.equal(h.events.length, 2);
  assert.equal(h.events[0].payload.fareAmount, 15);
  assert.equal(h.released, true);
});

test('rejecting cancels without charging the proposed fare and releases only this reservation', async () => {
  const h = harness();
  const trip = await h.run(false);
  assert.equal(trip.status, 'cancelled');
  assert.equal(trip.fare_amount, '10.00');
  const release = h.queries.find(q => q.sql.startsWith('UPDATE drivers'));
  assert.match(release.sql, /current_trip_id = \$2/);
  assert.deepEqual(release.args, ['driver', 'trip']);
});

test('driver cannot accept their own counteroffer', async () => {
  const h = harness({ role: 'driver' });
  await h.run(true);
  assert.equal(h.reply.status, 403);
  assert.equal(h.queries.length, 0);
});

test('unauthorized caller never reaches the transaction', async () => {
  const h = harness({ authorized: false });
  await h.run(true);
  assert.equal(h.queries.length, 0);
});

test('nonboolean decisions are rejected', async () => {
  const h = harness();
  await h.run('false');
  assert.equal(h.reply.status, 400);
  assert.equal(h.queries.length, 0);
});

test('duplicate response or cancelled reservation rolls back with conflict', async () => {
  const h = harness({ conflict: true });
  await h.run(true);
  assert.equal(h.reply.status, 409);
  assert.equal(h.queries.at(-1).sql, 'ROLLBACK');
  assert.equal(h.events.length, 0);
  assert.equal(h.released, true);
});

test('database failure rolls back and releases the connection', async () => {
  const h = harness({ failEvent: true });
  await assert.rejects(h.run(false), /database error/);
  assert.equal(h.queries.at(-1).sql, 'ROLLBACK');
  assert.equal(h.released, true);
  assert.equal(h.events.length, 0);
});

test('notification outage does not undo an already committed decision', async () => {
  const h = harness({ failNotification: true });
  assert.equal((await h.run(true)).status, 'arriving');
  assert.equal(h.queries.at(-1).sql, 'COMMIT');
});
