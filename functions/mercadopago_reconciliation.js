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
    merchantId: String(payment.collector_id || ''),
    liveMode: payment.live_mode === true,
    statusDetail: String(payment.status_detail || ''),
    refundedAmount: typeof payment.transaction_amount_refunded === 'number'
      ? payment.transaction_amount_refunded : null,
  };
}

async function fetchVerifiedPayment(paymentId, accessToken) {
  if (!/^[0-9]+$/.test(String(paymentId))) throw new Error('invalid payment ID');
  if (!accessToken) throw new Error('missing Mercado Pago credential');
  const response = await fetch('https://api.mercadopago.com/v1/payments/' + paymentId, {
    redirect: 'error',
    headers: {Authorization: 'Bearer ' + accessToken, Accept: 'application/json'},
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) throw new Error('payment provider query failed: ' + response.status);
  const payment = normalizePayment(await response.json());
  if (payment.id !== String(paymentId)) throw new Error('payment identity mismatch');
  return payment;
}

function eligiblePayment(payment) {
  return payment.liveMode === true && payment.status === 'approved' &&
    payment.statusDetail === 'accredited' && payment.refundedAmount === 0 &&
    payment.currency === 'BRL' && Number.isFinite(payment.amount) &&
    payment.amount > 0 && !!payment.dateApproved;
}

/** Returns a verified payment snapshot only. DOES NOT grant access.
 * Historical links may lack trusted UID mapping, and must be reconciled
 * through a separately authenticated, auditable account-claim workflow.
 * Never add time or update paidUntil merely from an ID or webhook payload.
 */
async function inspectPayment(paymentId, accessToken) {
  const payment = await fetchVerifiedPayment(paymentId, accessToken);
  return {...payment, eligibleForReview: eligiblePayment(payment)};
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
    if (existing.exists && String(existing.data().paymentId) !== payment.id) {
      throw new Error('payment ledger document identity mismatch');
    }
    // A snapshot-only operation must never erase a privileged grant ledger.
    // A reviewed event carries plan and audit fields needed for recomputation.
    if (existing.exists && existing.data().reviewed === true) {
      return {uid, paymentId: payment.id, status: payment.status,
        eligibleForReview: eligiblePayment(payment), entitlementGranted: false,
        previouslyRecorded: true};
    }
    const eligible = eligiblePayment(payment);
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
  recordVerifiedPayment, eligiblePayment};
