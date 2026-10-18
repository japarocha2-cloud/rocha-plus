import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { WebhookSignatureValidator } from 'mercadopago';
import { createService } from './service.js';
import { createStore, userKey } from './store.js';
import { access, addMonths, TRIAL_MS } from './policy.js';
import { memoryDb } from './test_helpers.js';
const start = Date.parse('2026-10-13T12:00:00Z');
const orderId = '11111111-1111-4111-8111-111111111111';
const secret = 'synthetic-test-secret';
function fixture(options={}) {
  const db=memoryDb(),store=createStore(db);let time=start,calls=0;
  let payment={id:123,external_reference:orderId,collector_id:987,currency_id:'BRL',
    transaction_amount:'4.90',transaction_amount_refunded:0,status:'approved',live_mode:false,
    date_last_updated:new Date(start).toISOString(),date_approved:new Date(start).toISOString()};
  const service=createService({store,collectorId:'987',liveMode:false,paymentsEnabled:true,
    now:()=>time,newId:()=>orderId,
    verifyIdentity:async(token,revoked)=>{assert.equal(revoked,true);if(!['A','B'].includes(token))throw Error('auth');
      return {uid:token,email:token+'@example.com',email_verified:true};},
    provider:{checkout:async()=> 'https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=test',
      payment:async()=>{calls++;return structuredClone(payment);}},
    verifySignature:({signature,dataId,requestId})=>WebhookSignatureValidator.validate({
      xSignature:signature,xRequestId:requestId,dataId,secret}),...options});
  const request=(action,account='A',extra={})=>service.handle({method:'POST',
    authorization:'Bearer '+account,body:{action,...extra}});
  const webhook=(extra={})=>{const ts=String(Math.floor(time/1000));
    const hash=createHmac('sha256',secret).update(`id:123;request-id:test-request;ts:${ts};`).digest('hex');
    return service.webhook({method:'POST',dataId:'123',requestId:'test-request',signature:`ts=${ts},v1=${hash}`,
      body:{type:'payment',data:{id:123}},...extra});};
  return {db,store,service,request,webhook,now:value=>{time=value;},
    payment:value=>{payment={...payment,...value};},calls:()=>calls};
}
test('seven days end exactly once and reinstall or client UID cannot reset them',async()=>{
  const f=fixture();assert.equal((await f.request('status')).body.trialEndsAt,start+TRIAL_MS);
  f.now(start+TRIAL_MS-1);assert.equal((await f.request('status')).body.active,true);
  f.now(start+TRIAL_MS);assert.equal((await f.request('status')).body.active,false);
  assert.equal((await f.request('status','B')).body.active,true);
  assert.equal((await f.request('status','A',{uid:'B'})).body.trialEndsAt,start+TRIAL_MS);
});
test('invalid identity and method do not create a trial',async()=>{
  const f=fixture();assert.equal((await f.request('status','fake')).status,401);
  assert.equal((await f.service.handle({method:'GET'})).status,405);assert.equal(f.db.data.size,0);
});
test('server owns price, plan and account binding',async()=>{
  const f=fixture();assert.equal((await f.request('checkout','A',{plan:'__proto__'})).status,400);
  await f.request('checkout','A',{plan:'monthly',cents:1,uid:'B'});
  assert.equal((await f.store.order(orderId)).uid,'A');
  f.payment({transaction_amount:'0.01'});assert.equal((await f.webhook()).status,503);
  assert.equal((await f.request('status')).body.paidUntil,null);
});
test('checkout opening and pending payment never grant paid time',async()=>{
  const f=fixture();await f.request('checkout','A',{plan:'monthly'});
  f.payment({status:'pending',date_approved:null});assert.equal((await f.webhook()).status,200);
  f.now(start+TRIAL_MS);assert.equal((await f.request('status')).body.active,false);
});
test('approved monthly preserves trial days; duplicate callbacks cannot extend it',async()=>{
  const f=fixture();await f.request('checkout','A',{plan:'monthly'});assert.equal((await f.webhook()).status,200);
  const first=(await f.request('status')).body;assert.equal(first.state,'paid');
  assert.equal(first.paidUntil,Date.parse('2026-11-20T12:00:00Z'));
  await Promise.all([f.webhook(),f.webhook()]);assert.equal((await f.request('status')).body.paidUntil,first.paidUntil);
  assert.equal((await f.request('status','B')).body.paidUntil,null);
});
test('annual is twelve calendar months and expires at the boundary',async()=>{
  const f=fixture();await f.request('checkout','A',{plan:'annual'});f.payment({transaction_amount:'55.00'});
  await f.webhook();const end=(await f.request('status')).body.paidUntil;
  assert.equal(end,Date.parse('2027-10-20T12:00:00Z'));f.now(end);assert.equal((await f.request('status')).body.active,false);
});
test('forged and cross-resource callbacks cannot query provider',async()=>{
  const f=fixture();assert.equal((await f.webhook({signature:'ts=1,v1='+'0'.repeat(64)})).status,401);
  assert.equal((await f.webhook({dataId:'999'})).status,400);assert.equal(f.calls(),0);
});
for(const patch of [{collector_id:1},{currency_id:'USD'},{live_mode:true}]) {
  test('mismatch rejected '+JSON.stringify(patch),async()=>{
    const f=fixture();await f.request('checkout','A',{plan:'monthly'});f.payment(patch);
    assert.equal((await f.webhook()).status,503);assert.equal((await f.request('status')).body.paidUntil,null);
  });
}
test('refund revokes access and stale approval cannot restore it',async()=>{
  const f=fixture();await f.request('checkout','A',{plan:'monthly'});await f.webhook();f.now(start+TRIAL_MS+1);
  f.payment({status:'refunded',transaction_amount_refunded:'4.90',date_last_updated:new Date(start+86400000).toISOString()});
  await f.webhook();assert.equal((await f.request('status')).body.active,false);
  f.payment({status:'approved',transaction_amount_refunded:0,date_last_updated:new Date(start).toISOString()});
  await f.webhook();assert.equal((await f.request('status')).body.active,false);
});
test('concurrent first access creates one trial',async()=>{
  const f=fixture();await Promise.all([f.request('status'),f.request('status')]);
  assert.equal(f.db.data.get('rochaBillingUsers/'+userKey('A')).trialEndsAt,start+TRIAL_MS);
});
test('checkout stays disabled until explicitly configured',async()=>{
  const f=fixture({paymentsEnabled:false});assert.equal((await f.request('checkout','A',{plan:'monthly'})).status,503);
  assert.equal((await f.request('status')).body.state,'trial');
});
test('calendar periods clamp month ends and leap years',()=>{
  assert.equal(addMonths(Date.parse('2028-01-31T10:00:00Z'),1),Date.parse('2028-02-29T10:00:00Z'));
  assert.equal(addMonths(Date.parse('2028-02-29T10:00:00Z'),12),Date.parse('2029-02-28T10:00:00Z'));
  assert.equal(access({trialEndsAt:start,payments:{}},start).active,false);
});

test('trial welcome is claimed once per verified account across devices', async()=>{
  const f=fixture();
  const replies=await Promise.all([f.request('claimTrialWelcomeNotice'),f.request('claimTrialWelcomeNotice')]);
  assert.deepEqual(replies.map(r=>r.body.showNotice).sort(),[false,true]);
  assert.equal((await f.request('claimTrialWelcomeNotice','A',{uid:'B'})).body.showNotice,false);
  assert.equal((await f.request('claimTrialWelcomeNotice','B')).body.showNotice,true);
  assert.equal((await f.request('claimTrialWelcomeNotice','fake')).status,401);
});
test('expired or paid accounts cannot receive a fresh seven-day welcome', async()=>{
  const f=fixture();await f.request('status');f.now(start+TRIAL_MS);
  assert.equal((await f.request('claimTrialWelcomeNotice')).body.showNotice,false);
  await f.request('checkout','A',{plan:'monthly'});await f.webhook();
  assert.equal((await f.request('claimTrialWelcomeNotice')).body.showNotice,false);
});

test('reading trial status never accepts the alert; acceptance survives account reload', async()=>{
  const f=fixture();
  assert.equal((await f.request('status')).body.trialWelcomeNoticeAccepted,false);
  assert.equal((await f.request('status')).body.trialWelcomeNoticeAccepted,false);
  await f.request('claimTrialWelcomeNotice');
  assert.equal((await f.request('status')).body.trialWelcomeNoticeAccepted,true);
  assert.equal((await f.request('status','B')).body.trialWelcomeNoticeAccepted,false);
});
