import assert from 'node:assert/strict';
import {createDeviceService} from '../../experiments/central-rights/devices.mjs';
import {memoryStore} from '../../experiments/central-rights/memory-store.mjs';
// Complete fixture-only manual approval flow. No external Auth, grants, socket or writes.
export async function runCrossPlatformPreparationTests(){
 let time=1800000000000,offline=false,revokedBefore=null;
 const uid='cross-fixture',phone='a'.repeat(64),store=memoryStore(),passed=[];
 const handle=createDeviceService({enabled:true,scope:'homologation',store,now:()=>time,
  verifyIdentity:async token=>({uid:token==='other'?'other':uid,email_verified:true,auth_time:Math.floor(time/1000),firebase:{sign_in_provider:'google.com'}}),
  getAccount:async id=>({uid:id,emailVerified:true,...(revokedBefore?{tokensValidAfterTime:new Date(revokedBefore).toISOString()}:{})}),
  loadRights:async id=>{if(offline)throw Error('offline');return {uid:id,labGrant:{uid:id,scope:'homologation',start:1800000000000-1,end:1800000000000+3600000}};}});
 const call=(action,extra={},token='phone')=>handle({body:{action,...extra},authorization:'Bearer '+token});
 const test=async(name,fn)=>{await fn();passed.push(name);};
 let pair,session;
 await test('manual TV code pending until explicit authenticated mobile approval',async()=>{assert.equal((await call('register_mobile',{mobile_id:phone})).status,200);pair=await call('start');assert.match(pair.body.user_code,/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);assert.equal((await call('poll',{device_code:pair.body.device_code})).status,202);assert.equal((await call('approve',{mobile_id:phone,user_code:pair.body.user_code})).status,200);const p=await call('poll',{device_code:pair.body.device_code});assert.equal(p.status,200);assert.equal(p.body.state,'lab');assert.equal(p.body.scope,'homologation');assert.equal(p.body.uid,uid);assert.equal(p.body.playbackAllowed,false);session=p.body.session_token;});
 await test('lost poll response safely retries same session without duplicate TV',async()=>{const retry=await call('poll',{device_code:pair.body.device_code});assert.equal(retry.body.session_token,session);const s=await store.read('devices');assert.equal(Object.keys(s.sessions).length,1);assert.equal(Object.values(s.accounts).find(a=>a.tvs.length)?.tvs.length,1);});
 await test('another authenticated account cannot claim already approved TV code',async()=>{const mobile='b'.repeat(64);await call('register_mobile',{mobile_id:mobile},'other');assert.equal((await call('approve',{mobile_id:mobile,user_code:pair.body.user_code},'other')).status,409);});
 await test('restored TV session survives transport failure without new pairing',async()=>{assert.equal((await call('status',{},session)).status,200);offline=true;assert.equal((await call('status',{},session)).status,503);offline=false;const restored=await call('status',{},session);assert.equal(restored.status,200);assert.equal(restored.body.device_id,pair.body.device_id);assert.equal(Object.keys((await store.read('devices')).sessions).length,1);});
 await test('identity global revocation rejects restored TV session at refresh',async()=>{revokedBefore=time+1;time+=2;assert.equal((await call('status',{playback_active:true},session)).status,401);assert.equal(Object.keys((await store.read('devices')).sessions).length,0);revokedBefore=null;});
 await test('unapproved pairing expires at ten minutes and cannot be replayed',async()=>{const pending=await call('start');time+=600000;assert.equal((await call('poll',{device_code:pending.body.device_code})).status,410);});
 return {passed:passed.length,failed:0,tests:passed,fixtureOnly:true,realGoogleLogin:false,qrImplemented:false,commercialWrites:0};
}
