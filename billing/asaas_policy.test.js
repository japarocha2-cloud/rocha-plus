import test from 'node:test';
import assert from 'node:assert/strict';
import { checkedAsaasBinding, checkedAsaasPayment, asaasCents } from './asaas_policy.js';
import { fixture, time } from './asaas_test_helpers.js';
function check(f, now = time) { return checkedAsaasPayment({ payment: f.payment,
  subscription: f.subscription, binding: f.binding, now }); }

for (const status of ['CONFIRMED', 'RECEIVED']) test(status + ' verifies a current R$5.50 monthly cycle', () => {
  const f = fixture(); f.payment.status = status;
  assert.equal(check(f).current, true); assert.equal(check(f).amountCents, 550);
});
for (const status of ['PENDING', 'OVERDUE', 'AWAITING_RISK_ANALYSIS', 'RECEIVED_IN_CASH',
  'DUNNING_REQUESTED', 'DUNNING_RECEIVED']) test(status + ' does not grant access', () => {
  const f = fixture(); f.payment.status = status;
  assert.equal(check(f).status, 'pending'); assert.equal(check(f).current, false);
});
for (const status of ['REFUNDED', 'REFUND_REQUESTED', 'REFUND_IN_PROGRESS',
  'CHARGEBACK_REQUESTED', 'CHARGEBACK_DISPUTE', 'AWAITING_CHARGEBACK_REVERSAL']) {
  test(status + ' revokes this payment only', () => {
    const f = fixture(); f.payment.status = status;
    assert.equal(check(f).status, 'revoked'); assert.equal(check(f).current, false);
  });
}
for (const [name, mutate] of [
  ['wrong payment', f => { f.payment.id = 'pay_other'; }],
  ['wrong customer', f => { f.payment.customer = 'cus_other'; }],
  ['wrong subscription customer', f => { f.subscription.customer = 'cus_other'; }],
  ['wrong subscription', f => { f.payment.subscription = 'sub_other'; }],
  ['wrong fetched subscription', f => { f.subscription.id = 'sub_other'; }],
  ['wrong reference', f => { f.subscription.externalReference = 'another-system'; }],
  ['missing reference', f => { delete f.subscription.externalReference; }],
  ['foreign payment reference', f => { f.payment.externalReference = 'another-system'; }],
  ['discounted payment', f => { f.payment.value = 0.01; }],
  ['old Mercado Pago price', f => { f.payment.value = 4.90; }],
  ['different plan value', f => { f.subscription.value = 55; }],
  ['yearly cycle', f => { f.subscription.cycle = 'YEARLY'; }],
  ['wrong billing type', f => { f.payment.billingType = 'PIX'; }],
  ['wrong subscription billing type', f => { f.subscription.billingType = 'BOLETO'; }],
  ['different due date', f => { f.payment.dueDate = '2026-10-16'; }],
  ['invented status', f => { f.payment.status = 'SUCCESS'; }],
  ['invalid refund data', f => { f.payment.refunds = 'none'; }],
  ['invalid deletion marker', f => { f.payment.deleted = 'false'; }],
  ['production binding', f => { f.binding.environment = 'production'; }],
  ['invalid calendar date', f => { f.binding.dueDate = '2026-02-30'; }],
  ['extra trial', f => { f.binding.periodEnd += 7 * 86_400_000; }],
  ['client price', f => { f.binding.amountCents = 1; }],
]) test('verification rejects ' + name, () => {
  const f = fixture(); mutate(f); assert.throws(() => check(f));
});
test('future and expired payments do not grant current access', () => {
  const f = fixture();
  assert.equal(check(f, f.binding.periodStart - 1).current, false);
  assert.equal(check(f, f.binding.periodEnd).current, false);
});
test('calendar month clamps Jan 31 to Feb 28 without adding trial days', () => {
  const f = fixture(); Object.assign(f.binding, { dueDate: '2027-01-31',
    periodStart: Date.parse('2027-01-31T00:00:00Z'), periodEnd: Date.parse('2027-02-28T00:00:00Z') });
  assert.equal(checkedAsaasBinding(f.binding).periodEnd, Date.parse('2027-02-28T00:00:00Z'));
});
test('partial refund and deleted payment with otherwise paid status are revoked', () => {
  const f = fixture(); f.payment.refunds = [{ value: 0.01, status: 'DONE' }];
  assert.equal(check(f).status, 'revoked');
  delete f.payment.refunds; f.payment.deleted = true;
  assert.equal(check(f).status, 'revoked');
});
test('money must be a finite numeric amount with at most two decimals', () => {
  assert.equal(asaasCents(5.5), 550);
  for (const value of ['5.50', NaN, Infinity, -1, 5.501]) assert.throws(() => asaasCents(value));
});
