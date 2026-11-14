'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {bindCheckoutClaim} = require('./checkout_claim');
const orderId = '12345678-1234-1234-1234-123456789abc';
function fixture({order = {}, existingClaim = false, merchant = '123', reference = orderId} = {}) {
  const rows = new Map([
    ['checkout_orders/' + orderId, {uid:'user1',plan:'monthly',amountCents:450,
      currency:'BRL',mode:'one_time',merchantId:'123',preferenceId:'pref',...order}],
    ['entitlements/user1', {paidUntil:'preserved',trialUntil:'preserved'}],
  ]);
  if (existingClaim) rows.set('payment_claims/9', {reviewed:true,uid:'historical'});
  const writes=[];
  const db={collection: name => ({doc:id=>name+'/'+id}), runTransaction: async fn => fn({
    get:async ref=>({exists:rows.has(ref),data:()=>rows.get(ref)}),
    create:(ref,data)=>writes.push({ref,data}),
    update:(ref,data)=>writes.push({ref,data}),
  })};
  const original=global.fetch;
  global.fetch=async()=>({ok:true,json:async()=>({id:9,external_reference:reference,
    collector_id:merchant,live_mode:true,transaction_amount:4.5,currency_id:'BRL',
    status:'approved',status_detail:'accredited',transaction_amount_refunded:0,
    date_approved:'2026-11-04T12:00:00Z'})});
  return {rows,writes,run:()=>bindCheckoutClaim({db,paymentId:'9',accessToken:'fixture'}),
    restore:()=>{global.fetch=original;}};
}
test('canonical payment binds authenticated order without resetting paid access',async()=>{
  const f=fixture();try {await f.run();
    assert.equal(f.writes[0].ref,'payment_claims/9');
    assert.equal(f.writes[0].data.uid,'user1');
    assert.equal(f.writes[0].data.plan,'monthly');
    assert.equal(f.writes.some(w=>w.ref.startsWith('entitlements/')),false);
  } finally {f.restore();}
});
test('merchant mismatch never writes',async()=>{
  const f=fixture({merchant:'999'});try {await assert.rejects(f.run);assert.equal(f.writes.length,0);}
  finally {f.restore();}
});
test('a second payment cannot consume same one-time order',async()=>{
  const f=fixture({order:{paymentId:'8'}});try {await assert.rejects(f.run);assert.equal(f.writes.length,0);}
  finally {f.restore();}
});
test('historical claims are preserved',async()=>{
  const f=fixture({existingClaim:true});try {await f.run();assert.equal(f.writes.length,0);}
  finally {f.restore();}
});
test('historical references do not generate new claims',async()=>{
  const f=fixture({reference:'old-link'});try {await f.run();assert.equal(f.writes.length,0);}
  finally {f.restore();}
});


test('current monthly amount binds to verified order',async()=>{
  const f=fixture({order:{amountCents:790}});
  global.fetch=async()=>({ok:true,json:async()=>({id:9,external_reference:orderId,
    collector_id:'123',live_mode:true,transaction_amount:7.9,currency_id:'BRL',
    status:'approved',status_detail:'accredited',transaction_amount_refunded:0,
    date_approved:'2026-11-05T12:00:00Z'})});
  try {await f.run();assert.equal(f.writes[0].data.amountCents,790);}
  finally {f.restore();}
});
test('legacy annual order retains originally recorded price',async()=>{
  const f=fixture({order:{plan:'annual',amountCents:4950}});
  global.fetch=async()=>({ok:true,json:async()=>({id:9,external_reference:orderId,
    collector_id:'123',live_mode:true,transaction_amount:49.5,currency_id:'BRL',
    status:'approved',status_detail:'accredited',transaction_amount_refunded:0,
    date_approved:'2026-11-04T12:00:00Z'})});
  try {await f.run();assert.equal(f.writes[0].data.amountCents,4950);}
  finally {f.restore();}
});
test('unsupported price rejected even if provider agrees',async()=>{
  const f=fixture({order:{amountCents:123}});
  global.fetch=async()=>({ok:true,json:async()=>({id:9,external_reference:orderId,
    collector_id:'123',live_mode:true,transaction_amount:1.23,currency_id:'BRL',
    status:'approved',status_detail:'accredited',transaction_amount_refunded:0,
    date_approved:'2026-11-04T12:00:00Z'})});
  try {await assert.rejects(f.run);assert.equal(f.writes.length,0);}
  finally {f.restore();}
});

test('missing entitlement on claim reuses the Spark trial start instead of 7 new days',async()=>{
  const started=new Date(Date.now()-5*86400000);
  const f=fixture({order:{googleSubject:'g-subject-1'}});
  f.rows.delete('entitlements/user1');
  f.rows.set('rochaSparkAccounts/g-subject-1',{trialStartedAt:started});
  try {await f.run();
    const ent=f.writes.find(w=>w.ref==='entitlements/user1');
    assert.equal(ent.data.trialStartedAt.getTime(),started.getTime());
    assert.equal(ent.data.trialUntil.getTime(),started.getTime()+7*86400000);
    assert.ok(f.writes.some(w=>w.ref==='trialAnchors/g-subject-1'));
  } finally {f.restore();}
});
