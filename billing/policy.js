export const TRIAL_MS = 7 * 24 * 60 * 60 * 1000;
export const PLANS = Object.freeze({
  monthly: { cents: 490, months: 1, title: 'Rocha+ Mensal' },
  annual: { cents: 5500, months: 12, title: 'Rocha+ Anual' },
});
export function amountCents(value) {
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(String(value));
  if (!match) throw new Error('amount');
  const cents = Number(match[1]) * 100 + Number((match[2] ?? '').padEnd(2, '0'));
  if (!Number.isSafeInteger(cents)) throw new Error('amount');
  return cents;
}
export function addMonths(time, months) {
  const date = new Date(time);
  const day = date.getUTCDate();
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + months);
  const last = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  date.setUTCDate(Math.min(day, last));
  return date.getTime();
}
export function access(user, now) {
  const approved = Object.entries(user.payments ?? {})
    .filter(([, p]) => p.status === 'approved' && p.refundedCents === 0)
    .sort((a, b) => a[1].approvedAt - b[1].approvedAt || a[0].localeCompare(b[0]));
  let paidUntil = null;
  for (const [, payment] of approved.filter(([, payment]) => payment.kind !== 'recurring')) {
    paidUntil = addMonths(Math.max(paidUntil ?? 0, user.trialEndsAt, payment.approvedAt),
      PLANS[payment.plan].months);
  }
  for (const [, payment] of approved.filter(([, payment]) => payment.kind === 'recurring')) {
    // Recurring invoices cover their own calendar cycle. Replays and a second
    // charge in the same cycle cannot add another month or another free trial.
    if (Number.isFinite(payment.periodEnd)) paidUntil = Math.max(paidUntil ?? 0, payment.periodEnd);
  }
  const activePaid = paidUntil != null && paidUntil > now;
  const trial = user.trialEndsAt > now;
  return {
    active: activePaid || trial,
    state: activePaid ? 'paid' : trial ? 'trial' : 'expired',
    serverTime: now,
    trialEndsAt: user.trialEndsAt,
    paidUntil,
    accessUntil: activePaid ? paidUntil : trial ? user.trialEndsAt : null,
    trialRemainingDays: Math.max(0, Math.ceil((user.trialEndsAt - now) / 86400000)),
    trialWelcomeNoticeAccepted: user.trialWelcomeNoticeAt != null,
    automaticRenewal: false,
  };
}
export function checkedPayment(payment, order, config) {
  if (String(payment.external_reference) !== order.id) throw new Error('payment-reference');
  return checkedPaymentDetails(payment, order.plan, config);
}
export function checkedPaymentDetails(payment, plan, { collectorId, liveMode, now }) {
  if (String(payment.collector_id) !== String(collectorId) ||
      payment.live_mode !== liveMode || payment.currency_id !== 'BRL' ||
      amountCents(payment.transaction_amount) !== PLANS[plan]?.cents) {
    throw new Error('payment-mismatch');
  }
  const updatedAt = Date.parse(payment.date_last_updated);
  const approvedAt = payment.date_approved == null ? null : Date.parse(payment.date_approved);
  if (!Number.isFinite(updatedAt) || updatedAt > now + 300000 ||
      (payment.status === 'approved' && (!Number.isFinite(approvedAt) || approvedAt > now + 300000))) {
    throw new Error('payment-date');
  }
  const status = payment.status;
  if (!['approved', 'pending', 'in_process', 'rejected', 'cancelled', 'refunded', 'charged_back', 'in_mediation', 'authorized'].includes(status)) {
    throw new Error('payment-status');
  }
  return { plan, status, updatedAt, approvedAt,
    refundedCents: amountCents(payment.transaction_amount_refunded ?? 0) };
}
