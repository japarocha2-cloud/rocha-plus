import test from 'node:test';
import assert from 'node:assert/strict';
import './account.js';
const RochaAccount = globalThis.RochaAccount;
function fixture() {
  let clock=1000;
  const values=new Map();
  const storage={getItem:key=>values.get(key),setItem:(key,value)=>values.set(key,value),removeItem:key=>values.delete(key)};
  let grant={active:true,state:'trial',serverTime:100000,accessUntil:200000,trialRemainingDays:1};
  const account=new RochaAccount({billingEndpoint:'https://example.com/billing',pairingEndpoint:'https://example.com/pairing'},
    {storage,clock:()=>clock,fetcher:async()=>({ok:true,json:async()=>grant})});
  account.uid='A';account.idToken='synthetic';
  return {account,clock:value=>clock=value,grant:value=>grant=value,storage};
}
test('web TV uses server duration and monotonic clock',async()=>{
  const f=fixture();await f.account.refreshAccess();assert.equal(f.account.allowed,true);
  f.clock(101001);assert.equal(f.account.allowed,false);f.account.dispose();
});
test('expired payment or invalid reply closes TV access',async()=>{
  const f=fixture();await f.account.refreshAccess();f.grant({active:false,state:'expired',serverTime:1,accessUntil:null});
  await f.account.refreshAccess();assert.equal(f.account.allowed,false);f.account.dispose();
});
test('missing TV configuration cannot enter authenticated content',async()=>{
  const f=fixture();f.account.config.billingEndpoint='';await f.account.start();
  assert.equal(f.account.allowed,false);f.account.dispose();
});
test('TV logout clears identity and cannot leave a playback grant',async()=>{
  const f=fixture();f.account.apiKey='public-client-config';f.account.setIdentity('synthetic','synthetic-refresh','A',3600);
  await f.account.refreshAccess();f.account.signOut();assert.equal(f.account.allowed,false);
  assert.equal(f.storage.getItem('rocha_account'),undefined);assert.equal(f.account.uid,'');
});
