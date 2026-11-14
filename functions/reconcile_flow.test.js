'use strict';
// End-to-end (simulated data only): webhook handler + real reconcileAndGrant
// over an in-memory Firestore fake. No network, no real identifiers.
const test = require('node:test');
const assert = require('node:assert/strict');
const {createHmac} = require('node:crypto');
const {createMercadoPagoWebhookHandler} = require('./mercadopago_webhook');
const {reconcileAndGrant} = require('./reconcile_and_grant');

const secret = 'fixture-webhook-secret-2026';
const ts = '1793746800';
const MONTHLY = '1001', ANNUAL = '1002';

function world() {
  const rows = new Map([['entitlements/u1', {trialUntil: 'kept'}]]);
  const payments = {};
  let failWrites = false, notif = 0;
  const ref = path => ({path});
  const db = {
    collection: name => ({doc: id => ref(name + '/' + id),
      where: (field, op, value) => ({collection: name, field, value})}),
    runTransaction: async cb => {
      const writes = [];
      const out = await cb({
        get: async t => t.path
          ? {exists: rows.has(t.path), data: () => rows.get(t.path)}
          : {docs: [...rows].filter(([k, v]) => k.startsWith(t.collection + '/') && v[t.field] === t.value)
            .map(([k, v]) => ({id: k.split('/')[1], data: () => v}))},
        set: (t, v, o) => writes.push([t.path, v, o]),
      });
      if (failWrites) throw new Error('storage down');
      for (const [p, v, o] of writes) rows.set(p, o?.merge ? {...rows.get(p), ...v} : v);
      return out;
    },
  };
  const admin = {firestore: {Timestamp: {now: () => 'now', fromDate: d => d.toISOString()}}};
  const inboxRows = new Map();
  const inbox = {
    async begin({notificationId, paymentId}) {
      const prior = inboxRows.get(notificationId);
      if (prior?.status === 'processed') return prior;
      const row = {paymentId, status: 'processing', token: 't'};
      inboxRows.set(notificationId, row); return row;
    },
    async finish({notificationId, status}) {
      inboxRows.set(notificationId, {...inboxRows.get(notificationId), status});
    },
  };
  global.fetch = async url => {
    const p = payments[String(url).split('/').pop()];
    return {ok: true, json: async () => ({...p})};
  };
  const handler = createMercadoPagoWebhookHandler({secret, inbox,
    reconcilePayment: ({paymentId}) => reconcileAndGrant({db, admin, paymentId, accessToken: 'fixture'})});
  async function deliver(paymentId, notificationId = String(++notif)) {
    const manifest = 'id:' + paymentId + ';request-id:rq-1;ts:' + ts + ';';
    const req = {method: 'POST', headers: {'x-request-id': 'rq-1',
      'x-signature': 'ts=' + ts + ',v1=' + createHmac('sha256', secret).update(manifest).digest('hex')},
      query: {'data.id': paymentId}, body: {id: notificationId, type: 'payment', data: {id: paymentId}}};
    const res = {status(c) { this.statusCode = c; return this; }, json(v) { this.body = v; return this; }};
    await handler(req, res); return res;
  }
  const pay = (id, amount, approved) => ({id, status: approved ? 'approved' : 'pending',
    status_detail: approved ? 'accredited' : 'pending_waiting_payment', live_mode: true,
    collector_id: 999, transaction_amount: amount, transaction_amount_refunded: 0,
    currency_id: 'BRL', date_approved: approved || null});
  const claim = (plan, cents) => ({uid: 'u1', reviewed: true, plan, currency: 'BRL',
    amountCents: cents, merchantId: '999'});
  return {rows, payments, inboxRows, deliver, pay, claim, setFail: v => { failWrites = v; }};
}

test('monthly + annual of the same customer are both recognised, in any order', async () => {
  for (const order of [[MONTHLY, ANNUAL], [ANNUAL, MONTHLY]]) {
    const w = world();
    w.payments[MONTHLY] = w.pay(MONTHLY, 4.5, '2026-01-20T10:00:00Z');
    w.payments[ANNUAL] = w.pay(ANNUAL, 49.5, '2026-02-10T10:00:00Z');
    w.rows.set('payment_claims/' + MONTHLY, w.claim('monthly', 450));
    w.rows.set('payment_claims/' + ANNUAL, w.claim('annual', 4950));
    for (const id of order) assert.equal((await w.deliver(id)).statusCode, 200);
    assert.equal(w.rows.get('payment_events/' + MONTHLY).eligibleForReview, true);
    assert.equal(w.rows.get('payment_events/' + ANNUAL).eligibleForReview, true);
    // Current policy: latest end date wins (not summed). Needs owner approval.
    assert.equal(w.rows.get('entitlements/u1').paidUntil, '2027-02-10T10:00:00.000Z');
    assert.equal(w.rows.get('entitlements/u1').trialUntil, 'kept');
  }
});

test('duplicate webhook delivery does not extend paidUntil', async () => {
  const w = world();
  w.payments[MONTHLY] = w.pay(MONTHLY, 4.5, '2026-01-20T10:00:00Z');
  w.rows.set('payment_claims/' + MONTHLY, w.claim('monthly', 450));
  await w.deliver(MONTHLY, '7'); const first = w.rows.get('entitlements/u1').paidUntil;
  const dup = await w.deliver(MONTHLY, '7');
  const again = await w.deliver(MONTHLY, '8');
  assert.equal(dup.body.duplicate, true);
  assert.equal(again.statusCode, 200);
  assert.equal(w.rows.get('entitlements/u1').paidUntil, first);
  assert.equal(first, '2026-02-20T10:00:00.000Z');
});

test('pending then approved (out of order) ends recognised; stale pending cannot revoke', async () => {
  const w = world();
  w.rows.set('payment_claims/' + MONTHLY, w.claim('monthly', 450));
  w.payments[MONTHLY] = w.pay(MONTHLY, 4.5, null);
  assert.equal((await w.deliver(MONTHLY)).statusCode, 200);
  assert.equal(w.rows.get('entitlements/u1').paidUntil, null);
  w.payments[MONTHLY] = w.pay(MONTHLY, 4.5, '2026-01-20T10:00:00Z');
  await w.deliver(MONTHLY);
  assert.equal(w.rows.get('entitlements/u1').paidUntil, '2026-02-20T10:00:00.000Z');
  await w.deliver(MONTHLY); // late redelivery re-fetches canonical state
  assert.equal(w.rows.get('entitlements/u1').paidUntil, '2026-02-20T10:00:00.000Z');
});

test('approved payment arriving before its claim is retryable, then recognised', async () => {
  const w = world();
  w.payments[ANNUAL] = w.pay(ANNUAL, 49.5, '2026-02-10T10:00:00Z');
  const first = await w.deliver(ANNUAL, '50');
  assert.equal(first.statusCode, 503, 'must not ack: provider must retry');
  assert.notEqual(w.inboxRows.get('50').status, 'processed');
  assert.equal(w.inboxRows.get('50').status, 'retryable_failure');
  w.rows.set('payment_claims/' + ANNUAL, w.claim('annual', 4950)); // claim lands later
  assert.equal((await w.deliver(ANNUAL, '50')).statusCode, 200);
  assert.equal(w.rows.get('entitlements/u1').paidUntil, '2027-02-10T10:00:00.000Z');
});

test('storage write failure is not acknowledged as processed and can be retried', async () => {
  const w = world();
  w.payments[MONTHLY] = w.pay(MONTHLY, 4.5, '2026-01-20T10:00:00Z');
  w.rows.set('payment_claims/' + MONTHLY, w.claim('monthly', 450));
  w.setFail(true);
  const res = await w.deliver(MONTHLY, '9');
  assert.equal(res.statusCode, 503);
  assert.equal(w.inboxRows.get('9').status, 'retryable_failure');
  assert.equal(w.rows.has('payment_events/' + MONTHLY), false);
  w.setFail(false);
  assert.equal((await w.deliver(MONTHLY, '9')).statusCode, 200);
  assert.equal(w.rows.get('entitlements/u1').paidUntil, '2026-02-20T10:00:00.000Z');
});
