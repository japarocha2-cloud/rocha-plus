// Explicitly injected Admin SDK objects; importing this adapter never connects or writes.
// Not wired to any deployed endpoint or scheduler.
import {createHash} from 'node:crypto';
const hash = value => createHash('sha256').update(value).digest('hex');
const millis = value => value==null ? null : value?.toMillis?.() ?? NaN;
export function regularPaymentFirestoreStore({db,auth,timestamp}) {
  async function snapshot(uid,ids,read) {
    const user=await auth.getUser(uid);
    const google=user.providerData?.filter(p=>p.providerId==='google.com');
    if (user.uid!==uid || google?.length!==1 || !/^\d{1,30}$/.test(google[0].uid)) throw Error('identity');
    const subject=google[0].uid;
    const sparkRef=db.doc('rochaSparkAccounts/'+subject);
    const projectionRef=db.doc('rochaDirectPaymentProjections/'+subject);
    const spark=await read(sparkRef), projection=await read(projectionRef);
    const identity=await read(db.doc('rochaSparkBillingIdentities/'+hash(uid)));
    const recurringProjection=await read(db.doc('rochaSparkBillingProjections/'+subject));
    for (const snap of [identity,recurringProjection]) {
      if (snap.exists && (snap.data().googleSubject!==subject ||
          (snap.data().uid!=null && snap.data().uid!==uid))) throw Error('identity-conflict');
    }
    const records=[];
    for (const id of ids) {
      const managed=await read(db.doc('rochaDirectPaymentLedger/'+id));
      const legacyPaths=['payment_claims/'+id,'payment_events/'+id,'rochaBillingPayments/'+id,
        'rochaSparkPaymentConfirmations/'+id,
        'rochaPayments/'+hash(JSON.stringify(['mercadopago',id]))];
      let legacyExists=false;
      for (const path of legacyPaths) if ((await read(db.doc(path))).exists) legacyExists=true;
      records.push({id,managed:managed.exists?managed.data():null,legacyExists});
    }
    return {user,googleSubject:subject,sparkExists:spark.exists,
      paidUntil:millis(spark.data()?.paidUntil),projection:projection.exists?projection.data():null,
      knownLedgersChecked:true,records};
  }
  return {
    read:(uid,ids)=>snapshot(uid,ids,ref=>ref.get()),
    transact:(uid,ids,callback)=>db.runTransaction(async tx=>{
      const state=await snapshot(uid,ids,ref=>tx.get(ref));
      return callback(state,async ({plan,authorization,checkedAt})=>{
        for (const row of plan.entries.filter(p=>!p.alreadyProcessed)) {
          const {alreadyProcessed,...record}=row;
          tx.create(db.doc('rochaDirectPaymentLedger/'+row.id),{
            ...record,provider:'mercadopago',contractEvidence:plan.contractEvidence,
            checkedAt:timestamp(checkedAt),authorizedBy:authorization.actorUid,
            authorizationReference:authorization.reference});
        }
        tx.update(db.doc('rochaSparkAccounts/'+plan.googleSubject),{
          paidUntil:timestamp(plan.paidUntil),reconciledAt:timestamp(checkedAt)});
        tx.set(db.doc('rochaDirectPaymentProjections/'+plan.googleSubject),{
          uid:plan.uid,googleSubject:plan.googleSubject,paidUntil:plan.paidUntil,digest:plan.digest});
        tx.create(db.doc('rochaDirectPaymentAudit/'+plan.digest),{
          uid:plan.uid,actorUid:authorization.actorUid,authorizationReference:authorization.reference,
          previousPaidUntil:plan.previousPaidUntil,paidUntil:plan.paidUntil,
          paymentIds:plan.entries.map(p=>p.id),at:timestamp(checkedAt)});
      });
    })
  };
}
