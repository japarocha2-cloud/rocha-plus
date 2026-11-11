import test from 'node:test';
import assert from 'node:assert/strict';
import { entitlement, assertOwner, accountId } from './policy.js';
const make = state => ({ subscriptionState: state, lineItems: [{
  productId: 'rocha_plus_monthly', offerDetails: {basePlanId: 'monthly'},
  expiryTime: '2030-01-01T00:00:00Z', autoRenewingPlan: {autoRenewEnabled: true}
}] });
for (const state of ['ACTIVE', 'IN_GRACE_PERIOD', 'CANCELED'])
  test(state + ' keeps access until expiry', () =>
    assert.equal(entitlement(make('SUBSCRIPTION_STATE_' + state), 0).active, true));
for (const state of ['PENDING', 'ON_HOLD', 'PAUSED', 'EXPIRED', 'PENDING_PURCHASE_CANCELED'])
  test(state + ' denies access', () =>
    assert.equal(entitlement(make('SUBSCRIPTION_STATE_' + state), 0).active, false));
test('expiry wins even when Play says active', () =>
  assert.equal(entitlement(make('SUBSCRIPTION_STATE_ACTIVE'), Date.parse('2031-01-01')).active, false));
test('wrong product and plan rejected', () => {
  const p = make('SUBSCRIPTION_STATE_ACTIVE');
  p.lineItems[0].offerDetails.basePlanId = 'yearly';
  assert.throws(() => entitlement(p));
});
test('missing expiry fails closed', () => {
  const p = make('SUBSCRIPTION_STATE_ACTIVE'); delete p.lineItems[0].expiryTime;
  assert.equal(entitlement(p).active, false);
});
test('account binding rejects replay', () => {
  const p = {externalAccountIdentifiers: {obfuscatedExternalAccountId: accountId('one')}};
  assert.doesNotThrow(() => assertOwner(p, 'one'));
  assert.throws(() => assertOwner(p, 'two'));
  assert.throws(() => assertOwner({}, 'one'));
});
