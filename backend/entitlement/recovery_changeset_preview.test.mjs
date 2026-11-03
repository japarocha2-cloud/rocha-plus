import test from 'node:test';
import assert from 'node:assert/strict';
import {previewRecoveryChangeset} from './recovery_changeset_preview.mjs';
function fixture() {
  const state=new Map([['rochaSparkAccounts/9001',{trialStartedAt:{toMillis:()=>1000},welcomeAcceptedAt:null}]]);
  const db={doc:path=>({get:async()=>({exists:state.has(path),data:()=>state.get(path)})}),
    runTransaction:()=>{throw Error('production-transaction-must-never-be-called');}};
  const auth={getUser:async()=>({uid:'fixture-user',providerData:[{providerId:'google.com',uid:'9001'}]})};
  const plan={dryRun:true,uid:'fixture-user',googleSubject:'9001',previousPaidUntil:null,paidUntil:100000,
    digest:'a'.repeat(64),contractEvidence:'fixture-review-pending',entries:['11','22'].map(id=>({id,uid:'fixture-user',
      googleSubject:'9001',merchantId:'123',plan:'annual',status:'confirmed',amountCents:4950,
      currency:'BRL',periodStart:1000,periodEnd:100000,bindingDigest:'b'.repeat(64),alreadyProcessed:false}))};
  return {state,db,auth,plan};
}
test('captures all five adapter writes including audit before/after without any production transaction',async()=>{
  const f=fixture(),r=await previewRecoveryChangeset(f);
  assert.equal(r.proposedDocumentCount,5);assert.equal(r.auditExistsBefore,false);assert.equal(r.writes,0);
  assert.equal(f.state.size,1);assert.equal(r.finalAuthorizationBoundDigest,null);
  assert.equal(r.operatorAuthenticated,false);assert.equal(r.authorizationGranted,false);
  assert.equal(r.documents.filter(d=>d.operation==='create').length,3);
  assert.equal(r.documents.find(d=>d.path.startsWith('rochaSparkAccounts/')).before.trialStartedAt.type,'timestamp');
  assert.equal(r.documents.find(d=>d.path.startsWith('rochaSparkAccounts/')).after.trialStartedAt.value,'1970-01-01T00:00:01.000Z');
  assert.equal(JSON.stringify(r).includes('fixture-user'),false);
  assert.equal(r.changesetTemplateDigest,(await previewRecoveryChangeset(f)).changesetTemplateDigest);
});
test('pre-existing audit blocks the template instead of claiming a future create will succeed',async()=>{
  const f=fixture();f.state.set('rochaDirectPaymentAudit/'+f.plan.digest,{existing:true});
  await assert.rejects(previewRecoveryChangeset(f),/document-precondition/);assert.equal(f.state.size,2);
});
test('changed source state blocks the template before capturing a proposal',async()=>{
  const f=fixture();f.state.set('rochaSparkAccounts/9001',{paidUntil:{toMillis:()=>5000}});
  await assert.rejects(previewRecoveryChangeset(f),/stale-plan/);
});
test('raw before-images reach only the explicitly private sink and never the masked return value',async()=>{
  const f=fixture();let baseline;
  const r=await previewRecoveryChangeset({...f,privateBaselineSink:async value=>{baseline=value;}});
  assert.equal(baseline.documents.length,5);
  assert(baseline.documents.every(d=>d.proposedOperation&&d.afterTemplate));
  assert.equal(baseline.documents.find(d=>d.path==='rochaDirectPaymentLedger/11').afterTemplate.uid,'fixture-user');
  assert.equal(baseline.documents.find(d=>d.path==='rochaSparkAccounts/9001').exists,true);
  assert.equal(JSON.stringify(r).includes('rochaSparkAccounts/9001'),false);
  assert.equal(r.finalAuthorizationBoundDigest,null);
});
