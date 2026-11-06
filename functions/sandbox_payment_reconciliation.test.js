'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {reconcileSandboxPayment} = require('./sandbox_payment_reconciliation');

const orderId = '12345678-1234-1234-1234-123456789abc';
function fixture(overrides = {}, orderChanges = {}) {
  const rows = new Map([
    ['sandbox_checkout_orders/' + orderId, {uid: 'new-test-account', mode: 'sandbox',
      merchantId: '700', currency: 'BRL', plan: 'monthly',
      amountCents: 790, preferenceId: 'sandbox-pref', ...orderChanges}],
    ['entitlements/new-test-account', {paidUntil: 'REAL-ACCESS-MUST-NOT-CHANGE'}],
    ['payment_events/42', {uid: 'real-client', status: 'approved'}],
  ]);
  const writes = [];
  const db = {
    collection: name => ({doc: id => name + '/' + id}),
    runTransaction: async fn => {
      const staged = [];
      const value = await fn({
        get: async ref => ({exists: rows.has(ref), data: () => rows.get(ref)}),
        set: (ref, data, opts) => staged.push([ref, data, opts]),
      });
      for (const [ref, data, opts] of staged) {
        writes.push(ref);
        rows.set(ref, opts?.merge ? {...rows.get(ref), ...data} : data);
      }
      return value;
    },
  };
  const payment = {id: '42', liveMode: false, merchantId: '700',
    currency: 'BRL', externalReference: orderId,
    status: 'approved', statusDetail: 'accredited', refundedAmount: 0,
    amount: 7.9, dateApproved: '2026-11-05T12:00:00Z', ...overrides};
  const run = () => reconcileSandboxPayment({db, paymentId: '42',
    accessToken: 'sandbox-token', merchantId: '700', testUid: 'new-test-account',
    fetchPayment: async () => payment});
  return {run, rows, writes};
}

test('approved sandbox payment writes only sandbox collections', async () => {
  const f = fixture();
  const r = await f.run();
  assert.equal(r.sandbox, true);
  assert.equal(r.approved, true);
  assert.equal(r.testPaidUntil, '2026-12-05T12:00:00.000Z');
  assert.deepEqual(f.writes.sort(), ['sandbox_entitlements/new-test-account',
    'sandbox_payment_events/42']);
  assert.equal(f.rows.get('entitlements/new-test-account').paidUntil,
    'REAL-ACCESS-MUST-NOT-CHANGE');
  assert.equal(f.rows.get('payment_events/42').uid, 'real-client');
});

test('live payment cannot enter sandbox collections', async () => {
  const f = fixture({liveMode: true});
  await assert.rejects(f.run(), /provider identity/);
  assert.deepEqual(f.writes, []);
});

test('wrong test account cannot claim payment', async () => {
  const f = fixture({}, {uid: 'another-test-account'});
  await assert.rejects(f.run(), /order mismatch/);
  assert.deepEqual(f.writes, []);
});

test('wrong merchant, amount, and external reference are rejected', async t => {
  for (const changes of [
    {merchantId: '999'}, {externalReference: 'not-an-order'},
  ]) {
    await t.test(JSON.stringify(changes), async () => {
      const f = fixture(changes);
      await assert.rejects(f.run());
      assert.deepEqual(f.writes, []);
    });
  }
  const f = fixture({amount: 0.01});
  const r = await f.run();
  assert.equal(r.approved, false);
  assert.equal(r.testPaidUntil, null);
});

test('refund cannot retain sandbox access', async () => {
  const f = fixture({status: 'refunded', refundedAmount: 7.9});
  const r = await f.run();
  assert.equal(r.approved, false);
  assert.equal(r.testPaidUntil, null);
  assert.equal(f.rows.get('entitlements/new-test-account').paidUntil,
    'REAL-ACCESS-MUST-NOT-CHANGE');
});

test('repeated sandbox reconciliation does not extend access', async () => {
  const f = fixture();
  const a = await f.run(); const b = await f.run();
  assert.equal(a.testPaidUntil, b.testPaidUntil);
  assert.equal(f.rows.get('sandbox_payment_events/42').paymentId, '42');
});
