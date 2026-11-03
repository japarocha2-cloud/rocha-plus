import {randomUUID,createHash} from 'node:crypto';
import {addMonths} from '../../billing/policy.js';
const emailHash=s=>createHash('sha256').update(s.trim().toLowerCase()).digest('hex');
// Trusted store only: reservations created from Firebase identity, or historical
// records reviewed with explicit owner approval. No endpoint accepts a paid grant.
export function createContractResolver({store}) {
 return async payment=>{
  const historical=await store.reviewedPayment(String(payment.id));
  if(historical?.reviewed===true&&historical.ownerAuthorization===true&&historical.paymentId===String(payment.id)){
   if(historical.payerId!==String(payment.payer?.id)||historical.emailHash!==emailHash(payment.payer?.email??''))return null;
   return {...historical,bindingVerified:true,approvedPolicy:true};
  }
  const ref=payment.external_reference;
  if(typeof ref!=='string'||!/^[a-f0-9-]{36}$/.test(ref))return null;
  const r=await store.reservation(ref);
  if(!r||r.reference!==ref||!r.uid||r.firebaseEmailVerified!==true||r.emailHash!==emailHash(payment.payer?.email??'')||
   r.periodPolicy!=='independent-calendar-months-from-approval'||r.policyApproved!==true||
   !Number.isSafeInteger(r.months)||r.months<1||r.months>12)return null;
  const start=Date.parse(payment.date_approved);if(!Number.isSafeInteger(start))return null;
  return {uid:r.uid,plan:r.plan,externalReference:ref,payerId:String(payment.payer.id),amountCents:r.amountCents,
   start,end:addMonths(start,r.months),bindingVerified:true,approvedPolicy:true};
 };
}
// Pure server intent preparation, no provider request and no charge. The caller
// must separately approve activation of a UID-bound provider checkout.
export function createCheckoutPreparation({verifyIdentity,store,catalog,now=Date.now,newId=randomUUID}) {
 return async({authorization,plan})=>{
  const token=/^Bearer (\S+)$/.exec(authorization??'')?.[1];if(!token)throw Error('auth');
  const identity=await verifyIdentity(token,true),offer=catalog?.[plan];
  if(!identity?.uid||!identity.email||identity.email_verified!==true)throw Error('identity');
  if(!offer||offer.policyApproved!==true||!Number.isSafeInteger(offer.amountCents)||offer.amountCents<=0||
   !Number.isSafeInteger(offer.months)||offer.months<1||offer.months>12||offer.periodPolicy!=='independent-calendar-months-from-approval')throw Error('unapproved-contract');
  const reference=newId();if(!/^[a-f0-9-]{36}$/.test(reference))throw Error('reference');
  const record={reference,uid:identity.uid,emailHash:emailHash(identity.email),firebaseEmailVerified:true,plan,
   amountCents:offer.amountCents,months:offer.months,periodPolicy:offer.periodPolicy,policyApproved:true,createdAt:now()};
  await store.reserve(record);
  return {reference,plan,providerCheckoutCreated:false,paymentActivationRequired:true};
 };
}
