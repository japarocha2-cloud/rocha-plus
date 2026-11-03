import test from 'node:test';
import assert from 'node:assert/strict';
import {probeCredentialPolicy} from './credential_policy_probe.mjs';
test('only infrastructure endpoints are queried and raw response/principal/secret data never leave the probe',async()=>{
  const calls=[];
  const r=await probeCredentialPolicy({credentialProject:'rocha-plus',request:async(url,body)=>{
    calls.push({url,body});
    return {http:200,data:{secret:'FIXTURE_SECRET',principal:'fixture@example.invalid',databaseEdition:'STANDARD',
      permissions:['datastore.entities.get','datastore.entities.update'],rulesetName:'projects/rocha-plus/rulesets/fixture_rules',
      source:{files:[{content:'FIXTURE_PRIVATE_RULES'}]}}};
  }});
  assert.equal(calls.length,4);assert.equal(r.customerQueries,0);assert.equal(r.documentQueries,0);
  assert.equal(r.iam.writePermissionDetected,true);assert.equal(r.leastPrivilegeConfirmed,false);
  for(const value of ['FIXTURE_SECRET','fixture@example.invalid','FIXTURE_PRIVATE_RULES'])assert.equal(JSON.stringify(r).includes(value),false);
  assert(calls.every(c=>!c.url.includes('/documents')&&!c.url.includes('identitytoolkit')&&!c.url.includes('mercadopago')));
});
test('unexpected credential project is rejected before any network query',async()=>{
  const r=await probeCredentialPolicy({credentialProject:'different',request:()=>{throw Error('must-not-call');}});
  assert.equal(r.blocked,'unexpected-credential-project');
});
test('forbidden reads retain safe reason codes but never error messages or external ruleset references',async()=>{
  let count=0;
  const r=await probeCredentialPolicy({credentialProject:'rocha-plus',request:async()=>{
    count++;return {http:403,data:{rulesetName:'projects/other/rulesets/fixture',error:{message:'FIXTURE_PRIVATE_MESSAGE',details:[{reason:'IAM_PERMISSION_DENIED'}]}}};
  }});
  assert.equal(count,3);assert.equal(r.database.http,403);assert.deepEqual(r.database.reasons,['IAM_PERMISSION_DENIED']);
  assert.equal(JSON.stringify(r).includes('FIXTURE_PRIVATE_MESSAGE'),false);assert.equal(r.rules.exactReviewedSparkSource,false);
});
