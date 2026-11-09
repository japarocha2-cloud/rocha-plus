'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {addUtcMonths, entitlementFromLedger} = require('./entitlement_periods');
const row = (paymentId, plan, extras = {}) => ({
  uid: 'user-1', paymentId, provider: 'mercadopago', status: 'approved',
  eligibleForReview: true, reviewed: true, approvalDate: '2026-10-26T10:00:00Z',
  plan, ...extras,
});
test('monthly and annual overlap rather than double charging time', () => {
  assert.equal(entitlementFromLedger('user-1', [row('1','monthly'), row('2','annual')]),
    '2027-10-26T10:00:00.000Z');
});
test('same payment may not be applied twice', () => {
  assert.throws(() => entitlementFromLedger('user-1',[row('1','monthly'),row('1','monthly')]),/duplicate/);
});
test('refund or chargeback removes its paid period on recomputation', () => {
  assert.equal(entitlementFromLedger('user-1',[row('1','annual',{status:'refunded'})]),null);
});
test('unreviewed or unlinked payment never grants time', () => {
  assert.equal(entitlementFromLedger('user-1',[row('1','annual',{reviewed:false})]),null);
  assert.throws(() => entitlementFromLedger('user-1',[row('1','annual',{uid:'other'})]));
});
test('month-end date is clamped', () => {
  assert.equal(addUtcMonths('2026-01-31T09:00:00Z',1).toISOString(),
    '2026-02-28T09:00:00.000Z');
});
