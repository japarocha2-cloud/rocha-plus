'use strict';

// Privileged back-office operation only. NEVER expose as an unauthenticated HTTP
// endpoint. Claims must already have been approved by a verified administrator.
const {fetchVerifiedPayment, eligiblePayment} = require('./mercadopago_reconciliation');
const {entitlementFromLedger} = require('./entitlement_periods');

async function reconcileAndGrant({db, admin, paymentId, accessToken}) {
  const payment = await fetchVerifiedPayment(paymentId, accessToken);
  const claimRef = db.collection('payment_claims').doc(payment.id);
  return db.runTransaction(async tx => {
    const claimSnap = await tx.get(claimRef);
    const claim = claimSnap.data();
    if (!claimSnap.exists || claim?.reviewed !== true ||
        !claim?.uid || typeof claim.uid !== 'string' ||
        claim.uid.includes('/') || !['monthly','annual'].includes(claim.plan)) {
      throw new Error('independently reviewed UID and plan required');
    }
    // Verify the expected amount from the independently approved claim. Never
    // derive plan from a client-provided amount or a mutable payment link.
    if (claim.currency !== 'BRL' ||
        !Number.isSafeInteger(claim.amountCents) ||
        claim.amountCents <= 0 ||
        !/^\d+$/.test(claim.merchantId || '') ||
        payment.merchantId !== claim.merchantId ||
        payment.liveMode !== true ||
        !Number.isFinite(payment.amount) ||
        Math.abs(payment.amount * 100 - Math.round(payment.amount * 100)) > 1e-6 ||
        Math.round(payment.amount * 100) !== claim.amountCents ||
        payment.currency !== 'BRL') throw new Error('payment does not match reviewed claim');

    const eventRef = db.collection('payment_events').doc(payment.id);
    const entitlementRef = db.collection('entitlements').doc(claim.uid);
    const q = db.collection('payment_events').where('uid', '==', claim.uid);
    // All reads precede every write in Firestore transactions.
    const [existing, entitlement, ledger] = await Promise.all([
      tx.get(eventRef), tx.get(entitlementRef), tx.get(q),
    ]);
    if (existing.exists && existing.data().uid !== claim.uid) {
      throw new Error('payment ownership conflict');
    }
    if (!entitlement.exists) throw new Error('account trial must be initialized first');
    const approved = eligiblePayment(payment);
    const updated = {
      uid: claim.uid, provider: 'mercadopago', paymentId: payment.id,
      status: payment.status, eligibleForReview: approved,
      reviewed: true, plan: claim.plan, amount: payment.amount,
      currency: payment.currency, approvalDate: payment.dateApproved,
      merchantId: payment.merchantId, liveMode: payment.liveMode,
      refundedAmount: payment.refundedAmount,
      checkedAt: admin.firestore.Timestamp.now(),
    };
    // A ledger document must match its provider payment identity. Reject
    // inconsistent records instead of silently granting another period.
    const otherRecords = ledger.docs.filter(doc => doc.id !== payment.id)
      .map(doc => {
        const row = doc.data();
        if (String(row.paymentId) !== doc.id) {
          throw new Error('payment ledger document identity mismatch');
        }
        return row;
      });
    const expiration = entitlementFromLedger(claim.uid, [...otherRecords, updated]);
    tx.set(eventRef, updated);
    // Recompute from source of truth. Never extend paidUntil by adding a period
    // to its previous value. A refund on a known payment is reversible.
    tx.set(entitlementRef, {
      paidUntil: expiration ? admin.firestore.Timestamp.fromDate(new Date(expiration)) : null,
      reconciledAt: admin.firestore.Timestamp.now(),
    }, {merge: true});
    return {uid: claim.uid, paymentId: payment.id,
      paidUntil: expiration, previouslyRecorded: existing.exists};
  });
}
module.exports = {reconcileAndGrant};
