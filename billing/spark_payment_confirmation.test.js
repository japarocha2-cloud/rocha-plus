import test from 'node:test';
import assert from 'node:assert/strict';
import { memoryDb } from './test_helpers.js';
import { addMonths } from './policy.js';
import { confirmSparkPayment } from './spark_payment_confirmation.js';

const time = Date.parse('2026-10-23T12:00:00Z');
const debit = time - 86400000;
const subId = 'cccccccccccccccccccccccccccccccc';
const planIds = { monthly: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', annual: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' };
function fixture() {
  const db = memoryDb();
  const sparkPath = 'rochaSparkAccounts/123456';
  db.data.set(sparkPath, { trialStartedAt: new Date(time - 10 * 86400000),
    welcomeAcceptedAt: new Date(time - 9 * 86400000) });
  db.data.set('users/A/favorites/synthetic', { name: 'Untouched' });
  const account = { uid: 'A', email: 'a@example.com', emailVerified: true, disabled: false,
    providerData: [{ providerId: 'google.com', uid: '123456' }] };
  const sub = { id: subId, collector_id: 987, preapproval_plan_id: planIds.monthly,
    payer_id: 7, payer_email: 'a@example.com', status: 'authorized', live_mode: true,
    date_created: new Date(debit).toISOString(), last_modified: new Date(debit).toISOString(),
    auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: 4.9, currency_id: 'BRL' } };
  const invoice = { id: 111, preapproval_id: subId, currency_id: 'BRL', transaction_amount: 4.9,
    debit_date: new Date(debit).toISOString(), payment: { id: 123 } };
  const payment = { id: 123, collector_id: 987, payer: { id: 7 }, currency_id: 'BRL',
    transaction_amount: 4.9, transaction_amount_refunded: 0, live_mode: true, status: 'approved',
    date_approved: new Date(debit).toISOString(), date_last_updated: new Date(debit).toISOString() };
  const args = { db, auth: { getUser: async () => structuredClone(account) },
    provider: { subscription: async () => structuredClone(sub), invoice: async () => structuredClone(invoice),
      payment: async () => structuredClone(payment) }, uid: 'A', subscriptionId: subId, invoiceId: '111',
    config: { collectorId: '987', planIds, liveMode: true, now: time } };
  return { db, account, sub, invoice, payment, args, sparkPath,
    run: extra => confirmSparkPayment({ ...args, ...extra }) };
}
test('dry-run validates payment but leaves every document unchanged', async () => {
  const f = fixture(), before = structuredClone(f.db.data);
  assert.deepEqual(await f.run(), { mode: 'dry-run', changed: false, plan: 'monthly', paidUntil: addMonths(debit, 1) });
  assert.deepEqual(f.db.data, before);
});
test('verified payment grants its cycle without changing trial, acceptance or favorites', async () => {
  const f = fixture(), before = structuredClone(f.db.data);
  const result = await f.run({ apply: true });
  assert.equal(result.mode, 'applied');
  assert.deepEqual(f.db.data.get(f.sparkPath), { ...before.get(f.sparkPath), paidUntil: new Date(addMonths(debit, 1)) });
  assert.deepEqual(f.db.data.get('users/A/favorites/synthetic'), before.get('users/A/favorites/synthetic'));
  assert.equal(f.db.data.size, before.size + 2);
});
test('repeated confirmation does not add another month or override later administrative revocation', async () => {
  const f = fixture(); await f.run({ apply: true });
  f.db.data.get(f.sparkPath).paidUntil = new Date(time - 1);
  const before = structuredClone(f.db.data);
  assert.equal((await f.run({ apply: true })).mode, 'already-recorded');
  assert.deepEqual(f.db.data, before);
});
test('concurrent confirmations record one payment and one cycle', async () => {
  const f = fixture();
  const results = await Promise.all([f.run({ apply: true }), f.run({ apply: true })]);
  assert.deepEqual(results.map(r => r.mode), ['applied', 'already-recorded']);
  assert.equal(f.db.data.get(f.sparkPath).paidUntil.getTime(), addMonths(debit, 1));
});
test('existing longer paid period is preserved', async () => {
  const f = fixture(); f.db.data.get(f.sparkPath).paidUntil = new Date(addMonths(debit, 12));
  assert.equal((await f.run({ apply: true })).paidUntil, addMonths(debit, 12));
});
test('annual payment grants twelve calendar months without extra trial', async () => {
  const f = fixture(); f.sub.preapproval_plan_id = planIds.annual;
  f.sub.auto_recurring.frequency = 12; f.sub.auto_recurring.transaction_amount = 55;
  f.invoice.transaction_amount = 55; f.payment.transaction_amount = 55;
  assert.equal((await f.run({ apply: true })).paidUntil, addMonths(debit, 12));
});
for (const status of ['pending', 'authorized', 'rejected', 'refunded', 'charged_back']) {
  test(`no grant for ${status} payment`, async () => {
    const f = fixture(); f.payment.status = status;
    const before = structuredClone(f.db.data);
    await assert.rejects(f.run({ apply: true })); assert.deepEqual(f.db.data, before);
  });
}
for (const [name, mutate] of [
  ['wrong payer email', f => { f.sub.payer_email = 'b@example.com'; }],
  ['unverified email', f => { f.account.emailVerified = false; }],
  ['disabled login', f => { f.account.disabled = true; }],
  ['no Google identity', f => { f.account.providerData = []; }],
  ['another seller', f => { f.payment.collector_id = 1; }],
  ['another payer', f => { f.payment.payer.id = 99; }],
  ['wrong amount', f => { f.payment.transaction_amount = 0.01; }],
  ['partial refund', f => { f.payment.transaction_amount_refunded = 0.01; }],
  ['test payment', f => { f.payment.live_mode = false; }],
  ['another invoice resource', f => { f.invoice.id = 222; }],
  ['another subscription', f => { f.invoice.preapproval_id = 'another-subscription'; }],
  ['another payment resource', f => { f.payment.id = 555; }],
  ['foreign external reference', f => { f.sub.external_reference = 'other-system'; }],
  ['missing Spark trial', f => { f.db.data.delete(f.sparkPath); }],
  ['invalid existing paid timestamp', f => { f.db.data.get(f.sparkPath).paidUntil = 'invalid'; }],
  ['future cycle', f => { f.invoice.debit_date = new Date(time + 1000).toISOString(); }],
  ['expired cycle', f => { f.invoice.debit_date = new Date(time - 90 * 86400000).toISOString(); }],
  ['subscription bound elsewhere', f => { f.db.data.set('rochaSparkSubscriptionOwners/' + subId,
    { googleSubject: '999', plan: 'monthly', payerId: '7' }); }],
  ['legacy subscription bound elsewhere', f => { f.db.data.set('rochaBillingSubscriptions/' + subId, { uid: 'B' }); }],
  ['legacy payment bound elsewhere', f => { f.db.data.set('rochaBillingPayments/123', { uid: 'B' }); }],
  ['payment bound elsewhere', f => { f.db.data.set('rochaSparkPaymentConfirmations/123',
    { googleSubject: '999', subscriptionId: subId, invoiceId: '111', periodEnd: addMonths(debit, 1) }); }],
]) {
  test(`no mutation on ${name}`, async () => {
    const f = fixture(); mutate(f); const before = structuredClone(f.db.data);
    await assert.rejects(f.run({ apply: true })); assert.deepEqual(f.db.data, before);
  });
}
test('test configuration cannot apply an entitlement to the live Spark database', async () => {
  const f = fixture(); await assert.rejects(f.run({ apply: true, config: { ...f.args.config, liveMode: false } }));
});
test('provider failure cannot grant access', async () => {
  const f = fixture(); f.args.provider.payment = async () => { throw new Error('offline'); };
  const before = structuredClone(f.db.data);
  await assert.rejects(f.run({ apply: true })); assert.deepEqual(f.db.data, before);
});
