const test = require('node:test');
const assert = require('node:assert/strict');
const Fastify = require('fastify');
const { registerSubscriptions, planSchema, grantSchema } = require('../src/subscriptions');

test('plan validation rejects invalid amounts and durations', () => {
  const valid = { code: 'semanal', name: 'Semanal', amount: 30, durationDays: 7, enabled: true };
  assert.ok(planSchema.safeParse(valid).success);
  for (const change of [{ amount: -1 }, { amount: Infinity }, { durationDays: 0 }, { durationDays: 1.5 }, { durationDays: 366 }, { code: '../plan' }]) {
    assert.equal(planSchema.safeParse({ ...valid, ...change }).success, false);
  }
  assert.equal(grantSchema.safeParse({ driverId: 'other', planCode: 'semanal', reference: 'ref-1' }).success, false);
});

test('routes require role checks and scope subscription lookup to authenticated user', async () => {
  const app = Fastify();
  const calls = [];
  const pool = { query: async (sql, params) => { calls.push({ sql, params }); return { rows: [] }; } };
  const guard = (role) => async (request, reply) => {
    if (request.headers.authorization !== role) return reply.code(403).send({ message: 'Denied' });
    request.user = { sub: 'authenticated-user', role: role === 'user' ? 'driver' : 'admin' };
  };
  await registerSubscriptions(app, { pool, ensureAdmin: guard('admin'), ensureUser: guard('user') });
  for (const url of ['/subscriptions/plans', '/subscriptions/grants', '/subscriptions/drivers', '/subscriptions/me']) {
    assert.equal((await app.inject({ method: 'GET', url })).statusCode, 403);
  }
  const response = await app.inject({ method: 'GET', url: '/subscriptions/me?userId=victim', headers: { authorization: 'user' } });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(calls.at(-1).params, ['authenticated-user']);
  assert.equal(response.json().subscription, null);
  assert.equal((await app.inject({ method: 'PUT', url: '/subscriptions/plans', headers: { authorization: 'admin' }, payload: {} })).statusCode, 400);
  await app.close();
});
