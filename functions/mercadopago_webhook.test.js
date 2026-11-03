'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {createHmac} = require('node:crypto');
const {createMercadoPagoWebhookHandler} = require('./mercadopago_webhook');

const secret = 'fixture-webhook-secret-2026';
const requestId = 'req-fixture-001';
const paymentId = '123456789';
const ts = '1793746800';
const signature = () => {
  const manifest = 'id:' + paymentId + ';request-id:' + requestId + ';ts:' + ts + ';';
  return 'ts=' + ts + ',v1=' + createHmac('sha256', secret).update(manifest).digest('hex');
};

function response() {
  return {
    statusCode: null, body: null,
    status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; return this; },
  };
}
function request(overrides = {}) {
  return {
    method: 'POST',
    headers: {'x-request-id': requestId, 'x-signature': signature()},
    query: {'data.id': paymentId},
    body: {id: '99887766', type: 'payment', action: 'payment.updated',
      data: {id: paymentId}, status: 'client-controlled'},
    ...overrides,
  };
}
function fixture() {
  const rows = new Map();
  const calls = [];
  const inbox = {
    async begin({notificationId, paymentId: id, action}) {
      const prior = rows.get(notificationId);
      if (prior && prior.paymentId !== id) throw new Error('notification-conflict');
      if (prior) return prior;
      const row = {paymentId: id, action, status: 'received'};
      rows.set(notificationId, row);
      return row;
    },
    async finish({notificationId, status, reason}) {
      const row = rows.get(notificationId);
      rows.set(notificationId, {...row, status, reason});
    },
  };
  const handler = createMercadoPagoWebhookHandler({
    secret: () => secret, inbox,
    reconcilePayment: async ({paymentId: id}) => { calls.push(id); return {paidUntil: 'fixture'}; },
  });
  return {handler, rows, calls};
}

test('valid signature triggers canonical-payment reconciliation and inbox completion', async () => {
  const f = fixture(), res = response();
  await f.handler(request(), res);
  assert.equal(res.statusCode, 200);
  assert.equal(f.calls[0], paymentId);
  assert.equal(f.rows.get('99887766').status, 'processed');
});

test('invalid signature is rejected before inbox or reconciliation', async () => {
  const f = fixture(), res = response();
  await f.handler(request({headers: {'x-request-id': requestId, 'x-signature': 'ts=' + ts + ',v1=' + '0'.repeat(64)}}), res);
  assert.equal(res.statusCode, 401);
  assert.equal(f.calls.length, 0);
  assert.equal(f.rows.size, 0);
});

test('client body status is ignored; provider reconciliation is called by ID only', async () => {
  const f = fixture(), res = response();
  const req = request({body: {id: 1, type: 'payment', action: 'payment.updated',
    status: 'approved', transaction_amount: 0.01, data: {id: paymentId}}});
  await f.handler(req, res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(f.calls, [paymentId]);
});

test('query/body resource mismatch is rejected', async () => {
  const f = fixture(), res = response();
  await f.handler(request({body: {id: 1, type: 'payment', data: {id: '987'}}}), res);
  assert.equal(res.statusCode, 400);
  assert.equal(f.calls.length, 0);
});

test('already processed notification is idempotent', async () => {
  const f = fixture();
  f.rows.set('99887766', {paymentId, action: 'payment.updated', status: 'processed'});
  const res = response();
  await f.handler(request(), res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.duplicate, true);
  assert.equal(f.calls.length, 0);
});

test('missing reviewed association is durably parked without granting access', async () => {
  const rows = new Map();
  const inbox = {
    async begin({notificationId, paymentId}) {
      const row = {paymentId, status: 'received'};
      rows.set(notificationId, row);
      return row;
    },
    async finish({notificationId, status, reason}) {
      rows.set(notificationId, {...rows.get(notificationId), status, reason});
    },
  };
  const handler = createMercadoPagoWebhookHandler({secret,
    inbox, reconcilePayment: async () => { throw new Error('independently reviewed UID and plan required'); }});
  const res = response();
  await handler(request(), res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.reviewRequired, true);
  assert.equal(rows.get('99887766').status, 'review_required');
});

test('provider/storage failure returns 503 and remains retryable', async () => {
  const f = fixture();
  f.handler = createMercadoPagoWebhookHandler({secret, inbox: {
    begin: async ({notificationId, paymentId}) => {
      f.rows.set(notificationId, {paymentId, status:'received'}); return f.rows.get(notificationId);
    },
    finish: async ({notificationId,status,reason}) => f.rows.set(notificationId, {status,reason}),
  }, reconcilePayment: async () => { throw new Error('provider timeout'); }});
  const res = response();
  await f.handler(request(), res);
  assert.equal(res.statusCode, 503);
  assert.equal(f.rows.get('99887766').status, 'retryable_failure');
});

test('non-payment notification is acknowledged without reconciliation', async () => {
  const f = fixture(), res = response();
  await f.handler(request({body: {id: 1, type: 'subscription_preapproval', data: {id: 'contract'}}}), res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ignored, true);
  assert.equal(f.calls.length, 0);
});

test('non-POST method is rejected', async () => {
  const f = fixture(), res = response();
  await f.handler(request({method: 'GET'}), res);
  assert.equal(res.statusCode, 405);
  assert.equal(f.calls.length, 0);
});

test('payment mismatch is parked for review instead of provider retry loop', async () => {
  const rows = new Map();
  const inbox = {async begin({notificationId,paymentId}) { const row={paymentId,status:'received'}; rows.set(notificationId,row); return row; }, async finish({notificationId,status,reason}) { rows.set(notificationId,{...rows.get(notificationId),status,reason}); }};
  const handler=createMercadoPagoWebhookHandler({secret,inbox,reconcilePayment:async()=>{throw new Error('payment does not match reviewed claim');}});
  const res=response(); await handler(request(),res);
  assert.equal(res.statusCode,200); assert.equal(res.body.reviewRequired,true);
  assert.equal(rows.get('99887766').status,'review_required');
});
