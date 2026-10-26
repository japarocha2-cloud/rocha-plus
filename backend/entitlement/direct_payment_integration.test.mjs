// Simulated integration: dry-run ledger planning -> admin-only atomic confirmation.
// This file uses fixtures, an in-memory serialized transaction double and NO provider/Firebase credentials.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createAccessService, DAY } from './service.mjs';
import { planDirectPaymentReconciliation } from './direct_payment_reconciliation.mjs';

function lab() {
  const accounts=new Map(), payments=new Map(), audit=[];
  let queue=Promise.resolve();
  const store={ transact(uid, paymentId, fn) {
    const action=queue.then(async()=>{
      const a=new Map(structuredClone([...accounts])), p=new Map(structuredClone([...payments]));
      const logs=structuredClone(audit);
      const result=await fn({
        account:a.get(uid),payment:p.get(paymentId),
        payments:[...p.values()].filter(x=>x.uid===uid),
        setAccount:x=>a.set(uid,x),setPayment:x=>p.set(paymentId,x),
        audit:(kind,data)=>logs.push({kind,...data}),
      });
      accounts.clear(); for(const [k,v] of a) accounts.set(k,v);
      payments.clear(); for(const [k,v] of p) payments.set(k,v);
      audit.splice(0,audit.length,...logs);
      return result;
    });
    queue=action.catch(()=>{});
    return action;
  }};
  const now=Date.UTC(2026,9,26);
  const service=createAccessService({
    verifyToken:async token=>({
      uid:token==='admin'?'lab-admin':token,
      firebase:{sign_in_provider:'google.com'},rochaAdmin:token==='admin',
    }),
    store,now:()=>now,
    plans:{monthly:{days:30,amountCents:450},annual:{days:365,amountCents:4950}},
  });
  const confirm=(transactionId,plan='monthly',uid='fixture-user')=>service({
    method:'POST',path:'/v1/admin/confirm',authorization:'Bearer admin',
    body:{uid,provider:'mercadopago',transactionId,plan,
      amountCents:plan==='monthly'?450:4950,currency:'BRL',
      evidenceReference:'FIXTURE-verified-provider-evidence'},
  });
  const read=()=>service({method:'GET',path:'/v1/entitlement',authorization:'Bearer fixture-user'});
  return {confirm,read,accounts,payments,audit,now};
}
const verified=id=>({provider:'mercadopago',transactionId:id,uid:'fixture-user',
  verified:true,approved:true,refunded:false,chargedBack:false});
test('dry run has no effects; two fixture payments are recorded once under concurrent retries',async()=>{
  const f=lab(), snapshot=[verified('11'),verified('22')];
  const preview=planDirectPaymentReconciliation({targetUid:'fixture-user',ledger:[],
    ledgerComplete:true,durationPolicyApproved:true,verifiedPayments:snapshot});
  assert.equal(preview.writes,0);assert.equal(f.payments.size,0);
  const results=await Promise.all([
    f.confirm('11','monthly'),f.confirm('11','monthly'),
    f.confirm('22','annual'),f.confirm('22','annual'),
  ]);
  assert.equal(results.filter(x=>x.duplicate===false).length,2);
  assert.equal(f.payments.size,2);assert.equal(f.audit.length,2);
  const before=(await f.read()).expiresAt;
  await Promise.all([f.confirm('11','monthly'),f.confirm('22','annual')]);
  assert.equal((await f.read()).expiresAt,before);
  const ledger=[...f.payments.values()].map(p=>({
    provider:p.provider,transactionId:p.transactionId,uid:p.uid,status:p.status,
  }));
  const next=planDirectPaymentReconciliation({targetUid:'fixture-user',ledger,
    ledgerComplete:true,durationPolicyApproved:true,verifiedPayments:snapshot});
  assert.deepEqual(next.pendingTransactionIds,[]);
  assert.deepEqual(next.alreadyProcessedTransactionIds,['11','22']);
});
test('competing accounts cannot claim the same transaction in the serialized lab store',async()=>{
  const f=lab();
  const outcomes=await Promise.allSettled([
    f.confirm('11','monthly','fixture-user'),
    f.confirm('11','monthly','other-user'),
  ]);
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
  assert.equal(outcomes.filter(x=>x.status==='rejected'&&x.reason.status===409).length,1);
  assert.equal(f.payments.size,1);assert.equal(f.audit.length,1);
});
test('fixture paid access expires by server clock, never by client input',async()=>{
  const f=lab();await f.confirm('11','monthly');
  const result=await f.read();
  assert.equal(result.allowed,true);
  assert.equal(Date.parse(result.expiresAt),f.now+30*DAY);
});
