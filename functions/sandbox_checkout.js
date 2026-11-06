'use strict';

// Isolated Mercado Pago sandbox checkout. Never creates production checkout_orders.
// Requires a server-configured, explicitly allowlisted Firebase test UID.
const {randomUUID} = require('node:crypto');
const {PLANS} = require('./checkout');
const {reconcileSandboxPayment} = require('./sandbox_payment_reconciliation');

function validatedSandboxUrl(raw, preferenceId) {
  const url = new URL(raw);
  // Mercado Pago's published sandbox_init_point uses sandbox.mercadopago.com
  // and /mla/checkout/pay; Brazilian integrations may use /mlb.
  if (url.protocol !== 'https:' ||
      !['sandbox.mercadopago.com', 'sandbox.mercadopago.com.br'].includes(url.hostname) ||
      !/^\/[a-z]{3}\/checkout\/pay$/.test(url.pathname) ||
      url.username || url.password || url.port || url.hash ||
      url.searchParams.getAll('pref_id').length !== 1 ||
      url.searchParams.get('pref_id') !== String(preferenceId)) {
    throw new Error('invalid Mercado Pago sandbox URL');
  }
  return url.href;
}

function createSandboxCheckoutHandler({verifyToken, db, config, request = fetch}) {
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (req.method !== 'POST') return res.status(405).json({error: 'method'});
    const c = config();
    if (c.enabled !== true || !c.accessToken || !/^\d+$/.test(c.merchantId || '') ||
        !c.testUid || c.testUid.includes('/') || !c.notificationUrl) {
      return res.status(503).json({error: 'sandbox_unavailable'});
    }
    let user;
    try {
      const header = req.get('authorization') || '';
      if (!header.startsWith('Bearer ')) throw Error();
      user = await verifyToken(header.slice(7));
    } catch (_) { return res.status(401).json({error: 'authentication'}); }
    if (user?.uid !== c.testUid) return res.status(403).json({error: 'test_account_only'});
    const plan = req.body?.plan;
    if (!Object.hasOwn(PLANS, plan || '')) return res.status(400).json({error: 'plan'});
    try {
      const callback = new URL(c.notificationUrl);
      if (callback.protocol !== 'https:' || callback.username || callback.password ||
          callback.hash) throw Error('notification URL');
      const headers = {Authorization: 'Bearer ' + c.accessToken,
        'Content-Type': 'application/json'};
      const identity = await request('https://api.mercadopago.com/users/me', {
        headers, redirect: 'error', signal: AbortSignal.timeout(12000),
      });
      if (!identity.ok || String((await identity.json()).id) !== c.merchantId)
        throw Error('sandbox merchant identity');
      const orderId = randomUUID();
      const orderRef = db.collection('sandbox_checkout_orders').doc(orderId);
      await orderRef.create({uid: c.testUid, plan, amountCents: PLANS[plan],
        merchantId: c.merchantId, currency: 'BRL', mode: 'sandbox',
        createdAt: new Date().toISOString(), preferenceId: null});
      const preferenceResponse = await request('https://api.mercadopago.com/checkout/preferences', {
        method: 'POST', redirect: 'error', headers: {...headers, 'X-Idempotency-Key': orderId},
        signal: AbortSignal.timeout(12000),
        body: JSON.stringify({external_reference: orderId, notification_url: callback.href,
          items: [{id: plan, title: 'Rocha+ TESTE ' + plan, quantity: 1,
            currency_id: 'BRL', unit_price: PLANS[plan] / 100}]}),
      });
      if (!preferenceResponse.ok) throw Error('sandbox preference failed');
      const pref = await preferenceResponse.json();
      // Never fall back to a production checkout link.
      if (String(pref.collector_id) !== c.merchantId || !pref.id ||
          pref.external_reference !== orderId || !pref.sandbox_init_point) {
        throw Error('sandbox preference identity');
      }
      const url = validatedSandboxUrl(pref.sandbox_init_point, pref.id);
      await orderRef.update({preferenceId: pref.id});
      return res.status(200).json({url, orderId, sandbox: true, plan,
        amountCents: PLANS[plan]});
    } catch (_) {
      return res.status(503).json({error: 'sandbox_unavailable'});
    }
  };
}

function createSandboxVerifyHandler({verifyToken, db, config}) {
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (req.method !== 'POST') return res.status(405).json({error: 'method'});
    let uid;
    try {
      const header = req.get('authorization') || '';
      if (!header.startsWith('Bearer ')) throw Error();
      uid = (await verifyToken(header.slice(7)))?.uid;
    } catch (_) { return res.status(401).json({error: 'authentication'}); }
    const c = config();
    if (c.enabled !== true || !c.accessToken || !/^\d+$/.test(c.merchantId || '') ||
        !c.testUid) return res.status(503).json({error: 'sandbox_unavailable'});
    if (uid !== c.testUid) return res.status(403).json({error: 'test_account_only'});
    const paymentId = req.body?.paymentId;
    if (!/^\d{1,30}$/.test(String(paymentId || '')))
      return res.status(400).json({error: 'payment_id'});
    try {
      const result = await reconcileSandboxPayment({db, paymentId: String(paymentId),
        accessToken: c.accessToken, merchantId: c.merchantId, testUid: uid});
      return res.status(200).json(result);
    } catch (_) { return res.status(422).json({error: 'sandbox_payment_not_verified'}); }
  };
}

module.exports = {createSandboxCheckoutHandler, createSandboxVerifyHandler, validatedSandboxUrl};
