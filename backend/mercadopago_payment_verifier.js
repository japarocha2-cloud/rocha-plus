'use strict';

// Server-only verification. Never import this file into the Flutter application.
// The caller must obtain payment data from Mercado Pago's authenticated
// GET /v1/payments/{id}, not from webhook bodies or client-supplied JSON.
const PLANS = Object.freeze({
  monthly: { amount: 4.90, currency: 'BRL' },
  annual: { amount: 55.00, currency: 'BRL' },
});
function verifyMercadoPagoPayment(payment, { accountId, plan, collectorId, expectedReference, referenceAccountId }) {
  const expected = PLANS[plan];
  if (!expected || !/^[0-9]{1,128}$/.test(String(accountId ?? ''))) return false;
  if (!payment || typeof payment !== 'object') return false;
  if (!/^[1-9][0-9]*$/.test(String(payment.id ?? '')) ||
      !Number.isSafeInteger(Number(payment.id))) return false;
  if (payment.status !== 'approved' || payment.status_detail !== 'accredited') return false;
  if (payment.currency_id !== expected.currency) return false;
  if (typeof payment.transaction_amount !== 'number' ||
      Math.round(payment.transaction_amount * 100) !== Math.round(expected.amount * 100)) return false;
  if (!collectorId || String(payment.collector_id) !== String(collectorId)) return false;
  // Per-user checkout must bind a unique, server-generated external_reference.
  // The static mpago.la links do not satisfy this requirement.
  if (!referenceAccountId || String(referenceAccountId) !== String(accountId)) return false;
  if (!expectedReference || payment.external_reference !== expectedReference) return false;
  // The opaque reference must be matched to an authenticated, server-stored
  // checkout correlation for accountId. Never infer ownership from substrings.
  if (!payment.date_approved || Number.isNaN(Date.parse(payment.date_approved))) return false;
  if (payment.refunded_amount != null && Number(payment.refunded_amount) > 0) return false;
  return true;
}
module.exports = { verifyMercadoPagoPayment, PLANS };
