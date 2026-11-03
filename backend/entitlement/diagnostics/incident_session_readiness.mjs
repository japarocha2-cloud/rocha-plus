// Only a simulation. This executable does not accept an apply flag or authorization.
import {cert,initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {createRegularPaymentRecovery} from '../regular_payment_recovery.mjs';
import {regularPaymentFirestoreStore} from '../regular_payment_firestore.mjs';
import {prepareMonthlyOnly} from '../monthly_only_preparation.mjs';
import {previewRecoveryChangeset} from '../recovery_changeset_preview.mjs';
import {createHash} from 'node:crypto';
import {mkdirSync,realpathSync,writeFileSync,chmodSync,readdirSync} from 'node:fs';
import {isAbsolute,resolve,sep,join,parse} from 'node:path';
// The owner selected private Work execution. Never collect real state in Actions.
if (process.env.GITHUB_ACTIONS==='true') throw Error('private-work-execution-only');
const requestedDirectory=process.env.ROCHA_PRIVATE_REPORT_DIR;
if (!requestedDirectory || !isAbsolute(requestedDirectory)) throw Error('absolute-private-report-directory-required');
mkdirSync(requestedDirectory,{recursive:true,mode:0o700});
const privateDirectory=realpathSync(requestedDirectory),checkout=realpathSync(resolve('.'));
if (privateDirectory===parse(privateDirectory).root || privateDirectory===checkout ||
    privateDirectory.startsWith(checkout+sep) || checkout.startsWith(privateDirectory+sep) ||
    readdirSync(privateDirectory).length!==0) throw Error('new-private-report-directory-outside-checkout-required');
chmodSync(privateDirectory,0o700);
const report={readOnly:true,dryRun:true,writes:0,accessGranted:false,readyForProduction:false};
const fingerprint=value=>createHash('sha256').update(value).digest('hex').slice(0,12);
try {
  const ids=JSON.parse(process.env.INCIDENT_PAYMENT_IDS_JSON||'null');
  const email=process.env.INCIDENT_TARGET_EMAIL?.trim().toLowerCase();
  const merchantId=process.env.EXPECTED_RECEIVING_MERCHANT_ID;
  const token=process.env.MP_RECEIVING_ACCESS_TOKEN;
  const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'{}');
  if (!Array.isArray(ids) || ids.length!==2 || !ids.every(id=>typeof id==='string' && /^\d{1,30}$/.test(id)) ||
      new Set(ids).size!==ids.length || !email || !token || !/^\d+$/.test(merchantId||'') || key.project_id!=='rocha-plus') throw Error('inputs');
  initializeApp({credential:cert(key),projectId:'rocha-plus'});
  const auth=getAuth(), user=await auth.getUserByEmail(email);
  if(user.email?.toLowerCase()!==email)throw Error('identity');
  async function get(path) {
    const r=await fetch('https://api.mercadopago.com'+path,{method:'GET',redirect:'error',signal:AbortSignal.timeout(20000),headers:{Authorization:`Bearer ${token}`}});
    if(!r.ok)throw Error('provider');return r.json();
  }
  const provider={merchant:()=>get('/users/me'),payment:id=>get('/v1/payments/'+id),subscription:id=>get('/preapproval/'+id)};
  const receipts=[];
  for(const id of ids){const payment=await provider.payment(id);if(String(payment.id)!==id)throw Error('payment-identity');receipts.push(payment);}
  const monthlyReceipts=receipts.filter(p=>p.transaction_amount===4.5),annualReceipts=receipts.filter(p=>p.transaction_amount===49.5);
  if(monthlyReceipts.length!==1||annualReceipts.length!==1)throw Error('one-monthly-and-one-annual-required');
  const selection=await prepareMonthlyOnly({monthlyPayment:monthlyReceipts[0],annualPayment:annualReceipts[0],provider,merchantId});
  const monthlyTerms=[{id:selection.monthly.paymentId,plan:'monthly',amountCents:450,periodStart:selection.monthly.periodCandidate.start,periodEnd:selection.monthly.periodCandidate.end}];
  // This complete selection stays ONLY in the protected private output, never console/Actions.
  report.recurringPreparation=selection;
  report.contractIds={monthly:selection.monthly.subscriptionId,annual:selection.annual.subscriptionId};
  report.externalRefund={reportedByOwner:true,reconciledWithReceipt:false,mercadoPagoRefundConfirmed:false};
  const store=regularPaymentFirestoreStore({db:getFirestore(),auth,timestamp:()=>{throw Error('writes-disabled');}});
  // Expose ONLY read, never the adapter's transaction entrypoint, to this executable.
  const recover=createRegularPaymentRecovery({provider,store:{read:store.read}});
  const plan=await recover({uid:user.uid,mode:'dry-run',contract:{uid:user.uid,reviewed:false,
    merchantId,currency:'BRL',evidenceReference:'provider-linked-contracts-pending-independent-review',
    periodPolicy:'explicit-independent-periods',payments:monthlyTerms}});
  report.identity={firebaseUidFingerprint:fingerprint(user.uid),googleSubjectFingerprint:fingerprint(plan.googleSubject),
    firebaseUidEqualsGoogleSubject:user.uid===plan.googleSubject,
    targetProject:'rocha-plus',clientSessionVerified:false,installedPackageVerified:false,backendVerified:false};
  report.changeset=await previewRecoveryChangeset({db:getFirestore(),auth,plan,
    privateBaselineSink:async baseline=>writeFileSync(join(privateDirectory,'before-images.private.json'),
      JSON.stringify(baseline,null,2),{flag:'wx',mode:0o600})});
  report.plan={digest:plan.digest,targetCollection:plan.targetCollection,
    previousPaidUntil:plan.previousPaidUntil?new Date(plan.previousPaidUntil).toISOString():null,
    proposedPaidUntil:new Date(plan.paidUntil).toISOString(),currentlyValid:plan.currentlyValid,
    requiresContractReview:plan.requiresContractReview,readyForAuthorization:plan.readyForAuthorization,
    periods:plan.entries.map((p,index)=>({index,plan:p.plan,start:new Date(p.periodStart).toISOString(),
      end:new Date(p.periodEnd).toISOString(),alreadyProcessed:p.alreadyProcessed})),
    knownLedgerPathsChecked:true,globalInventoryComplete:false};

  const access=await cert(key).getAccessToken();
  const headers={Authorization:'Bearer '+access.access_token,'Content-Type':'application/json'};
  async function cloud(url,body) {
    try {
      const response=await fetch(url,{method:body?'POST':'GET',headers,redirect:'error',
        signal:AbortSignal.timeout(20000),...(body?{body:JSON.stringify(body)}:{})});
      let data;try{data=await response.json();}catch(_){data={};}
      const reasons=(data.error?.details||[]).map(v=>v.reason).filter(v=>typeof v==='string'&&/^[A-Z_]+$/.test(v));
      return {http:response.status,data,reasons};
    }catch(_){return {http:null,data:{},reasons:['TRANSPORT_NOT_CONFIRMED']};}
  }
  const metadata=await cloud('https://firestore.googleapis.com/v1/projects/rocha-plus/databases/(default)');
  report.database={http:metadata.http,reasons:metadata.reasons,
    edition:['STANDARD','ENTERPRISE'].includes(metadata.data.databaseEdition)?metadata.data.databaseEdition:null,
    type:['FIRESTORE_NATIVE','DATASTORE_MODE'].includes(metadata.data.type)?metadata.data.type:null};
  const permissions=['datastore.entities.get','datastore.entities.create','datastore.entities.update',
    'datastore.entities.delete','firebaserules.releases.get','firebaserules.rulesets.get'];
  const iam=await cloud('https://cloudresourcemanager.googleapis.com/v1/projects/rocha-plus:testIamPermissions',{permissions});
  report.permissionProbe={http:iam.http,reasons:iam.reasons,principalScope:'diagnostic-credential-only',
    granted:iam.http===200?permissions.filter(p=>(iam.data.permissions||[]).includes(p)):null,
    note:'Project-level probe does not prove document-level conditional IAM or authorize execution.'};
  const release=await cloud('https://firebaserules.googleapis.com/v1/projects/rocha-plus/releases/cloud.firestore');
  report.rules={releaseReadHttp:release.http,reasons:release.reasons,deployedRulesReviewed:false};
  if(release.http===200 && /^projects\/rocha-plus\/rulesets\/[a-zA-Z0-9_-]+$/.test(release.data.rulesetName||'')){
    const rules=await cloud('https://firebaserules.googleapis.com/v1/'+release.data.rulesetName);
    report.rules.rulesetReadHttp=rules.http;
    report.rules.rulesetReasons=rules.reasons;
    const files=rules.data.source?.files;
    if(rules.http===200 && Array.isArray(files)){
      const gitBlob=text=>createHash('sha1').update('blob '+Buffer.byteLength(text)+'\0'+text).digest('hex');
      const hashes=files.map(f=>typeof f.content==='string'?gitBlob(f.content):null);
      report.rules.sourceBlobHashes=hashes;
      report.rules.exactReviewedSparkSource=files.length===1 && hashes[0]==='8752a9513863819eb2b4b8ae424a5280b5a3164b';
      report.rules.deployedRulesReviewed=report.rules.exactReviewedSparkSource;
      if(report.rules.exactReviewedSparkSource) report.rules.conclusion={
        sparkOwnerGetAllowed:true,clientPaidUntilWriteDenied:true,
        directPaymentLedgerClientAccessDenied:true,projectionClientAccessDenied:true,auditClientAccessDenied:true,
        basis:'Exact source match to reviewed Spark rules, including implicit deny of unmatched paths.'};
      else report.rules.conclusion={manualReviewRequired:true};
    }
  }

} catch(error) { report.blocked=true;report.reason=error.code||'provider-contract-identity-or-ledger-not-confirmed';process.exitCode=1; }
writeFileSync(join(privateDirectory,'readiness.private.json'),JSON.stringify(report,null,2),{flag:'wx',mode:0o600});
console.log(JSON.stringify({readOnly:true,writes:0,resultStoredPrivately:true,readyForProduction:false}));

