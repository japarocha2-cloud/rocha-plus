// Records the existing adapter's intended writes in memory. The real database
// object is used ONLY for get(); its runTransaction/create/set/update are never called.
import {createHash} from 'node:crypto';
import {regularPaymentFirestoreStore} from './regular_payment_firestore.mjs';
const canonical=value=>{
  if (value?.toMillis instanceof Function) return {type:'timestamp',value:new Date(value.toMillis()).toISOString()};
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value==='object') return Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])]));
  if (value===undefined) return {type:'absent'};
  return value;
};
const digest=value=>createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const identityFingerprint=value=>createHash('sha256').update(String(value)).digest('hex').slice(0,12);
const identityKeys=new Set(['uid','googleSubject','id','merchantId','authorizedBy','actorUid','paymentIds']);
function masked(value,key='') {
  if (identityKeys.has(key)) return value==null ? null : Array.isArray(value)
    ? value.map(v=>({fingerprint:identityFingerprint(v)})) : {fingerprint:identityFingerprint(value)};
  if (key==='authorizationReference' || key==='contractEvidence') return value==null ? null : {fingerprint:digest(value).slice(0,12)};
  if (Array.isArray(value)) return value.map(v=>masked(v));
  if (value && typeof value==='object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,masked(v,k)]));
  if (typeof value==='string' && !['type','value','plan','status','provider','digest','bindingDigest'].includes(key)) {
    return {type:'string',fingerprint:digest(value).slice(0,12)};
  }
  return value;
}
export async function previewRecoveryChangeset({db,auth,plan}) {
  if (plan?.dryRun!==true || plan.entries?.length!==2 || !plan.uid || !plan.googleSubject) throw Error('two-payment-dry-run-required');
  const snapshots=new Map(),operations=[];
  async function read(path) {
    if (!snapshots.has(path)) snapshots.set(path,await db.doc(path).get());
    return snapshots.get(path);
  }
  const recordingDb={doc:path=>({path}),runTransaction:async callback=>callback({
    get:ref=>read(ref.path),
    create:(ref,data)=>operations.push({path:ref.path,operation:'create',data}),
    update:(ref,data)=>operations.push({path:ref.path,operation:'update',data}),
    set:(ref,data)=>operations.push({path:ref.path,operation:'set',data})
  })};
  const timestamp=value=>value===null?{type:'execution-time-pending'}:{type:'timestamp',value:new Date(value).toISOString()};
  const store=regularPaymentFirestoreStore({db:recordingDb,auth,timestamp});
  await store.transact(plan.uid,plan.entries.map(p=>p.id),async (snapshot,commit)=>{
    if (snapshot.paidUntil!==plan.previousPaidUntil || snapshot.googleSubject!==plan.googleSubject) throw Error('stale-plan');
    await commit({plan,authorization:{actorUid:null,reference:null},checkedAt:null});
  });
  const documents=[];
  for (const op of operations) {
    const snap=await read(op.path),before=snap.exists?canonical(snap.data()):null;
    if ((op.operation==='create' && snap.exists) || (op.operation==='update' && !snap.exists)) throw Error('document-precondition');
    const after=op.operation==='update'?{...before,...canonical(op.data)}:canonical(op.data);
    const [collection,key]=op.path.split('/');
    documents.push({path:collection+'/'+identityFingerprint(key),operation:op.operation,
      beforeExists:snap.exists,before:masked(before),after:masked(after),
      beforeDigest:digest(before),afterTemplateDigest:digest(after),
      updateTime:snap.updateTime?.toDate?.().toISOString()??null});
  }
  return {readOnly:true,simulationOnly:true,writes:0,expectedDocumentCount:5,
    proposedDocumentCount:documents.length,documents,
    auditExistsBefore:documents.find(d=>d.path.startsWith('rochaDirectPaymentAudit/'))?.beforeExists??null,
    financialPlanDigest:plan.digest,changesetTemplateDigest:digest(operations),
    finalAuthorizationBoundDigest:null,operatorAuthenticated:false,authorizationGranted:false,
    executionTimePending:true,consistentSnapshot:false,
    blockingInputs:['installed-session-and-backend','contract-review','authenticated-operator','specific-authorization','fresh-atomic-preconditions'],
    note:'Template uses null for unselected operator/authorization and symbolic execution timestamps; it is not an applicable changeset.'};
}
