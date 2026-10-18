import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { WebhookSignatureValidator } from 'mercadopago';
import { createRecurringService } from './recurring_service.js';
import { createStore, userKey } from './store.js';
import { memoryDb } from './test_helpers.js';
import { addMonths, TRIAL_MS } from './policy.js';
import { LINKS } from './recurring.js';
const start = Date.parse('2026-10-13T12:00:00Z');
const planIds = { monthly: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', annual: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' };
const subId = 'cccccccccccccccccccccccccccccccc';
const secret = 'synthetic-recurring-secret';
function fixture(options = {}) {
  const db = memoryDb(), store = createStore(db); let time = start;
  let sub = { id: subId, collector_id: 987, preapproval_plan_id: planIds.monthly,
    payer_id: 7, payer_email: 'a@example.com', status: 'authorized', external_reference: null,
    date_created: new Date(start).toISOString(), last_modified: new Date(start).toISOString(),
    auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: 4.90,
      currency_id: 'BRL', start_date: new Date(start + TRIAL_MS).toISOString() } };
  let payment = { id: 123, collector_id: 987, payer: { id: 7 }, currency_id: 'BRL',
    transaction_amount: 4.90, transaction_amount_refunded: 0, live_mode: false, status: 'approved',
    date_approved: new Date(start + TRIAL_MS).toISOString(), date_last_updated: new Date(start + TRIAL_MS).toISOString() };
  let invoice = { id: 111, preapproval_id: subId, currency_id: 'BRL', transaction_amount: 4.90,
    debit_date: new Date(start + TRIAL_MS).toISOString(), payment: { id: 123 } };
  let invoices = [], search = [sub], searchedEmail, queries = 0, fail = false;
  const provider = {
    subscriptions: async email => { searchedEmail = email; if (fail) throw Error('unavailable'); return structuredClone(search); },
    subscription: async () => { queries++; return structuredClone(sub); },
    invoices: async () => structuredClone(invoices),
    invoicesForPayment: async () => structuredClone(invoices),
    invoice: async () => structuredClone(invoice),
    payment: async () => structuredClone(payment),
    plan: async id => ({ id, collector_id: 987, status: 'active', auto_recurring: {
      currency_id: 'BRL', transaction_amount: id === planIds.monthly ? 4.90 : 55,
      frequency_type: 'months', frequency: id === planIds.monthly ? 1 : 12 } }),
  };
  const service = createRecurringService({ store, provider, collectorId: '987', planIds,
    paymentsEnabled: true, liveMode: false, now: () => time,
    verifyIdentity: async (token, revoked) => { assert.equal(revoked, true);
      if (!['A', 'B', 'A2', 'unverified'].includes(token)) throw Error('auth');
      return { uid: token, email: token === 'B' ? 'b@example.com' : 'a@example.com', email_verified: token !== 'unverified' }; },
    verifySignature: ({ signature, dataId, requestId }) => WebhookSignatureValidator.validate({
      xSignature: signature, xRequestId: requestId, dataId, secret }), ...options });
  const request = (action, uid = 'A', extra = {}) => service.handle({ method: 'POST',
    authorization: 'Bearer ' + uid, body: { action, ...extra } });
  const webhook = (type = 'subscription_preapproval', id = subId, extra = {}) => {
    const ts = String(Math.floor(time / 1000));
    const hash = createHmac('sha256', secret).update(`id:${id};request-id:recurring;ts:${ts};`).digest('hex');
    return service.webhook({ method: 'POST', dataId: id, body: { type, data: { id } },
      requestId: 'recurring', signature: `ts=${ts},v1=${hash}`, ...extra });
  };
  return { db, store, request, webhook, queries: () => queries, email: () => searchedEmail,
    now: value => { time = value; }, sub: value => { sub = { ...sub, ...value }; },
    payment: value => { payment = { ...payment, ...value }; },
    invoice: value => { invoice = { ...invoice, ...value }; },
    invoices: () => { invoices = [invoice]; }, search: value => { search = value; }, fail: () => { fail = true; } };
}
test('existing generic-link subscription is recognized by verified login without a new charge', async () => {
  const f = fixture(); const reply = await f.request('status', 'A', { uid: 'B', payer_email: 'b@example.com' });
  assert.equal(reply.status, 200); assert.equal(f.email(), 'a@example.com');
  assert.equal(reply.body.recognition, 'linked'); assert.equal(reply.body.state, 'trial');
  assert.equal(reply.body.automaticRenewal, true); assert.equal(reply.body.paidUntil, null);
  assert.equal((await f.store.subscriptionOwner(subId)).uid, 'A');
});
test('authorization alone never releases playback after seven days', async () => {
  const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS);
  const reply = await f.request('status'); assert.equal(reply.body.state, 'expired'); assert.equal(reply.body.active, false);
});
test('a subscription made before first login cannot create a second trial', async () => {
  const f = fixture(); const older = new Date(start - 8 * 86400000).toISOString();
  f.sub({ date_created: older, last_modified: older });
  const reply = await f.request('status'); assert.equal(reply.body.active, false);
  assert.equal(reply.body.trialEndsAt, start - 86400000);
});
test('later next billing date never extends the app trial', async () => {
  const f = fixture(); f.sub({ auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: 4.9,
    currency_id: 'BRL', start_date: new Date(start + 30 * 86400000).toISOString() } });
  assert.equal((await f.request('status')).body.trialEndsAt, start + TRIAL_MS);
});
test('approved recurring invoice grants exactly its monthly cycle; replays do not stack', async () => {
  const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS); f.invoices();
  const first = (await f.request('status')).body; assert.equal(first.state, 'paid');
  assert.equal(first.paidUntil, addMonths(start + TRIAL_MS, 1));
  assert.equal((await f.webhook('subscription_authorized_payment', '111')).status, 200);
  assert.equal((await f.webhook('payment', '123')).status, 200);
  assert.equal((await f.request('status')).body.paidUntil, first.paidUntil);
  f.now(first.paidUntil); assert.equal((await f.request('status')).body.active, false);
});
test('annual invoice covers twelve months without adding free days', async () => {
  const f = fixture(); f.sub({ preapproval_plan_id: planIds.annual, auto_recurring: {
    frequency: 12, frequency_type: 'months', transaction_amount: 55, currency_id: 'BRL' } });
  await f.request('status'); f.now(start + TRIAL_MS); f.invoice({ transaction_amount: 55 });
  f.payment({ transaction_amount: 55 }); f.invoices();
  assert.equal((await f.request('status')).body.paidUntil, addMonths(start + TRIAL_MS, 12));
});
test('pending invoice and scheduled future charge never count as paid', async () => {
  const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS); f.invoices();
  f.payment({ status: 'pending', date_approved: null });
  const reply = await f.request('status'); assert.equal(reply.body.active, false); assert.equal(reply.body.paidUntil, null);
});
test('refund revokes a current cycle and a stale approval cannot restore it', async () => {
  const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS); f.invoices(); await f.request('status');
  f.payment({ status: 'refunded', transaction_amount_refunded: 4.9 });
  assert.equal((await f.webhook('payment', '123')).status, 200);
  assert.equal((await f.request('status')).body.active, false);
  f.payment({ status: 'approved', transaction_amount_refunded: 0 });
  assert.equal((await f.request('status')).body.active, false);
});
test('cancellation preserves already-paid period and stale authorization cannot re-enable renewal', async () => {
  const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS); f.invoices(); await f.request('status');
  f.sub({ status: 'cancelled' }); assert.equal((await f.webhook()).status, 200);
  f.sub({ status: 'authorized' }); const reply = await f.request('status');
  assert.equal(reply.body.active, true); assert.equal(reply.body.automaticRenewal, false);
});
test('another payer email cannot claim an existing subscription', async () => {
  const f = fixture(); const reply = await f.request('status', 'B');
  assert.equal(reply.body.recognition, 'not-found'); assert.equal(await f.store.subscriptionOwner(subId), undefined);
});
test('another UID cannot take a bound subscription even with the same verified email', async () => {
  const f = fixture(); await f.request('status'); assert.equal((await f.request('status', 'A2')).status, 503);
  assert.equal((await f.store.subscriptionOwner(subId)).uid, 'A');
});
test('recreated UID with same verified email cannot reset expired trial', async () => {
  const f = fixture(); f.search([]); await f.request('status'); f.now(start + TRIAL_MS);
  assert.equal((await f.request('status', 'A2')).body.active, false);
});
for (const change of [{ collector_id: 1 }, { preapproval_plan_id: 'unknownunknown' }, { live_mode: true },
  { auto_recurring: { frequency: 1, frequency_type: 'months', currency_id: 'BRL', transaction_amount: .01 } }]) {
  test('foreign or altered subscription rejected ' + JSON.stringify(change), async () => {
    const f = fixture(); f.sub(change); assert.equal((await f.request('status')).status, 503);
    assert.equal(await f.store.subscriptionOwner(subId), undefined);
  });
}
for (const change of [{ collector_id: 1 }, { payer: { id: 8 } }, { currency_id: 'USD' }, { live_mode: true },
  { transaction_amount: .01 }, { id: 999 }]) {
  test('altered recurring payment never grants access ' + JSON.stringify(change), async () => {
    const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS); f.invoices(); f.payment(change);
    assert.equal((await f.request('status')).status, 503);
    assert.equal(Object.keys(f.db.data.get('rochaBillingUsers/' + userKey('A')).payments).length, 0);
  });
}
test('forged subscription webhook is rejected before provider reads', async () => {
  const f = fixture(); const calls = f.queries();
  assert.equal((await f.webhook('subscription_preapproval', subId, { signature: 'invalid' })).status, 401);
  assert.equal(f.queries(), calls);
});
test('invoice associated with another subscription is rejected', async () => {
  const f = fixture(); await f.request('status'); f.now(start + TRIAL_MS); f.invoices();
  f.invoice({ preapproval_id: 'dddddddddddddddddddddddddddddddd' });
  assert.equal((await f.request('status')).status, 503);
});
test('existing checkout links are preserved and repeat subscription is prevented', async () => {
  const f = fixture(); f.search([]);
  assert.equal((await f.request('checkout', 'A', { plan: 'monthly', price: .01 })).body.checkoutUrl, LINKS.monthly);
  assert.equal((await f.request('checkout', 'A', { plan: 'annual' })).body.checkoutUrl, LINKS.annual);
  assert.equal((await f.request('checkout', 'A', { plan: '__proto__' })).status, 400);
  assert.equal((await f.request('checkout', 'unverified', { plan: 'monthly' })).status, 403);
  const linked = fixture(); assert.equal((await linked.request('checkout', 'A', { plan: 'monthly' })).status, 409);
});
test('missing configuration and provider errors never return a playback grant', async () => {
  assert.equal((await fixture({ planIds: {} }).request('status')).status, 503);
  const f = fixture(); await f.request('status'); f.fail(); assert.equal((await f.request('status')).status, 503);
});
test('external reference from another integration is not silently rebound', async () => {
  const f = fixture(); f.sub({ external_reference: 'someone-elses-order' });
  assert.equal((await f.request('status')).body.recognition, 'not-found');
});
