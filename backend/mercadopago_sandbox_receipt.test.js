'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { verifySandboxReceipt } = require('./mercadopago_sandbox_receipt');
async function run(overrides = {}, seller = '123', fail = false) {
  const calls = [];
  const result = await verifySandboxReceipt({ token: 'synthetic-secret', sellerId: '123', buyerId: '456', paymentId: '789',
    request: async (url, options) => {
      calls.push(url); assert.equal(options.method, 'GET'); assert.equal(options.redirect, 'error');
      if (fail) throw Error('synthetic-secret');
      return { status: 200, json: async () => url.endsWith('/users/me') ? { id: seller, site_id: 'MLB' } : {
        id: 789, collector_id: 123, payer: { id: 456 }, live_mode: false,
        status: 'approved', currency_id: 'BRL', transaction_amount: 4.9,
        transaction_amount_refunded: 0, date_approved: '2026-10-15T05:06:00Z', ...overrides } };
    } });
  assert.ok(!JSON.stringify(result).includes('synthetic-secret'));
  return { result, calls };
}
test('confirms only the expected approved sandbox payment without granting access', async () => {
  const { result, calls } = await run(); assert.equal(result.ok, true);
  assert.equal(result.appAccessGranted, false); assert.equal(calls.length, 2);
});
for (const [name, overrides] of Object.entries({
  live: { live_mode: true }, missingMode: { live_mode: undefined }, pending: { status: 'pending' },
  refunded: { transaction_amount_refunded: 1 }, wrongAmount: { transaction_amount: 55 },
  wrongBuyer: { payer: { id: 999 } }, wrongCollector: { collector_id: 999 },
  wrongId: { id: 999 }, wrongCurrency: { currency_id: 'USD' }, invalidDate: { date_approved: 'bad' },
})) test('rejects ' + name, async () => assert.equal((await run(overrides)).result.ok, false));
test('foreign credentials never query a payment', async () => {
  const { result, calls } = await run({}, '999'); assert.equal(result.ok, false); assert.equal(calls.length, 1);
});
test('transport errors do not leak credentials', async () => assert.equal((await run({}, '123', true)).result.ok, false));
