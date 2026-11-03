// Only a simulation. This executable does not accept an apply flag or authorization.
import {cert,initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {createRegularPaymentRecovery} from '../regular_payment_recovery.mjs';
import {regularPaymentFirestoreStore} from '../regular_payment_firestore.mjs';
import {inspectRegularPaymentContract} from '../regular_payment_contract.mjs';
const report={readOnly:true,dryRun:true,writes:0,accessGranted:false};
try {
  const ids=JSON.parse(process.env.INCIDENT_PAYMENT_IDS_JSON||'null');
  const email=process.env.INCIDENT_TARGET_EMAIL?.trim().toLowerCase();
  const merchantId=process.env.EXPECTED_RECEIVING_MERCHANT_ID;
  const token=process.env.MP_RECEIVING_ACCESS_TOKEN;
  const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'{}');
  if (!Array.isArray(ids) || ids.length<1 || ids.length>5 || !ids.every(id=>typeof id==='string' && /^\d{1,30}$/.test(id)) ||
      new Set(ids).size!==ids.length || !email || !token || !/^\d+$/.test(merchantId||'') || key.project_id!=='rocha-plus') throw Error('inputs');
  initializeApp({credential:cert(key),projectId:'rocha-plus'});
  const auth=getAuth(), user=await auth.getUserByEmail(email);
  if(user.email?.toLowerCase()!==email)throw Error('identity');
  async function get(path) {
    const r=await fetch('https://api.mercadopago.com'+path,{method:'GET',redirect:'error',signal:AbortSignal.timeout(20000),headers:{Authorization:`Bearer ${token}`}});
    if(!r.ok)throw Error('provider');return r.json();
  }
  const provider={merchant:()=>get('/users/me'),payment:id=>get('/v1/payments/'+id),subscription:id=>get('/preapproval/'+id)};
  const terms=[];
  for(const id of ids) {
    const payment=await provider.payment(id);
    if(String(payment.id)!==id)throw Error('payment-identity');
    const candidate=await inspectRegularPaymentContract({payment,provider,merchantId});
    terms.push({id,plan:candidate.plan,amountCents:Math.round(payment.transaction_amount*100),
      periodStart:candidate.periodStart,periodEnd:candidate.periodEnd});
  }
  const store=regularPaymentFirestoreStore({db:getFirestore(),auth,timestamp:()=>{throw Error('writes-disabled');}});
  // Expose ONLY read, never the adapter's transaction entrypoint, to this executable.
  const recover=createRegularPaymentRecovery({provider,store:{read:store.read}});
  const plan=await recover({uid:user.uid,mode:'dry-run',contract:{uid:user.uid,reviewed:false,
    merchantId,currency:'BRL',evidenceReference:'provider-linked-contracts-pending-independent-review',
    periodPolicy:'explicit-independent-periods',payments:terms}});
  report.plan={digest:plan.digest,targetCollection:plan.targetCollection,
    previousPaidUntil:plan.previousPaidUntil?new Date(plan.previousPaidUntil).toISOString():null,
    proposedPaidUntil:new Date(plan.paidUntil).toISOString(),currentlyValid:plan.currentlyValid,
    requiresContractReview:plan.requiresContractReview,readyForAuthorization:plan.readyForAuthorization,
    periods:plan.entries.map((p,index)=>({index,plan:p.plan,start:new Date(p.periodStart).toISOString(),
      end:new Date(p.periodEnd).toISOString(),alreadyProcessed:p.alreadyProcessed})),
    knownLedgerPathsChecked:true,globalInventoryComplete:false};
} catch(error) { report.blocked=true;report.reason=error.code||'provider-contract-identity-or-ledger-not-confirmed';process.exitCode=1; }
console.log(JSON.stringify(report,null,2));
