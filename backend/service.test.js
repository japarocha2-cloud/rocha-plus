import test from 'node:test';
import assert from 'node:assert/strict';
import { createBillingService, packageName } from './service.js';
import { accountId } from './policy.js';
const a = 'test-token-aaaaaaaa', b = 'test-token-bbbbbbbb';
const now = Date.parse('2026-10-09T00:00:00Z');
function purchase(state = 'ACTIVE', uid = 'one', expires = now + 86400000) {
  return { testPurchase: {}, acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    subscriptionState: 'SUBSCRIPTION_STATE_' + state,
    externalAccountIdentifiers: { obfuscatedExternalAccountId: accountId(uid) },
    lineItems: [{ productId: 'rocha_plus_monthly', offerDetails: { basePlanId: 'monthly' },
      expiryTime: new Date(expires).toISOString(), autoRenewingPlan: {autoRenewEnabled: true} }] };
}
function fixture() {
  const purchases = new Map([[a, purchase()], [b, purchase()]]);
  const owners = new Map(), users = new Map(), ack = [], identity = [];
  const store = {
    owner: async token => owners.get(token),
    tokens: async uid => users.get(uid) ?? [],
    claim: async (uid, token, linked) => {
      if ((owners.has(token) && owners.get(token) !== uid) ||
          (owners.has(linked) && owners.get(linked) !== uid)) throw new Error('owned');
      owners.set(token, uid); users.set(uid, [...new Set([...(users.get(uid) ?? []), token])]);
    },
  };
  const service = createBillingService({ store, now: () => now,
    verifyIdentity: async (id, revoked) => {
      identity.push({id, revoked}); if (id === 'invalid') throw new Error('revoked');
      return { uid: id };
    },
    readPlay: async token => {
      const value = purchases.get(token);
      if (value instanceof Error) throw value;
      if (!value) throw new Error('unknown'); return structuredClone(value);
    },
    acknowledge: async token => { ack.push(token);
      purchases.get(token).acknowledgementState = 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'; },
  });
  const request = (body, uid = 'one') => service.handle({
    method: 'POST', authorization: 'Bearer ' + uid, body,
  });
  return { service, request, purchases, owners, users, ack, identity };
}
test('authentication checked with revocation; caller UID ignored', async () => {
  const f = fixture();
  assert.equal((await f.request({action:'account', uid:'two'})).body.accountId, accountId('one'));
  assert.deepEqual(f.identity[0], {id:'one', revoked:true});
  assert.equal((await f.request({action:'account'}, 'invalid')).status, 401);
  assert.equal((await f.service.handle({method:'POST'})).status, 401);
  assert.equal((await f.service.handle({method:'GET'})).status, 405);
});
test('valid purchase grants; restore is idempotent; response contains no token', async () => {
  const f = fixture();
  const result = await f.request({action:'verify',token:a});
  assert.equal(result.body.active, true); assert.equal(f.ack.length, 1);
  assert.equal((await f.request({action:'verify',token:a})).body.active, true);
  assert.equal(f.ack.length, 1); assert.equal(JSON.stringify(result).includes(a), false);
});
test('pending is bound but never acknowledged or granted', async () => {
  const f = fixture(); f.purchases.set(a, purchase('PENDING'));
  assert.equal((await f.request({action:'verify',token:a})).body.active, false);
  assert.equal(f.ack.length, 0);
  f.purchases.set(a, purchase());
  assert.equal((await f.request({action:'entitlement'})).body.active, true);
  assert.equal(f.ack.length, 1);
});
test('real purchase and wrong account rejected before store or acknowledgement', async () => {
  const f = fixture(); const p = purchase(); delete p.testPurchase; f.purchases.set(a,p);
  assert.equal((await f.request({action:'verify',token:a})).status, 403);
  f.purchases.set(a,purchase('ACTIVE','two'));
  assert.equal((await f.request({action:'verify',token:a})).status, 403);
  assert.equal(f.owners.size, 0); assert.equal(f.ack.length, 0);
});
test('restore order cannot replace active purchase with old revoked one', async () => {
  const f = fixture();
  f.purchases.set(a,purchase('EXPIRED','one',now + 999999999));
  await f.request({action:'verify',token:b});
  const restored = await f.request({action:'verify',token:a});
  assert.equal(restored.body.active, true);
  assert.equal(restored.body.expiresAt, now + 86400000);
});
test('fresh queries reflect renew, cancel, hold, recover, revoke and expire', async () => {
  const f = fixture(); await f.request({action:'verify',token:a});
  for (const [state, expires, active] of [
    ['ACTIVE',now+200000,true], ['CANCELED',now+200000,true],
    ['ON_HOLD',now+200000,false], ['IN_GRACE_PERIOD',now+200000,true],
    ['EXPIRED',now+200000,false], ['ACTIVE',now-1,false]]) {
    f.purchases.set(a,purchase(state,'one',expires));
    assert.equal((await f.request({action:'entitlement'})).body.active,active,state);
  }
});
test('Publisher transient errors and acknowledgement failure deny access', async () => {
  const f = fixture(); await f.request({action:'verify',token:a});
  f.purchases.set(a,new Error('network secret detail'));
  const result = await f.request({action:'entitlement'});
  assert.equal(result.status,403); assert.equal(result.body.active,false);
  assert.equal(JSON.stringify(result).includes('secret'),false);
  const g=fixture(); g.purchases.get(a).acknowledgementState='ACKNOWLEDGEMENT_STATE_PENDING';
  // Frozen response means acknowledge cannot mark it and throws.
  Object.freeze(g.purchases.get(a));
  assert.equal((await g.request({action:'verify',token:a})).status,403);
});
test('unqueryable old Play token (410) cannot override newer active purchase', async () => {
  const f=fixture(); await f.request({action:'verify',token:a});
  await f.request({action:'verify',token:b});
  f.purchases.set(a,Object.assign(new Error('gone'),{response:{status:410}}));
  assert.equal((await f.request({action:'entitlement'})).body.active,true);
});
test('RTDN ignores foreign package, malformed or unbound token', async () => {
  const f=fixture();
  await f.service.notification(null);
  await f.service.notification({packageName:'wrong',subscriptionNotification:{purchaseToken:a}});
  await f.service.notification({packageName,subscriptionNotification:{purchaseToken:a}});
  assert.equal(f.ack.length,0);
});
test('RTDN re-reads state; duplicate and out-of-order messages cannot grant', async () => {
  const f=fixture(); await f.request({action:'verify',token:a});
  f.purchases.set(a,purchase('EXPIRED'));
  const message={packageName,subscriptionNotification:{purchaseToken:a,notificationType:2}};
  await f.service.notification(message); await f.service.notification(message);
  assert.equal((await f.request({action:'entitlement'})).body.active,false);
});
test('RTDN transient error is thrown for Pub/Sub retry', async () => {
  const f=fixture(); await f.request({action:'verify',token:a});
  f.purchases.set(a,new Error('offline'));
  await assert.rejects(f.service.notification({packageName,subscriptionNotification:{purchaseToken:a}}));
});
test('linked token owned by another user rejects before acknowledgement', async () => {
  const f=fixture(); f.owners.set(b,'two'); f.purchases.get(a).linkedPurchaseToken=b;
  assert.equal((await f.request({action:'verify',token:a})).status,403);
  assert.equal(f.ack.length,0);
});
test('input limits and unknown actions fail without contacting store', async () => {
  const f=fixture();
  for (const token of ['',42,'x'.repeat(4097)]) {
    assert.equal((await f.request({action:'verify',token})).status,400);
  }
  assert.equal((await f.request({action:'delete'})).status,400);
  assert.equal((await f.request({action:'entitlement'})).body.active,false);
});
