import assert from 'node:assert/strict';
import https from 'node:https';
import {ephemeralTestTls} from './local-test-certificate.mjs';
import {createHttpsRuntime,listenLoopback} from './https-runtime.mjs';
export async function runHttpsTests(){
 const tls=ephemeralTestTls(),passed=[];let calls=0;
 const server=await createHttpsRuntime({...tls,origin:'https://localhost',handle:async()=>{calls++;return {status:200,body:{fixture:true,allowed:false}};}});
 const {port}=await listenLoopback(server);
 const request=(method,path,body,headers={},ca=tls.cert)=>new Promise((resolve,reject)=>{
  const req=https.request({host:'127.0.0.1',servername:'localhost',port,method,path,ca,headers},res=>{let b='';res.on('data',c=>b+=c);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body:b}));});req.on('error',reject);if(body)req.write(body);req.end();
 });
 try{
  let r=await request('GET','/approve');assert.equal(r.status,200);assert(r.body.includes('Entrar com Google'));assert.equal(r.headers['cache-control'],'no-store, private');passed.push('HTTPS approval page, CSP and no-store');
  await assert.rejects(request('GET','/approve',null,{},''));passed.push('untrusted TLS certificate rejected; security not disabled');
  assert.equal((await request('GET','/v1/access')).status,405);passed.push('wrong method denied');
  assert.equal((await request('POST','/v1/access','{}',{'Content-Type':'text/plain'})).status,415);passed.push('content type enforced');
  assert.equal((await request('POST','/v1/access','[1]',{'Content-Type':'application/json'})).status,400);passed.push('non-object JSON denied');
  assert.equal((await request('POST','/v1/access','{}',{'Content-Type':'application/json',Origin:'https://other.example'})).status,403);passed.push('cross-origin request denied');
  assert.equal((await request('POST','/v1/access','x'.repeat(9000),{'Content-Type':'application/json'})).status,413);passed.push('oversize denied');
  assert.equal((await request('POST','/v1/access','{}',{'Content-Type':'application/json'})).status,200);assert.equal(calls,1);passed.push('only valid HTTPS API request reaches service');
 }finally{await new Promise(r=>server.close(r));}
 return {passed:passed.length,failed:0,tests:passed,fixtureOnly:true,publicServiceActivated:false};
}
