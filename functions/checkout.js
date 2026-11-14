'use strict';
const {randomUUID} = require('node:crypto');
const {googleSubjectOf} = require('./trial_anchor');
const PLANS = Object.freeze({monthly: 790, annual: 8690});
function officialUrl(raw) {
  const u = new URL(raw);
  if (u.protocol !== 'https:' || u.hostname !== 'www.mercadopago.com.br' ||
      u.username || u.password || u.port || u.hash ||
      u.pathname !== '/checkout/v1/redirect' || !u.searchParams.get('pref_id')) {
    throw new Error('invalid provider checkout URL');
  }
  return u.href;
}
function createCheckoutHandler({verifyToken, createOrder, savePreference, token, config, request = fetch}) {
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (req.method !== 'POST') return res.status(405).json({error: 'method'});
    let user;
    try {
      const header = req.get('authorization') || '';
      if (!header.startsWith('Bearer ')) throw Error();
      user = await verifyToken(header.slice(7));
      if (!user?.uid || user.uid.includes('/')) throw Error();
    } catch (_) { return res.status(401).json({error: 'authentication'}); }
    const plan = req.body?.plan;
    if (!Object.hasOwn(PLANS, plan || '')) return res.status(400).json({error: 'plan'});
    const c = config();
    // This gate is set only after private financial/merchant review. Default off.
    if (c.enabled !== true || !/^[0-9]+$/.test(c.merchantId || '') ||
        c.mode !== 'one_time' || !token()) {
      return res.status(503).json({error: 'checkout_unavailable'});
    }
    try {
      const notification = new URL(c.notificationUrl);
      if (notification.protocol !== 'https:' || notification.username || notification.password ||
          notification.hash) throw Error('notification URL');
      const headers = {Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json'};
      const merchant = await request('https://api.mercadopago.com/users/me',
        {headers, redirect: 'error', signal: AbortSignal.timeout(12000)});
      if (!merchant.ok || String((await merchant.json()).id) !== c.merchantId)
        throw Error('merchant identity');
      const orderId = randomUUID();
      // Identity, amount and purchase reference are server-owned, before provider call.
      // googleSubject lets a later claim anchor the trial like /entitlement does.
      await createOrder(orderId, {uid: user.uid, googleSubject: googleSubjectOf(user),
        plan, amountCents: PLANS[plan],
        merchantId: c.merchantId, currency: 'BRL', mode: 'one_time',
        createdAt: new Date().toISOString(), preferenceId: null});
      const response = await request('https://api.mercadopago.com/checkout/preferences', {
        method: 'POST', redirect: 'error', headers: {...headers, 'X-Idempotency-Key': orderId},
        signal: AbortSignal.timeout(12000),
        body: JSON.stringify({external_reference: orderId, notification_url: notification.href,
          items: [{id: plan, title: 'Rocha+ ' + (plan === 'monthly' ? 'Mensal' : 'Anual'),
            quantity: 1, currency_id: 'BRL', unit_price: PLANS[plan] / 100}]}),
      });
      if (!response.ok) throw Error('provider');
      const pref = await response.json();
      if (String(pref.collector_id) !== c.merchantId || typeof pref.id !== 'string' ||
          !pref.id || pref.external_reference !== orderId) throw Error('preference identity');
      const url = officialUrl(pref.init_point);
      if (new URL(url).searchParams.get('pref_id') !== pref.id) throw Error('preference URL');
      await savePreference(orderId, pref.id);
      return res.status(200).json({url, orderId, plan, amountCents: PLANS[plan], mode: 'one_time'});
    } catch (_) { return res.status(503).json({error: 'checkout_unavailable'}); }
  };
}
module.exports = {PLANS, officialUrl, createCheckoutHandler};

