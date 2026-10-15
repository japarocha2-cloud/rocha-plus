import { createStore, userKey } from './store.js';
import { PLANS, TRIAL_MS } from './policy.js';
import { subscriptionIdValid } from './recurring.js';

const fail = code => { throw new Error('spark-sync-' + code); };
const millis = value => value?.toMillis?.() ?? (value instanceof Date ? value.getTime() : NaN);
const paidValue = value => value == null ? null : millis(value);

export async function sparkIdentity(auth, uid) {
  const account = await auth.getUser(uid);
  const google = account.providerData?.filter(p => p.providerId === 'google.com');
  if (account.uid !== uid || account.disabled || !account.emailVerified || !account.email ||
      google?.length !== 1 || !/^\d{1,128}$/.test(google[0].uid ?? '')) fail('identity');
  return { subject: google[0].uid, email: account.email.trim().toLowerCase() };
}

// Projects ONLY the server-verified recurring ledger. Clients never supply a
// validity, UID, email or payment response. Existing manual validity is a floor;
// an external change after adoption requires review rather than silent overwrite.
export function createSparkProjection({ db, auth, collectorId, liveMode,
  timestamp = time => new Date(time) }) {
  return async function project(uid, now) {
    // These are the actual merchant and project-specific test accounts. A test
    // account payment may have live_mode=true, so that flag alone is insufficient.
    if (String(collectorId) !== '1981204845' || liveMode !== true || !Number.isFinite(now)) fail('production-required');
    const { subject } = await sparkIdentity(auth, uid);
    return db.runTransaction(async tx => {
      const sparkRef = db.doc('rochaSparkAccounts/' + subject);
      const stateRef = db.doc('rochaSparkBillingProjections/' + subject);
      const identityRef = db.doc('rochaSparkBillingIdentities/' + userKey(uid));
      const source = (await tx.get(db.doc('rochaBillingUsers/' + userKey(uid)))).data();
      const spark = (await tx.get(sparkRef)).data();
      const state = (await tx.get(stateRef)).data();
      const identity = (await tx.get(identityRef)).data();
      if (!source || source.uid !== uid || !spark || !Number.isFinite(millis(spark.trialStartedAt)) ||
          millis(spark.trialStartedAt) > now) fail('existing-account-required');
      const current = paidValue(spark.paidUntil);
      if (current !== null && !Number.isFinite(current)) fail('invalid-paid-until');
      if ((state && (state.uid !== uid || state.googleSubject !== subject)) ||
          (identity && identity.googleSubject !== subject)) fail('identity-owner');
      if (state && current !== state.lastPaidUntil) fail('external-change-review-required');
      const baseline = state ? state.baselinePaidUntil : current;
      if (baseline !== null && !Number.isFinite(baseline)) fail('invalid-baseline');
      const payments = Object.entries(source.payments ?? {});
      const subscriptions = Object.values(source.subscriptions ?? {});
      if (payments.length > 200 || subscriptions.length > 10) fail('ledger-limit');
      const owners = [];
      for (const s of subscriptions) {
        if (!subscriptionIdValid(s.id) || s.uid !== uid || !Object.hasOwn(PLANS, s.plan) ||
            !/^\d{1,30}$/.test(s.payerId ?? '')) fail('subscription-owner');
        const ref = db.doc('rochaSparkSubscriptionOwners/' + s.id);
        const owner = (await tx.get(ref)).data();
        if (owner && (owner.googleSubject !== subject || owner.plan !== s.plan ||
            owner.payerId !== s.payerId)) fail('subscription-owner');
        if (!owner) owners.push([ref, { googleSubject: subject, plan: s.plan, payerId: s.payerId }]);
      }
      let managed = 0;
      for (const [id, p] of payments) {
        if (p.kind !== 'recurring') fail('unsupported-payment');
        if (p.verifiedCollectorId !== String(collectorId) || p.verifiedLiveMode !== true) fail('verification-scope');
        const s = subscriptions.find(s => s.id === p.subscriptionId);
        if (!/^\d{1,30}$/.test(id) || !s || s.plan !== p.plan ||
            !Number.isFinite(p.periodStart) || !Number.isFinite(p.periodEnd) ||
            p.periodEnd <= p.periodStart || !Number.isFinite(p.updatedAt)) fail('invalid-ledger');
        const manual = (await tx.get(db.doc('rochaSparkPaymentConfirmations/' + id))).data();
        // Administrative confirmations have their own revocation policy. Require
        // explicit migration instead of adopting their cycles as an unmanaged floor.
        if (manual) fail('manual-payment-migration-required');
        if (p.status === 'approved' && p.refundedCents === 0 && Number.isFinite(p.approvedAt) &&
            p.approvedAt <= now && p.periodStart <= now) managed = Math.max(managed, p.periodEnd);
      }
      const target = Math.max(baseline ?? 0, managed) || null;
      const changed = (target ?? 0) !== (current ?? 0);
      const lastPaidUntil = changed ? target ?? 0 : current;
      // All transaction reads precede all writes. A refund removes only the
      // managed portion; the trial, welcome acceptance and favorites are untouched.
      if (changed) tx.update(sparkRef, { paidUntil: timestamp(target ?? 0) });
      if (!state || changed || state.managedPaidUntil !== managed) {
        tx.set(stateRef, { uid, googleSubject: subject, baselinePaidUntil: baseline,
          managedPaidUntil: managed, lastPaidUntil, synchronizedAt: timestamp(now) });
      }
      if (!identity) tx.create(identityRef, { googleSubject: subject });
      for (const [ref, value] of owners) tx.set(ref, value);
      return { changed, paidUntil: target, state: target !== null && target > now ? 'paid' : 'unpaid' };
    });
  };
}

export function createSparkRecurringStore(options) {
  const source = createStore(options.db);
  const project = createSparkProjection(options);
  return { ...source,
    async user(uid, now, email) {
      const identity = await sparkIdentity(options.auth, uid);
      const spark = (await options.db.doc('rochaSparkAccounts/' + identity.subject).get()).data();
      if (!spark || !Number.isFinite(millis(spark.trialStartedAt)) || millis(spark.trialStartedAt) > now ||
          (email && email !== identity.email)) fail('existing-account-required');
      await source.user(uid, now, email);
      // Keep legacy HTTP/TV status within the already-established Spark trial.
      // Adoption must never give another seven days to an expired Google account.
      return options.db.runTransaction(async tx => {
        const ref = options.db.doc('rochaBillingUsers/' + userKey(uid));
        const user = (await tx.get(ref)).data();
        const trialEndsAt = Math.min(user.trialEndsAt, millis(spark.trialStartedAt) + TRIAL_MS);
        if (trialEndsAt !== user.trialEndsAt) tx.update(ref, { trialEndsAt });
        return { ...user, trialEndsAt };
      });
    },
    project,
  };
}
