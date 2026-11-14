const test = require('node:test');
const assert = require('node:assert/strict');
const {entitlementFromLedger} = require('../../functions/entitlement_periods');
test('fixture annual ending 21 October 2027 is not compounded with prior monthly', () => {
 const input=[
  {uid:'fixture',paymentId:'1',provider:'mercadopago',status:'approved',eligibleForReview:true,reviewed:true,approvalDate:'2026-10-20T12:00:00Z',plan:'monthly'},
  {uid:'fixture',paymentId:'2',provider:'mercadopago',status:'approved',eligibleForReview:true,reviewed:true,approvalDate:'2026-10-21T12:00:00Z',plan:'annual'},
 ];
 const original=JSON.stringify(input);
 assert.equal(entitlementFromLedger('fixture',input),'2027-10-21T12:00:00.000Z');
 assert.equal(JSON.stringify(input),original);
 assert.throws(()=>entitlementFromLedger('different-subject',input),/ownership/);
 assert.throws(()=>entitlementFromLedger('fixture',[...input,input[1]]),/duplicate/);
});
