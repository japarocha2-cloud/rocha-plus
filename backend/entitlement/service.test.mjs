import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccessService, DAY } from './service.mjs';

function fixture() {
  let time = Date.UTC(2026, 9, 22);
  const accounts = new Map(), payments = new Map(), audit = [];
  let queue = Promise.resolve();
  const store = { transact(uid, id, callback) {
    // A serialized, atomic in-memory double; not a Firestore integration test.
    const run = queue.then(async () => {
      const nextAccounts = structuredClone(accounts), nextPayments = structuredClone(payments);
      const nextAudit = structuredClone(audit);
      const result = await callback({ account: nextAccounts.get(uid), payment: nextPayments.get(id),
        payments: [...nextPayments.values()].filter(p => p.uid === uid),
        setAccount: data => nextAccounts.set(uid, data), setPayment: data => nextPayments.set(id, data),
        audit: (action, data) => nextAudit.push({ action, ...data }),
      });
      accounts.clear(); for (const [key, value] of nextAccounts) accounts.set(key, value);
      payments.clear(); for (const [key, value] of nextPayments) payments.set(key, value);
      audit.splice(0, audit.length, ...nextAudit);
      return result;
    });
    queue = run.catch(() => {});
    return run;
  }};
  const tokens = {
    user: { uid: 'one', firebase: { sign_in_provider: 'google.com' } },
    second: { uid: 'two', firebase: { sign_in_provider: 'apple.com' } },
    anonymous: { uid: 'guest', firebase: { sign_in_provider: 'anonymous' } },
    admin: { uid: 'operator', firebase: { sign_in_provider: 'google.com' }, rochaAdmin: true },
    fakeAdmin: { uid: 'one', firebase: { sign_in_provider: 'google.com' }, rochaAdmin: 'true' },
  };
  const verifierCalls = [];
  const access = createAccessService({
    verifyToken: async (token, checkRevoked) => {
      verifierCalls.push({ token, checkRevoked });
      if (!tokens[token]) throw new Error('invalid, expired, revoked or unavailable');
      return tokens[token];
    }, store, plans: { monthly: { amountCents: 450, days: 30 } }, now: () => time,
  });
  const get = (token = 'user', body = {}) => access({ method: 'GET', path: '/v1/entitlement',
    authorization: `Bearer ${token}`, body });
  const approve = (overrides = {}, token = 'admin') => access({ method: 'POST', path: '/v1/admin/confirm',
    authorization: `Bearer ${token}`, body: { uid: 'one', provider: 'manual-fixture', transactionId: 'txn1',
      evidenceReference: 'TEST-ONLY-bank-statement-record', plan: 'monthly', amountCents: 450, currency: 'BRL', ...overrides } });
  const refund = (overrides = {}) => access({ method: 'POST', path: '/v1/admin/refund',
    authorization: 'Bearer admin', body: { uid: 'one', provider: 'manual-fixture', transactionId: 'txn1',
      evidenceReference: 'TEST-ONLY-refund-confirmation', ...overrides } });
  return { access, get, approve, refund, accounts, payments, audit, store, verifierCalls,
    advance: days => { time += days * DAY; }, now: () => time };
}
const rejectsStatus = (promise, status) => assert.rejects(promise, e => e.status === status);

test('missing/invalid/revoked tokens and unsupported providers never create trial', async () => {
  const f = fixture();
  await rejectsStatus(f.access({ method: 'GET', path: '/v1/entitlement' }), 401);
  await rejectsStatus(f.get('expired-or-revoked'), 401);
  await rejectsStatus(f.get('anonymous'), 401);
  assert.equal(f.accounts.size, 0);
  assert.ok(f.verifierCalls.every(call => call.checkRevoked === true));
});

test('UID comes from verified token; client UID, paid flag and clock are ignored', async () => {
  const f = fixture();
  const result = await f.get('user', { uid: 'two', allowed: true, now: 1, paidThrough: 9999999999999 });
  assert.equal(result.uid, 'one');
  assert.equal(f.accounts.has('two'), false);
  assert.equal(f.accounts.get('one').trialEndsAtMs, f.now() + 7 * DAY);
});

test('trial lasts exactly seven days and reinstatement of the same UID never restarts it', async () => {
  const f = fixture();
  await f.get(); const first = structuredClone(f.accounts.get('one'));
  f.advance(6); assert.equal((await f.get()).allowed, true);
  f.advance(1); assert.equal((await f.get()).allowed, false);
  f.advance(50); assert.equal((await f.get()).allowed, false);
  assert.deepEqual(f.accounts.get('one'), first);
});

test('parallel first requests produce a single stable trial', async () => {
  const f = fixture();
  const results = await Promise.all(Array.from({ length: 10 }, () => f.get()));
  assert.equal(f.accounts.size, 1);
  assert.equal(new Set(results.map(r => r.expiresAt)).size, 1);
});

test('unprivileged clients and string admin claim cannot confirm or self-grant payment', async () => {
  const f = fixture();
  await rejectsStatus(f.approve({}, 'user'), 403);
  await rejectsStatus(f.approve({}, 'fakeAdmin'), 403);
  assert.equal(f.payments.size, 0); assert.equal(f.audit.length, 0);
});

test('wrong price, missing evidence and unknown plan cannot be approved', async () => {
  const f = fixture();
  await rejectsStatus(f.approve({ amountCents: 1 }), 400);
  await rejectsStatus(f.approve({ evidenceReference: '' }), 400);
  await rejectsStatus(f.approve({ plan: 'inherited' }), 400);
  await rejectsStatus(f.approve({ currency: 'USD' }), 400);
  assert.equal(f.payments.size, 0);
});

test('expired trial remains blocked until administrator confirmation, then paid access expires', async () => {
  const f = fixture();
  await f.get(); f.advance(8);
  assert.equal((await f.get()).allowed, false);
  await f.approve();
  assert.equal((await f.get()).allowed, true);
  assert.equal(f.audit[0].adminUid, 'operator');
  f.advance(30); assert.equal((await f.get()).allowed, false);
});

test('payment retry and concurrent duplication never extend the paid period twice', async () => {
  const f = fixture(); await f.get(); f.advance(8);
  const results = await Promise.all([f.approve(), f.approve()]);
  assert.equal(results.filter(r => !r.duplicate).length, 1);
  const expires = (await f.get()).expiresAt;
  f.advance(1); await f.approve();
  assert.equal((await f.get()).expiresAt, expires);
  assert.equal(f.payments.size, 1); assert.equal(f.audit.length, 1);
});

test('one bank transaction cannot be credited to a different account or plan', async () => {
  const f = fixture(); await f.approve();
  await rejectsStatus(f.approve({ uid: 'two' }), 409);
  assert.equal(f.payments.size, 1);
});

test('renewal preserves unused days and expires at the server boundary', async () => {
  const f = fixture(); await f.get(); f.advance(8); await f.approve();
  const firstExpiry = Date.parse((await f.get()).expiresAt);
  f.advance(15); await f.approve({ transactionId: 'txn2' });
  assert.equal(Date.parse((await f.get()).expiresAt), firstExpiry + 30 * DAY);
  f.advance(44); assert.equal((await f.get()).allowed, true);
  f.advance(1); assert.equal((await f.get()).allowed, false);
});

test('refund removes its grant, is idempotent and cannot be reapproved', async () => {
  const f = fixture(); await f.get(); f.advance(8); await f.approve();
  await f.refund(); assert.equal((await f.get()).allowed, false);
  assert.equal((await f.refund()).duplicate, true);
  await rejectsStatus(f.approve(), 409);
  assert.equal(f.audit.length, 2);
});

test('refund does not remove an independent valid payment or restart trial', async () => {
  const f = fixture(); await f.get(); f.advance(8); await f.approve();
  f.advance(1); await f.approve({ transactionId: 'txn2' });
  await f.refund();
  assert.equal((await f.get()).allowed, true);
  assert.equal(Date.parse((await f.get()).expiresAt), f.now() + 30 * DAY);
  f.advance(30); assert.equal((await f.get()).allowed, false);
});

test('unknown refund and arbitrary pending-payment route never grant access', async () => {
  const f = fixture();
  await rejectsStatus(f.refund(), 404);
  await rejectsStatus(f.access({ method: 'POST', path: '/v1/payment/pending', authorization: 'Bearer user' }), 404);
  assert.equal(f.payments.size, 0);
});

test('storage outage rejects rather than returning an allowed response', async () => {
  const access = createAccessService({ verifyToken: async () => ({ uid: 'one', firebase: { sign_in_provider: 'google.com' } }),
    store: { transact: async () => { throw new Error('network unavailable'); } }, plans: {}, now: () => Date.now() });
  await assert.rejects(access({ method: 'GET', path: '/v1/entitlement', authorization: 'Bearer valid' }), /network unavailable/);
});

test('invalid server plan configuration fails startup', () => {
  assert.throws(() => createAccessService({ plans: { bad: { days: 0, amountCents: 450 } } }), /configuration/);
});
