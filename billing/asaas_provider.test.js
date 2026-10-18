import test from 'node:test';
import assert from 'node:assert/strict';
import { createAsaasProvider } from './asaas_provider.js';
import { token } from './asaas_test_helpers.js';

test('read-only provider uses sandbox, access_token, timeout and redirect protection', async () => {
  const calls = [];
  const provider = createAsaasProvider({ apiKey: 'synthetic-key', webhookToken: token,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return { ok: true, json: async () => ({ id: url.split('/').at(-1) }) };
    } });
  await provider.payment('pay_test'); await provider.subscription('sub_test');
  assert.deepEqual(calls.map(c => c.url), ['https://api-sandbox.asaas.com/v3/payments/pay_test',
    'https://api-sandbox.asaas.com/v3/subscriptions/sub_test']);
  for (const { options } of calls) {
    assert.equal(options.method, 'GET'); assert.equal(options.redirect, 'error');
    assert.equal(options.headers.access_token, 'synthetic-key');
    assert.match(options.headers['User-Agent'], /^RochaPlus/);
    assert.ok(options.signal instanceof AbortSignal);
  }
  assert.equal(provider.environment, 'sandbox');
  assert.equal(Object.hasOwn(provider, 'createPayment'), false);
});
for (const [name, config] of [
  ['unknown environment', { environment: 'http://attacker.invalid' }],
  ['missing credential', { apiKey: '' }], ['whitespace credential', { apiKey: 'bad key' }],
  ['short webhook token', { webhookToken: 'short' }],
  ['webhook token with whitespace', { webhookToken: token + ' ' }],
  ['same API and webhook key', { apiKey: token }],
  ['API key as webhook secret', { webhookToken: '$aact_' + 'x'.repeat(40) }],
  ['unbounded timeout', { timeoutMs: 100_000 }],
]) test('configuration refuses ' + name, () => {
  assert.throws(() => createAsaasProvider({ apiKey: 'synthetic-key', webhookToken: token, ...config }));
});
test('webhook token requires exact match including UTF-8 byte length', () => {
  const provider = createAsaasProvider({ apiKey: 'synthetic-key', webhookToken: token });
  provider.verifyWebhookToken(token);
  for (const bad of [null, undefined, '', token + 'x', 'x'.repeat(token.length), 'é'.repeat(token.length)]) {
    assert.throws(() => provider.verifyWebhookToken(bad));
  }
});
for (const id of ['pay_../secret', 'https://attacker.invalid', 'pay_x?token=y', 'sub_other', null]) {
  test('invalid payment ID cannot send credentials: ' + String(id), async () => {
    let called = false;
    const provider = createAsaasProvider({ apiKey: 'synthetic-key', webhookToken: token,
      fetchImpl: async () => { called = true; } });
    await assert.rejects(provider.payment(id)); assert.equal(called, false);
  });
}
for (const response of [
  { ok: false, json: async () => ({ errors: ['synthetic-private-detail'] }) },
  { ok: true, json: async () => ({ id: 'pay_someoneelse' }) },
  { ok: true, json: async () => [] },
  { ok: true, json: async () => { throw new Error('synthetic-private-detail'); } },
]) test('provider fails closed and hides error details', async () => {
  const provider = createAsaasProvider({ apiKey: 'synthetic-key', webhookToken: token,
    fetchImpl: async () => response });
  await assert.rejects(provider.payment('pay_test'), { message: 'asaas-resource-unavailable' });
});
