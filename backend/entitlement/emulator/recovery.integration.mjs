// Real Firestore emulator transaction integration; fixture identities/provider only.
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
import {createRegularPaymentRecovery} from '../regular_payment_recovery.mjs';
import {regularPaymentFirestoreStore} from '../regular_payment_firestore.mjs';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8086' ||
   process.env.GCLOUD_PROJECT!=='demo-rocha-recovery' || process.env.GOOGLE_APPLICATION_CREDENTIALS ||
   process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.MP_RECEIVING_ACCESS_TOKEN) throw Error('isolated-emulator-required');
const app=initializeApp({projectId:'demo-rocha-recovery'}),db=getFirestore(app);
try {
  const user={uid:'fixture-firebase',email:'fixture@example.invalid',emailVerified:true,disabled:false,
    providerData:[{providerId:'google.com',uid:'9001'}]};
  const now=Date.UTC(2026,9,25),start=Date.UTC(2026,9,20),end=Date.UTC(2027,9,20);
  const contract={uid:user.uid,reviewed:true,evidenceReference:'FIXTURE-emulator-contract',merchantId:'123',currency:'BRL',
    periodPolicy:'explicit-independent-periods',payments:[{id:'11',plan:'annual',amountCents:4950,periodStart:start,periodEnd:end}]};
  const provider={merchant:async()=>({id:123,site_id:'MLB',tags:[]}),payment:async id=>({id,collector_id:123,payer:{email:user.email},
    status:'approved',status_detail:'accredited',live_mode:true,operation_type:'regular_payment',currency_id:'BRL',
    transaction_amount:49.5,transaction_amount_refunded:0,date_approved:new Date(start).toISOString()})};
  await db.doc('rochaSparkAccounts/9001').set({trialStartedAt:Timestamp.fromMillis(1000),welcomeAcceptedAt:null,favorites:['fixture']});
  const store=regularPaymentFirestoreStore({db,auth:{getUser:async()=>structuredClone(user)},timestamp:ms=>Timestamp.fromMillis(ms)});
  const recover=createRegularPaymentRecovery({provider,store,now:()=>now,verifyAuthorization:async()=>true});
  const request={uid:user.uid,contract};
  const preview=await recover(request);
  assert.equal((await db.collection('rochaDirectPaymentLedger').get()).size,0);
  assert.equal((await db.doc('rochaSparkAccounts/9001').get()).get('paidUntil'),undefined);
  const authorization={uid:user.uid,actorUid:'fixture-admin',scope:'regular-payment-recovery',reference:'FIXTURE-approved',digest:preview.digest};
  const apply=()=>recover({...request,mode:'apply',authorization});
  const results=await Promise.all([apply(),apply(),apply()]);
  assert.equal(results.filter(r=>!r.duplicate).length,1);
  assert.equal((await db.collection('rochaDirectPaymentLedger').get()).size,1);
  assert.equal((await db.collection('rochaDirectPaymentAudit').get()).size,1);
  const spark=(await db.doc('rochaSparkAccounts/9001').get()).data();
  assert.equal(spark.paidUntil.toMillis(),end);assert.equal(spark.trialStartedAt.toMillis(),1000);
  assert.deepEqual(spark.favorites,['fixture']);assert.equal(spark.welcomeAcceptedAt,null);
  // A real Firestore transaction aborts every queued write if the callback fails.
  const rollbackContract={...contract,payments:[{...contract.payments[0],id:'22'}]};
  const abortStore={read:store.read,transact:(uid,ids,fn)=>store.transact(uid,ids,(state,commit)=>fn(state,async payload=>{
    await commit(payload);throw Error('fixture-abort-after-queued-writes');
  }))};
  const abort=createRegularPaymentRecovery({provider,store:abortStore,now:()=>now,verifyAuthorization:async()=>true});
  const next=await abort({uid:user.uid,contract:rollbackContract});
  await assert.rejects(abort({uid:user.uid,contract:rollbackContract,mode:'apply',authorization:{...authorization,digest:next.digest}}));
  assert.equal((await db.doc('rochaDirectPaymentLedger/22').get()).exists,false);
  assert.equal((await db.collection('rochaDirectPaymentAudit').get()).size,1);
  assert.equal((await db.doc('rochaSparkAccounts/9001').get()).get('paidUntil').toMillis(),end);
  console.log(JSON.stringify({project:'demo-rocha-recovery',fixtureOnly:true,providerSimulated:true,
    realFirestoreTransactions:true,concurrentCalls:3,committedPayments:1,auditRecords:1,
    replayStable:true,rollbackConfirmed:true,productionWrites:0}));
} finally {await db.terminate();await deleteApp(app);}
