'use strict';
const { checkSandboxCredentials } = require('./mercadopago_sandbox_check');

// Read-only evidence for a sandbox payment. Never grants access in Firebase.
async function verifySandboxReceipt({ token, sellerId, buyerId, paymentId, request = fetch }) {
  const failure = { ok: false, code: 'sandbox-payment-not-confirmed', readOnly: true };
  if (![sellerId, buyerId, paymentId].every(id => typeof id === 'string' && /^\d{1,30}$/.test(id))) return failure;
  const auth = await checkSandboxCredentials({ token, expectedSellerId: sellerId, request });
  if (!auth.ok) return auth;
  try {
    const response = await request('https://api.mercadopago.com/v1/payments/' + paymentId, {
      method: 'GET', redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { Authorization: `Bearer ${token.trim()}`, Accept: 'application/json' },
    });
    if (response.status !== 200) return { ...failure, code: 'sandbox-payment-api-unavailable',
      httpStatus: Number.isInteger(response.status) ? response.status : null };
    const p = await response.json();
    const checks = { paymentMatches: String(p?.id) === paymentId,
      sellerMatches: String(p?.collector_id) === sellerId, buyerMatches: String(p?.payer?.id) === buyerId,
      sandboxMode: p?.live_mode === false, approved: p?.status === 'approved',
      currencyMatches: p?.currency_id === 'BRL', amountMatches: Number(p?.transaction_amount) === 4.9,
      unrefunded: Number(p?.transaction_amount_refunded) === 0,
      approvalDateValid: !!p?.date_approved && Number.isFinite(Date.parse(p.date_approved)) };
    if (!Object.values(checks).every(Boolean)) return { ...failure, checks };
    return { ok: true, code: 'sandbox-payment-approved', readOnly: true,
      paymentId, amount: 4.9, currency: 'BRL', liveMode: false, appAccessGranted: false };
  } catch (_) { return failure; }
}
module.exports = { verifySandboxReceipt };
if (require.main === module) {
  verifySandboxReceipt({ token: process.env.MP_TEST_ACCESS_TOKEN,
    sellerId: process.env.MP_EXPECTED_TEST_SELLER_ID,
    buyerId: process.env.MP_EXPECTED_TEST_BUYER_ID,
    paymentId: process.env.MP_TEST_PAYMENT_ID })
    .then(result => { console.log(JSON.stringify(result)); if (!result.ok) process.exitCode = 1; })
    .catch(() => { console.log(JSON.stringify({ ok: false, code: 'sandbox-payment-not-confirmed' })); process.exitCode = 1; });
}
