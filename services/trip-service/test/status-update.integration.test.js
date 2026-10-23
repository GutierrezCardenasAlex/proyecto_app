const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');
const { randomUUID } = require('node:crypto');
const { statusUpdateQuery } = require('../src/status-update');

test('status updates cast text parameters to the PostgreSQL trip_status enum', {
  skip: !process.env.OFFER_TEST_DATABASE_URL
}, async () => {
  const client = new Client({ connectionString: process.env.OFFER_TEST_DATABASE_URL });
  await client.connect();
  await client.query('BEGIN');
  try {
    const schema = `status_test_${randomUUID().replaceAll('-', '')}`;
    await client.query(`CREATE SCHEMA ${schema}`);
    await client.query(`SET LOCAL search_path TO ${schema}`);
    await client.query("CREATE TYPE trip_status AS ENUM ('arriving','at_pickup','in_progress','completed','cancelled')");
    await client.query(`CREATE TABLE trips (id text PRIMARY KEY, status trip_status,
      counter_offer_status text, updated_at timestamptz, started_at timestamptz,
      completed_at timestamptz, cancelled_at timestamptz)`);
    await client.query("INSERT INTO trips (id,status) VALUES ('trip','arriving')");
    for (const status of ['arriving', 'at_pickup', 'in_progress', 'completed', 'cancelled']) {
      await client.query("UPDATE trips SET status='arriving', counter_offer_status=NULL");
      const result = await client.query(statusUpdateQuery(status), ['trip', status]);
      assert.equal(result.rows[0].status, status);
      assert.ok(result.rows[0].updated_at);
      const timestamp = {in_progress:'started_at', completed:'completed_at', cancelled:'cancelled_at'}[status];
      if (timestamp) assert.ok(result.rows[0][timestamp]);
    }
    await client.query("UPDATE trips SET status='arriving', counter_offer_status='pending'");
    assert.equal((await client.query(statusUpdateQuery('in_progress'), ['trip','in_progress'])).rowCount, 0);
    const cancelled = await client.query(statusUpdateQuery('cancelled'), ['trip','cancelled']);
    assert.equal(cancelled.rows[0].counter_offer_status, 'rejected');
    assert.equal((await client.query(statusUpdateQuery('arriving'), ['trip','arriving'])).rowCount, 0);
  } finally {
    await client.query('ROLLBACK');
    await client.end();
  }
});
