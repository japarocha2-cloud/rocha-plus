import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const states=new Set(['approved','pending','in_process','rejected','cancelled','refunded','charged_back','in_mediation','authorized']);
const terminal=new Set(['refunded','charged_back','in_mediation','cancelled']);
const amount=n=>{if(typeof n!=='number'||n<0||!Number.isFinite(n)||Math.abs(n*100-Math.round(n*100))>0.000001)throw Error('amount');return Math.round(n*100);};
// Trusted periodResolver must resolve an existing server contract or verified
// invoice. Never infer a plan, UID or duration from an app/webhook/payment title.
export function createPaymentPipeline({store,provider,verifySignature,periodResolver,merchantId,liveMode=false,now=Date.now}) {
 async function process(id) {
  if(!/^\d{1,30}$/.test(id))throw Error('resource');
  const p=await provider.payment(id),time=now();
  if(String(p.id)!==id||String(p.collector_id)!==String(merchantId)||p.live_mode!==liveMode||p.currency_id!=='BRL'||!states.has(p.status))throw Error('provider-mismatch');
  const updated=Date.parse(p.date_last_updated),approved=Date.parse(p.date_approved);
  if(!Number.isSafeInteger(time)||!Number.isFinite(updated)||updated>time+300000)throw Error('provider-clock');
  const cents=amount(p.transaction_amount),refunded=amount(p.transaction_amount_refunded??0);
  if(refunded>cents)throw Error('refund');
  const paymentKey=hash('mercadopago:'+id);
  // A queue item, ledger and entitlement live in a single transactional scope.
  return store.transact('payment:'+paymentKey,async old=>{
   if(old?.updated>updated||(old?.updated===updated&&terminal.has(old.status)&&p.status==='approved'))return {value:old,result:{status:'stale',changed:false}};
   if(!old?.reviewRequired&&old?.updated===updated&&old.status===p.status&&old.refundedCents===refunded)return {value:old,result:{status:'duplicate',changed:false}};
   const contract=await periodResolver(p);
   if(!contract||contract.approvedPolicy!==true||contract.bindingVerified!==true||!contract.uid||!contract.plan||contract.amountCents!==cents||
      String(contract.payerId??'')!==String(p.payer?.id??'')||!contract.payerId||
      !(contract.paymentId===id||(typeof contract.externalReference==='string'&&/^[a-f0-9-]{36}$/.test(contract.externalReference)&&contract.externalReference===p.external_reference))||
      !Number.isSafeInteger(contract.start)||!Number.isSafeInteger(contract.end)||contract.end<=contract.start||
      (p.status==='approved'&&(!Number.isFinite(approved)||approved>time||contract.start>time))) {
    if(old?.uid)throw Error('contract-unavailable-for-existing-right');
    const review={status:p.status,updated,refundedCents:refunded,reviewRequired:true};
    return {value:review,result:{status:'reconciliation_pending',alert:p.status==='approved',changed:false}};
   }
   if(old?.uid&&old.uid!==contract.uid)throw Error('cross-account');
   const record={uid:contract.uid,plan:contract.plan,start:contract.start,end:contract.end,status:p.status,refundedCents:refunded,updated,verified:true,paymentKey};
   // The adapter atomically replaces this period together with the global ledger.
   return {value:record,period:record,result:{status:'recorded',changed:true}};
  });
 }
 async function webhook({method,dataId,body,signature,requestId}) {
  if(method!=='POST')return {status:405,body:{received:false}};
  if(typeof dataId!=='string'||!/^\d{1,30}$/.test(dataId)||body?.type!=='payment'||String(body.data?.id)!==dataId)return {status:400,body:{received:false}};
  try{if(await verifySignature({dataId,signature,requestId})!==true)return {status:401,body:{received:false}};}catch{return {status:401,body:{received:false}};}
  try{const r=await process(dataId);return {status:200,body:{received:true,reconciliationRequired:r.status==='reconciliation_pending'}};}
  catch{return {status:503,body:{received:false,error:'retry'}};}
 }
 return {webhook,reprocess:process};
}
