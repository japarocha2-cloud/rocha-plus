'use strict';
const { checkSandboxCredentials } = require('./mercadopago_sandbox_check');
const REASON = 'Rocha Plus - TESTE SANDBOX mensal';
const BACK_URL = 'https://github.com/japarocha2-cloud/rocha-plus';
const planIdValid = id => typeof id === 'string' && /^[a-zA-Z0-9_-]{8,100}$/.test(id);
function checkedPlan(plan, sellerId) {
  const cycle = plan?.auto_recurring;
  if (!planIdValid(plan?.id) || String(plan.collector_id) !== sellerId || plan.status !== 'active' ||
      plan.reason !== REASON || plan.back_url !== BACK_URL || cycle?.frequency !== 1 ||
      cycle.frequency_type !== 'months' || Number(cycle.transaction_amount) !== 4.9 ||
      cycle.currency_id !== 'BRL' || cycle.free_trial != null) throw Error('sandbox-plan-mismatch');
  const url = new URL(plan.init_point);
  if (url.protocol !== 'https:' || url.hostname !== 'www.mercadopago.com.br' || url.username ||
      url.password || url.port || url.pathname !== '/subscriptions/checkout' ||
      url.searchParams.get('preapproval_plan_id') !== plan.id) throw Error('sandbox-checkout-url');
  return { ok: true, code: 'sandbox-checkout-ready', planId: plan.id, checkoutUrl: url.href };
}

async function prepareSandboxCheckout({ token, expectedSellerId, request = fetch }) {
  const authenticated = await checkSandboxCredentials({ token, expectedSellerId, request });
  if (!authenticated.ok) return authenticated;
  const headers = { Authorization: `Bearer ${token.trim()}`, Accept: 'application/json',
    'Content-Type': 'application/json' };
  async function api(path, options = {}) {
    const response = await request('https://api.mercadopago.com' + path,
      { method: 'GET', ...options, headers, redirect: 'error', signal: AbortSignal.timeout(15000) });
    if (![200, 201].includes(response.status)) throw Error('sandbox-api-unavailable');
    return response.json();
  }
  try {
    let candidate;
    for (let offset = 0; offset < 200; offset += 50) {
      const page = await api('/preapproval_plan/search?limit=50&offset=' + offset);
      if (!Array.isArray(page.results) || !Number.isSafeInteger(page.paging?.total) ||
          page.paging.total < 0) throw Error('sandbox-plan-search');
      const found = page.results.filter(p => p.reason === REASON && String(p.collector_id) === expectedSellerId);
      if (found.length > 1 || (candidate && found.length)) throw Error('sandbox-plan-ambiguous');
      if (found.length) candidate = found[0];
      if (offset + 50 >= page.paging.total) break;
      if (offset === 150) throw Error('sandbox-plan-search-limit');
    }
    if (candidate) {
      if (!planIdValid(candidate.id)) throw Error('sandbox-plan-id');
      return checkedPlan(await api('/preapproval_plan/' + candidate.id), expectedSellerId);
    }
    // This endpoint creates only a plan template on the exact sandbox seller.
    // It never submits a card, creates a subscription or initiates a charge.
    const created = await api('/preapproval_plan', { method: 'POST', body: JSON.stringify({
      reason: REASON, auto_recurring: { frequency: 1, frequency_type: 'months',
        transaction_amount: 4.9, currency_id: 'BRL' }, back_url: BACK_URL,
    }) });
    return checkedPlan(created, expectedSellerId);
  } catch (_) { return { ok: false, code: 'sandbox-checkout-not-confirmed' }; }
}
module.exports = { prepareSandboxCheckout, REASON, BACK_URL };
if (require.main === module) {
  prepareSandboxCheckout({ token: process.env.MP_TEST_ACCESS_TOKEN,
    expectedSellerId: process.env.MP_EXPECTED_TEST_SELLER_ID })
    .then(result => { console.log(JSON.stringify(result)); if (!result.ok) process.exitCode = 1; })
    .catch(() => { console.log(JSON.stringify({ ok: false, code: 'sandbox-checkout-not-confirmed' })); process.exitCode = 1; });
}
