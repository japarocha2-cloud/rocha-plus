'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const {normalizePayment, inspectPayment} = require('./mercadopago_reconciliation');
test('reject missing payment identity', () => {
  assert.throws(() => normalizePayment({status: 'approved'}));
});
test('normalize does not grant entitlements', () => {
  const p = normalizePayment({id: 123, status: 'approved',
    transaction_amount: 4.5, currency_id: 'BRL'});
  assert.equal(p.id, '123');
  assert.equal('paidUntil' in p, false);
  assert.equal('uid' in p, false);
});
test('untrusted receipt is not approved without provider credentials', async () => {
  await assert.rejects(inspectPayment('123', ''), /missing Mercado Pago credential/);
});

test('snapshot reconciliation cannot overwrite reviewed entitlement ledger', async t => {
  const {recordVerifiedPayment} = require('./mercadopago_reconciliation');
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  global.fetch = async () => ({ok: true, json: async () => ({
    id: 123, status: 'approved', status_detail: 'accredited',
    live_mode: true, collector_id: 999, transaction_amount: 4.5,
    transaction_amount_refunded: 0, currency_id: 'BRL',
    date_approved: '2026-01-20T10:00:00Z',
  })});
  const reviewed = {uid: 'account-1', paymentId: '123',
    reviewed: true, plan: 'annual', status: 'approved',
    eligibleForReview: true, approvalDate: '2026-01-20T10:00:00Z'};
  const rows = new Map([
    ['payment_claims/123', {uid: 'account-1', reviewed: true}],
    ['payment_events/123', {...reviewed}],
  ]);
  let writes = 0;
  const db = {collection: name => ({doc: id => ({path: name + '/' + id})}),
    runTransaction: async fn => fn({
      get: async ref => ({exists: rows.has(ref.path),
        data: () => rows.get(ref.path)}),
      set: () => { writes++; },
    })};
  const result = await recordVerifiedPayment({db, paymentId: '123',
    accessToken: 'fixture'});
  assert.equal(result.entitlementGranted, false);
  assert.equal(result.previouslyRecorded, true);
  assert.equal(writes, 0);
  assert.deepEqual(rows.get('payment_events/123'), reviewed);
});

test('snapshot reconciliation rejects corrupted payment identity without writes', async t => {
  const {recordVerifiedPayment} = require('./mercadopago_reconciliation');
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  global.fetch = async () => ({ok: true, json: async () => ({
    id: 123, status: 'approved', status_detail: 'accredited',
    live_mode: true, collector_id: 999, transaction_amount: 4.5,
    transaction_amount_refunded: 0, currency_id: 'BRL',
    date_approved: '2026-01-20T10:00:00Z',
  })});
  const rows = new Map([
    ['payment_claims/123', {uid: 'account-1', reviewed: true}],
    ['payment_events/123', {uid: 'account-1', paymentId: '456', reviewed: true}],
  ]);
  let writes = 0;
  const db = {collection: name => ({doc: id => ({path: name + '/' + id})}),
    runTransaction: async fn => fn({
      get: async ref => ({exists: rows.has(ref.path), data: () => rows.get(ref.path)}),
      set: () => { writes++; },
    })};
  await assert.rejects(recordVerifiedPayment({db, paymentId: '123',
    accessToken: 'fixture'}), /ledger document identity mismatch/);
  assert.equal(writes, 0);
});
