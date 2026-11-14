'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {addUtcMonths, entitlementFromLedger} = require('./entitlement_periods');
const row = (paymentId, plan, extras = {}) => ({
  uid: 'user-1', paymentId, provider: 'mercadopago', status: 'approved',
  eligibleForReview: true, reviewed: true, approvalDate: '2026-10-26T10:00:00Z',
  plan, ...extras,
});
test('monthly and annual stack to 13 months (owner decision)', () => {
  assert.equal(entitlementFromLedger('user-1', [row('1','monthly'), row('2','annual')]),
    '2027-11-26T10:00:00.000Z');
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

test('monthly+annual policy is stacked: 13 months in either approval and delivery order', () => {
  const {MONTHLY_ANNUAL_POLICY} = require('./entitlement_periods');
  assert.equal(MONTHLY_ANNUAL_POLICY, 'stacked');
  const r = (id, plan, at) => row(id, plan, {approvalDate: at});
  // monthly approved before annual
  const mFirst = [r('1','monthly','2026-01-20T10:00:00Z'), r('2','annual','2026-02-10T10:00:00Z')];
  // annual approved before monthly
  const aFirst = [r('1','annual','2026-01-20T10:00:00Z'), r('2','monthly','2026-02-10T10:00:00Z')];
  for (const rows of [mFirst, aFirst]) {
    assert.equal(entitlementFromLedger('user-1', rows), '2027-02-20T10:00:00.000Z');
    assert.equal(entitlementFromLedger('user-1', [...rows].reverse()), '2027-02-20T10:00:00.000Z');
  }
  // latest_end stays available for comparison
  assert.equal(entitlementFromLedger('user-1', mFirst, 'latest_end'), '2027-02-10T10:00:00.000Z');
  assert.throws(() => entitlementFromLedger('user-1', mFirst, 'sum'), /invalid period policy/);
});
