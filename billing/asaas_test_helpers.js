import { createHash, randomBytes } from 'node:crypto';
import { memoryDb } from './test_helpers.js';
import { createAsaasProvider } from './asaas_provider.js';
import { createAsaasSandboxStore } from './asaas_sandbox_store.js';
import { createAsaasReconciliation } from './asaas_reconciliation.js';
export const time = Date.parse('2026-10-17T12:00:00Z');
// Generated for each test process; never a real Asaas credential.
export const token = randomBytes(32).toString('hex');
export const hash = value => createHash('sha256').update(value).digest('hex');
export function fixture() {
  const db = memoryDb();
  db.data.set('rochaSparkAccounts/123456', { trialStartedAt: new Date('2026-10-01'),
    welcomeAcceptedAt: new Date('2026-10-01'), paidUntil: new Date('2027-01-01') });
  db.data.set('users/A/favorites/test', { name: 'SBC TV' });
  db.data.set('rochaBillingUsers/existing', { uid: 'A', provider: 'mercadopago' });
  const binding = { uid: 'A', environment: 'sandbox', plan: 'monthly', paymentId: 'pay_test1',
    subscriptionId: 'sub_test1', customerId: 'cus_test1', amountCents: 550,
    externalReference: 'rocha-asaas-syntheticreference123', dueDate: '2026-10-15',
    periodStart: Date.parse('2026-10-15T00:00:00Z'), periodEnd: Date.parse('2026-11-15T00:00:00Z') };
  const payment = { id: binding.paymentId, subscription: binding.subscriptionId,
    customer: binding.customerId, externalReference: binding.externalReference,
    value: 5.5, netValue: 4.85, dueDate: binding.dueDate, billingType: 'CREDIT_CARD', status: 'CONFIRMED' };
  const subscription = { id: binding.subscriptionId, customer: binding.customerId,
    externalReference: binding.externalReference, value: 5.5, billingType: 'CREDIT_CARD', cycle: 'MONTHLY' };
  const calls = [];
  const provider = createAsaasProvider({ apiKey: randomBytes(32).toString('hex'), webhookToken: token,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      const value = url.includes('/payments/') ? payment : subscription;
      return { ok: true, json: async () => structuredClone(value) };
    } });
  const store = createAsaasSandboxStore({ db });
  const service = createAsaasReconciliation({ provider, store, enabled: true, now: () => time });
  const event = { id: 'evt_synthetic1&1', event: 'PAYMENT_CONFIRMED', payment: { id: payment.id } };
  return { db, binding, payment, subscription, calls, provider, store, service, event,
    run: body => service.webhook({ method: 'POST', token, body: body ?? event }) };
}
