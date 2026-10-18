'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { prepareSandboxCheckout, REASON, BACK_URL } = require('./mercadopago_sandbox_checkout');
function fixture({ existing = false, seller = 123456, mutate = p => p, failedSearch = false } = {}) {
  const calls = [];
  const plan = mutate({ id: 'testplanabcdefgh', collector_id: 123456, reason: REASON, status: 'active',
    back_url: BACK_URL, auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: 4.9, currency_id: 'BRL' },
    init_point: 'https://www.mercadopago.com.br/subscriptions/checkout?preapproval_plan_id=testplanabcdefgh' });
  const request = async (url, options) => {
    calls.push({ url, options });
    assert.equal(options.redirect, 'error');
    const response = body => ({ status: 200, json: async () => body });
    if (url.endsWith('/users/me')) return response({ id: seller, site_id: 'MLB' });
    if (url.includes('/search?')) {
      if (failedSearch) throw Error('synthetic-secret');
      return response({ paging: { total: existing ? 1 : 0 }, results: existing ? [plan] : [] });
    }
    if (options.method === 'POST') {
      const data = JSON.parse(options.body);
      assert.equal(data.reason, REASON); assert.equal(data.auto_recurring.transaction_amount, 4.9);
      assert.equal(data.auto_recurring.free_trial, undefined);
      assert.equal(data.card_token_id, undefined); assert.equal(data.payer_email, undefined);
    }
    return response(plan);
  };
  return { calls, run: () => prepareSandboxCheckout({ token: 'synthetic-secret', expectedSellerId: '123456', request }) };
}
test('creates only one sandbox plan after checking seller, never a payment or subscription', async () => {
  const f = fixture(); const result = await f.run();
  assert.equal(result.ok, true);
  assert.deepEqual(f.calls.map(c => [new URL(c.url).pathname, c.options.method]),
    [['/users/me', 'GET'], ['/preapproval_plan/search', 'GET'], ['/preapproval_plan', 'POST']]);
  assert.ok(!JSON.stringify(result).includes('synthetic-secret'));
});
test('reuses a fully verified existing sandbox plan without any POST', async () => {
  const f = fixture({ existing: true }); assert.equal((await f.run()).ok, true);
  assert.equal(f.calls.filter(c => c.options.method === 'POST').length, 0);
});
test('different seller cannot create or search plans', async () => {
  const f = fixture({ seller: 999 }); assert.equal((await f.run()).ok, false); assert.equal(f.calls.length, 1);
});
test('uncertain search never creates a new plan', async () => {
  const f = fixture({ failedSearch: true }); assert.equal((await f.run()).ok, false);
  assert.equal(f.calls.filter(c => c.options.method === 'POST').length, 0);
});
for (const [name, mutate] of [
  ['other collector', p => ({ ...p, collector_id: 999 })],
  ['cancelled', p => ({ ...p, status: 'cancelled' })],
  ['wrong price', p => ({ ...p, auto_recurring: { ...p.auto_recurring, transaction_amount: 55 } })],
  ['additional trial', p => ({ ...p, auto_recurring: { ...p.auto_recurring, free_trial: { frequency: 7 } } })],
  ['foreign URL', p => ({ ...p, init_point: 'https://example.com/subscriptions/checkout' })],
  ['wrong plan in checkout', p => ({ ...p, init_point: p.init_point.replace('testplanabcdefgh', 'anotherplanid') })],
]) test(`rejects ${name}`, async () => { assert.equal((await fixture({ mutate }).run()).ok, false); });
