import test from 'node:test';
import assert from 'node:assert/strict';
import { accountId, entitlement } from './policy.js';
import { createBillingService } from './service.js';
const now = Date.parse('2026-10-10T12:00:00Z');
function annual(state = 'ACTIVE', expires = now + 365 * 86400000) {
  return { testPurchase: {}, subscriptionState: 'SUBSCRIPTION_STATE_' + state,
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: { obfuscatedExternalAccountId: accountId('tester') },
    lineItems: [{ productId: 'rocha_plus_monthly', offerDetails: { basePlanId: 'yearly' },
      expiryTime: new Date(expires).toISOString(), autoRenewingPlan: { autoRenewEnabled: state !== 'CANCELED' } }] };
}
for (const state of ['ACTIVE', 'IN_GRACE_PERIOD', 'CANCELED']) {
  test('annual ' + state + ' keeps paid access', () => {
    const result = entitlement(annual(state), now);
    assert.equal(result.active, true); assert.equal(result.basePlanId, 'yearly');
  });
}
for (const state of ['EXPIRED', 'ON_HOLD', 'PAUSED', 'PENDING'])
  test('annual ' + state + ' blocks access', () => assert.equal(entitlement(annual(state), now).active, false));
test('annual expiry overrides ACTIVE', () => assert.equal(entitlement(annual('ACTIVE', now), now).active, false));
test('wrong annual product rejected', () => {
  const p = annual(); p.lineItems[0].productId = 'other'; assert.throws(() => entitlement(p, now));
});
test('annual HTTP verify and restore; real purchases still rejected before acknowledge', async () => {
  let value = annual(), claimed = false, acknowledged = 0;
  const service = createBillingService({ now: () => now, verifyIdentity: async () => ({uid:'tester'}),
    readPlay: async () => value, acknowledge: async () => { acknowledged++; },
    store: { claim: async () => { claimed = true; }, owner: async () => claimed ? 'tester' : undefined,
      tokens: async () => claimed ? ['annual-test-token'] : [] } });
  const request = action => service.handle({method:'POST', authorization:'Bearer test', body:{action, token:'annual-test-token'}});
  assert.equal((await request('verify')).body.basePlanId, 'yearly');
  assert.equal((await request('entitlement')).body.active, true);
  value = annual('CANCELED'); assert.equal((await request('entitlement')).body.active, true);
  value = annual('EXPIRED', now); assert.equal((await request('entitlement')).body.active, false);
  value = annual(); delete value.testPurchase;
  const before = acknowledged; assert.equal((await request('verify')).status, 403); assert.equal(acknowledged, before);
});
