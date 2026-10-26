// Administrative preview only; no network, SDK or writes. Provider/Auth inputs
// must be read server-side. It cannot authorize an import without a ledger check.
const reject = () => { throw Error('direct-payment-preview-not-verified'); };
const cents = n => {
  if (typeof n !== 'number' || !Number.isFinite(n) || n < 0 ||
      !Number.isSafeInteger(Math.round(n * 100)) || Math.abs(n * 100 - Math.round(n * 100)) > 1e-6) reject();
  return Math.round(n * 100);
};
function addMonths(ms, months) {
  const d = new Date(ms), day = d.getUTCDate();
  d.setUTCDate(1); d.setUTCMonth(d.getUTCMonth() + months);
  const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, last)); return d.getTime();
}
export function previewDirectPayments({ user, merchantId, payments, assignments, plans, now, existingPaidUntil = null }) {
  if (!user?.uid || user.disabled || user.emailVerified !== true || !user.email ||
      user.providerData?.filter(p => p.providerId === 'google.com').length !== 1 ||
      !/^\d+$/.test(String(merchantId)) || !Number.isSafeInteger(now) || now <= 0 ||
      (existingPaidUntil !== null && (!Number.isSafeInteger(existingPaidUntil) || existingPaidUntil <= 0)) ||
      !Array.isArray(payments) || !payments.length) reject();
  const seen = new Set();
  const checked = payments.map(p => {
    const id = String(p.id), name = Object.hasOwn(assignments, id) ? assignments[id] : null;
    const plan = Object.hasOwn(plans, name) ? plans[name] : null, approved = Date.parse(p.date_approved);
    if (!/^\d{1,30}$/.test(id) || seen.has(id) || !plan ||
        !Number.isSafeInteger(plan.amountCents) || plan.amountCents <= 0 ||
        !Number.isSafeInteger(plan.months) || plan.months < 1 || plan.months > 12 ||
        p.status !== 'approved' || p.status_detail !== 'accredited' || p.live_mode !== true ||
        p.operation_type !== 'regular_payment' || p.currency_id !== 'BRL' ||
        cents(p.transaction_amount) !== plan.amountCents || cents(p.transaction_amount_refunded) !== 0 ||
        String(p.collector_id) !== String(merchantId) ||
        p.payer?.email?.trim().toLowerCase() !== user.email.trim().toLowerCase() ||
        !Number.isSafeInteger(approved) || approved <= 0 || approved > now) reject();
    seen.add(id); return { id, months: plan.months, approved };
  }).sort((a, b) => a.approved - b.approved || a.id.localeCompare(b.id));
  let until = existingPaidUntil ?? 0;
  for (const p of checked) until = addMonths(Math.max(until, p.approved), p.months);
  return { previewOnly: true, writes: 0, accessGranted: false, paymentCount: checked.length,
    proposedPaidUntil: new Date(until).toISOString(), durationPolicy: 'calendar-months-UTC-proposal',
    requiresDurationPolicyReview: true, existingPaymentLedgerChecked: false, readyToApply: false };
}
