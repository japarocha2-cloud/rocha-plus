import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createDeviceService} from './devices.mjs';
import {memoryStore} from './memory-store.mjs';
const same=(a,b)=>assert.equal(JSON.stringify(a),JSON.stringify(b));
const hash=s=>createHash('sha256').update(s).digest('hex');
export async function runReservationTests(factory=createDeviceService){
 const passed=[];
 async function fixture(){
  let time=1800000000000,offline=false,revoked=false;
  const uid='reservation-fixture',phone='a'.repeat(64),tv1='b'.repeat(64),tv2='c'.repeat(64),token1='d'.repeat(64),token2='e'.repeat(64);
  const store=memoryStore();
  await store.seed('devices',{pairs:{},rates:{},sessions:{[hash(token1)]:{uid,device:tv1,issuedAt:time,until:time+86400000},[hash(token2)]:{uid,device:tv2,issuedAt:time,until:time+86400000}},accounts:{[hash(uid)]:{phone:{id:hash(phone),authTime:time/1000},tvs:[tv1,tv2],streams:{}}}});
  const handle=factory({store,enabled:true,scope:'homologation',now:()=>time,
   verifyIdentity:async()=>({uid,email_verified:true,auth_time:time/1000,firebase:{sign_in_provider:'google.com'}}),
   getAccount:async()=>({uid,emailVerified:true}),
   loadRights:async()=>{if(offline)throw Error('network');return {uid,...(revoked?{revokedAt:time}:{}),labGrant:{uid,scope:'homologation',start:1800000000000-1,end:1800000000000+3600000}};}});
  const call=(action,extra={},token='fixture')=>handle({body:{action,...extra},authorization:'Bearer '+token});
  const mobile=()=>call('mobile_playback',{mobile_id:phone});
  const play=token=>call('status',{playback_active:true},token);
  const streams=async()=>structuredClone((await store.read('devices')).accounts[hash(uid)].streams);
  const two=async()=>{assert.equal((await mobile()).status,200);assert.equal((await play(token1)).status,200);};
  return {call,mobile,play,streams,two,phone,tv1,tv2,token1,token2,store,uid,advance:n=>time+=n,offline:v=>offline=v,revoked:v=>revoked=v};
 }
 async function test(name,fn){const f=await fixture();await fn(f);passed.push(name);}
 await test('1 two playback reservations allowed and repeat start occupies one slot',async f=>{await f.two();await f.mobile();assert.equal(Object.keys(await f.streams()).length,2);});
 await test('2 third playback rejected with HTTP409',async f=>{await f.two();assert.equal((await f.play(f.token2)).status,409);});
 await test('3 mobile entitlement preserves reservations and third remains409',async f=>{await f.two();const before=await f.streams();assert.equal((await f.call('entitlement',{mobile_id:f.phone})).status,200);same(await f.streams(),before);assert.equal((await f.play(f.token2)).status,409);});
 await test('4 Android TV neutral navigation preserves both reservations',async f=>{await f.two();const before=await f.streams();assert.equal((await f.call('status',{},f.token1)).status,200);same(await f.streams(),before);assert.equal((await f.play(f.token2)).status,409);});
 await test('5 repeated status reads neither release nor extend leases',async f=>{await f.two();const before=await f.streams();f.advance(1000);for(let i=0;i<5;i++)await f.call('status',{},f.token1);same(await f.streams(),before);assert.equal((await f.play(f.token2)).status,409);});
 await test('6 explicit TV stop releases only corresponding slot',async f=>{await f.two();const before=await f.streams();await f.call('status',{playback_active:false},f.token1);same(await f.streams(),{mobile:before.mobile});});
 await test('7 logout removes only its TV session and stream, preserving phone/other TV',async f=>{await f.play(f.token1);await f.play(f.token2);await f.call('logout',{},f.token1);const state=await f.store.read('devices');assert(!state.sessions[hash(f.token1)]);assert(state.sessions[hash(f.token2)]);same(state.accounts[hash(f.uid)].tvs,[f.tv2]);assert(state.accounts[hash(f.uid)].phone);same(Object.keys(await f.streams()),[f.tv2]);});
 await test('8 revocation denies renewal for mobile and TV',async f=>{await f.two();f.revoked(true);assert.equal((await f.mobile()).status,403);assert.equal((await f.play(f.token1)).status,403);});
 await test('9 lease expiry frees capacity only at actual deadline',async f=>{await f.two();f.advance(59999);assert.equal((await f.play(f.token2)).status,409);f.advance(1);assert.equal((await f.play(f.token2)).status,200);});
 await test('10 network failure does not release a valid reservation',async f=>{await f.two();const before=await f.streams();f.offline(true);assert.equal((await f.play(f.token1)).status,503);same(await f.streams(),before);f.offline(false);assert.equal((await f.play(f.token2)).status,409);});
 await test('11 concurrent contenders for last slot: one200 and one409 atomically',async f=>{await f.mobile();const r=await Promise.all([f.play(f.token1),f.play(f.token2)]);same(r.map(x=>x.status).sort(),[200,409]);assert.equal(Object.keys(await f.streams()).length,2);});
 await test('12 legitimate mobile stop permits retry without altering TV lease',async f=>{await f.two();const before=await f.streams();await f.call('mobile_stop',{mobile_id:f.phone});same(await f.streams(),{[f.tv1]:before[f.tv1]});assert.equal((await f.play(f.token2)).status,200);});
 return {passed:passed.length,failed:0,tests:passed,fixtureOnly:true,cloudWrites:0};
}
