import test from 'node:test';
import assert from 'node:assert/strict';
import {createSessionIdentityDiagnostic} from './session_identity_diagnostic.mjs';
const now=Date.UTC(2026,10,3);
function fixture() {
  const claims={uid:'fixture-user',sub:'fixture-user',aud:'fixture-project',iss:'https://securetoken.google.com/fixture-project',
    iat:now/1000,email_verified:true,firebase:{sign_in_provider:'google.com',identities:{'google.com':['9001']}}};
  const user={uid:'fixture-user',disabled:false,emailVerified:true,providerData:[{providerId:'google.com',uid:'9001'}]};
  let revokedCheck;
  const options={projectId:'fixture-project',targetUid:user.uid,targetGoogleSubject:'9001',now:()=>now,
    verifyToken:async(token,check)=>{assert.equal(token,'FIXTURE_TOKEN');revokedCheck=check;return claims;},readUser:async()=>user};
  return {claims,user,options,run:()=>createSessionIdentityDiagnostic(options)('Bearer FIXTURE_TOKEN'),revokedCheck:()=>revokedCheck};
}
test('server-verifies identity with revocation without asserting package or leaking token/identifiers',async()=>{
  const f=fixture(),r=await f.run();assert.equal(f.revokedCheck(),true);assert.equal(r.identityVerified,true);
  assert.equal(r.uidMatchesRecovery,true);assert.equal(r.googleMatchesRecovery,true);
  assert.equal(r.deviceSessionVerified,false);assert.equal(r.backendVerified,false);
  for(const value of ['FIXTURE_TOKEN','fixture-user','9001'])assert.equal(JSON.stringify(r).includes(value),false);
});
test('another authenticated account is reported as a mismatch, never silently selected for recovery',async()=>{
  const f=fixture();f.options.targetUid='different-target';f.options.targetGoogleSubject='9002';
  const r=await f.run();assert.equal(r.identityVerified,true);assert.equal(r.uidMatchesRecovery,false);assert.equal(r.googleMatchesRecovery,false);
});
test('wrong project, unverified email, wrong identity, disabled account and future issuance fail closed',async()=>{
  for(const change of [f=>f.claims.aud='another-project',f=>f.claims.email_verified=false,
    f=>f.claims.firebase.identities['google.com']=['9002'],f=>f.user.disabled=true,f=>f.claims.iat+=300]){
    const f=fixture();change(f);assert.equal((await f.run()).identityVerified,false);
  }
});
test('expired/revoked/missing tokens return only a generic failure without logging input',async()=>{
  const f=fixture();f.options.verifyToken=async()=>{throw Error('FIXTURE_PRIVATE_ERROR');};
  const r=await f.run();assert.equal(r.identityVerified,false);assert.equal(JSON.stringify(r).includes('FIXTURE_PRIVATE_ERROR'),false);
  assert.equal((await createSessionIdentityDiagnostic(f.options)('')).identityVerified,false);
});
