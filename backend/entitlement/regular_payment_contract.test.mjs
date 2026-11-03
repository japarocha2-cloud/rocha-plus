import test from 'node:test';
import assert from 'node:assert/strict';
import {inspectRegularPaymentContract} from './regular_payment_contract.mjs';
function fixture() {
  const payment={id:'11',collector_id:123,payer:{id:55,email:'fixture@example.invalid'},
    currency_id:'BRL',transaction_amount:4.5,operation_type:'regular_payment',date_approved:'2026-10-20T00:00:03Z',
    point_of_interaction:{transaction_data:{subscription_id:'fixture_contract_1'}}};
  const subscription={id:'fixture_contract_1',collector_id:123,payer_id:55,payer_email:'masked@example.invalid',status:'authorized',
    auto_recurring:{frequency:1,frequency_type:'months',transaction_amount:4.5,currency_id:'BRL',start_date:'2026-10-20T00:00:00Z'},
    next_payment_date:'2026-11-20T00:00:00Z'};
  return {payment,subscription,request:()=>({payment,merchantId:'123',provider:{subscription:async()=>subscription}})};
}
test('regular payment resolves its contract even when payer_email search cannot match',async()=>{
  const f=fixture(),r=await inspectRegularPaymentContract(f.request());
  assert.equal(r.plan,'monthly');assert.equal(r.periodEnd,Date.parse('2026-11-20T00:00:00Z'));
  assert.equal(r.accessGranted,false);assert.equal(r.independentlyReviewed,false);
});
test('annual provider schedule preserves exact next payment date rather than adding a month',async()=>{
  const f=fixture();f.subscription.auto_recurring.frequency_type='years';f.subscription.next_payment_date='2027-10-20T00:00:00Z';
  const r=await inspectRegularPaymentContract(f.request());assert.equal(r.plan,'annual');
  assert.equal(r.periodEnd,Date.parse(f.subscription.next_payment_date));
});
test('receipt reference alone cannot bind wrong merchant, payer, amount, status or cycle',async()=>{
  for(const change of [s=>s.collector_id=999,s=>s.payer_id=99,s=>s.id='different_contract',
    s=>s.status='cancelled',s=>s.auto_recurring.transaction_amount=4.9,
    s=>s.auto_recurring.start_date='2025-10-20T00:00:00Z',s=>s.next_payment_date=null,
    s=>delete s.payer_id]) {
    const f=fixture();change(f.subscription);await assert.rejects(inspectRegularPaymentContract(f.request()));
  }
});
