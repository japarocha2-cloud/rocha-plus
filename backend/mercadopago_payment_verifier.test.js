'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { verifyMercadoPagoPayment } = require('./mercadopago_payment_verifier');
const opts = { accountId: '12345', plan: 'monthly', collectorId: '99', expectedReference: 'rocha-12345-invoice-1' };
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
