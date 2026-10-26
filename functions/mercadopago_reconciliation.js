'use strict';

// Deliberately server-only: no mobile-provided payment status is authoritative.
// A verified Mercado Pago API response must match an existing, independently
// verified UID/payment association before any grant.
const admin = require('firebase-admin');

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

module.exports = {normalizePayment, fetchVerifiedPayment, inspectPayment};
