'use strict';
// Production (rocha-plus) readiness: the prepared deploy target and the safe default
// (checkout unavailable, sandbox payments refused) until the owner-authorized activation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {acceptedPaymentMode} = require('./payment_mode');
const {createCheckoutHandler} = require('./checkout');

const root = path.join(__dirname, '..');
const PROD_WEBHOOK = 'https://southamerica-east1-rocha-plus.cloudfunctions.net/mercadoPagoWebhook';

test('production deploy target is isolated and keeps the unified deny-by-default rules', () => {
  const cfg = JSON.parse(fs.readFileSync(path.join(root, 'firebase.producao.json'), 'utf8'));
  assert.equal(cfg.functions.length, 1);
  assert.equal(cfg.functions[0].source, 'functions');
  assert.equal(cfg.functions[0].codebase, 'subscription-producao');
  assert.equal(cfg.functions[0].runtime, 'nodejs22');
  assert.ok(cfg.functions[0].ignore.includes('*.test.js'));
  assert.deepEqual(cfg.firestore, [{database: '(default)', rules: 'firestore.rules'}]);
  const rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');
  for (const c of ['entitlements', 'payment_events', 'payment_claims', 'checkout_orders',
    'trialAnchors', 'mercadoPagoWebhookInbox', 'mercadoPagoWebhookLocks']) {
    assert.match(rules, new RegExp(`match /${c}/\\{\\w+\\} \\{ allow read, write: if false; \\}`), c);
  }
  // Current production rules (users favorites, Spark trial owner) are preserved.
  assert.match(rules, /match \/users\/\{uid\}\/favorites\/\{id\}/);
  assert.match(rules, /match \/rochaSparkAccounts\/\{accountId\}/);
});

test('no production .env is committed: deploy starts with checkout off and webhook paused', () => {
  assert.equal(fs.existsSync(path.join(__dirname, '.env.rocha-plus')), false);
  assert.equal(fs.existsSync(path.join(__dirname, '.env')), false);
});

test('production never accepts sandbox payments, even if the mode is misconfigured', () => {
  const prod = {GCLOUD_PROJECT: 'rocha-plus', ROCHA_PAYMENT_MODE: 'sandbox'};
  assert.equal(acceptedPaymentMode(false, prod), false);
  assert.equal(acceptedPaymentMode(true, prod), true);
  assert.equal(acceptedPaymentMode(undefined, prod), false);
});

test('activation template targets production webhook and never sandbox', () => {
  const t = fs.readFileSync(path.join(root, 'docs/release-comercial/producao.env.template'), 'utf8');
  const vars = Object.fromEntries(t.split('\n').filter(l => /^[A-Z_]+=/.test(l))
    .map(l => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]));
  assert.equal(vars.ROCHA_CHECKOUT_WEBHOOK_URL, PROD_WEBHOOK);
  assert.equal(vars.ROCHA_CHECKOUT_MODE, 'one_time');
  assert.equal(vars.ROCHA_CHECKOUT_MERCHANT_ID, '');
  assert.equal('ROCHA_PAYMENT_MODE' in vars, false);
});

test('checkout stays unavailable (503) with the production default configuration', async () => {
  let providerCalls = 0;
  const handler = createCheckoutHandler({
    verifyToken: async () => ({uid: 'user-1'}),
    createOrder: async () => { throw new Error('must not create orders'); },
    savePreference: async () => {},
    token: () => '',
    config: () => ({enabled: false, merchantId: undefined, mode: undefined, notificationUrl: undefined}),
    request: async () => { providerCalls++; throw new Error('must not call provider'); },
  });
  const res = {code: 0, body: null, set() {}, status(c) { this.code = c; return this; },
    json(b) { this.body = b; return this; }};
  await handler({method: 'POST', get: () => 'Bearer t', body: {plan: 'monthly'}}, res);
  assert.equal(res.code, 503);
  assert.equal(providerCalls, 0);
});
