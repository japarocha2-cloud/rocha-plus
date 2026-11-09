import test from 'node:test';
import assert from 'node:assert/strict';
import { previewDirectPayments as preview } from './direct_payment_preview.mjs';
function fixture() {
  const payment = (id, amount, date) => ({ id, transaction_amount: amount, transaction_amount_refunded: 0,
    currency_id: 'BRL', status: 'approved', status_detail: 'accredited', live_mode: true,
    operation_type: 'regular_payment', collector_id: 123, payer: { email: 'buyer@example.com' }, date_approved: date });
  return { user: { uid: 'fixture', email: 'buyer@example.com', emailVerified: true, disabled: false,
    providerData: [{ providerId: 'google.com' }] }, merchantId: '123', now: Date.UTC(2026, 9, 26),
    assignments: { '11': 'monthly', '22': 'annual' },
    plans: { monthly: { amountCents: 450, months: 1 }, annual: { amountCents: 4950, months: 12 } },
    payments: [payment('11', 4.5, '2026-10-20T22:30:41Z'), payment('22', 49.5, '2026-10-21T09:39:29Z')] };
}
test('monthly plus annual proposal preserves unused credit, is repeatable and never grants access', () => {
  const f = fixture(), before = structuredClone(f), r = preview(f);
  assert.equal(r.proposedPaidUntil, '2027-11-20T22:30:41.000Z');
  assert.equal(r.readyToApply, false); assert.equal(r.accessGranted, false);
  assert.equal(r.existingPaymentLedgerChecked, false); assert.equal(r.writes, 0);
  assert.deepEqual(f, before); assert.deepEqual(preview(f), r);
});
test('card validation, pending, refund and sandbox cannot create paid preview', () => {
  for (const change of [{ operation_type: 'card_validation', transaction_amount: 0 }, { status: 'pending' },
    { status: 'refunded' }, { transaction_amount_refunded: 1 }, { live_mode: false }]) {
    const f = fixture(); Object.assign(f.payments[0], change); assert.throws(() => preview(f));
  }
});
test('different payer, merchant, disabled or unverified identity are rejected', () => {
  for (const kind of ['payer', 'merchant', 'disabled', 'unverified', 'provider']) {
    const f = fixture();
    if (kind === 'payer') f.payments[0].payer.email = 'other@example.com';
    if (kind === 'merchant') f.payments[0].collector_id = 999;
    if (kind === 'disabled') f.user.disabled = true;
    if (kind === 'unverified') f.user.emailVerified = false;
    if (kind === 'provider') f.user.providerData = [];
    assert.throws(() => preview(f));
  }
});
test('duplicate, unassigned, wrong price, imprecise amount and absent refund evidence fail closed', () => {
  for (const kind of ['duplicate', 'unassigned', 'price', 'precision', 'refund']) {
    const f = fixture();
    if (kind === 'duplicate') f.payments.push(structuredClone(f.payments[0]));
    if (kind === 'unassigned') f.payments[0].id = '33';
    if (kind === 'price') f.payments[0].transaction_amount = 4.9;
    if (kind === 'precision') f.payments[0].transaction_amount = 4.501;
    if (kind === 'refund') delete f.payments[0].transaction_amount_refunded;
    assert.throws(() => preview(f));
  }
});
test('invalid clocks, future approval and malformed existing credit cannot produce preview', () => {
  for (const change of [{ now: 0 }, { now: NaN }, { existingPaidUntil: 'bad' }]) assert.throws(() => preview({ ...fixture(), ...change }));
  const f = fixture(); f.payments[0].date_approved = '2099-01-01T00:00:00Z'; assert.throws(() => preview(f));
});
test('calendar-month proposal handles month ends and leap years', () => {
  for (const [date, expected] of [['2024-01-31T10:00:00Z', '2024-02-29T10:00:00.000Z'], ['2025-01-31T10:00:00Z', '2025-02-28T10:00:00.000Z']]) {
    const f = fixture(); f.payments = [f.payments[0]]; f.payments[0].date_approved = date;
    assert.equal(preview(f).proposedPaidUntil, expected);
  }
});
test('future existing credit is preserved but ledger still blocks application', () => {
  const f = fixture(); f.existingPaidUntil = Date.UTC(2026, 11, 1);
  const r = preview(f); assert.equal(r.proposedPaidUntil, '2028-01-01T00:00:00.000Z'); assert.equal(r.readyToApply, false);
});
