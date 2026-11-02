import assert from 'node:assert/strict';
import {inspectStoredRights} from '../../tools/roku-lab-access/stored-rights-audit.mjs';
import {createHash} from 'node:crypto';
export async function runStoredRightsTests(){
 const uid='fixture-private-uid',email='fixture@example.test',subject='12345',ids=['111111','222222'],key=createHash('sha256').update(uid).digest('hex'),now=1800000000000;
 let mismatch=false,clock=true,exists=true,reads=[];
 const auth={getUserByEmail:async e=>{assert.equal(e,email);return {uid,email,disabled:false,emailVerified:true,providerData:[{providerId:'google.com',uid:subject}]};}};
 const db=new Proxy({doc:p=>({get:async()=>{reads.push(p);return {exists:exists&&p==='rochaBillingUsers/'+key,readTime:{toMillis:()=>clock?now:NaN},data:()=>p==='rochaBillingUsers/'+key&&exists?{uid:mismatch?'another':uid,payments:{}}:undefined};}})},{get:(o,p)=>{assert.equal(p,'doc','no transaction/batch/write API available');return o[p];}});
 const input={auth,db,email,paymentIds:ids,computeAccess:()=>({state:'paid',active:true})},tests=[];
 const ok=await inspectStoredRights(input);assert.equal(ok.legacy.activePaidFromExistingLedger,true);assert.equal(ok.commercialAccessGranted,false);assert.equal(ok.writes,0);tests.push('existing ledger can be inspected without granting or writing access');
 const json=JSON.stringify(ok);for(const value of [uid,email,subject,...ids])assert(!json.includes(value));tests.push('output excludes email, UID, subject and payment identifiers');
 mismatch=true;await assert.rejects(()=>inspectStoredRights(input),/binding/);mismatch=false;tests.push('another UID ledger is rejected');
 exists=false;const empty=await inspectStoredRights(input);assert.equal(empty.legacy.recordFound,false);assert.equal(empty.legacy.activePaidFromExistingLedger,false);tests.push('absent stored ledger never becomes paid');
 clock=false;await assert.rejects(()=>inspectStoredRights(input),/server_clock/);tests.push('unconfirmed server time fails closed');
 await assert.rejects(()=>inspectStoredRights({...input,paymentIds:['unsafe/path']}),/payment_scope/);tests.push('only the two scoped numeric payment references may be read');
 return {passed:tests.length,failed:0,tests,fixtureOnly:true};
}
