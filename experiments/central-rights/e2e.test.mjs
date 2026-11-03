import assert from 'node:assert/strict';
import {createHash,createHmac} from 'node:crypto';
import https from 'node:https';
import {createCheckoutPreparation,createContractResolver} from './contracts.mjs';
import {fixturePaymentStore} from './fixture-payment-store.mjs';
import {memoryStore} from './memory-store.mjs';
import {createDeviceService} from './devices.mjs';
import {createPaymentPipeline} from './payments.mjs';
import {verifySignature} from './webhook-signature.mjs';
import {ephemeralTestTls} from './local-test-certificate.mjs';
import {createHttpsRuntime,listenLoopback} from './https-runtime.mjs';
export async function runEndToEndTests(){
 const labels=[],uid='fixture-account',time=1793640000000,DAY=86400000;
 const reservations=new Map(),binding={reserve:async v=>reservations.set(v.reference,v),reservation:async id=>reservations.get(id),reviewedPayment:async()=>null};
 const identity={uid,email:'fixture@example.test',email_verified:true,auth_time:Math.floor(time/1000),firebase:{sign_in_provider:'google.com'}};
 const verifyIdentity=async token=>{if(token!=='fixture-auth')throw Error('auth');return identity;};
 const prepare=createCheckoutPreparation({verifyIdentity,store:binding,now:()=>time,newId:()=> 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',catalog:{fixture:{amountCents:1000,months:1,policyApproved:true,periodPolicy:'independent-calendar-months-from-approval'}}});
 const intent=await prepare({authorization:'Bearer fixture-auth',plan:'fixture'});
 assert.equal(intent.providerCheckoutCreated,false);labels.push('verified checkout intent binds UID without creating charge');
 let payment={id:'1001',collector_id:'2002',payer:{id:'3003',email:identity.email},external_reference:intent.reference,currency_id:'BRL',live_mode:false,status:'approved',transaction_amount:10,transaction_amount_refunded:0,date_approved:new Date(time-DAY).toISOString(),date_last_updated:new Date(time).toISOString()};
 const paid=fixturePaymentStore(),pipeline=createPaymentPipeline({store:paid,provider:{payment:async()=>structuredClone(payment)},merchantId:'2002',now:()=>time,periodResolver:createContractResolver({store:binding}),verifySignature:a=>verifySignature({...a,secret:'fixture-secret',now:time})});
 const device=createDeviceService({enabled:true,scope:'commercial',store:memoryStore(),now:()=>time,verifyIdentity,getAccount:async id=>({uid:id,emailVerified:true,disabled:false}),loadRights:async id=>({uid:id,trialStartedAt:time-8*DAY,periods:(await paid.snapshot(id))?.periods??[]})});
 const tls=ephemeralTestTls(),server=await createHttpsRuntime({...tls,origin:'https://localhost',handle:device,paymentWebhook:pipeline.webhook}),address=await listenLoopback(server);
 const post=(path,body,token,headers={})=>new Promise((resolve,reject)=>{const req=https.request({host:'127.0.0.1',servername:'localhost',port:address.port,ca:tls.cert,method:'POST',path,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...headers}},res=>{let b='';res.on('data',d=>b+=d);res.on('end',()=>resolve({status:res.statusCode,body:JSON.parse(b)}));});req.on('error',reject);req.end(JSON.stringify(body));});
 const sig=()=> 'ts='+time+',v1='+createHmac('sha256','fixture-secret').update('id:1001;request-id:fixture-request;ts:'+time+';').digest('hex');
 const notification=()=>post('/v1/payment-notifications?data.id=1001',{type:'payment',data:{id:'1001'}},null,{'x-request-id':'fixture-request','x-signature':sig()});
 try {
  assert.equal((await post('/v1/access',{action:'register_mobile',mobile_id:'a'.repeat(64)},'fixture-auth')).status,403);labels.push('no paid right before reconciliation; expired trial not reset');
  assert.equal((await notification()).status,200);assert.equal((await notification()).status,200);assert.equal((await paid.snapshot(uid)).periods.length,1);labels.push('signed webhook GET verification and duplicate through HTTPS record one period');
  const phone='a'.repeat(64);assert.equal((await post('/v1/access',{action:'register_mobile',mobile_id:phone},'fixture-auth')).status,200);
  const start=await post('/v1/access',{action:'start'});
  assert.equal((await post('/v1/access',{action:'poll',device_code:start.body.device_code})).status,202);
  assert.equal((await post('/v1/access',{action:'approve',mobile_id:phone,user_code:start.body.user_code},'fixture-auth')).status,200);
  const poll=await post('/v1/access',{action:'poll',device_code:start.body.device_code});assert.equal(poll.body.uid,uid);assert.equal(poll.body.device_id,createHash('sha256').update(start.body.device_code).digest('hex'));labels.push('mobile approval and TV session bound to same canonical UID over HTTPS');
  const phoneState=await post('/v1/access',{action:'entitlement',mobile_id:phone},'fixture-auth'),tvState=await post('/v1/access',{action:'status',playback_active:true},poll.body.session_token);
  assert.equal(phoneState.body.state,'paid');assert.equal(tvState.body.state,'paid');assert.equal(phoneState.body.grantUntil,tvState.body.grantUntil);assert.equal(tvState.body.playbackAllowed,true);labels.push('phone and TV receive same period; stream lease distinct from navigation');
  payment={...payment,status:'refunded',transaction_amount_refunded:10,date_last_updated:new Date(time+1).toISOString()};assert.equal((await notification()).status,200);assert.equal((await post('/v1/access',{action:'status',playback_active:true},poll.body.session_token)).status,403);labels.push('refund through HTTPS removes period and denies TV renewal without touching trial');
 }finally{await new Promise(r=>server.close(r));}
 return {passed:labels.length,failed:0,tests:labels,fixtureOnly:true,realTlsLoopback:true,realFirebaseLogin:false,realPaymentCalls:false,commercialWrites:0,physicalPlayback:false};
}
