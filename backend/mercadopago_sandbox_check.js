'use strict';

// Read-only credential check. Never log provider bodies, headers, tokens or user data.
async function checkSandboxCredentials({ token, expectedSellerId, request = fetch }) {
  const cleanToken = typeof token === 'string' ? token.trim() : '';
  if (!cleanToken) return { ok: false, code: 'missing-test-secret' };
  if (/\s/.test(cleanToken) || !/^\d{1,30}$/.test(expectedSellerId ?? '')) {
    return { ok: false, code: 'invalid-test-configuration' };
  }
  let response;
  try {
    response = await request('https://api.mercadopago.com/users/me', {
      method: 'GET', redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { Authorization: `Bearer ${cleanToken}`, Accept: 'application/json' },
    });
  } catch (_) { return { ok: false, code: 'provider-unreachable' }; }
  if (response.status === 401 || response.status === 403) return { ok: false, code: 'credentials-rejected' };
  if (response.status !== 200) return { ok: false, code: 'provider-unavailable' };
  let account;
  try { account = await response.json(); }
  catch (_) { return { ok: false, code: 'invalid-provider-response' }; }
  if (!account || String(account.id) !== expectedSellerId || account.site_id !== 'MLB') {
    return { ok: false, code: 'test-seller-mismatch' };
  }
  // The exact test seller ID is copied from this application's sandbox screen.
  // A production credential or a different account must never pass this check.
  return { ok: true, code: 'test-seller-authenticated', readOnly: true };
}

module.exports = { checkSandboxCredentials };
if (require.main === module) {
  checkSandboxCredentials({ token: process.env.MP_TEST_ACCESS_TOKEN,
    expectedSellerId: process.env.MP_EXPECTED_TEST_SELLER_ID })
    .then(result => { console.log(JSON.stringify(result)); if (!result.ok) process.exitCode = 1; })
    .catch(() => { console.log(JSON.stringify({ ok: false, code: 'check-unavailable' })); process.exitCode = 1; });
}
