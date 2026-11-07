import test from 'node:test';
import assert from 'node:assert/strict';
import { planDirectPaymentReconciliation as plan } from './direct_payment_reconciliation.mjs';
const payment = (id, uid='fixture-user') => ({
  provider:'mercadopago', transactionId:id, uid, verified:true,
  approved:true, refunded:false, chargedBack:false,
});
const base = () => ({ targetUid:'fixture-user', ledgerComplete:true,
  durationPolicyApproved:true, ledger:[], verifiedPayments:[payment('11'),payment('22')] });
test('two validated payments are proposed without granting or mutating input', () => {
  const f=base(), previous=structuredClone(f), r=plan(f);
  assert.deepEqual(r.pendingTransactionIds,['11','22']);
  assert.equal(r.dryRun,true); assert.equal(r.writes,0);
  assert.equal(r.accessGranted,false); assert.equal(r.readyToApply,false);
  assert.deepEqual(f,previous);
});
test('same known payments are not proposed a second time', () => {
  const f=base(); f.ledger=f.verifiedPayments.map(p=>({provider:p.provider,transactionId:p.transactionId,uid:p.uid,status:'confirmed'}));
  const r=plan(f);
  assert.deepEqual(r.pendingTransactionIds,[]);
  assert.deepEqual(r.alreadyProcessedTransactionIds,['11','22']);
});
test('incomplete ledger or unapproved duration blocks any proposal', () => {
  const f=base();
  for(const change of [{ledgerComplete:false},{ledger:null},{durationPolicyApproved:false}]) {
    assert.throws(()=>plan({...f,...change}),/reconciliation-blocked/);
  }
});
test('cross-account, refunded and chargeback records cannot be reused', () => {
  for(const entry of [
    {provider:'mercadopago',transactionId:'11',uid:'other',status:'confirmed'},
    {provider:'mercadopago',transactionId:'11',uid:'fixture-user',status:'refunded'},
    {provider:'mercadopago',transactionId:'11',uid:'fixture-user',status:'charged_back'},
  ]) assert.throws(()=>plan({...base(),ledger:[entry]}),/reconciliation-blocked/);
});
test('duplicate payments or ledger entries are rejected', () => {
  const f=base();
  assert.throws(()=>plan({...f,verifiedPayments:[payment('11'),payment('11')]}),/reconciliation-blocked/);
  const entry={provider:'mercadopago',transactionId:'11',uid:'fixture-user',status:'confirmed'};
  assert.throws(()=>plan({...f,ledger:[entry,entry]}),/reconciliation-blocked/);
});
test('rejects missing provider verification and payment reversal signals', () => {
  for(const change of [{verified:false},{approved:false},{refunded:true},{chargedBack:true},{uid:'other'},{transactionId:'../escape'}]) {
    assert.throws(()=>plan({...base(),verifiedPayments:[{...payment('11'),...change}]}),/reconciliation-blocked/);
  }
});
