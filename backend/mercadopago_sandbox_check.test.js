'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { checkSandboxCredentials } = require('./mercadopago_sandbox_check');
const token = 'synthetic-token-not-real';
const expectedSellerId = '123456';
const reply = (status, body) => ({ status, json: async () => body });
const check = request => checkSandboxCredentials({ token, expectedSellerId, request });

test('only authenticates the exact Brazilian test seller through one official GET', async () => {
  let calls = 0;
  const result = await check(async (url, options) => {
    calls++; assert.equal(url, 'https://api.mercadopago.com/users/me');
    assert.equal(options.method, 'GET'); assert.equal(options.redirect, 'error');
    assert.equal(options.headers.Authorization, `Bearer ${token}`);
    assert.equal(options.body, undefined);
    return reply(200, { id: 123456, site_id: 'MLB', email: 'private@example.com' });
  });
  assert.equal(calls, 1);
  assert.deepEqual(result, { ok: true, code: 'test-seller-authenticated', readOnly: true });
  assert.ok(!JSON.stringify(result).includes('private'));
});
test('missing secret never sends a request', async () => {
  const result = await checkSandboxCredentials({ expectedSellerId, request: () => assert.fail('network') });
  assert.equal(result.code, 'missing-test-secret');
});
test('invalid token or expected identity never sends a request', async () => {
  for (const args of [{ token: 'contains\nnewline', expectedSellerId }, { token, expectedSellerId: 'other' }]) {
    const result = await checkSandboxCredentials({ ...args, request: () => assert.fail('network') });
    assert.equal(result.code, 'invalid-test-configuration');
  }
});
test('accidental production account or different test seller fails closed', async () => {
  assert.equal((await check(async () => reply(200, { id: 999999, site_id: 'MLB' }))).ok, false);
});
test('another country or missing identity fails closed', async () => {
  for (const body of [{ id: 123456, site_id: 'MLA' }, {}, null]) {
    assert.equal((await check(async () => reply(200, body))).ok, false);
  }
});
test('provider credential errors return static diagnostics only', async () => {
  for (const status of [401, 403]) {
    const result = await check(async () => reply(status, { token, private: 'hidden' }));
    assert.deepEqual(result, { ok: false, code: 'credentials-rejected' });
  }
});
test('rate limit or server error does not reveal provider response', async () => {
  for (const status of [429, 500, 302]) {
    assert.deepEqual(await check(async () => reply(status, { token })),
      { ok: false, code: 'provider-unavailable' });
  }
});
test('transport exceptions cannot leak credentials or response details', async () => {
  assert.deepEqual(await check(async () => { throw new Error(token); }),
    { ok: false, code: 'provider-unreachable' });
});
test('malformed provider JSON fails without logging its content', async () => {
  assert.deepEqual(await check(async () => ({ status: 200, json: async () => { throw Error(token); } })),
    { ok: false, code: 'invalid-provider-response' });
});
