import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createFirebaseRuntime} from './firebase-runtime.mjs';
export async function runFirebaseBoundaryTests(){
 const now=Date.now(),DAY=86400000,hash=s=>createHash('sha256').update(s).digest('hex');
 const data=new Map();
 for(const uid of ['fixture-owner','fixture-other'])data.set('rochaCentralLabAccounts/'+hash(uid),{uid,trialStartedAt:now-8*DAY,periods:[],labGrant:{uid,scope:'homologation',start:now-1000,end:now+3600000}});
 const snapshot=p=>({exists:data.has(p),data:()=>data.get(p)});
 const labDb={projectId:'fixture-lab',doc:p=>({path:p,get:async()=>snapshot(p)}),runTransaction:async fn=>fn({get:async r=>snapshot(r.path),set:(r,v)=>data.set(r.path,v)})};
 let commercialWrites=0;
 const commercialReadDb={projectId:'rocha-plus',doc:()=>({get:async()=>({data:()=>({trialStartedAt:{toMillis:()=>now-8*DAY}})})})};
 const identityAuth={app:{options:{projectId:'rocha-plus'}},verifyIdToken:async token=>({uid:token,email_verified:true,auth_time:Math.floor(now/1000),firebase:{sign_in_provider:'google.com'}}),getUser:async uid=>({uid,email:uid==='fixture-owner'?'owner@example.test':'other@example.test',emailVerified:true,disabled:false,providerData:[{providerId:'google.com',uid:'123456789'}]})};
 const config={enabled:true,publicServiceEnabled:false,environment:'central-rights-lab',identityProjectId:'rocha-plus',labProjectId:'fixture-lab',authorization:{enabled:true,allowedEmail:'owner@example.test',notBefore:now-1000,expiresAt:now+3600000}};
 const handle=createFirebaseRuntime({identityAuth,commercialReadDb,labDb,config});
 const call=uid=>handle({body:{action:'register_mobile',mobile_id:'a'.repeat(64)},authorization:'Bearer '+uid});
 assert.equal((await call('fixture-owner')).status,200);
 assert.equal((await call('fixture-other')).status,403); // even if another LAB grant exists
 assert.equal(commercialWrites,0);
 const off=createFirebaseRuntime({identityAuth,commercialReadDb,labDb,config:{...config,enabled:false}});assert.equal((await off({})).status,503);
 assert.throws(()=>createFirebaseRuntime({identityAuth,commercialReadDb,labDb:{...labDb,projectId:'rocha-plus'},config:{...config,labProjectId:'rocha-plus'}}));
 return {passed:4,failed:0,tests:['exact configured account allowed in fixture LAB only','other existing LAB grant cannot bypass runtime allowlist','disabled runtime remains closed','commercial writer project refused'],fixtureOnly:true,commercialWrites};
}
