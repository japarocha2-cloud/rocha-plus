import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccessService, DAY } from './service.mjs';
import { DEFAULT_LIMITS, validateLimits } from './devices.mjs';

// Serialized, atomic in-memory double (same contract as service.test.mjs plus sessions).
// Not a Firestore integration test.
function fixture() {
  let time = Date.UTC(2026, 10, 14);
  const accounts = new Map(), payments = new Map(), sessions = new Map();
  let queue = Promise.resolve();
  const store = { transact(uid, id, callback) {
    const run = queue.then(async () => {
      const nextAccounts = structuredClone(accounts), nextSessions = structuredClone(sessions);
      const result = await callback({ account: nextAccounts.get(uid), payment: payments.get(id),
        payments: [...payments.values()].filter(p => p.uid === uid),
        sessions: nextSessions.get(uid) ?? null,
        setAccount: data => nextAccounts.set(uid, data), setPayment: data => payments.set(id, data),
        setSessions: data => nextSessions.set(uid, data), audit: () => {},
      });
      accounts.clear(); for (const [k, v] of nextAccounts) accounts.set(k, v);
      sessions.clear(); for (const [k, v] of nextSessions) sessions.set(k, v);
      return result;
    });
    queue = run.catch(() => {});
    return run;
  }};
  const tokens = {
    user: { uid: 'one', firebase: { sign_in_provider: 'google.com' } },
    second: { uid: 'two', firebase: { sign_in_provider: 'google.com' } },
  };
  const access = createAccessService({
    verifyToken: async token => { if (!tokens[token]) throw new Error('invalid'); return tokens[token]; },
    store, plans: { monthly: { amountCents: 790, days: 30 } }, now: () => time,
  });
  const call = (path, body, token = 'user') =>
    access({ method: 'POST', path, authorization: `Bearer ${token}`, body });
  const entitle = (token = 'user') =>
    access({ method: 'GET', path: '/v1/entitlement', authorization: `Bearer ${token}` });
  return { call, entitle, sessions, advance: ms => { time += ms; } };
}

const dev = n => `device-${String(n).padStart(12, '0')}`;
const reg = (f, n, kind, token) => f.call('/v1/devices/register', { deviceId: dev(n), kind }, token);
const start = (f, n, token) => f.call('/v1/streams/start', { deviceId: dev(n) }, token);
const rejects = (promise, status, pattern) =>
  assert.rejects(promise, e => e.status === status && (!pattern || pattern.test(e.message)));

test('defaults match the commercial plan: 1 phone, 2 TVs, 2 streams', () => {
  assert.equal(DEFAULT_LIMITS.phone, 1);
  assert.equal(DEFAULT_LIMITS.tv, 2);
  assert.equal(DEFAULT_LIMITS.streams, 2);
});

test('one phone is allowed; a second phone is refused; re-registering is idempotent', async () => {
  const f = fixture();
  assert.deepEqual(await reg(f, 1, 'phone'), { registered: true, duplicate: false, kind: 'phone' });
  assert.equal((await reg(f, 1, 'phone')).duplicate, true);
  await rejects(reg(f, 2, 'phone'), 409, /Phone limit/);
});

test('two TVs are allowed; a third TV is refused', async () => {
  const f = fixture();
  await reg(f, 1, 'tv');
  await reg(f, 2, 'tv');
  await rejects(reg(f, 3, 'tv'), 409, /TV limit/);
});

test('removing a device frees its slot', async () => {
  const f = fixture();
  await reg(f, 1, 'phone');
  assert.deepEqual(await f.call('/v1/devices/remove', { deviceId: dev(1) }), { removed: true });
  await reg(f, 2, 'phone');
});

test('a device cannot change kind or use malformed identifiers', async () => {
  const f = fixture();
  await reg(f, 1, 'phone');
  await rejects(reg(f, 1, 'tv'), 409, /another kind/);
  await rejects(f.call('/v1/devices/register', { deviceId: 'short', kind: 'tv' }), 400);
  await rejects(f.call('/v1/devices/register', { deviceId: dev(9), kind: 'tablet' }), 400);
  await rejects(f.call('/v1/devices/register', { deviceId: `${dev(9)};x`, kind: 'tv' }), 400);
});

test('device IDs are stored only as hashes', async () => {
  const f = fixture();
  await reg(f, 1, 'phone');
  assert.ok(!JSON.stringify([...f.sessions.values()]).includes(dev(1)));
});

test('playback requires an entitlement; no trial is created by stream routes', async () => {
  const f = fixture();
  await reg(f, 1, 'phone');
  await rejects(start(f, 1), 403, /Entitlement/);
  await f.entitle(); // first GET starts the 7-day trial
  assert.ok((await start(f, 1)).streamId);
});

test('playback requires a registered device', async () => {
  const f = fixture();
  await f.entitle();
  await rejects(start(f, 7), 403, /not registered/);
});

test('two simultaneous streams; the third is refused; restart on a device reuses its lease', async () => {
  const f = fixture();
  await f.entitle();
  await reg(f, 1, 'phone'); await reg(f, 2, 'tv'); await reg(f, 3, 'tv');
  const first = await start(f, 1);
  await start(f, 2);
  assert.equal((await start(f, 1)).streamId, first.streamId);
  await rejects(start(f, 3), 409, /Concurrent stream limit/);
});

test('an abandoned stream frees its slot when the lease expires', async () => {
  const f = fixture();
  await f.entitle();
  await reg(f, 1, 'phone'); await reg(f, 2, 'tv'); await reg(f, 3, 'tv');
  await start(f, 1); await start(f, 2);
  f.advance(DEFAULT_LIMITS.leaseMs + 1);
  assert.ok((await start(f, 3)).streamId);
});

test('heartbeat renews only a live lease owned by the same device', async () => {
  const f = fixture();
  await f.entitle();
  await reg(f, 1, 'phone'); await reg(f, 2, 'tv');
  const { streamId } = await start(f, 1);
  f.advance(DEFAULT_LIMITS.leaseMs - 1000);
  await f.call('/v1/streams/heartbeat', { deviceId: dev(1), streamId });
  f.advance(DEFAULT_LIMITS.leaseMs - 1000);
  await f.call('/v1/streams/heartbeat', { deviceId: dev(1), streamId }); // still alive
  await rejects(f.call('/v1/streams/heartbeat', { deviceId: dev(2), streamId }), 409);
  f.advance(DEFAULT_LIMITS.leaseMs + 1);
  await rejects(f.call('/v1/streams/heartbeat', { deviceId: dev(1), streamId }), 409, /expired/);
});

test('heartbeat is refused once the entitlement expires', async () => {
  const f = fixture();
  await f.entitle();
  await reg(f, 1, 'tv');
  const { streamId } = await start(f, 1);
  f.advance(7 * DAY);
  await rejects(f.call('/v1/streams/heartbeat', { deviceId: dev(1), streamId }), 403, /Entitlement/);
});

test('stop and device removal free stream slots; stop is idempotent', async () => {
  const f = fixture();
  await f.entitle();
  await reg(f, 1, 'phone'); await reg(f, 2, 'tv'); await reg(f, 3, 'tv');
  const { streamId } = await start(f, 1);
  await start(f, 2);
  await f.call('/v1/streams/stop', { streamId });
  await f.call('/v1/streams/stop', { streamId });
  await start(f, 3);
  await f.call('/v1/devices/remove', { deviceId: dev(2) });
  await start(f, 1);
  await rejects(f.call('/v1/streams/stop', { streamId: 'not-a-uuid' }), 400);
});

test('limits are per account and the body cannot select another account', async () => {
  const f = fixture();
  await reg(f, 1, 'phone');
  await f.call('/v1/devices/register', { deviceId: dev(2), kind: 'phone', uid: 'one' }, 'second');
  await rejects(reg(f, 3, 'phone'), 409);
  await rejects(reg(f, 4, 'phone', 'second'), 409);
});

test('concurrent starts from three devices grant exactly two streams', async () => {
  const f = fixture();
  await f.entitle();
  await reg(f, 1, 'phone'); await reg(f, 2, 'tv'); await reg(f, 3, 'tv');
  const results = await Promise.allSettled([start(f, 1), start(f, 2), start(f, 3)]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 2);
  assert.equal(results.filter(r => r.status === 'rejected' && r.reason.status === 409).length, 1);
});

test('device swaps are capped per 30 days; the window rolls over', async () => {
  const f = fixture();
  for (let n = 1; n <= DEFAULT_LIMITS.removalsPer30Days; n++) {
    await reg(f, n, 'phone');
    await f.call('/v1/devices/remove', { deviceId: dev(n) });
  }
  const last = 100;
  await reg(f, last, 'phone');
  await rejects(f.call('/v1/devices/remove', { deviceId: dev(last) }), 429, /change limit/);
  // Removing an unknown device does not consume a swap.
  assert.deepEqual(await f.call('/v1/devices/remove', { deviceId: dev(999) }), { removed: false });
  f.advance(30 * DAY + 1);
  assert.deepEqual(await f.call('/v1/devices/remove', { deviceId: dev(last) }), { removed: true });
});

test('invalid limit configuration is rejected at startup', () => {
  assert.throws(() => validateLimits({ removalsPer30Days: 0 }));
  assert.throws(() => validateLimits({ phone: 0 }));
  assert.throws(() => validateLimits({ streams: 1.5 }));
  assert.throws(() => validateLimits({ leaseMs: 1000 }));
  assert.equal(validateLimits(undefined).tv, 2);
});
