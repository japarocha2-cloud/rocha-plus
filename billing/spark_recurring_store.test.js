import test from 'node:test';
import assert from 'node:assert/strict';
import { memoryDb } from './test_helpers.js';
import { userKey } from './store.js';
import { addMonths } from './policy.js';
import { createRecurringService } from './recurring_service.js';
import { createSparkRecurringStore } from './spark_recurring_store.js';

const now = Date.parse('2026-10-23T12:00:00Z'), debit = now - 86400000;
const collectorId = '1981204845';
const planIds = { monthly: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', annual: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' };
const subId = 'cccccccccccccccccccccccccccccccc';
function fixture(extra = {}) {
  const db = memoryDb(), sparkPath = 'rochaSparkAccounts/123456';
  db.data.set(sparkPath, { trialStartedAt: new Date(now - 10 * 86400000),
    welcomeAcceptedAt: new Date(now - 9 * 86400000) });
  db.data.set('users/A/favorites/channel', { id: 'untouched' });
  const account = { uid: 'A', email: 'a@example.com', emailVerified: true, disabled: false,
    providerData: [{ providerId: 'google.com', uid: '123456' }] };
  const auth = { getUser: async uid => ({ ...structuredClone(account), uid }) };
  const sub = { id: subId, collector_id: Number(collectorId), preapproval_plan_id: planIds.monthly,
    payer_id: 7, payer_email: 'a@example.com', status: 'authorized', live_mode: true,
    date_created: new Date(debit).toISOString(), last_modified: new Date(debit).toISOString(),
    auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: 4.9, currency_id: 'BRL' } };
  const invoice = { id: 111, preapproval_id: subId, currency_id: 'BRL', transaction_amount: 4.9,
    debit_date: new Date(debit).toISOString(), payment: { id: 123 } };
  const payment = { id: 123, collector_id: Number(collectorId), payer: { id: 7 }, currency_id: 'BRL',
    transaction_amount: 4.9, transaction_amount_refunded: 0, live_mode: true, status: 'approved',
    date_approved: new Date(debit).toISOString(), date_last_updated: new Date(debit).toISOString() };
  let invoices = [invoice], unavailable = false;
  const provider = { subscriptions: async () => { if (unavailable) throw Error('offline'); return [sub]; },
    subscription: async () => structuredClone(sub), invoice: async () => structuredClone(invoice),
    invoices: async () => structuredClone(invoices), invoicesForPayment: async () => structuredClone(invoices),
    payment: async () => structuredClone(payment) };
  const store = createSparkRecurringStore({ db, auth, collectorId, liveMode: true, ...extra });
  const service = createRecurringService({ store, provider, collectorId, liveMode: true, planIds,
    projectAccess: store.project, now: () => now, verifySignature: () => {},
    verifyIdentity: async () => ({ uid: 'A', email: account.email, email_verified: true }) });
  return { db, account, sub, invoice, payment, store, sparkPath,
    run: uid => service.reconcileAccount(uid ?? 'A', account.email),
    paid: () => db.data.get(sparkPath).paidUntil?.getTime(),
    noInvoice: () => { invoices = []; }, fail: () => { unavailable = true; },
    webhook: () => service.webhook({ method: 'POST', dataId: '123', body: { type: 'payment', data: { id: '123' } } }) };
}
test('scheduled reconciliation grants existing Spark account without touching trial, welcome or favorites', async () => {
  const f = fixture(), before = structuredClone(f.db.data.get(f.sparkPath)); await f.run();
  assert.equal(f.paid(), addMonths(debit, 1));
  assert.deepEqual(f.db.data.get(f.sparkPath), { ...before, paidUntil: new Date(addMonths(debit, 1)) });
  assert.deepEqual(f.db.data.get('users/A/favorites/channel'), { id: 'untouched' });
});
test('replays and concurrent passes never stack cycles', async () => {
  const f = fixture(); await f.run(); await Promise.all([f.run(), f.run()]);
  assert.equal(f.paid(), addMonths(debit, 1));
});
test('refund webhook revokes only the managed cycle and stale approval cannot restore it', async () => {
  const f = fixture(); await f.run(); f.payment.status = 'refunded'; f.payment.transaction_amount_refunded = 4.9;
  assert.equal((await f.webhook()).status, 200); assert.equal(f.paid(), 0);
  f.payment.status = 'approved'; f.payment.transaction_amount_refunded = 0;
  await f.run(); assert.equal(f.paid(), 0);
});
test('partial refund removes access from the managed cycle', async () => {
  const f = fixture(); await f.run(); f.payment.transaction_amount_refunded = .01;
  f.payment.date_last_updated = new Date(now).toISOString(); await f.run(); assert.equal(f.paid(), 0);
});
test('existing manual validity remains the floor after a managed refund', async () => {
  const f = fixture(); const baseline = now + 1000;
  f.db.data.get(f.sparkPath).paidUntil = new Date(baseline); await f.run();
  f.payment.status = 'refunded'; await f.run(); assert.equal(f.paid(), baseline);
});
test('cancellation preserves a cycle that was already paid', async () => {
  const f = fixture(); await f.run(); f.sub.status = 'cancelled'; await f.run(); assert.equal(f.paid(), addMonths(debit, 1));
});
test('annual cycle remains twelve months', async () => {
  const f = fixture(); f.sub.preapproval_plan_id = planIds.annual;
  f.sub.auto_recurring.frequency = 12; f.sub.auto_recurring.transaction_amount = 55;
  f.invoice.transaction_amount = 55; f.payment.transaction_amount = 55;
  await f.run(); assert.equal(f.paid(), addMonths(debit, 12));
});
test('authorization without an invoice never changes Spark validity', async () => {
  const f = fixture(); f.noInvoice(); const user = await f.run(); assert.equal(f.paid(), undefined);
  assert.equal(user.trialEndsAt, now - 3 * 86400000);
});
test('pending payment never grants Spark access', async () => {
  const f = fixture(); f.payment.status = 'pending'; f.payment.date_approved = null;
  await f.run(); assert.equal(f.paid(), undefined);
});
test('provider failure leaves an existing paid validity unchanged', async () => {
  const f = fixture(); await f.run(); f.fail(); await assert.rejects(f.run()); assert.equal(f.paid(), addMonths(debit, 1));
});
test('manual revocation is never restored by a scheduled replay', async () => {
  const f = fixture(); await f.run(); f.db.data.get(f.sparkPath).paidUntil = new Date(0);
  await assert.rejects(f.run(), /external-change-review-required/); assert.equal(f.paid(), 0);
});
test('a manual extension after adoption requires review and is preserved', async () => {
  const f = fixture(); await f.run(); const until = addMonths(now, 12);
  f.db.data.get(f.sparkPath).paidUntil = new Date(until);
  await assert.rejects(f.run(), /external-change-review-required/); assert.equal(f.paid(), until);
});
test('another UID with same Google subject cannot take a bound subscription', async () => {
  const f = fixture(); await f.run(); await assert.rejects(f.run('B')); assert.equal(f.paid(), addMonths(debit, 1));
});
test('another Google identity cannot take a linked Firebase UID', async () => {
  const f = fixture(); await f.run(); f.account.providerData[0].uid = '999';
  f.db.data.set('rochaSparkAccounts/999', { trialStartedAt: new Date(debit) });
  await assert.rejects(f.run(), /identity-owner/); assert.equal(f.db.data.get('rochaSparkAccounts/999').paidUntil, undefined);
});
test('manual confirmations require explicit migration instead of duplicate adoption', async () => {
  const f = fixture(); f.db.data.set('rochaSparkPaymentConfirmations/123', { googleSubject: '123456' });
  await assert.rejects(f.run(), /manual-payment-migration-required/); assert.equal(f.paid(), undefined);
});
test('a manually linked subscription belonging elsewhere cannot grant access', async () => {
  const f = fixture(); f.db.data.set('rochaSparkSubscriptionOwners/' + subId,
    { googleSubject: '999', payerId: '7', plan: 'monthly' });
  await assert.rejects(f.run(), /subscription-owner/); assert.equal(f.paid(), undefined);
});
for (const [name, mutate] of [
  ['missing Spark account', f => f.db.data.delete(f.sparkPath)],
  ['unverified Google account', f => { f.account.emailVerified = false; }],
  ['disabled account', f => { f.account.disabled = true; }],
  ['invalid Google subject', f => { f.account.providerData[0].uid = '../wrong'; }],
  ['wrong payer', f => { f.payment.payer.id = 999; }],
  ['wrong amount', f => { f.payment.transaction_amount = .01; }],
]) test('no grant for ' + name, async () => {
  const f = fixture(); mutate(f); await assert.rejects(f.run()); assert.equal(f.db.data.get(f.sparkPath)?.paidUntil, undefined);
});
test('test seller cannot project even with production-style live_mode flag', async () => {
  const f = fixture({ collectorId: '3717765439' }); await assert.rejects(f.run(), /production-required/);
  assert.equal(f.paid(), undefined);
});
test('sandbox mode cannot project onto the real account', async () => {
  const f = fixture({ liveMode: false }); await assert.rejects(f.run(), /production-required/); assert.equal(f.paid(), undefined);
});
test('unscoped legacy ledger cannot be projected without provider reconciliation', async () => {
  const f = fixture(); await f.run();
  delete f.db.data.get('rochaBillingUsers/' + userKey('A')).payments['123'].verifiedCollectorId;
  await assert.rejects(f.store.project('A', now), /verification-scope/);
});

test('expired approved billing cycle never grants current access', async () => {
  const f = fixture();
  const old = now - 70 * 86400000;
  f.invoice.debit_date = new Date(old).toISOString();
  f.payment.date_approved = new Date(old).toISOString();
  f.payment.date_last_updated = new Date(old).toISOString();
  await f.run();
  assert.ok(f.paid() === undefined || f.paid() <= now);
});

test('sandbox seller cannot unlock an existing real account', async () => {
  const f = fixture({ collectorId: '3717765439' });
  await assert.rejects(f.run(), /production-required/);
  assert.equal(f.paid(), undefined);
});

test('simulated full payment lifecycle unlocks then revokes without changing favorites', async () => {
  const f = fixture();
  const favoritesBefore = structuredClone(f.db.data.get('users/A/favorites/channel'));
  f.payment.status = 'pending';
  f.payment.date_approved = null;
  await f.run();
  assert.equal(f.paid(), undefined);
  f.payment.status = 'approved';
  f.payment.date_approved = new Date(debit).toISOString();
  f.payment.date_last_updated = new Date(now).toISOString();
  await f.run();
  assert.equal(f.paid(), addMonths(debit, 1));
  f.payment.status = 'refunded';
  f.payment.transaction_amount_refunded = 4.9;
  f.payment.date_last_updated = new Date(now + 1000).toISOString();
  await f.run();
  assert.equal(f.paid(), 0);
  assert.deepEqual(f.db.data.get('users/A/favorites/channel'), favoritesBefore);
});
