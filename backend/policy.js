import { createHash } from 'node:crypto';
export const productId = 'rocha_plus_monthly';
export const accountId = uid => createHash('sha256').update('rocha-plus:' + uid).digest('hex');
export function entitlement(purchase, now = Date.now()) {
  const item = purchase.lineItems?.find(x => x.productId === productId &&
    x.offerDetails?.basePlanId === 'monthly');
  if (!item) throw new Error('invalid-product');
  const expiresAt = Date.parse(item.expiryTime);
  const state = purchase.subscriptionState;
  const active = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED'].includes(state) && Number.isFinite(expiresAt) && expiresAt > now;
  return { active, state, expiresAt: Number.isFinite(expiresAt) ? expiresAt : null,
    autoRenewing: item.autoRenewingPlan?.autoRenewEnabled === true,
    testPurchase: !!purchase.testPurchase };
}
export function assertOwner(purchase, uid) {
  if (purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId !== accountId(uid))
    throw new Error('account-mismatch');
}
