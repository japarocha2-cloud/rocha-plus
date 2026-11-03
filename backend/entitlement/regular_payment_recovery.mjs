// Back-office recovery only. No HTTP endpoint, SDK initialization or production CLI.
// Terms are independently reviewed evidence, never inferred from amount/email.
import {createHash} from 'node:crypto';
export class RecoveryBlocked extends Error {
  constructor(code) { super('regular-payment-recovery-blocked:' + code); this.code=code; }
}
const deny = code => { throw new RecoveryBlocked(code); };
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const validUid = s => typeof s==='string' && s.length>0 && s.length<=128 && !s.includes('/');
const validId = s => typeof s==='string' && /^\d{1,30}$/.test(s);
const text = s => typeof s==='string' && s.trim().length>0 && s.length<=500;
const time = n => Number.isSafeInteger(n) && n>0;
const email = s => typeof s==='string' ? s.trim().toLowerCase() : '';
const amount = n => typeof n==='number' && Number.isFinite(n) && n>=0 &&
  Number.isSafeInteger(Math.round(n*100)) && Math.abs(n*100-Math.round(n*100))<1e-6 ? Math.round(n*100) : null;

function makePlan({uid,contract,payments,merchant,snapshot,now,requireReviewed=false}) {
  if (!validUid(uid) || !time(now)) deny('identity-or-clock');
  if (!contract || typeof contract.reviewed!=='boolean' || (requireReviewed && contract.reviewed!==true) || !text(contract.evidenceReference) ||
      contract.uid!==uid || !validId(contract.merchantId) || contract.currency!=='BRL' ||
      contract.periodPolicy!=='explicit-independent-periods' || !Array.isArray(contract.payments) ||
      contract.payments.length<1 || contract.payments.length>5) deny('reviewed-contract-required');
  if (!merchant || String(merchant.id)!==contract.merchantId || merchant.site_id!=='MLB' ||
      !Array.isArray(merchant.tags) || merchant.tags.includes('test_user')) deny('receiving-account');
  const user=snapshot.user;
  const google=user?.providerData?.filter(p=>p.providerId==='google.com');
  if (user?.uid!==uid || user.disabled!==false || user.emailVerified!==true || !email(user.email) ||
      google?.length!==1 || !validId(google[0].uid) || snapshot.googleSubject!==google[0].uid ||
      snapshot.sparkExists!==true || snapshot.knownLedgersChecked!==true) deny('identity-or-ledger');
  if (snapshot.paidUntil!==null && !time(snapshot.paidUntil)) deny('existing-expiration');
  if (snapshot.projection && (snapshot.projection.uid!==uid ||
      snapshot.projection.googleSubject!==snapshot.googleSubject ||
      snapshot.projection.paidUntil!==snapshot.paidUntil)) deny('manual-change-requires-review');
  if (!Array.isArray(snapshot.records) || snapshot.records.length!==contract.payments.length ||
      !Array.isArray(payments) || payments.length!==contract.payments.length) deny('incomplete-records');
  const ids=new Set(), entries=[];
  let paidUntil=snapshot.paidUntil;
  for (const term of contract.payments) {
    if (!validId(term.id) || ids.has(term.id) || !['monthly','annual'].includes(term.plan) ||
        !Number.isSafeInteger(term.amountCents) || term.amountCents<=0 ||
        !time(term.periodStart) || !time(term.periodEnd) || term.periodEnd<=term.periodStart ||
        term.periodStart>now) deny('explicit-periods-required');
    ids.add(term.id);
    const matching=payments.filter(p=>String(p.id)===term.id);
    const records=snapshot.records.filter(p=>p.id===term.id);
    if (matching.length!==1 || records.length!==1) deny('payment-identity');
    const p=matching[0], prior=records[0];
    const approved=Date.parse(p.date_approved);
    if (p.status!=='approved' || p.status_detail!=='accredited' || p.live_mode!==true ||
        p.operation_type!=='regular_payment' || String(p.collector_id)!==contract.merchantId ||
        p.currency_id!=='BRL' || amount(p.transaction_amount)!==term.amountCents ||
        amount(p.transaction_amount_refunded)!==0 || email(p.payer?.email)!==email(user.email) ||
        !time(approved) || approved>now || term.periodEnd<=approved) deny('provider-payment');
    if (prior.legacyExists!==false) deny('legacy-record-requires-review');
    const bindingDigest=hash([uid,snapshot.googleSubject,contract.merchantId,contract.currency,
      contract.evidenceReference,contract.periodPolicy,term.id,term.plan,term.amountCents,term.periodStart,term.periodEnd]);
    if (prior.managed && (prior.managed.uid!==uid || prior.managed.googleSubject!==snapshot.googleSubject ||
        prior.managed.bindingDigest!==bindingDigest || prior.managed.status!=='confirmed')) deny('ownership-or-reversal');
    entries.push({id:term.id,uid,googleSubject:snapshot.googleSubject,merchantId:contract.merchantId,
      plan:term.plan,amountCents:term.amountCents,currency:'BRL',periodStart:term.periodStart,
      periodEnd:term.periodEnd,status:'confirmed',bindingDigest,alreadyProcessed:!!prior.managed});
    paidUntil=Math.max(paidUntil??0,term.periodEnd);
  }
  entries.sort((a,b)=>a.id.localeCompare(b.id));
  const digest=hash([uid,snapshot.googleSubject,snapshot.paidUntil,entries]);
  return {dryRun:true,writes:0,accessGranted:false,readyForAuthorization:contract.reviewed,
    requiresContractReview:!contract.reviewed,digest,
    uid,googleSubject:snapshot.googleSubject,targetCollection:'rochaSparkAccounts',
    previousPaidUntil:snapshot.paidUntil,paidUntil,currentlyValid:paidUntil>now,entries,
    legacyScope:'known-payment-ledgers-only',contractEvidence:contract.evidenceReference};
}

export function createRegularPaymentRecovery({provider,store,now=Date.now,verifyAuthorization}) {
  return async ({uid,contract,mode='dry-run',authorization}) => {
    if (!['dry-run','apply'].includes(mode)) deny('mode');
    // Validate private selectors before network/storage calls.
    if (!validUid(uid) || !Array.isArray(contract?.payments) || contract.payments.length<1 ||
        contract.payments.length>5 || !contract.payments.every(p=>validId(p.id)) ||
        new Set(contract.payments.map(p=>p.id)).size!==contract.payments.length) deny('selectors');
    const ids=contract.payments.map(p=>p.id);
    // Always refetch official state, including on repeats and immediately before application.
    const merchant=await provider.merchant();
    const payments=await Promise.all(ids.map(id=>provider.payment(id)));
    const evaluate=snapshot=>makePlan({uid,contract,payments,merchant,snapshot,now:now(),requireReviewed:mode==='apply'});
    if (mode==='dry-run') return evaluate(await store.read(uid,ids));
    if (!authorization || authorization.scope!=='regular-payment-recovery' || authorization.uid!==uid ||
        !validUid(authorization.actorUid) || !text(authorization.reference) ||
        !/^[a-f0-9]{64}$/.test(authorization.digest||'')) deny('specific-authorization-required');
    if (typeof verifyAuthorization!=='function' ||
        await verifyAuthorization(authorization)!==true) deny('authorization-not-verified');
    return store.transact(uid,ids,async (snapshot,commit)=>{
      const plan=evaluate(snapshot);
      if (plan.entries.every(p=>p.alreadyProcessed) && snapshot.projection?.digest===authorization.digest) {
        return {...plan,dryRun:false,duplicate:true,writes:0};
      }
      if (plan.digest!==authorization.digest) deny('stale-preview');
      if (plan.entries.every(p=>p.alreadyProcessed)) return {...plan,dryRun:false,duplicate:true,writes:0};
      if (!plan.currentlyValid) deny('expired-period');
      await commit({plan,authorization,checkedAt:now()});
      return {...plan,dryRun:false,accessGranted:true,duplicate:false,writes:plan.entries.filter(p=>!p.alreadyProcessed).length+3};
    });
  };
}
