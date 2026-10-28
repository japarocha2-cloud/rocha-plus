'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {reconcileAndGrant} = require('./reconcile_and_grant');
const {fetchVerifiedPayment} = require('./mercadopago_reconciliation');

// Transaction fixture: tests the privileged grant and its persisted ledger,
// without network calls or writes to either Firebase project.
test('privileged reconciliation rejects unsafe payments and recalculates refunds', async t => {
  const originalFetch = global.fetch;
  t.after(() => { global.fetch = originalFetch; });
  let payment = {id: '123', status: 'approved', status_detail: 'accredited',
    live_mode: true, collector_id: 999, transaction_amount: 4.5,
    transaction_amount_refunded: 0, currency_id: 'BRL',
    date_approved: '2026-01-20T10:00:00Z'};
  global.fetch = async () => ({ok: true, json: async () => ({...payment})});
  const initial = () => new Map([
    ['payment_claims/123', {uid: 'account-1', reviewed: true, plan: 'monthly',
      currency: 'BRL', amountCents: 450, merchantId: '999'}],
    ['entitlements/account-1', {trialUntil: 'preserved'}],
  ]);
  let rows = initial();
  const ref = path => ({path});
  const db = {
    collection: name => ({doc: id => ref(name + '/' + id),
      where: (field, op, value) => ({collection: name, field, value})}),
    runTransaction: async callback => {
      const writes = [];
      const result = await callback({
        get: async target => target.path
          ? {exists: rows.has(target.path), data: () => rows.get(target.path)}
          : {docs: [...rows].filter(([key, value]) =>
            key.startsWith(target.collection + '/') && value[target.field] === target.value)
            .map(([key, value]) => ({id: key.split('/')[1], data: () => value}))},
        set: (target, value, options) => writes.push([target.path, value, options]),
      });
      for (const [path, value, options] of writes) {
        rows.set(path, options?.merge ? {...rows.get(path), ...value} : value);
      }
      return result;
    },
  };
  const admin = {firestore: {Timestamp: {now: () => 'server-time', fromDate: d => d.toISOString()}}};
  const run = () => reconcileAndGrant({db, admin, paymentId: '123', accessToken: 'fixture'});

  await t.test('same payment twice preserves the exact expiration and trial', async () => {
    const first = await run();
    const second = await run();
    assert.equal(first.paidUntil, '2026-02-20T10:00:00.000Z');
    assert.equal(second.paidUntil, first.paidUntil);
    assert.equal(second.previouslyRecorded, true);
    assert.equal(rows.get('entitlements/account-1').trialUntil, 'preserved');
  });
  await t.test('partial refund while approved removes the period', async () => {
    payment.transaction_amount_refunded = 1;
    assert.equal((await run()).paidUntil, null);
    assert.equal(rows.get('payment_events/123').eligibleForReview, false);
    payment.transaction_amount_refunded = 0;
  });
  await t.test('refund and chargeback remove the period', async () => {
    for (const status of ['refunded', 'charged_back']) {
      payment.status = status;
      assert.equal((await run()).paidUntil, null);
    }
    payment.status = 'approved';
  });
  await t.test('test mode, wrong merchant and wrong amount cannot write', async () => {
    for (const change of [{live_mode: false}, {collector_id: 1234},
      {transaction_amount: 4.501}, {transaction_amount: 0}]) {
      rows = initial();
      const before = structuredClone([...rows]);
      const original = payment;
      payment = {...payment, ...change};
      await assert.rejects(run(), /match reviewed claim/);
      assert.deepEqual([...rows], before);
      payment = original;
    }
  });
  await t.test('existing different owner cannot be reassigned', async () => {
    rows = initial();
    rows.set('payment_events/123', {uid: 'other-account'});
    await assert.rejects(run(), /ownership conflict/);
  });
  await t.test('expired entitlement can be renewed without changing trial fields', async () => {
    rows = initial();
    rows.set('entitlements/account-1', {
      createdAt: 'original-created', trialStartedAt: 'original-start',
      trialUntil: 'expired-trial', paidUntil: 'expired-paid',
    });
    payment.date_approved = '2026-10-27T10:00:00Z';
    const result = await run();
    assert.equal(result.paidUntil, '2026-11-27T10:00:00.000Z');
    assert.equal(rows.get('entitlements/account-1').paidUntil, result.paidUntil);
    assert.equal(rows.get('entitlements/account-1').createdAt, 'original-created');
    assert.equal(rows.get('entitlements/account-1').trialStartedAt, 'original-start');
    assert.equal(rows.get('entitlements/account-1').trialUntil, 'expired-trial');
    assert.equal((await run()).paidUntil, result.paidUntil);
    payment.date_approved = '2026-01-20T10:00:00Z';
  });
  await t.test('unreviewed or missing claim cannot mutate ledger or entitlement', async () => {
    for (const claim of [null, {uid: 'account-1', reviewed: false, plan: 'monthly'}]) {
      rows = initial();
      if (claim === null) rows.delete('payment_claims/123');
      else rows.set('payment_claims/123', claim);
      const before = structuredClone([...rows]);
      await assert.rejects(run(), /reviewed UID and plan required/);
      assert.deepEqual([...rows], before);
    }
  });
  await t.test('missing entitlement fails closed without writing payment event', async () => {
    rows = initial();
    rows.delete('entitlements/account-1');
    const before = structuredClone([...rows]);
    await assert.rejects(run(), /trial must be initialized/);
    assert.deepEqual([...rows], before);
  });
  await t.test('provider response must match requested payment ID', async () => {
    payment.id = '456';
    await assert.rejects(fetchVerifiedPayment('123', 'fixture'), /identity mismatch/);
  });
});
