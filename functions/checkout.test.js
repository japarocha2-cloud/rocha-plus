'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createCheckoutHandler, officialUrl} = require('./checkout');
const good = 'https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=p1';
function fixture(overrides = {}) {
  const writes = []; const calls = [];
  const deps = {verifyToken: async () => ({uid:'firebase-user',
      firebase:{identities:{'google.com':['g-subject-1']}}}),
    token: () => 'fixture', config: () => ({enabled:true, merchantId:'123', mode:'one_time',
      notificationUrl:'https://example.com/webhook'}),
    createOrder: async (id, data) => writes.push({id, data}),
    savePreference: async (id, preferenceId) => writes.push({id, preferenceId}),
    request: async (url, opts) => {
      calls.push({url, opts});
      if (url.endsWith('/users/me')) return {ok:true,json:async()=>({id:123})};
      const body=JSON.parse(opts.body);
      return {ok:true,json:async()=>({id:'p1',collector_id:123,
        external_reference:body.external_reference,init_point:good})};
    }, ...overrides};
  const res = {code:0, body:null, set(){}, status(n){this.code=n; return this;},
    json(b){this.body=b;return this;}};
  const req={method:'POST',body:{plan:'monthly',uid:'attacker',amount:1},
    get:()=> 'Bearer fixture'};
  return {deps,writes,calls,res,req,run:()=>createCheckoutHandler(deps)(req,res)};
}
test('authenticated checkout fixes price and UID on server',async()=>{
  const f=fixture();await f.run();assert.equal(f.res.code,200);
  assert.equal(f.writes[0].data.uid,'firebase-user');
  // Server-derived Google subject lets a later claim anchor the trial.
  assert.equal(f.writes[0].data.googleSubject,'g-subject-1');
  assert.equal(f.writes[0].data.amountCents,790);
  assert.equal(JSON.parse(f.calls[1].opts.body).items[0].unit_price,7.9);
});
test('annual amount is 86.90 BRL',async()=>{
  const f=fixture();f.req.body.plan='annual';await f.run();
  assert.equal(f.res.code,200);assert.equal(f.writes[0].data.amountCents,8690);
});
test('disabled configuration never contacts provider',async()=>{
  const f=fixture({config:()=>({enabled:false})});await f.run();
  assert.equal(f.res.code,503);assert.equal(f.calls.length,0);
});
test('invalid authentication never creates orders',async()=>{
  const f=fixture({verifyToken:async()=>{throw Error();}});await f.run();
  assert.equal(f.res.code,401);assert.equal(f.writes.length,0);
});
test('reject invalid plan',async()=>{
  const f=fixture();f.req.body.plan='__proto__';await f.run();assert.equal(f.res.code,400);
});
test('wrong merchant cannot create preference',async()=>{
  const f=fixture({request:async()=>({ok:true,json:async()=>({id:999})})});
  await f.run();assert.equal(f.res.code,503);assert.equal(f.writes.length,0);
});
test('only official redirect URL accepted',()=>{
  assert.equal(officialUrl(good),good);
  for (const u of ['https://evil.test/checkout/v1/redirect?pref_id=p1',
    'https://www.mercadopago.com.br.evil.test/checkout/v1/redirect?pref_id=p1',
    'http://www.mercadopago.com.br/checkout/v1/redirect?pref_id=p1',
    'https://attacker@www.mercadopago.com.br/checkout/v1/redirect?pref_id=p1']) {
    assert.throws(()=>officialUrl(u));
  }
});

