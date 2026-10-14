'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { verifyMercadoPagoPayment } = require('./mercadopago_payment_verifier');
const opts = { accountId: '12345', plan: 'monthly', collectorId: '99', referenceAccountId: '12345', expectedReference: 'rocha-12345-invoice-1' };
const payment = {
  id: 123, status: 'approved', status_detail: 'accredited', currency_id: 'BRL',
  transaction_amount: 4.90, collector_id: 99, external_reference: opts.expectedReference,
  date_approved: '2026-10-14T10:00:00Z', refunded_amount: 0,
};
test('approved account-linked payment passes', () => assert.equal(verifyMercadoPagoPayment(payment, opts), true));
for (const [name, change] of Object.entries({
  pending: { status: 'pending' },
  wrongAmount: { transaction_amount: 1.00 },
  wrongCurrency: { currency_id: 'USD' },
  otherUser: { external_reference: 'rocha-00000-invoice-1' },
  refunded: { refunded_amount: 4.9 },
  wrongSeller: { collector_id: 10 },
  unaccredited: { status_detail: 'pending_contingency' },
})) test('rejects ' + name, () => assert.equal(verifyMercadoPagoPayment({ ...payment, ...change }, opts), false));

test('rejects missing collector identity', () => assert.equal(
  verifyMercadoPagoPayment(payment, { ...opts, collectorId: '' }), false));
test('rejects missing individual reference', () => assert.equal(
  verifyMercadoPagoPayment(payment, { ...opts, expectedReference: '' }), false));
test('rejects a mismatched subscription plan', () => assert.equal(
  verifyMercadoPagoPayment(payment, { ...opts, plan: 'annual' }), false));
test('rejects a missing approval timestamp', () => assert.equal(
  verifyMercadoPagoPayment({ ...payment, date_approved: null }, opts), false));
test('rejects malformed payment id', () => assert.equal(
  verifyMercadoPagoPayment({ ...payment, id: 'not-a-payment' }, opts), false));
test('rejects a different Firebase identity', () => assert.equal(
  verifyMercadoPagoPayment(payment, { ...opts, accountId: '99999' }), false));

test('accepts opaque checkout reference when server owner mapping matches', () => {
  const opaque = 'checkout_6f2a0eeab93';
  assert.equal(verifyMercadoPagoPayment(
    { ...payment, external_reference: opaque },
    { ...opts, expectedReference: opaque }), true);
});
test('rejects server checkout mapping owned by another account', () => {
  assert.equal(verifyMercadoPagoPayment(payment,
    { ...opts, referenceAccountId: '99999' }), false);
});
