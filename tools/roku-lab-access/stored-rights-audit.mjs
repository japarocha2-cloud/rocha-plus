import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
export async function inspectStoredRights({auth,db,email,paymentIds,computeAccess}) {
 const u=await auth.getUserByEmail(email);
 if(u.disabled||!u.emailVerified||u.email?.toLowerCase()!==email.toLowerCase())throw Error('identity_not_confirmed');
 const google=u.providerData.filter(p=>p.providerId==='google.com');if(google.length!==1||!/^\d{1,128}$/.test(google[0].uid))throw Error('google_identity_not_confirmed');
 if(paymentIds.length!==2||!paymentIds.every(x=>/^\d{1,30}$/.test(x)))throw Error('invalid_payment_scope');
 const subject=google[0].uid,key=hash(u.uid),get=p=>db.doc(p).get();
 const [spark,legacy,projection]=await Promise.all([get('rochaSparkAccounts/'+subject),get('rochaBillingUsers/'+key),get('rochaSparkBillingProjections/'+subject)]);
 const now=spark.readTime?.toMillis?.();if(!Number.isSafeInteger(now))throw Error('server_clock_not_confirmed');
 const l=legacy.data(),s=spark.data(),p=projection.data();
 if(l&&l.uid!==u.uid)throw Error('legacy_uid_binding_mismatch');
 let ledgerState=null;if(l)ledgerState=computeAccess(l,now);
 const paid=s?.paidUntil?.toMillis?.()??null;
 const checks=await Promise.all(paymentIds.map(async id=>{const [r,c]=await Promise.all([get('rochaBillingPayments/'+id),get('rochaSparkPaymentConfirmations/'+id)]);return {legacyPaymentRecordExists:r.exists,legacyRecordMatchesUid:r.exists?r.data()?.uid===u.uid:null,manualConfirmationExists:c.exists,manualConfirmationMatchesIdentity:c.exists?c.data()?.verifiedUid===u.uid&&c.data()?.googleSubject===subject:null,inExistingUserLedger:!!l?.payments?.[id]};}));
 return {project:'rocha-plus',readOnly:true,writes:0,checkedAt:new Date(now).toISOString(),accountFound:true,verifiedGoogleAccount:true,spark:{recordFound:spark.exists,paidUntilPresent:paid!==null,paidAccessCurrent:paid!==null&&paid>now},legacy:{recordFound:legacy.exists,uidBindingConfirmed:!!l&&l.uid===u.uid,computedState:ledgerState?.state??null,activePaidFromExistingLedger:ledgerState?.state==='paid'&&ledgerState.active===true},projection:{exists:projection.exists,consistent:projection.exists?paid===p.lastPaidUntil:null},specifiedPaymentLedgerChecks:checks,commercialAccessGranted:false};
}
