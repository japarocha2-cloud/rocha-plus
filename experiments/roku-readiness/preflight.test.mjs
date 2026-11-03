import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {inspectPreparation,diagnosticEvent} from './preflight.mjs';
import {ephemeralTestTls} from '../central-rights/local-test-certificate.mjs';
export async function runReadinessTests(){
 const passed=[];const test=(name,fn)=>{fn();passed.push(name);};
 const now=Date.now(),tls=ephemeralTestTls();
 const config={enabled:false,publicServiceEnabled:false,environment:'central-rights-lab',scope:'homologation',identityProjectId:'rocha-plus',labProjectId:'fixture-lab',origin:'https://localhost',authorization:{enabled:false,ownerApproved:true,accountReference:'fixture-only',notBefore:now-1,expiresAt:now+3600000}};
 const observed={hostIsolated:true,networkReachable:{roku:true,mobile:true,android:true},identityProject:'rocha-plus',labProject:'fixture-lab',commercialReadOnly:true,labTransactions:true,authorizedDomains:['localhost'],googleEnabled:true,publicCertificatePem:tls.cert,tlsTrusted:{roku:true,mobile:true,android:true}};
 test('complete synthetic evidence never authorizes activation',()=>{const r=inspectPreparation(config,observed,now);assert(r.readyToRequestActivation);assert.equal(r.activationAllowed,false);});
 test('missing infrastructure reports failures without network calls',()=>{const r=inspectPreparation({}, {},now);assert(!r.readyToRequestActivation);assert(r.missing.includes('trusted_https_origin'));});
 test('commercial/candidate writer projects rejected',()=>{for(const p of ['rocha-plus','rocha-plus-candidate'])assert(inspectPreparation({...config,labProjectId:p},observed,now).missing.includes('separate_lab_project'));});
 test('enabled runtime or grant cannot pass preparation',()=>{assert(inspectPreparation({...config,enabled:true},observed,now).missing.includes('activation_must_remain_disabled'));assert(inspectPreparation({...config,authorization:{...config.authorization,enabled:true}},observed,now).missing.includes('grant_must_remain_disabled'));});
 test('wrong name, untrusted devices and missing Google domain deny readiness',()=>{const r=inspectPreparation({...config,origin:'https://wrong.invalid'},{...observed,authorizedDomains:[],googleEnabled:false,tlsTrusted:{}},now);for(const x of ['trusted_https_origin','auth_domain_not_confirmed','certificate_name_or_validity','device_tls_trust_not_confirmed','google_provider_not_confirmed'])assert(r.missing.includes(x));});
 test('expired, unapproved or excessive authorization remains blocked',()=>{for(const g of [{expiresAt:now-1},{ownerApproved:false},{expiresAt:now+86400001}])assert(inspectPreparation({...config,authorization:{...config.authorization,...g}},observed,now).missing.includes('exact_authorization_not_ready'));});
 test('diagnostic allowlist drops credentials and identifiers',()=>{const r=diagnosticEvent({operation:'status',status:503,elapsedMs:10,uid:'private',email:'private',token:'secret',body:{session:'secret'},url:'https://private'});assert.deepEqual(Object.keys(r),['operation','status','elapsedMs','environment']);assert(!JSON.stringify(r).includes('private'));assert(!JSON.stringify(r).includes('secret'));});
 const prepared=JSON.parse(await readFile(new URL('./runtime-preparation.json',import.meta.url),'utf8'));
 test('persisted runtime and grant remain disabled with empty origin/project',()=>{assert.equal(prepared.enabled,false);assert.equal(prepared.authorization.enabled,false);assert.equal(prepared.origin,'');assert.equal(prepared.labProjectId,'');assert.equal(inspectPreparation(prepared,{},now).readyToRequestActivation,false);});
 return {passed:passed.length,failed:0,tests:passed,fixtureOnly:true,activation:false,externalWrites:0};
}
