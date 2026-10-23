import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createRequestBudget } from './request-budget.mjs';
import { createHttpServer } from './http_server.mjs';

test('pair budget preserves access capacity and resets after expiry', () => {
  let time = 1000;
  const budget = createRequestBudget({ now: () => time, pairingLimit: 2, totalLimit: 3 });
  assert.equal(budget('/v1/office/pair/start').allowed, true);
  assert.equal(budget('/v1/office/pair/finish?changed=1').allowed, true);
  assert.deepEqual(budget('/v1/office/pair/approve'), { allowed: false, retryAfter: 60 });
  assert.equal(budget('/v1/office/access').allowed, true);
  assert.equal(budget('/v1/office/me').allowed, false);
  time += 60_000;
  assert.equal(budget('/v1/office/pair/start').allowed, true);
});

test('invalid configuration and clock fail closed', () => {
  for (const totalLimit of [0, -1, Infinity, 1.5]) {
    assert.throws(() => createRequestBudget({ totalLimit }));
  }
  assert.equal(createRequestBudget({ now: () => NaN })('/').allowed, false);
});

test('HTTP rejects excess requests before parsing or accessing Firebase; forwarded IP cannot reset budget', async t => {
  let calls = 0;
  const server = createHttpServer({ access: async () => { calls++; return { allowed: true }; },
    allowedOrigins: ['https://office.example'],
    requestBudget: createRequestBudget({ pairingLimit: 1 }) });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const url = `http://127.0.0.1:${server.address().port}/v1/office/pair/start`;
  const first = await fetch(url, { method: 'POST', body: '{}' });
  assert.equal(first.status, 200);
  const denied = await fetch(`${url}?alternate=1`, { method: 'POST', body: 'invalid JSON',
    headers: { Origin: 'https://office.example', 'X-Forwarded-For': '203.0.113.2' } });
  assert.equal(denied.status, 429);
  assert.ok(Number(denied.headers.get('retry-after')) > 0);
  assert.equal(denied.headers.get('access-control-allow-origin'), 'https://office.example');
  assert.equal((await denied.json()).allowed, false);
  assert.equal(calls, 1);
});
