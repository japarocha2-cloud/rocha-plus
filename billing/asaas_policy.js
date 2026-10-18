import { asaasId } from './asaas_provider.js';

export const ASAAS_MONTHLY_CENTS = 550;
const DAY = 86_400_000;
const fail = () => { throw new Error('asaas-verification'); };
export function asaasCents(value) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 ||
      !Number.isSafeInteger(Math.round(value * 100)) ||
      Math.abs(value * 100 - Math.round(value * 100)) > 0.000001) fail();
  return Math.round(value * 100);
}
function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) fail();
  const time = Date.parse(value + 'T00:00:00.000Z');
  if (!Number.isFinite(time) || new Date(time).toISOString().slice(0, 10) !== value) fail();
  return time;
}
function nextMonth(time) {
  const start = new Date(time), day = start.getUTCDate();
  start.setUTCDate(1);
  start.setUTCMonth(start.getUTCMonth() + 1);
  const last = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 0)).getUTCDate();
  start.setUTCDate(Math.min(day, last));
  return start.getTime();
}
// Bindings must be created by a trusted server checkout flow; never from the
// webhook body, matching emails or a mobile-supplied UID/period/price.
export function checkedAsaasBinding(binding) {
  if (!binding || binding.environment !== 'sandbox' || binding.plan !== 'monthly' ||
      typeof binding.uid !== 'string' || !binding.uid || binding.uid.length > 128 ||
      !asaasId(binding.paymentId, 'pay') || !asaasId(binding.subscriptionId, 'sub') ||
      !asaasId(binding.customerId, 'cus') || binding.amountCents !== ASAAS_MONTHLY_CENTS ||
      typeof binding.externalReference !== 'string' ||
      !/^rocha-asaas-[A-Za-z0-9_-]{16,100}$/.test(binding.externalReference)) fail();
  const start = date(binding.dueDate);
  if (binding.periodStart !== start || binding.periodEnd !== nextMonth(start) ||
      binding.periodEnd - start < 28 * DAY || binding.periodEnd - start > 31 * DAY) fail();
  return binding;
}
export function checkedAsaasPayment({ payment, subscription, binding, now }) {
  checkedAsaasBinding(binding);
  if (!Number.isFinite(now) || payment?.id !== binding.paymentId ||
      subscription?.id !== binding.subscriptionId ||
      payment.subscription !== binding.subscriptionId ||
      payment.customer !== binding.customerId || subscription.customer !== binding.customerId ||
      subscription.externalReference !== binding.externalReference ||
      (payment.externalReference != null && payment.externalReference !== '' &&
        payment.externalReference !== binding.externalReference) ||
      payment.billingType !== 'CREDIT_CARD' || subscription.billingType !== 'CREDIT_CARD' ||
      subscription.cycle !== 'MONTHLY' || payment.dueDate !== binding.dueDate ||
      asaasCents(payment.value) !== binding.amountCents ||
      asaasCents(subscription.value) !== binding.amountCents) fail();
  if (payment.deleted != null && typeof payment.deleted !== 'boolean') fail();
  if (payment.refunds != null && !Array.isArray(payment.refunds)) fail();
  const revoked = payment.deleted === true || (payment.refunds?.length ?? 0) > 0 ||
    ['REFUNDED', 'REFUND_REQUESTED', 'REFUND_IN_PROGRESS', 'CHARGEBACK_REQUESTED',
      'CHARGEBACK_DISPUTE', 'AWAITING_CHARGEBACK_REVERSAL'].includes(payment.status);
  let status;
  if (revoked) status = 'revoked';
  else if (['CONFIRMED', 'RECEIVED'].includes(payment.status)) status = 'paid';
  else if (['PENDING', 'OVERDUE', 'AWAITING_RISK_ANALYSIS', 'DUNNING_REQUESTED',
    'DUNNING_RECEIVED', 'RECEIVED_IN_CASH'].includes(payment.status)) status = 'pending';
  else fail();
  return { status, paymentId: binding.paymentId, subscriptionId: binding.subscriptionId,
    customerId: binding.customerId, uid: binding.uid, environment: 'sandbox',
    amountCents: binding.amountCents, periodStart: binding.periodStart,
    periodEnd: binding.periodEnd, providerStatus: payment.status,
    // A future or expired cycle never creates current access.
    current: status === 'paid' && binding.periodStart <= now && binding.periodEnd > now };
}
