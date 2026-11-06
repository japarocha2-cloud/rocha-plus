'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createSandboxCheckoutHandler, createSandboxVerifyHandler} = require('./sandbox_checkout');

const sandboxUrl = 'https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=test-1';
function fixture({enabled = true, uid = 'test-account-001', sandboxLink = sandboxUrl} = {}) {
  const writes = []; const calls = [];
  const orders = new Map();
  const db = {collection: name => {
    assert.equal(name, 'sandbox_checkout_orders');
    return {doc: id => ({
      async create(data) {writes.push({kind:'create', name, id, data}); orders.set(id,data);},
      async update(data) {writes.push({kind:'update', name, id, data});},
    })};
  }};
  const config = () => ({enabled, testUid: 'test-account-001',
    merchantId: '700', accessToken: 'test-credential',
    notificationUrl: 'https://sandbox.example.com/payment'});
  const request = async (url, opts) => {
    calls.push({url, opts});
    if (url.endsWith('/users/me')) return {ok:true, json:async()=>({id:700})};
    const data = JSON.parse(opts.body);
    return {ok:true, json:async()=>({id:'test-1',collector_id:700,
      external_reference:data.external_reference, sandbox_init_point:sandboxLink})};
  };
  const req = {method:'POST',body:{plan:'monthly'},
    get:()=>'Bearer test-auth'};
  const res = {code:null,body:null,set(){},status(n){this.code=n;return this;},
    json(value){this.body=value;return this;}};
  const handler = createSandboxCheckoutHandler({
    verifyToken:async()=>({uid}),db,config,request,
  });
  return {run:()=>handler(req,res),res,req,writes,calls,orders};
}
test('sandbox checkout locks account and price to server config', async () => {
  const f=fixture();
  await f.run();
  assert.equal(f.res.code,200);
  assert.equal(f.res.body.sandbox,true);
  assert.equal(f.res.body.url,sandboxUrl);
  assert.equal(f.writes[0].data.uid,'test-account-001');
  assert.equal(f.writes[0].data.amountCents,790);
  assert.equal(f.writes[0].data.mode,'sandbox');
  assert.equal(JSON.parse(f.calls[1].opts.body).items[0].unit_price,7.9);
  assert.equal(f.calls[1].opts.body.includes('notification_url'),true);
});
test('disabled sandbox makes no provider request or order', async () => {
  const f=fixture({enabled:false});
  await f.run(); assert.equal(f.res.code,503);
  assert.equal(f.calls.length,0); assert.equal(f.writes.length,0);
});
test('different account cannot create a sandbox order', async () => {
  const f=fixture({uid:'real-client'});
  await f.run(); assert.equal(f.res.code,403);
  assert.equal(f.calls.length,0); assert.equal(f.writes.length,0);
});
test('no production checkout URL is accepted in sandbox', async () => {
  const f=fixture({sandboxLink:null});
  await f.run(); assert.equal(f.res.code,503);
  assert.equal(f.res.body.url,undefined);
});
test('sandbox verify endpoint denies other accounts before provider request', async () => {
  const res={code:null,body:null,set(){},status(n){this.code=n;return this;},
    json(x){this.body=x;return this;}};
  const handler=createSandboxVerifyHandler({
    verifyToken:async()=>({uid:'real-client'}),
    db:null,
    config:()=>({enabled:true,testUid:'test-account-001',
      merchantId:'700',accessToken:'test-credential'}),
  });
  await handler({method:'POST',body:{paymentId:'42'},
    get:()=> 'Bearer token'},res);
  assert.equal(res.code,403);
});
