import { asaasId } from './asaas_provider.js';
import { checkedAsaasPayment } from './asaas_policy.js';

// Sandbox only and disabled by default. This is not exported as a deployed
// Cloud Function. Store records are isolated from all existing app entitlements.
export function createAsaasReconciliation({ provider, store, enabled = false, now = Date.now }) {
  const configured = () => enabled === true && provider?.environment === 'sandbox' &&
    store?.environment === 'sandbox';
  async function reconcilePayment(paymentId, eventId) {
    const binding = await store.binding(paymentId);
    if (!binding) return { ignored: 'unbound-payment' };
    const payment = await provider.payment(paymentId);
    const subscription = await provider.subscription(binding.subscriptionId);
    const time = now();
    const decision = checkedAsaasPayment({ payment, subscription, binding, now: time });
    return store.record({ eventId, decision, now: time });
  }
  return {
    async webhook({ method, token, body }) {
      if (method !== 'POST') return { status: 405, body: { error: 'method' } };
      if (!configured()) return { status: 503, body: { error: 'asaas-not-enabled' } };
      try { provider.verifyWebhookToken(token); }
      catch (_) { return { status: 401, body: { error: 'auth' } }; }
      if (!body || typeof body.id !== 'string' ||
          !/^evt_[A-Za-z0-9_&-]{1,240}$/.test(body.id) ||
          typeof body.event !== 'string') return { status: 400, body: { error: 'event' } };
      if (!body.event.startsWith('PAYMENT_')) {
        return { status: 200, body: { received: true, ignored: 'not-payment' } };
      }
      if (!asaasId(body.payment?.id, 'pay')) return { status: 400, body: { error: 'payment-id' } };
      try {
        // Payload status/value/customer are untrusted hints. Always re-fetch.
        await reconcilePayment(body.payment.id, body.id);
        return { status: 200, body: { received: true } };
      } catch (_) { return { status: 503, body: { error: 'asaas-reconciliation-unavailable' } }; }
    },
    // Internal server runner only; never expose this method to an HTTP body.
    async reconcilePayment(paymentId, eventId) {
      if (!configured() || !asaasId(paymentId, 'pay') || typeof eventId !== 'string' ||
          !/^evt_[A-Za-z0-9_&-]{1,240}$/.test(eventId)) throw new Error('asaas-not-enabled');
      return reconcilePayment(paymentId, eventId);
    },
  };
}
