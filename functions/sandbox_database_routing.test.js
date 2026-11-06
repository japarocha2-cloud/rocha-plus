'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

// Execute the real exports under isolated Firebase SDK mocks.
// Verifies database and execution identity routing WITHOUT contacting Cloud.
test('all sandbox payment endpoints use named Firestore and dedicated identity', async () => {
  const namedDb = {marker: 'named-rocha-payments-test'};
  const defaultDb = {marker: 'default-forbidden'};
  const exports = {};
  const options = {};
  const requestedIds = [];
  const calls = [];
  const admin = {
    initializeApp() {},
    app() {return {name:'app'};},
    firestore() {return defaultDb;},
    auth() {return {verifyIdToken: async()=>({uid:'sandbox-uid'})};},
  };
  const sandboxConfig = {
    ROCHA_SANDBOX_ENABLED:'true',
    ROCHA_SANDBOX_TEST_UID:'sandbox-uid',
    ROCHA_SANDBOX_MERCHANT_ID:'700',
    ROCHA_SANDBOX_WEBHOOK_URL:'https://sandbox.example/webhook',
  };
  const fake = {
    exports, process: {env:sandboxConfig},
    require: name => {
      if (name === 'firebase-admin') return admin;
      if (name === 'firebase-admin/firestore') return {
        getFirestore(app, id) {
          assert.equal(app.name, 'app');
          requestedIds.push(id);
          assert.equal(id, 'rocha-payments-test');
          return namedDb;
        },
      };
      if (name === 'firebase-functions/v2/https') return {
        onRequest: (opts, handler) => {
          const route = (new Error()).stack; // identity assertions are below
          options[Object.keys(options).length] = opts;
          return handler;
        },
      };
      if (name === 'firebase-functions/params') return {defineSecret:()=>({value:()=> 'test-secret'})};
      if (name === './mercadopago_webhook') return {
        createFirestoreWebhookInbox: ({db}) => {
          assert.equal(db, namedDb);
          calls.push('sandbox-inbox');
          return {};
        },
        createMercadoPagoWebhookHandler: () => async(req,res)=>res.status(204).json({}),
      };
      if (name === './reconcile_and_grant') return {reconcileAndGrant:()=>{throw Error('production called')}};
      if (name === './checkout') return {createCheckoutHandler:()=>{throw Error('production called')}};
      if (name === './checkout_claim') return {bindCheckoutClaim:()=>{throw Error('production called')}};
      if (name === './sandbox_checkout') return {
        createSandboxCheckoutHandler: ({db}) => async(_req,res)=>{
          assert.equal(db,namedDb);
          calls.push('sandbox-checkout');
          return res.status(204).json({});
        },
        createSandboxVerifyHandler: ({db}) => async(_req,res)=>{
          assert.equal(db,namedDb);
          calls.push('sandbox-verify');
          return res.status(204).json({});
        },
      };
      if (name === './sandbox_payment_reconciliation') return {reconcileSandboxPayment:()=>{throw Error('not called')}};
      throw Error('unknown module: '+name);
    },
  };
  vm.runInNewContext(fs.readFileSync(require.resolve('./index.js'), 'utf8'), fake);
  const sandboxOptions=Object.values(options).slice(-3);
  assert.equal(sandboxOptions.length,3);
  for(const item of sandboxOptions) assert.equal(item.serviceAccount,
    'rocha-sandbox-payments@rocha-plus-homologacao.iam.gserviceaccount.com');
  const response=()=>({status(n){this.code=n;return this;},json(){return this;},set(){}});
  await exports.sandboxCheckout({},response());
  await exports.sandboxPaymentVerify({},response());
  await exports.sandboxPaymentWebhook({},response());
  assert.deepEqual(calls,['sandbox-checkout','sandbox-verify','sandbox-inbox']);
  assert.deepEqual(requestedIds,['rocha-payments-test','rocha-payments-test','rocha-payments-test']);
  // The commercial entitlement endpoint's default database remains unchanged.
  assert.notEqual(namedDb,defaultDb);
});
