// Fixture-only integration through the real Firestore adapter. No SDK or credentials.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createRegularPaymentRecovery} from './regular_payment_recovery.mjs';
import {regularPaymentFirestoreStore} from './regular_payment_firestore.mjs';
const clone=x=>JSON.parse(JSON.stringify(x));
const decode=x=>x && typeof x==='object' ? (Object.hasOwn(x,'__time') ? {toMillis:()=>x.__time} :
  Array.isArray(x)?x.map(decode):Object.fromEntries(Object.entries(x).map(([k,v])=>[k,decode(v)]))) : x;
const encode=x=>x && typeof x==='object' ? (typeof x.toMillis==='function'?{__time:x.toMillis()}:
  Array.isArray(x)?x.map(encode):Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]))) : x;
function fixture() {
  let data=new Map([['rochaSparkAccounts/9001',{trialStartedAt:{__time:1000},welcomeAcceptedAt:null,favorites:['fixture-channel']}]]);
  let queue=Promise.resolve(), writes=0, failCommit=false, calls=0;
  const snap=(state,path)=>({exists:state.has(path),data:()=>state.has(path)?decode(clone(state.get(path))):undefined});
  const db={doc:path=>({path,get:async()=>snap(data,path)}),runTransaction:fn=>{
    const run=queue.then(async()=>{
      const copy=new Map([...data].map(([k,v])=>[k,clone(v)]));let wrote=false,count=0;
      const put=(ref,value,merge=false)=>{wrote=true;count++;copy.set(ref.path,merge?{...copy.get(ref.path),...encode(value)}:encode(value));};
      const result=await fn({get:async ref=>{assert.equal(wrote,false,'Firestore requires all reads before writes');return snap(copy,ref.path);},
        create:(r,v)=>{if(copy.has(r.path))throw Error('already-exists');put(r,v);},
        update:(r,v)=>{assert(copy.has(r.path));put(r,v,true);},set:(r,v)=>put(r,v)});
      if(failCommit)throw Error('fixture-atomic-commit-failure');data=copy;writes+=count;return result;
    });queue=run.catch(()=>{});return run;
  }};
  const now=Date.UTC(2026,9,25), monthly=Date.UTC(2026,9,20), annual=Date.UTC(2026,9,21);
  const user={uid:'firebase-fixture',email:'fixture@example.invalid',emailVerified:true,disabled:false,
    providerData:[{providerId:'google.com',uid:'9001'}]};
  const contract={uid:user.uid,reviewed:true,evidenceReference:'FIXTURE-contract',merchantId:'123',currency:'BRL',
    periodPolicy:'explicit-independent-periods',payments:[
      {id:'11',plan:'monthly',amountCents:450,periodStart:monthly,periodEnd:Date.UTC(2026,10,20)},
      {id:'22',plan:'annual',amountCents:4950,periodStart:annual,periodEnd:Date.UTC(2027,9,21)}]};
  const payments=contract.payments.map(t=>({id:t.id,collector_id:123,payer:{email:user.email},status:'approved',
    status_detail:'accredited',live_mode:true,operation_type:'regular_payment',currency_id:'BRL',
    transaction_amount:t.amountCents/100,transaction_amount_refunded:0,date_approved:new Date(t.periodStart).toISOString()}));
  const merchant={id:123,site_id:'MLB',tags:[]};
  const store=regularPaymentFirestoreStore({db,auth:{getUser:async()=>clone(user)},timestamp:ms=>({toMillis:()=>ms})});
  const options={provider:{merchant:async()=>{calls++;return clone(merchant);},payment:async id=>{calls++;return clone(payments.find(p=>p.id===id));}},
    store,now:()=>now,verifyAuthorization:async a=>a.reference==='FIXTURE-approved-action'};
  const recover=createRegularPaymentRecovery(options);
  const request=()=>({uid:user.uid,contract});
  const preview=()=>recover(request());
  const authorize=plan=>({actorUid:'fixture-operator',uid:user.uid,scope:'regular-payment-recovery',
    reference:'FIXTURE-approved-action',digest:plan.digest});
  const apply=plan=>recover({...request(),mode:'apply',authorization:authorize(plan)});
  return {user,contract,payments,merchant,options,recover,request,preview,apply,authorize,
    read:()=>clone([...data]),set:(p,d)=>data.set(p,d),writes:()=>writes,calls:()=>calls,
    failCommit:()=>{failCommit=true;}};
}
test('reproduces expired Spark without ledger; dry run proposes explicit annual end without stacking or writes',async()=>{
  const f=fixture(),before=f.read(),p=await f.preview();
  assert.equal(p.paidUntil,Date.UTC(2027,9,21));assert.equal(p.targetCollection,'rochaSparkAccounts');
  assert.equal(p.googleSubject,'9001');assert.notEqual(p.googleSubject,p.uid);
  assert.equal(p.writes,0);assert.equal(p.accessGranted,false);assert.deepEqual(f.read(),before);
});
test('atomic recovery uses Google document and preserves trial/welcome/favorites; replay never adds time',async()=>{
  const f=fixture(),p=await f.preview();const r=await f.apply(p);
  assert.equal(r.writes,5);assert.equal(f.writes(),5);
  const data=new Map(f.read()),spark=data.get('rochaSparkAccounts/9001');
  assert.equal(spark.paidUntil.__time,Date.UTC(2027,9,21));assert.deepEqual(spark.favorites,['fixture-channel']);
  assert.equal(spark.trialStartedAt.__time,1000);assert.equal(spark.welcomeAcceptedAt,null);
  assert.equal(data.has('entitlements/firebase-fixture'),false);
  const before=f.read();assert.equal((await f.apply(p)).duplicate,true);
  assert.deepEqual(f.read(),before);assert.equal(f.writes(),5);assert.equal(f.calls(),9);
});
test('concurrent repeats create one global record per payment and one audit',async()=>{
  const f=fixture(),p=await f.preview();const r=await Promise.all([f.apply(p),f.apply(p)]);
  assert.equal(r.filter(x=>x.duplicate).length,1);assert.equal(f.writes(),5);
});
test('transaction failure rolls back ledger, access and audit together',async()=>{
  const f=fixture(),p=await f.preview(),before=f.read();f.failCommit();
  await assert.rejects(f.apply(p));assert.deepEqual(f.read(),before);assert.equal(f.writes(),0);
});
test('pending/rejected/refunded/chargeback/sandbox/partial refund never grant',async()=>{
  for(const change of [{status:'pending'},{status:'rejected'},{status:'refunded'},{status:'charged_back'},
    {live_mode:false},{transaction_amount_refunded:1},{transaction_amount_refunded:undefined}]){
    const f=fixture();Object.assign(f.payments[0],change);await assert.rejects(f.preview());assert.equal(f.writes(),0);
  }
});
test('fresh provider read prevents applying a preview after refund',async()=>{
  const f=fixture(),p=await f.preview();f.payments[0].status='refunded';
  await assert.rejects(f.apply(p));assert.equal(f.writes(),0);
});
test('wrong payer/merchant/amount, duplicate IDs and missing contractual terms fail closed',async()=>{
  for(const change of [f=>f.payments[0].payer.email='other@example.invalid',f=>f.merchant.id=456,
    f=>f.payments[0].transaction_amount=4.9,f=>f.contract.payments.push(f.contract.payments[0]),
    f=>delete f.contract.payments[0].periodEnd,f=>delete f.contract.reviewed,
    f=>f.contract.periodPolicy='stack',f=>f.user.emailVerified=false]){
    const f=fixture();change(f);await assert.rejects(f.preview());assert.equal(f.writes(),0);
  }
});
test('unreviewed provider contract can be simulated but never applied',async()=>{
  const f=fixture();f.contract.reviewed=false;const p=await f.preview();
  assert.equal(p.readyForAuthorization,false);assert.equal(p.requiresContractReview,true);
  await assert.rejects(f.apply(p));assert.equal(f.writes(),0);
});
test('contract start just before payment approval is preserved',async()=>{
  const f=fixture();f.contract.payments[0].periodStart-=3000;
  assert.equal((await f.preview()).entries[0].periodStart,f.contract.payments[0].periodStart);
});
test('legacy or cross-account records require explicit review, never duplicate adoption',async()=>{
  for(const path of ['payment_events/11','payment_claims/11','rochaBillingPayments/11','rochaSparkPaymentConfirmations/11',
    'rochaDirectPaymentLedger/11']) {
    const f=fixture();f.set(path,{uid:'other-fixture',status:'confirmed'});
    await assert.rejects(f.preview());assert.equal(f.writes(),0);
  }
});
test('stale preview, unauthorized actor and absent authorization cannot apply',async()=>{
  const f=fixture(),p=await f.preview();
  await assert.rejects(f.recover({...f.request(),mode:'apply'}));
  await assert.rejects(f.recover({...f.request(),mode:'apply',authorization:{...f.authorize(p),reference:'unverified'}}));
  f.set('rochaSparkAccounts/9001',{paidUntil:{__time:Date.UTC(2028,0,1)}});
  await assert.rejects(f.apply(p));assert.equal(f.writes(),0);
});
test('manual revocation after recovery cannot be undone by approval replay',async()=>{
  const f=fixture(),p=await f.preview();await f.apply(p);
  f.set('rochaSparkAccounts/9001',{paidUntil:null});
  await assert.rejects(f.apply(p));assert.equal(f.writes(),5);
});
test('expired explicit periods and future starts do not create current access',async()=>{
  const f=fixture();f.contract.payments=f.contract.payments.slice(0,1);f.payments.splice(1);
  f.contract.payments[0].periodEnd=Date.UTC(2026,9,22);
  const p=await f.preview();assert.equal(p.currentlyValid,false);await assert.rejects(f.apply(p));
  f.contract.payments[0].periodStart=Date.UTC(2026,10,1);await assert.rejects(f.preview());
});
