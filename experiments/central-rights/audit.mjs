// Exact owner-requested scope only. No writes, reconciliation or checkout creation.
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const numeric=v=>/^\d{1,30}$/.test(String(v));
export async function auditPaymentBoundary({auth,db,getProvider,email,paymentIds,expectedMerchant}) {
  if(paymentIds.length!==2||new Set(paymentIds).size!==2||!paymentIds.every(numeric)||!numeric(expectedMerchant)) throw Error('scope');
  const user=await auth.getUserByEmail(email);
  const google=user.providerData?.filter(p=>p.providerId==='google.com');
  if(user.disabled||!user.emailVerified||user.email?.toLowerCase()!==email.toLowerCase()||google?.length!==1||!numeric(google[0].uid)) throw Error('identity');
  const merchant=await getProvider('/users/me');
  if(String(merchant.id)!==String(expectedMerchant))throw Error('merchant');
  const nowSnapshot=await db.doc('rochaSparkAccounts/'+google[0].uid).get();
  const now=nowSnapshot.readTime?.toMillis?.();if(!Number.isSafeInteger(now))throw Error('clock');
  const uid=user.uid,subject=google[0].uid;
  const accountPaths={spark:'rochaSparkAccounts/'+subject,legacy:'rochaBillingUsers/'+hash(uid),experimental:'rochaEntitlements/'+hash(uid),functions:'entitlements/'+uid,projection:'rochaSparkBillingProjections/'+subject};
  const stores={};
  for(const [name,p] of Object.entries(accountPaths)) {
    const s=await db.doc(p).get(),d=s.data();
    stores[name]={exists:s.exists,uidBinding:d?.uid==null?null:d.uid===uid,paidUntilPresent:d?.paidUntil!=null,paidUntilCurrent:(d?.paidUntil?.toMillis?.()??0)>now};
  }
  const payments=[];
  for(const id of paymentIds) {
    const p=await getProvider('/v1/payments/'+id);
    if(String(p.id)!==String(id))throw Error('resource');
    const legacy=await db.doc('rochaBillingPayments/'+id).get();
    const manual=await db.doc('rochaSparkPaymentConfirmations/'+id).get();
    const experimental=await db.doc('rochaPayments/'+hash(JSON.stringify(['mercadopago',id]))).get();
    payments.push({authoritativeGet:true,status:['approved','pending','in_process','rejected','cancelled','refunded','charged_back','in_mediation','authorized'].includes(p.status)?p.status:'unknown',
      operation:p.operation_type==='regular_payment'?'regular_payment':p.operation_type==='recurring_payment'?'recurring_payment':'other',
      liveMode:p.live_mode===true,payerMatches:p.payer?.email?.toLowerCase()===email.toLowerCase(),merchantMatches:String(p.collector_id)===String(merchant.id),
      refunded:Number(p.transaction_amount_refunded??0)>0,disputeStatus:p.status==='charged_back'||p.status==='in_mediation',
      approvalDateValid:Number.isFinite(Date.parse(p.date_approved))&&Date.parse(p.date_approved)<=now,
      externalReferencePresent:typeof p.external_reference==='string'&&p.external_reference.length>0,
      notificationUrlPresent:typeof p.notification_url==='string'&&p.notification_url.length>0,
      // A missing payment-level URL does not disprove an application-level webhook.
      metadataPlanPresent:typeof p.metadata?.plan==='string',
      explicitPeriodPresent:typeof p.metadata?.period_start==='string'&&typeof p.metadata?.period_end==='string',
      legacyRecord:legacy.exists,manualConfirmation:manual.exists,experimentalRecord:experimental.exists});
  }
  return {project:'rocha-plus',checkedAt:new Date(now).toISOString(),readOnly:true,writes:0,commercialAccessGranted:false,stores,payments,
    limitations:['Payment-level notification metadata is not proof of dashboard configuration or delivery.','No duration inferred from price, title or owner assertion.','Only listed stores and the two requested references were inspected.']};
}
