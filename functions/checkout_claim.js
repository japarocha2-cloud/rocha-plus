'use strict';
const {fetchVerifiedPayment} = require('./mercadopago_reconciliation');
const {PLANS} = require('./checkout');
// Keep previously created checkout orders valid at their original server-set amount.
const LEGACY_PLANS = Object.freeze({monthly: 450, annual: 4950});
function validOrderAmount(plan, cents) {
  return Number.isInteger(cents) &&
    (cents === PLANS[plan] || cents === LEGACY_PLANS[plan]);
}
// Called only behind signed webhook verification. Never infer account from email.
async function bindCheckoutClaim({db, paymentId, accessToken}) {
  const p = await fetchVerifiedPayment(paymentId, accessToken);
  if (!/^[a-f0-9-]{36}$/.test(p.externalReference)) return;
  const orderRef = db.collection('checkout_orders').doc(p.externalReference);
  const claimRef = db.collection('payment_claims').doc(p.id);
  await db.runTransaction(async tx => {
    const [orderSnap, claimSnap] = await Promise.all([tx.get(orderRef), tx.get(claimRef)]);
    if (claimSnap.exists) return; // preserve existing reviewed and historical claims
    const o = orderSnap.data();
    if (!orderSnap.exists || !o?.preferenceId || !o.uid || o.uid.includes('/') ||
        !Object.hasOwn(PLANS, o.plan || '') || !validOrderAmount(o.plan, o.amountCents) ||
        o.mode !== 'one_time' || o.currency !== 'BRL' || p.currency !== 'BRL' ||
        o.merchantId !== p.merchantId || p.liveMode !== true ||
        !Number.isFinite(p.amount) || Math.abs(p.amount * 100 - o.amountCents) > 1e-6 ||
        (o.paymentId && o.paymentId !== p.id)) throw Error('checkout order mismatch');
    const entitlementRef = db.collection('entitlements').doc(o.uid);
    const entitlement = await tx.get(entitlementRef);
    // Initialize a missing trial once; never reset an existing trial or paid license.
    if (!entitlement.exists) {
      const now = new Date();
      tx.create(entitlementRef, {trialStartedAt: now,
        trialUntil: new Date(now.getTime() + 7 * 86400000), createdAt: now});
    }
    tx.create(claimRef, {uid: o.uid, plan: o.plan, amountCents: o.amountCents,
      currency: 'BRL', merchantId: o.merchantId, reviewed: true,
      reviewSource: 'authenticated_checkout_order', orderId: p.externalReference});
    tx.update(orderRef, {paymentId: p.id});
  });
}
module.exports = {bindCheckoutClaim};

