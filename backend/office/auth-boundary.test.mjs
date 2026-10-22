import test from 'node:test';
import assert from 'node:assert/strict';
import { officeTokenVerifier } from './auth-boundary.mjs';
test('Google revocation after browser approval invalidates a paired session even after custom-token exchange',async()=>{
  const time=Date.UTC(2026,9,22), claims={uid:'buyer',firebase:{sign_in_provider:'custom'},officeGoogleBridge:true,officeDeviceId:'a'.repeat(64),officeGoogleAuthTime:time/1000};
  let revoked=time-1000;
  const verify=officeTokenVerifier({verifyIdToken:async(_,check)=>{assert.equal(check,true);return claims;},getUser:async()=>({disabled:false,tokensValidAfterTime:new Date(revoked).toISOString()})});
  assert.equal((await verify('TEST',true)).uid,'buyer');revoked=time+1000;await assert.rejects(verify('TEST',true));
});
test('unscoped custom sessions and disabled Google accounts are denied',async()=>{
  const claims={uid:'buyer',firebase:{sign_in_provider:'custom'}};
  const verify=officeTokenVerifier({verifyIdToken:async()=>claims,getUser:async()=>({disabled:true,tokensValidAfterTime:new Date(0).toISOString()})});
  await assert.rejects(verify('TEST',true));Object.assign(claims,{officeGoogleBridge:true,officeDeviceId:'a'.repeat(64),officeGoogleAuthTime:1});await assert.rejects(verify('TEST',true));
});
