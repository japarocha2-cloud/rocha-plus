import test from 'node:test';import assert from 'node:assert/strict';
import {createPairingService,keyOf} from './service.mjs';
function setup(){
 const records=new Map();const codes=new Map();let time=1000;let uid='owner';let fail=false;let minted=0;
 const store={throttle:async()=>true,create:async r=>{records.set(r.key,r);codes.set(r.codeKey,r.key);return true;},read:async k=>records.get(k),approve:async(k,id,now)=>{const r=records.get(codes.get(k));if(!r||r.expires<=now)return'expired';if(r.uid&&r.uid!==id)return'conflict';r.uid=id;return'approved';},remove:async r=>{records.delete(r.key);codes.delete(r.codeKey);}};
 const handler=createPairingService({store,apiKey:'public-client-config',now:()=>time,verifyIdentity:async()=>{if(fail)throw Error();return{uid,firebase:{sign_in_provider:'google.com'},roku_device:[...records.keys()][0]};},mintToken:async()=>{minted++;return'fake-custom-token';}});
 return{handler,store,records,setTime:t=>time=t,setUid:v=>uid=v,setFail:v=>fail=v,minted:()=>minted};
}
test('only verified approval releases a token and complete invalidates pairing',async()=>{
 const s=setup();const start=await s.handler({method:'POST',body:{action:'start'},address:'test'});assert.equal(start.status,200);
 const body={action:'poll',device_code:start.body.device_code};assert.equal((await s.handler({method:'POST',body})).status,202);assert.equal(s.minted(),0);
 assert.equal((await s.handler({method:'POST',body:{action:'approve',user_code:start.body.user_code},authorization:'Bearer valid'})).status,200);
 const poll=await s.handler({method:'POST',body});assert.equal(poll.body.custom_token,'fake-custom-token');
 assert.equal((await s.handler({method:'POST',body:{...body,action:'complete'},authorization:'Bearer valid'})).status,200);
 assert.equal((await s.handler({method:'POST',body})).status,410);
});
test('unsigned or invalid identities cannot approve',async()=>{
 const s=setup();const start=await s.handler({method:'POST',body:{action:'start'}});
 const body={action:'approve',user_code:start.body.user_code};assert.equal((await s.handler({method:'POST',body})).status,401);
 s.setFail(true);assert.equal((await s.handler({method:'POST',body,authorization:'Bearer invalid'})).status,401);assert.equal(s.minted(),0);
});
test('expired codes and another user cannot take ownership',async()=>{
 const s=setup();const start=await s.handler({method:'POST',body:{action:'start'}});const body={action:'approve',user_code:start.body.user_code};
 await s.handler({method:'POST',body,authorization:'Bearer valid'});s.setUid('another');assert.equal((await s.handler({method:'POST',body,authorization:'Bearer valid'})).status,409);
 s.setTime(700000);assert.equal((await s.handler({method:'POST',body:{action:'poll',device_code:start.body.device_code}})).status,410);
});
test('wrong device and rate limited requests fail closed',async()=>{
 const s=setup();assert.equal((await s.handler({method:'POST',body:{action:'poll',device_code:'guess'}})).status,400);
 s.store.throttle=async()=>false;assert.equal((await s.handler({method:'POST',body:{action:'start'}})).status,429);
});
test('missing configuration and store errors return safe failures',async()=>{
 const s=setup();const off=createPairingService({apiKey:'',store:s.store});assert.equal((await off({method:'POST',body:{action:'start'}})).status,503);
 s.store.create=async()=>{throw Error('private credential')};const r=await s.handler({method:'POST',body:{action:'start'}});assert.equal(r.status,503);assert(!JSON.stringify(r).includes('private credential'));
});
