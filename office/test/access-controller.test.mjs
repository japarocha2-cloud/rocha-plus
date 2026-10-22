import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccessController } from '../src/access-controller.mjs';
import { buildConfig } from '../src/build-config.mjs';
const grant = uid => ({ uid, allowed: true, product: 'rocha-office-basic' });
const pending = () => { let resolve, reject; const promise = new Promise((a,b) => {resolve=a;reject=b;}); return {promise,resolve,reject}; };
function fixture(verifyAccess, options = {}) {
  const events = [], timers = new Map(); let id = 0;
  const controller = createAccessController({ verifyAccess,
    showEditor: uid => events.push(['open', uid]), hideEditor: discard => events.push(['lock', discard]),
    setStatus: message => events.push(['status', message]),
    schedule: callback => { timers.set(++id,callback); return id; }, unschedule: id => timers.delete(id), ...options });
  return { controller, events, tick: () => Promise.all([...timers.values()].map(f => f())), timers };
}
test('editor opens only after matching account and bundle authorization', async () => {
  for (const result of [{allowed:false},grant('another-account'),{...grant('alice'),product:'tv'}]) {
    const f=fixture(async()=>result); await f.controller.account('alice');
    assert.equal(f.events.some(e=>e[0]==='open'),false); f.controller.close();
  }
  const f=fixture(async()=>grant('alice')); await f.controller.account('alice');
  assert.equal(f.events.filter(e=>e[0]==='open').length,1); f.controller.close();
});
test('logout and switching account discard the previous editor and reject late grants', async()=>{
  const old=pending(); const f=fixture(uid=>uid==='alice'?old.promise:Promise.resolve(grant(uid)));
  const first=f.controller.account('alice'); await f.controller.account('bob'); old.resolve(grant('alice')); await first;
  assert.deepEqual(f.events.filter(e=>e[0]==='open'),[['open','bob']]);
  await f.controller.account(null); assert.deepEqual(f.events.filter(e=>e[0]==='lock').at(-1),['lock',true]); f.controller.close();
});
test('refresh denial locks the editor without discarding unsaved work; regrant resumes it', async()=>{
  let allowed=true; const calls=[];const f=fixture(async(uid,activate)=>{calls.push(activate);return {...grant(uid),allowed};});
  await f.controller.account('alice');allowed=false;await f.tick();
  assert.deepEqual(f.events.filter(e=>e[0]==='lock').at(-1),['lock',false]);
  allowed=true;await f.controller.resume();assert.equal(f.events.filter(e=>e[0]==='open').length,2);
  assert.deepEqual(calls,[true,false,false]);f.controller.close();
});
test('older successful refresh cannot undo a newer denial',async()=>{
  const requests=[];let initial=true;const f=fixture(uid=>{if(initial){initial=false;return Promise.resolve(grant(uid));}const p=pending();requests.push(p);return p.promise;});
  await f.controller.account('alice');const a=f.tick();const b=f.tick();
  requests[1].resolve({...grant('alice'),allowed:false});await b;requests[0].resolve(grant('alice'));await a;
  assert.equal(f.events.filter(e=>e[0]==='open').length,1);f.controller.close();
});
test('verification timeout denies access and ignores eventual result',async()=>{
  const p=pending();const f=fixture(()=>p.promise,{verificationTimeoutMs:10});
  await f.controller.account('alice');assert.equal(f.events.some(e=>e[0]==='open'),false);
  p.resolve(grant('alice'));await Promise.resolve();assert.equal(f.events.some(e=>e[0]==='open'),false);f.controller.close();
});
test('closing cancels timers and ignores pending checks',async()=>{
  const p=pending();const f=fixture(()=>p.promise);const check=f.controller.account('alice');f.controller.close();p.resolve(grant('alice'));await check;
  assert.equal(f.timers.size,0);assert.equal(f.events.some(e=>e[0]==='open'),false);
});
test('commercial build cannot silently ship without Firebase and fixed HTTPS endpoints',()=>{
  assert.deepEqual(buildConfig({}),{commercial:false,enabled:false});
  assert.throws(()=>buildConfig({ROCHA_OFFICE_COMMERCIAL:'true'}));
  assert.throws(()=>buildConfig({ROCHA_OFFICE_COMMERCIAL:'TRUE'}));
  const env={ROCHA_OFFICE_COMMERCIAL:'true',ROCHA_OFFICE_LICENSE_URL:'https://office.example',ROCHA_OFFICE_PORTAL_URL:'https://site.example/activate/',ROCHA_OFFICE_FIREBASE_JSON:JSON.stringify({projectId:'rocha-plus',apiKey:'public-test',authDomain:'rocha-plus.firebaseapp.com',private_key:'must-never-be-copied'})};
  const result=buildConfig(env);assert.equal(result.enabled,true);assert.equal(result.firebase.private_key,undefined);
  assert.throws(()=>buildConfig({...env,ROCHA_OFFICE_LICENSE_URL:'http://office.example'}));
});

test('manual retry can activate a newly available slot while automatic refresh cannot',async()=>{
  const calls=[];let first=true;
  const f=fixture(async(uid,activate)=>{calls.push(activate);if(first){first=false;throw Error('Two installation limit reached');}return grant(uid);});
  await f.controller.account('alice');await f.controller.resume({activate:true});
  assert.deepEqual(calls,[true,true]);assert.equal(f.events.filter(e=>e[0]==='open').length,1);f.controller.close();
});
