import { timingSafeEqual } from 'node:crypto';

const HOSTS = Object.freeze({
  sandbox: 'https://api-sandbox.asaas.com/v3/',
  production: 'https://api.asaas.com/v3/',
});
export const asaasId = (value, prefix) => typeof value === 'string' &&
  new RegExp('^' + prefix + '_[A-Za-z0-9_-]{1,80}$').test(value);

// Read-only server client. No credentials, provider responses or card details
// are returned in errors. Redirects must not forward the API credential.
export function createAsaasProvider({ environment = 'sandbox', apiKey, webhookToken,
  fetchImpl = fetch, timeoutMs = 10_000 }) {
  if (!Object.hasOwn(HOSTS, environment) || typeof apiKey !== 'string' ||
      !apiKey || /\s/.test(apiKey) || typeof webhookToken !== 'string' ||
      webhookToken.length < 32 || webhookToken.length > 255 || /\s/.test(webhookToken) ||
      webhookToken === apiKey || webhookToken.startsWith('$aact_') ||
      !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 30_000) {
    throw new Error('asaas-configuration');
  }
  async function get(kind, id, prefix) {
    if (!asaasId(id, prefix)) throw new Error('asaas-resource-id');
    try {
      const response = await fetchImpl(HOSTS[environment] + kind + '/' + id, {
        method: 'GET', redirect: 'error', signal: AbortSignal.timeout(timeoutMs),
        headers: { access_token: apiKey, Accept: 'application/json',
          'User-Agent': 'RochaPlus-Asaas-Readiness/1.0' },
      });
      if (!response.ok) throw new Error('http');
      const value = await response.json();
      if (!value || typeof value !== 'object' || Array.isArray(value) || value.id !== id) {
        throw new Error('resource');
      }
      return value;
    } catch (_) { throw new Error('asaas-resource-unavailable'); }
  }
  return Object.freeze({
    environment,
    payment: id => get('payments', id, 'pay'),
    subscription: id => get('subscriptions', id, 'sub'),
    verifyWebhookToken(value) {
      if (typeof value !== 'string') throw new Error('asaas-webhook-auth');
      const received = Buffer.from(value), expected = Buffer.from(webhookToken);
      if (received.length !== expected.length || !timingSafeEqual(received, expected)) {
        throw new Error('asaas-webhook-auth');
      }
    },
  });
}
