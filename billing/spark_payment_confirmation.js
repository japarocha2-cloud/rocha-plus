import { checkedSubscription, checkedRecurringPayment, normalizeEmail, subscriptionIdValid } from './recurring.js';

const reject = code => { throw new Error('spark-confirmation-' + code); };
const millis = value => value?.toMillis?.() ?? (value instanceof Date ? value.getTime() : NaN);

// Administrative grant only. No HTTP endpoint, charge, trial reset or automatic renewal.
// Provider and Auth must be trusted server-side clients, never client-supplied responses.
export async function confirmSparkPayment({ db, auth, provider, uid, subscriptionId,
  invoiceId, config, apply = false, timestamp = value => new Date(value) }) {
  if (!uid || !Number.isFinite(config?.now) || !/^\d{1,30}$/.test(invoiceId ?? '') ||
      !subscriptionIdValid(subscriptionId) || !/^\d{1,30}$/.test(String(config.collectorId ?? '')) ||
      !subscriptionIdValid(config.planIds?.monthly) || !subscriptionIdValid(config.planIds?.annual) ||
      config.planIds.monthly === config.planIds.annual) reject('arguments');
  if (apply && config.liveMode !== true) reject('production-required');
  const account = await auth.getUser(uid);
  const google = account.providerData?.filter(p => p.providerId === 'google.com');
  if (account.uid !== uid || account.disabled || !account.emailVerified ||
      !normalizeEmail(account.email) || google?.length !== 1 ||
      !/^\d{1,128}$/.test(google[0].uid ?? '')) reject('identity');
  const subject = google[0].uid;
  const raw = await provider.subscription(subscriptionId);
  if (raw.id !== subscriptionId || (raw.external_reference != null && raw.external_reference !== '')) {
    reject('subscription-reference');
  }
  const subscription = checkedSubscription(raw, config);
  if (!subscription.email || subscription.email !== normalizeEmail(account.email)) reject('payer-identity');
  const invoice = await provider.invoice(invoiceId);
  if (String(invoice.id) !== invoiceId || !/^\d{1,30}$/.test(String(invoice.payment?.id ?? ''))) reject('invoice');
  const paymentId = String(invoice.payment.id);
  const payment = await provider.payment(paymentId);
  if (String(payment.id) !== paymentId) reject('payment-resource');
  const checked = checkedRecurringPayment(invoice, payment, subscription, config);
  if (checked.status !== 'approved' || checked.refundedCents !== 0 ||
      checked.periodStart > config.now || checked.approvedAt > config.now || checked.periodEnd <= config.now) {
    reject('not-current-paid-cycle');
  }
  return db.runTransaction(async tx => {
    const sparkRef = db.doc('rochaSparkAccounts/' + subject);
    const paymentRef = db.doc('rochaSparkPaymentConfirmations/' + paymentId);
    const ownerRef = db.doc('rochaSparkSubscriptionOwners/' + subscription.id);
    const legacyOwnerRef = db.doc('rochaBillingSubscriptions/' + subscription.id);
    const legacyPaymentRef = db.doc('rochaBillingPayments/' + paymentId);
    const spark = (await tx.get(sparkRef)).data();
    const previous = (await tx.get(paymentRef)).data();
    const owner = (await tx.get(ownerRef)).data();
    const legacyOwner = (await tx.get(legacyOwnerRef)).data();
    const legacyPayment = (await tx.get(legacyPaymentRef)).data();
    if (!spark || !Number.isFinite(millis(spark.trialStartedAt)) ||
        millis(spark.trialStartedAt) > config.now) reject('existing-trial-required');
    if ((owner && (owner.googleSubject !== subject || owner.plan !== subscription.plan ||
          owner.payerId !== subscription.payerId)) ||
        (legacyOwner && legacyOwner.uid !== uid) || (legacyPayment && legacyPayment.uid !== uid) ||
        (previous && (previous.googleSubject !== subject || previous.subscriptionId !== subscription.id ||
          previous.invoiceId !== invoiceId || previous.periodEnd !== checked.periodEnd))) reject('ownership-conflict');
    if (spark.paidUntil != null && !Number.isFinite(millis(spark.paidUntil))) reject('invalid-paid-until');
    // A replay cannot re-grant a payment after another administrator revoked it.
    if (previous) return { mode: 'already-recorded', changed: false, plan: subscription.plan,
      paidUntil: millis(spark.paidUntil) || null };
    const paidUntil = Math.max(millis(spark.paidUntil) || 0, checked.periodEnd);
    const result = { mode: apply ? 'applied' : 'dry-run', changed: apply,
      plan: subscription.plan, paidUntil };
    if (!apply) return result;
    tx.update(sparkRef, { paidUntil: timestamp(paidUntil) });
    tx.set(ownerRef, { googleSubject: subject, plan: subscription.plan, payerId: subscription.payerId });
    tx.create(paymentRef, { googleSubject: subject, verifiedUid: uid, subscriptionId: subscription.id,
      invoiceId, plan: subscription.plan, periodEnd: checked.periodEnd,
      providerUpdatedAt: checked.updatedAt, confirmedAt: timestamp(config.now) });
    return result;
  });
}
