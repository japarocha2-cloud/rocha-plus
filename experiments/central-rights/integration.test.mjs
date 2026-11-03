import assert from 'node:assert/strict';
import {createHmac,createHash} from 'node:crypto';
import {resolveRights,rightsPacket,validatePacket,DAY} from './rights.mjs';
import {fixturePaymentStore} from './fixture-payment-store.mjs';
import {memoryStore} from './memory-store.mjs';
import {createPaymentPipeline} from './payments.mjs';
import {createDeviceService} from './devices.mjs';
import {verifySignature} from './webhook-signature.mjs';
import {assertExperimentalStore} from './firestore-adapters.mjs';
export async function runIntegrationTests(){
 const passed=[];async function test(name,fn){await fn();passed.push(name);}
 let time=1793640000000;const uid='fixture-user';
 const period={uid,verified:true,plan:'fixture-plan',start:time-DAY,end:time+DAY,status:'approved',refundedCents:0};
 const rights={uid,trialStartedAt:time-10*DAY,periods:[period]};
 await test('paid current and matching UID',()=>assert.equal(resolveRights(rights,uid,time).state,'paid'));
 await test('seven-day trial uses original start; no new trial',()=>{assert.equal(resolveRights({uid,trialStartedAt:time-DAY},uid,time).state,'trial');assert.equal(resolveRights({uid,trialStartedAt:time-8*DAY},uid,time).state,'trial_expired');assert.equal(resolveRights(null,uid,time).state,'unknown');});
 await test('independent paid periods never stack',()=>assert.equal(resolveRights({...rights,periods:[period,{...period,end:time+2*DAY}]},uid,time).expiresAt,time+2*DAY));
 await test('paid expiry, revocation and wrong UID deny',()=>{assert(!resolveRights(rights,uid,time+2*DAY).active);assert(!resolveRights({...rights,revokedAt:time},uid,time).active);assert(!resolveRights(rights,'other',time).active);});
 await test('unknown/network response never authorizes',()=>assert.equal(validatePacket(null,{uid,device:'tv',scope:'commercial'}),0));
 await test('lease binds UID/device/scope and server clock',()=>{const p=rightsPacket(resolveRights(rights,uid,time),uid,'tv',time,'commercial');assert.equal(validatePacket(p,{uid,device:'tv',scope:'commercial',elapsedMs:20}),59980);assert.equal(validatePacket(p,{uid:'wrong',device:'tv',scope:'commercial'}),0);assert.equal(validatePacket({...p,grantUntil:time+1},{uid,device:'tv',scope:'commercial'}),0);});
 const payStore=fixturePaymentStore();let approvedPolicy=false,contractUid=uid;
 let payment={id:'1001',collector_id:'2002',payer:{id:'3003'},currency_id:'BRL',live_mode:false,status:'approved',transaction_amount:10,transaction_amount_refunded:0,date_approved:new Date(time-DAY).toISOString(),date_last_updated:new Date(time).toISOString()};
 const provider={payment:async()=>structuredClone(payment)};
 const pipeline=createPaymentPipeline({store:payStore,provider,verifySignature:()=>true,merchantId:'2002',now:()=>time,
  periodResolver:async p=>({uid:contractUid,plan:'fixture-plan',amountCents:1000,start:time-DAY,end:time+DAY,approvedPolicy,bindingVerified:true,payerId:'3003',paymentId:String(p.id)})});
 const event=()=>pipeline.webhook({method:'POST',dataId:String(payment.id),body:{type:'payment',data:{id:payment.id}}});
 await test('approved payment without approved contract queues alert, no entitlement',async()=>{const r=await event();assert.equal(r.status,200);assert.equal(r.body.reconciliationRequired,true);assert.equal(await payStore.snapshot(uid),undefined);assert.equal(Object.keys(await payStore.alerts()).length,1);});
 approvedPolicy=true;
 await test('reprocess same pending revision after contract verification',async()=>{const r=await pipeline.reprocess('1001');assert.equal(r.changed,true);assert.equal((await payStore.snapshot(uid)).periods.length,1);assert.equal(Object.keys(await payStore.alerts()).length,0);});
 await test('duplicate and concurrent webhook never extend period',async()=>{const out=await Promise.all([event(),event(),event()]);assert(out.every(r=>r.status===200));assert.equal((await payStore.snapshot(uid)).periods.length,1);assert.equal((await payStore.snapshot(uid)).periods[0].end,time+DAY);});
 await test('temporary provider failure returns 503 and safe retry',async()=>{const bad=createPaymentPipeline({store:payStore,provider:{payment:async()=>{throw Error('network');}},verifySignature:()=>true,merchantId:'2002'});assert.equal((await bad.webhook({method:'POST',dataId:'1001',body:{type:'payment',data:{id:'1001'}}})).status,503);assert.equal((await event()).status,200);});
 await test('pending/rejected/cancelled never authorize',async()=>{for(const status of ['pending','rejected','cancelled']){payment={...payment,id:String(Number(payment.id)+1),status,date_last_updated:new Date(time).toISOString()};await event();assert(!resolveRights(await payStore.snapshot(uid),uid,time+2*DAY).active);}});
 payment={...payment,id:'1001',status:'refunded',transaction_amount_refunded:10,date_last_updated:new Date(time+1).toISOString()};
 await test('refund revokes only corresponding period and leaves trial untouched',async()=>{await event();assert(!resolveRights(await payStore.snapshot(uid),uid,time).active);assert.equal(resolveRights({...await payStore.snapshot(uid),trialStartedAt:time-1},uid,time).state,'trial');});
 await test('out-of-order approval cannot resurrect refunded payment',async()=>{payment={...payment,status:'approved',transaction_amount_refunded:0,date_last_updated:new Date(time).toISOString()};await event();assert.equal((await payStore.snapshot(uid)).periods.find(p=>p.paymentKey===createHash('sha256').update('mercadopago:1001').digest('hex')).status,'refunded');});
 await test('global payment UID conflict rejects',async()=>{contractUid='other';payment={...payment,date_last_updated:new Date(time+2).toISOString()};await assert.rejects(pipeline.reprocess('1001'));contractUid=uid;});
 await test('wrong merchant/resource and fake signature rejected',async()=>{payment={...payment,collector_id:'wrong'};assert.equal((await event()).status,503);const bad=createPaymentPipeline({store:payStore,provider,verifySignature:()=>false});assert.equal((await bad.webhook({method:'POST',dataId:'1001',body:{type:'payment',data:{id:'1001'}}})).status,401);});
 await test('signature seconds/milliseconds, tamper and timestamp tolerance',()=>{for(const ts of [String(Math.floor(time/1000)),String(time)]){const sig=createHmac('sha256','fixture-secret').update('id:abc;request-id:req;ts:'+ts+';').digest('hex');const args={secret:'fixture-secret',dataId:'ABC',requestId:'req',signature:'ts='+ts+',v1='+sig,now:time};assert(verifySignature(args));assert(!verifySignature({...args,dataId:'other'}));assert(!verifySignature({...args,now:time+300001}));}});
 const store=memoryStore();let network=false,revoked=false,accountDisabled=false;
 const getAccount=async id=>({uid:id,emailVerified:true,disabled:accountDisabled});
 let currentAuthTime=Math.floor(time/1000);
 const handle=createDeviceService({enabled:true,store,now:()=>time,getAccount,
  verifyIdentity:async token=>{if(token==='expired')throw Error('expired');return {uid:token==='other'?'other':uid,email_verified:true,auth_time:currentAuthTime,firebase:{sign_in_provider:'google.com'}};},
  loadRights:async id=>{if(network)throw Error('offline');return {...rights,uid:id,periods:[{...period,uid:id}],...(revoked?{revokedAt:time}:{})};}});
 const phone='a'.repeat(64),phone2='b'.repeat(64);
 const call=(action,body={},token='valid')=>handle({body:{action,...body},authorization:'Bearer '+token,address:'fixture'});
 await test('expired identity token and nonexistent account denied',async()=>{assert.equal((await call('register_mobile',{mobile_id:phone},'expired')).status,401);accountDisabled=true;assert.equal((await call('register_mobile',{mobile_id:phone})).status,401);accountDisabled=false;});
 await test('register one fresh phone',async()=>assert.equal((await call('register_mobile',{mobile_id:phone})).status,200));
 async function bind(){const start=await call('start');assert.equal(start.status,200);const a=await call('approve',{mobile_id:phone,user_code:start.body.user_code});return{start,a,poll:()=>call('poll',{device_code:start.body.device_code})};}
 const tv1=await bind(),tv2=await bind();const poll1=await tv1.poll(),poll2=await tv2.poll();const token1=poll1.body.session_token,token2=poll2.body.session_token;
 await test('two TVs securely linked; idle TVs consume no streams',async()=>{assert.equal(tv1.a.status,200);assert.equal(tv2.a.status,200);assert.equal((await call('mobile_playback',{mobile_id:phone})).status,200);await call('mobile_stop',{mobile_id:phone});});
 await test('third TV rejected',async()=>{const tv3=await bind();assert.equal(tv3.a.status,409);});
 await test('two concurrent TV plays allowed; third stream denied',async()=>{const r=await Promise.all([call('status',{playback_active:true},token1),call('status',{playback_active:true},token2)]);assert(r.every(x=>x.status===200&&x.body.playbackAllowed));assert.equal((await call('mobile_playback',{mobile_id:phone})).status,409);});
 await test('stop releases slot for TV plus phone',async()=>{await call('status',{playback_active:false},token2);assert.equal((await call('mobile_playback',{mobile_id:phone})).status,200);});
 await test('new phone disconnects old phone but preserves both TVs',async()=>{time+=1000;currentAuthTime=Math.floor(time/1000);assert.equal((await call('register_mobile',{mobile_id:phone2})).status,200);assert.equal((await call('mobile_playback',{mobile_id:phone})).status,403);assert.equal((await call('status',{},token1)).status,200);assert.equal((await call('status',{},token2)).status,200);});
 await test('network failure denies renewal and existing lease expires',async()=>{network=true;assert.equal((await call('status',{playback_active:true},token1)).status,503);network=false;assert.equal((await call('status',{playback_active:true},token1)).status,200);});
 await test('expiry/revocation during playback denies and frees slot',async()=>{revoked=true;assert.equal((await call('status',{playback_active:true},token1)).status,403);revoked=false;time=period.end+1;assert([401,403].includes((await call('status',{playback_active:true},token2)).status));});
 await test('production and candidate Firestore writers refused',()=>{for(const projectId of ['rocha-plus','rocha-plus-candidate'])assert.throws(()=>assertExperimentalStore({projectId},{projectId,enableExperimentalWrites:true}));assert.throws(()=>assertExperimentalStore({projectId:'fixture-lab'},{projectId:'fixture-lab'}));});
 return {passed:passed.length,failed:0,tests:passed,fixtureOnly:true,commercialWrites:0};
}
