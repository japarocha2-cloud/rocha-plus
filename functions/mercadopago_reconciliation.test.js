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
