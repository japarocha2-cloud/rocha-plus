import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { createPairingService } from './pairing.mjs';
import { PRODUCT } from './service.mjs';
import { pairInstallation } from '../../office/src/pairing-client.mjs';
const rejects = (p,s)=>assert.rejects(p,e=>e.status===s);
function device(){const k=generateKeyPairSync('ec',{namedCurve:'prime256v1'});return {publicKey:k.publicKey.export({format:'jwk'}),sign:m=>sign('sha256',Buffer.from(m),{key:k.privateKey,dsaEncoding:'ieee-p1363'}).toString('base64url')};}
function fixture(){
  let time=Date.UTC(2026,9,22);const records=new Map(),issued=[];let queue=Promise.resolve();
  const service=createPairingService({portalUrl:'https://site.example/activate/',now:()=>time,
    verifyToken:async(t,revoked)=>{assert.equal(revoked,true);if(t!=='buyer'&&t!=='unpaid')throw Error();return {uid:t,email_verified:true,email:`${t}@example.test`,auth_time:Math.floor(time/1000),firebase:{sign_in_provider:'google.com'}};},
    licenseStore:{transact:async(uid,_,cb)=>cb({payments:uid==='buyer'?[{product:PRODUCT,status:'confirmed'}]:[]})},
    store:{transact(id,cb){const task=queue.then(async()=>{let record=structuredClone(records.get(id));const result=await cb({record,set:r=>{record=r;}});records.set(id,record);return result;});queue=task.catch(()=>{});return task;}},
    mintSession:async args=>{issued.push(args);return 'TEST-CUSTOM-TOKEN';},
  });
  const req=(action,body,token)=>service({method:'POST',path:`/v1/office/pair/${action}`,body,authorization:token?`Bearer ${token}`:undefined});
  const start=d=>req('start',{publicKey:d.publicKey,label:'Windows'});
  const finish=(d,s,overrides={})=>req('finish',{id:s.id,secret:s.secret,signature:d.sign(s.message),...overrides});
  const approve=(s,token='buyer',body={})=>req('approve',{id:s.id,code:s.code,...body},token);
  return {req,start,finish,approve,records,issued,advance:ms=>{time+=ms;}};
}
test('pairing needs real Google approval and private installation proof before token minting',async()=>{
  const f=fixture(),d=device(),s=await f.start(d);assert.equal((await f.finish(d,s)).pending,true);
  assert.ok(!s.approvalUrl.includes(s.secret)&&!s.approvalUrl.includes(s.code));
  await f.approve(s);await rejects(f.finish(device(),s),403);
  const result=await f.finish(d,s);assert.equal(result.customToken,'TEST-CUSTOM-TOKEN');assert.equal(f.issued[0].uid,'buyer');
  await rejects(f.finish(d,s),410);assert.equal(f.issued.length,1);
});
test('unpaid account, missing Google token and wrong user code cannot authorize',async()=>{
  const f=fixture(),s=await f.start(device());await rejects(f.approve(s,'unpaid'),403);await rejects(f.approve(s,null),401);
  await rejects(f.approve(s,'buyer',{code:'WRONG123'}),403);assert.equal(f.issued.length,0);
});
test('expired and concurrently redeemed pairings mint at most one token',async()=>{
  const f=fixture(),d=device(),s=await f.start(d);await f.approve(s);
  const results=await Promise.allSettled([f.finish(d,s),f.finish(d,s)]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(f.issued.length,1);
  const expired=await f.start(d);f.advance(120_000);await rejects(f.approve(expired),410);await rejects(f.finish(d,expired),410);
});
test('pairing client rejects changed browser destination before opening it',async()=>{
  let opened=false;
  await assert.rejects(pairInstallation({endpoint:'https://office.example',portalUrl:'https://site.example/activate/',device:device(),showCode:()=>{},openBrowser:()=>{opened=true;},fetch:async()=>new Response(JSON.stringify({id:'x'.repeat(43),approvalUrl:'https://attacker.example/#pair='+ 'x'.repeat(43),code:'ABCDEFGH',expiresAtMs:Date.now()+60_000}))}));
  assert.equal(opened,false);
});
test('pairing browser approval and client redemption complete the signed-key flow',async()=>{
  const f=fixture(),d=device();let shown;
  const token=await pairInstallation({endpoint:'https://office.example',portalUrl:'https://site.example/activate/',device:d,showCode:c=>{shown=c;},
    openBrowser:async url=>{const id=new URLSearchParams(new URL(url).hash.slice(1)).get('pair');await f.req('approve',{id,code:shown},'buyer');},
    fetch:async(url,opts)=>{try{return new Response(JSON.stringify(await f.req(url.split('/').at(-1),JSON.parse(opts.body))));}catch(e){return new Response(JSON.stringify({error:e.message}),{status:e.status||503});}},
  });assert.equal(token,'TEST-CUSTOM-TOKEN');assert.equal(f.issued.length,1);
});
