'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function load(env) {
  const exported = {};
  let calls = 0;
  const forbidden = () => { throw Error('unexpected financial or storage access'); };
  vm.runInNewContext(fs.readFileSync(require.resolve('./index.js'), 'utf8'), {
    exports: exported, process: {env},
    require: name => {
      if (name === 'firebase-admin') return {initializeApp() {}, firestore: () => ({collection: forbidden})};
      if (name === 'firebase-functions/v2/https') return {onRequest: (_, handler) => handler};
      if (name === 'firebase-functions/params') return {defineSecret: () => ({value: forbidden})};
      if (name === './mercadopago_webhook') return {
        createFirestoreWebhookInbox: () => {calls++; return {};},
        createMercadoPagoWebhookHandler: () => async (_, res) => res.status(204).json({}),
      };
      if (name === './reconcile_and_grant') return {reconcileAndGrant: forbidden};
      if (name === './checkout') return {createCheckoutHandler: forbidden};
      if (name === './checkout_claim') return {bindCheckoutClaim: forbidden};
      if (name === './sandbox_checkout') return {createSandboxCheckoutHandler: forbidden, createSandboxVerifyHandler: forbidden};
      if (name === './sandbox_payment_reconciliation') return {reconcileSandboxPayment: forbidden};
      throw Error('unexpected dependency');
    },
  });
  return {exported, calls: () => calls};
}
for (const env of [
  {}, {ROCHA_CHECKOUT_ENABLED: 'false'},
  {ROCHA_CHECKOUT_ENABLED: 'true'},
  {ROCHA_CHECKOUT_ENABLED: 'false', ROCHA_WEBHOOK_RECONCILIATION_ENABLED: 'false'},
]) {
  test('paused webhook cannot touch inbox, provider, historical claims or licenses: ' + JSON.stringify(env), async () => {
    const h = load(env);
    const res = {headers: {}, set(k,v) {this.headers[k]=v;},
      status(n) {this.code=n; return this;}, json(body) {this.body=body;}};
    await h.exported.mercadoPagoWebhook({}, res);
    assert.equal(res.code, 503);
    assert.equal(res.body.paused, true);
    assert.equal(res.headers['Cache-Control'], 'no-store');
    assert.equal(h.calls(), 0);
  });
}
test('explicit receiver enablement reaches the signed handler independently of new purchases', async () => {
  const h = load({ROCHA_CHECKOUT_ENABLED:'false', ROCHA_WEBHOOK_RECONCILIATION_ENABLED:'true'});
  const res = {status(n) {this.code=n; return this;}, json() {}};
  await h.exported.mercadoPagoWebhook({}, res);
  assert.equal(h.calls(), 1);
  assert.equal(res.code, 204);
});
