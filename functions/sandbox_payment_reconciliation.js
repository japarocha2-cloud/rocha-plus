'use strict';

// Sandbox ONLY. Never call reconcileAndGrant or touch production entitlements.
// A sandbox payment is linked to a server-created, authenticated test checkout order.
const {fetchVerifiedPayment} = require('./mercadopago_reconciliation');
const {PLANS} = require('./checkout');
const {addUtcMonths} = require('./entitlement_periods');

const ORDER_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PAYMENT_ID = /^[0-9]{1,30}$/;

async function reconcileSandboxPayment({
  db, paymentId, accessToken, merchantId, testUid, fetchPayment = fetchVerifiedPayment,
}) {
  if (!PAYMENT_ID.test(String(paymentId)) || !/^\d+$/.test(String(merchantId || '')) ||
      !testUid || typeof testUid !== 'string' || testUid.includes('/') || !accessToken) {
    throw new Error('sandbox configuration or identity invalid');
  }
  // Provider data is authoritative, never the webhook payload or the client.
  const p = await fetchPayment(String(paymentId), accessToken);
  if (p.id !== String(paymentId) || p.liveMode !== false ||
      p.merchantId !== String(merchantId) || p.currency !== 'BRL' ||
      !ORDER_ID.test(p.externalReference || '')) {
    throw new Error('sandbox provider identity mismatch');
  }

  const orderRef = db.collection('sandbox_checkout_orders').doc(p.externalReference);
  const eventRef = db.collection('sandbox_payment_events').doc(p.id);
  const entitlementRef = db.collection('sandbox_entitlements').doc(testUid);
  return db.runTransaction(async tx => {
    // All reads precede writes. These are separate sandbox-only collections.
    const [orderSnap, eventSnap] = await Promise.all([tx.get(orderRef), tx.get(eventRef)]);
    const order = orderSnap.exists ? orderSnap.data() : null;
    if (!order || order.uid !== testUid || order.mode !== 'sandbox' ||
        order.merchantId !== String(merchantId) || order.currency !== 'BRL' ||
        !Object.hasOwn(PLANS, order.plan || '') ||
        order.amountCents !== PLANS[order.plan] ||
        !order.preferenceId || (order.paymentId && order.paymentId !== p.id)) {
      throw new Error('sandbox checkout order mismatch');
    }
    if (eventSnap.exists && eventSnap.data().uid !== testUid) {
      throw new Error('sandbox payment ownership conflict');
    }
    const valid = p.status === 'approved' && p.statusDetail === 'accredited' &&
      p.refundedAmount === 0 && Number.isFinite(p.amount) &&
      Math.round(p.amount * 100) === order.amountCents &&
      Math.abs(p.amount * 100 - order.amountCents) < 1e-6 &&
      typeof p.dateApproved === 'string' &&
      Number.isFinite(Date.parse(p.dateApproved)) &&
      /Z$|[+-]\d\d:\d\d$/.test(p.dateApproved) &&
      Date.parse(p.dateApproved) <= Date.now() + 300000;
    // Rejected/refunded events must not create test access.
    const end = valid ? addUtcMonths(p.dateApproved, order.plan === 'monthly' ? 1 : 12).toISOString() : null;
    const previous = eventSnap.exists ? eventSnap.data() : null;
    if (previous && previous.orderId !== p.externalReference) {
      throw new Error('sandbox payment order conflict');
    }
    tx.set(eventRef, {uid: testUid, paymentId: p.id, orderId: p.externalReference,
      status: p.status, plan: order.plan, approved: valid, sandbox: true,
      testedAt: new Date().toISOString()});
    tx.set(entitlementRef, {uid: testUid, sandbox: true, lastPaymentId: p.id,
      approved: valid, testPaidUntil: end, checkedAt: new Date().toISOString()}, {merge: true});
    // This is NEVER a production entitlement, and cannot unlock the real app.
    return {sandbox: true, approved: valid, testPaidUntil: end, paymentId: p.id};
  });
}

module.exports = {reconcileSandboxPayment};
