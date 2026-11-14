'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {acceptedPaymentMode, sandboxPaymentsAllowed} = require('./payment_mode');

test('production always requires live payments, even if sandbox mode is set', () => {
  const prod = {GCLOUD_PROJECT: 'rocha-plus', ROCHA_PAYMENT_MODE: 'sandbox'};
  assert.equal(sandboxPaymentsAllowed(prod), false);
  assert.equal(acceptedPaymentMode(false, prod), false);
  assert.equal(acceptedPaymentMode(true, prod), true);
  assert.equal(acceptedPaymentMode(undefined, prod), false);
});

test('sandbox payments only in homologation or demo-* with the explicit mode', () => {
  assert.equal(acceptedPaymentMode(false, {GCLOUD_PROJECT: 'rocha-plus-homologacao', ROCHA_PAYMENT_MODE: 'sandbox'}), true);
  assert.equal(acceptedPaymentMode(false, {GOOGLE_CLOUD_PROJECT: 'demo-rocha-lab', ROCHA_PAYMENT_MODE: 'sandbox'}), true);
  assert.equal(acceptedPaymentMode(false, {GCLOUD_PROJECT: 'rocha-plus-homologacao'}), false);
  assert.equal(acceptedPaymentMode(false, {GCLOUD_PROJECT: 'other-project', ROCHA_PAYMENT_MODE: 'sandbox'}), false);
  assert.equal(acceptedPaymentMode('false', {GCLOUD_PROJECT: 'demo-x', ROCHA_PAYMENT_MODE: 'sandbox'}), false);
});

test('only the homologation env file enables checkout, webhook and sandbox', () => {
  const files = fs.readdirSync(__dirname).filter(f => /^\.env/.test(f));
  assert.deepEqual(files, ['.env.rocha-plus-homologacao']);
  const text = fs.readFileSync(path.join(__dirname, files[0]), 'utf8');
  for (const line of ['ROCHA_PAYMENT_MODE=sandbox', 'ROCHA_CHECKOUT_ENABLED=true',
    'ROCHA_WEBHOOK_RECONCILIATION_ENABLED=true']) assert.ok(text.includes(line), line);
  assert.match(text, /cloudfunctions\.net\/mercadoPagoWebhook/);
  assert.ok(!/rocha-plus\.|-rocha-plus\.cloudfunctions/.test(text), 'no production URL');
  assert.ok(!/^ROCHA_CHECKOUT_MERCHANT_ID=/m.test(text), 'seller ID is not committed');
});
