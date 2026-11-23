const { test } = require('node:test');
const assert = require('node:assert/strict');
const Fastify = require('fastify');
const { registerLegalSettings } = require('./legal-settings');
const { isPublicLegalRequest } = require('../../gateway-api/src/public-legal');

test('gateway only exposes exact read-only legal routes', () => {
  assert.equal(isPublicLegalRequest({ method: 'GET', url: '/api/admin/public/legal/privacidad?lang=es' }), true);
  for (const url of ['/api/admin/settings/legal', '/api/admin/users', '/api/admin/public/legal/privacidad/other', '/api/admin/public/legal/../settings/legal']) {
    assert.equal(isPublicLegalRequest({ method: 'GET', url }), false);
  }
  assert.equal(isPublicLegalRequest({ method: 'PUT', url: '/api/admin/public/legal/config' }), false);
});

test('drafts are private, publishing validates data, edits appear in safe public HTML', async t => {
  const app = Fastify();
  t.after(() => app.close());
  let row;
  const pool = { query: async (sql, args) => {
    if (sql.startsWith('INSERT')) row = { value: args[0], updated_at: '2026-11-23' };
    return { rows: row ? [row] : [] };
  } };
  registerLegalSettings(app, { pool, ensureAdmin: async (request, reply) => {
    if (request.headers.authorization !== 'Bearer admin-test') return reply.code(403).send({ message: 'Forbidden' });
  } });
  assert.equal((await app.inject('/settings/legal')).statusCode, 403);
  assert.equal((await app.inject('/public/legal/config')).statusCode, 503);
  const headers = { authorization: 'Bearer admin-test' };
  const defaults = (await app.inject({ url: '/settings/legal', headers })).json();
  delete defaults.updatedAt;
  assert.equal((await app.inject({ method: 'PUT', url: '/settings/legal', payload: defaults })).statusCode, 403);
  assert.equal((await app.inject({ method: 'PUT', url: '/settings/legal', headers, payload: { ...defaults, published: true } })).statusCode, 400);
  const data = { ...defaults, legalName: 'Responsable de prueba', address: 'Dirección de prueba', email: 'privacy@example.test', retention: 'Plazos de prueba', providers: '<script>alert(1)</script>', deletionTime: 'Plazo de prueba', published: true };
  assert.equal((await app.inject({ method: 'PUT', url: '/settings/legal', headers, payload: data })).statusCode, 200);
  const page = await app.inject('/public/legal/privacidad');
  assert.equal(page.statusCode, 200);
  assert.ok(page.body.includes('&lt;script&gt;'));
  assert.ok(!page.body.includes('<script>'));
  assert.equal(page.headers['cache-control'], 'no-store');
  data.email = 'new@example.test';
  await app.inject({ method: 'PUT', url: '/settings/legal', headers, payload: data });
  assert.ok((await app.inject('/public/legal/eliminar-cuenta')).body.includes('mailto:new@example.test'));
  data.published = false;
  await app.inject({ method: 'PUT', url: '/settings/legal', headers, payload: data });
  assert.equal((await app.inject('/public/legal/privacidad')).statusCode, 503);
});
