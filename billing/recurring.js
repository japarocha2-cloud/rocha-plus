import { amountCents, addMonths, checkedPaymentDetails, PLANS, TRIAL_MS } from './policy.js';
export const subscriptionIdValid = id => typeof id === 'string' && /^[a-zA-Z0-9_-]{8,100}$/.test(id);
export const normalizeEmail = email => typeof email === 'string' ? email.trim().toLowerCase() : '';
export const LINKS = Object.freeze({ monthly: 'https://mpago.la/2E7yjF4', annual: 'https://mpago.la/2b9hitF' });
export function checkedSchedule(schedule, plan) {
  if (!schedule || schedule.currency_id !== 'BRL' ||
      amountCents(schedule.transaction_amount) !== PLANS[plan]?.cents ||
      schedule.frequency_type !== 'months' || schedule.frequency !== PLANS[plan]?.months) {
    throw new Error('subscription-schedule');
  }
}
export function checkedPlan(value, plan, config) {
  if (!subscriptionIdValid(value?.id) || value.id !== config.planIds[plan] ||
      String(value.collector_id) !== String(config.collectorId) || value.status !== 'active') {
    throw new Error('subscription-plan');
  }
  checkedSchedule(value.auto_recurring, plan);
  return value;
}
export function checkedSubscription(value, config) {
  if (!subscriptionIdValid(value?.id) || String(value.collector_id) !== String(config.collectorId)) {
    throw new Error('subscription-owner');
  }
  const plan = Object.keys(PLANS).find(key => config.planIds[key] && config.planIds[key] === value.preapproval_plan_id);
  if (!plan || !['pending', 'authorized', 'paused', 'cancelled'].includes(value.status) ||
      (value.live_mode != null && value.live_mode !== config.liveMode)) throw new Error('subscription-plan');
  checkedSchedule(value.auto_recurring, plan);
  const createdAt = Date.parse(value.date_created), updatedAt = Date.parse(value.last_modified);
  if (!Number.isFinite(createdAt) || !Number.isFinite(updatedAt) || createdAt > config.now + 300000 ||
      updatedAt > config.now + 300000 || updatedAt < createdAt || !value.payer_id) {
    throw new Error('subscription-date');
  }
  // Never extend a Firebase trial with a later Mercado Pago trial or next billing date.
  const firstDeadline = createdAt + TRIAL_MS;
  const firstCharge = Date.parse(value.auto_recurring.start_date);
  return { id: value.id, plan, payerId: String(value.payer_id), status: value.status,
    email: normalizeEmail(value.payer_email), createdAt, updatedAt,
    trialEndsAt: Number.isFinite(firstCharge) && firstCharge >= createdAt
      ? Math.min(firstDeadline, firstCharge) : firstDeadline,
    checkoutUrl: value.init_point ?? null };
}
export function checkedRecurringPayment(invoice, payment, subscription, config) {
  if (String(invoice.preapproval_id) !== subscription.id || !/^\d{1,30}$/.test(String(invoice.id)) ||
      String(invoice.payment?.id) !== String(payment.id) ||
      String(payment.payer?.id) !== subscription.payerId || invoice.currency_id !== 'BRL' ||
      amountCents(invoice.transaction_amount) !== PLANS[subscription.plan].cents) {
    throw new Error('invoice-owner');
  }
  // Ownership comes from the GET invoice -> GET subscription -> reserved UID chain,
  // not the optional external_reference on generic-link subscriptions.
  const checked = checkedPaymentDetails(payment, subscription.plan, config);
  const periodStart = Date.parse(invoice.debit_date);
  if (!Number.isFinite(periodStart) ||
      (checked.status === 'approved' && periodStart > config.now + 300000)) throw new Error('invoice-date');
  return { ...checked, kind: 'recurring', subscriptionId: subscription.id,
    invoiceId: String(invoice.id), periodStart, periodEnd: addMonths(periodStart, PLANS[subscription.plan].months) };
}
export function recurringStatus(user, result) {
  const subscriptions = Object.values(user.subscriptions ?? {});
  return { ...result, automaticRenewal: subscriptions.some(s => s.status === 'authorized'),
    subscriptionStatus: subscriptions.some(s => s.status === 'authorized') ? 'authorized'
      : subscriptions.some(s => s.status === 'pending') ? 'pending'
      : subscriptions.length ? 'cancelled' : 'none',
    recognition: subscriptions.length ? 'linked' : 'not-found' };
}
