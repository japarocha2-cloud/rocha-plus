'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { verifyWebhookSignature } = require('./mercadopago_webhook_signature');
const secret = 'testing-only-secret';
const now = 1791972000000;
function signed(dataId = 'PAY123', requestId = 'req-1', ts = String(now)) {
  const manifest = `id:${dataId.toLowerCase()};request-id:${requestId};ts:${ts};`;
  const v1 = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
  return { secret, signature: `ts=${ts},v1=${v1}`, requestId, dataId, now };
}
test('valid signed webhook accepted', () => assert.equal(verifyWebhookSignature(signed()), true));
test('case normalized data ID accepted', () => assert.equal(verifyWebhookSignature(signed('ORD01ABC')), true));
test('reject modified resource', () => assert.equal(verifyWebhookSignature({...signed(), dataId: 'PAY999'}), false));
test('reject wrong request id', () => assert.equal(verifyWebhookSignature({...signed(), requestId:'another'}), false));
test('reject incorrect secret', () => assert.equal(verifyWebhookSignature({...signed(), secret:'wrong'}), false));
test('reject missing signature', () => assert.equal(verifyWebhookSignature({...signed(), signature:''}), false));
test('reject old signature', () => assert.equal(verifyWebhookSignature({...signed(), now: now + 600000}), false));
test('reject future signature', () => assert.equal(verifyWebhookSignature({...signed(), now: now - 600000}), false));
test('reject malformed digest', () => assert.equal(verifyWebhookSignature({...signed(), signature:'ts=1791972000000,v1=ab'}), false));
