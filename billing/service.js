import { randomUUID } from 'node:crypto';
import { access, checkedPayment, PLANS } from './policy.js';
const orderIdValid = id => typeof id === 'string' && /^[0-9a-f-]{36}$/.test(id);
export const paymentIdValid = id => typeof id === 'string' && /^\d{1,30}$/.test(id);
export function createService({ store, verifyIdentity, provider, verifySignature,
  collectorId, liveMode = false, paymentsEnabled = false, now = Date.now, newId = randomUUID }) {
  async function handle({ method, authorization, body }) {
    if (method !== 'POST') return { status: 405, body: { error: 'method' } };
    const token = /^Bearer (\S+)$/.exec(authorization ?? '')?.[1];
    if (!token) return { status: 401, body: { error: 'auth' } };
    let identity;
    try { identity = await verifyIdentity(token, true); }
    catch (_) { return { status: 401, body: { error: 'auth' } }; }
    if (!identity?.uid) return { status: 401, body: { error: 'auth' } };
    if (!['status', 'checkout'].includes(body?.action)) return { status: 400, body: { error: 'action' } };
    if (body.action === 'checkout' && !Object.hasOwn(PLANS, body.plan)) return { status: 400, body: { error: 'plan' } };
    try {
      const time = now();
      const user = await store.user(identity.uid, time,
        identity.email_verified === true ? identity.email : null);
      if (body.action === 'status') return { status: 200, body: access(user, time) };
      if (!paymentsEnabled) return { status: 503, body: { error: 'payments-not-configured' } };
      const order = { id: newId(), uid: identity.uid, plan: body.plan, createdAt: time };
      await store.reserve(order, time);
      const checkoutUrl = await provider.checkout(order, PLANS[order.plan]);
      const uri = new URL(checkoutUrl);
      if (uri.protocol !== 'https:' || uri.username || uri.password ||
          !['www.mercadopago.com.br', 'mercadopago.com.br'].includes(uri.hostname)) {
        throw new Error('checkout-url');
      }
      return { status: 200, body: { checkoutUrl, automaticRenewal: false } };
    } catch (_) { return { status: 503, body: { error: 'billing-unavailable' } }; }
  }
  async function webhook({ method, dataId, body, signature, requestId }) {
    if (method !== 'POST') return { status: 405, body: { error: 'method' } };
    if (!paymentIdValid(dataId) || body?.type !== 'payment' || String(body.data?.id) !== dataId) {
      return { status: 400, body: { error: 'notification' } };
    }
    try { verifySignature({ dataId, signature, requestId }); }
    catch (_) { return { status: 401, body: { error: 'signature' } }; }
    try {
      // The callback body never grants access. Fetch authoritative provider state.
      const payment = await provider.payment(dataId);
      if (String(payment.id) !== dataId) throw new Error('payment-id');
      const id = payment.external_reference;
      if (!orderIdValid(id)) return { status: 200, body: { received: true } };
      const order = await store.order(id);
      if (!order) return { status: 200, body: { received: true } };
      const time = now();
      const checked = checkedPayment(payment, order, { collectorId, liveMode, now: time });
      await store.apply(order, dataId, checked, time);
      return { status: 200, body: { received: true } };
    } catch (_) {
      // Do not acknowledge failed provider/storage reads: Mercado Pago retries.
      return { status: 503, body: { error: 'notification-unavailable' } };
    }
  }
  return { handle, webhook };
}
