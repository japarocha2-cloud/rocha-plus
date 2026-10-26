'use strict';

// Deliberately server-only: no mobile-provided payment status is authoritative.
// A verified Mercado Pago API response must match an existing, independently
// verified UID/payment association before any grant.

function normalizePayment(payment) {
  if (!payment || !/^[0-9]+$/.test(String(payment.id))) throw new Error('invalid payment ID');
  return {
    id: String(payment.id),
    status: String(payment.status || ''),
    externalReference: String(payment.external_reference || ''),
    dateApproved: payment.date_approved || null,
    amount: Number(payment.transaction_amount),
    currency: String(payment.currency_id || ''),
  };
}

async function fetchVerifiedPayment(paymentId, accessToken) {
  if (!/^[0-9]+$/.test(String(paymentId))) throw new Error('invalid payment ID');
  if (!accessToken) throw new Error('missing Mercado Pago credential');
  const response = await fetch('https://api.mercadopago.com/v1/payments/' + paymentId, {
    headers: {Authorization: 'Bearer ' + accessToken, Accept: 'application/json'},
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) throw new Error('payment provider query failed: ' + response.status);
  return normalizePayment(await response.json());
}

/** Returns a verified payment snapshot only. DOES NOT grant access.
 * Historical links may lack trusted UID mapping, and must be reconciled
 * through a separately authenticated, auditable account-claim workflow.
 * Never add time or update paidUntil merely from an ID or webhook payload.
 */
async function inspectPayment(paymentId, accessToken) {
  const payment = await fetchVerifiedPayment(paymentId, accessToken);
  return {...payment, eligibleForReview: payment.status === 'approved' &&
    payment.currency === 'BRL' && Number.isFinite(payment.amount) &&
    payment.amount > 0};
}

/**
 * Record an independently verified payment without granting access. A pre-existing
 * admin-reviewed claim must bind this payment ID to one Firebase UID. The claim
 * must be created through an authenticated back-office process, never by clients.
 * Repeated delivery is idempotent. A conflicting claim fails closed.
 */
async function recordVerifiedPayment({db, paymentId, accessToken}) {
  const payment = await fetchVerifiedPayment(paymentId, accessToken);
  const ref = db.collection('payment_claims').doc(payment.id);
  const eventRef = db.collection('payment_events').doc(payment.id);
  return db.runTransaction(async tx => {
    const [claim, existing] = await Promise.all([tx.get(ref), tx.get(eventRef)]);
    if (!claim.exists || claim.data().reviewed !== true ||
        typeof claim.data().uid !== 'string' || !claim.data().uid ||
        claim.data().uid.includes('/')) throw new Error('unverified account association');
    const uid = claim.data().uid;
    if (existing.exists && existing.data().uid !== uid) {
      throw new Error('payment already associated with another account');
    }
    const eligible = payment.status === 'approved' &&
      payment.currency === 'BRL' && Number.isFinite(payment.amount) &&
      payment.amount > 0 && !!payment.dateApproved;
    const record = {
      uid, provider: 'mercadopago', paymentId: payment.id,
      status: payment.status, eligibleForReview: eligible,
      amount: payment.amount, currency: payment.currency,
      approvalDate: payment.dateApproved,
      checkedAt: new Date().toISOString(),
    };
    // The stored record is a ledger, NOT a subscription grant.
    tx.set(eventRef, record);
    return {uid, paymentId: payment.id, status: payment.status,
      eligibleForReview: eligible, entitlementGranted: false,
      previouslyRecorded: existing.exists};
  });
}

module.exports = {normalizePayment, fetchVerifiedPayment, inspectPayment,
  recordVerifiedPayment};
