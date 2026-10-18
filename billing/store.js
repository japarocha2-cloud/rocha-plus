import { createHash } from 'node:crypto';
import { access, TRIAL_MS } from './policy.js';
export const userKey = uid => createHash('sha256').update(uid).digest('hex');
export function createStore(db) {
  const userRef = uid => db.doc('rochaBillingUsers/' + userKey(uid));
  return {
    async user(uid, now, email) {
      return db.runTransaction(async tx => {
        const ref = userRef(uid);
        const snapshot = await tx.get(ref);
        const emailRef = email ? db.doc('rochaBillingEmailTrials/' + userKey(email.trim().toLowerCase())) : null;
        const shared = emailRef ? (await tx.get(emailRef)).data() : null;
        const user = snapshot.exists ? snapshot.data() : { uid, email: email ?? null,
          createdAt: now, trialEndsAt: now + TRIAL_MS, payments: {} };
        const until = Math.min(user.trialEndsAt, shared?.trialEndsAt ?? user.trialEndsAt);
        if (until !== user.trialEndsAt) { user.trialEndsAt = until; tx.set(ref, user); }
        else if (!snapshot.exists) tx.create(ref, user);
        if (emailRef && shared?.trialEndsAt !== until) tx.set(emailRef, { trialEndsAt: until });
        return user;
      });
    },
    async subscriptionOwner(id) {
      return (await db.doc('rochaBillingSubscriptions/' + id).get()).data();
    },
    async bindSubscription(uid, subscription, now) {
      return db.runTransaction(async tx => {
        const ref = userRef(uid), ownerRef = db.doc('rochaBillingSubscriptions/' + subscription.id);
        const user = (await tx.get(ref)).data();
        const owner = (await tx.get(ownerRef)).data();
        const emailRef = subscription.email ? db.doc('rochaBillingEmailTrials/' + userKey(subscription.email)) : null;
        const shared = emailRef ? (await tx.get(emailRef)).data() : null;
        if (!user || (owner && (owner.uid !== uid || owner.plan !== subscription.plan ||
            owner.payerId !== subscription.payerId))) throw new Error('subscription-owner');
        const subscriptions = user.subscriptions ?? {};
        const old = subscriptions[subscription.id];
        if (old && old.updatedAt === subscription.updatedAt && old.status === subscription.status) return old;
        if (old && (old.updatedAt > subscription.updatedAt ||
            (old.updatedAt === subscription.updatedAt && ['paused', 'cancelled'].includes(old.status) &&
              subscription.status === 'authorized'))) return old;
        if (!old && Object.keys(subscriptions).length >= 10) throw new Error('subscription-limit');
        const record = { id: subscription.id, uid, plan: subscription.plan, payerId: subscription.payerId,
          status: subscription.status, createdAt: subscription.createdAt, updatedAt: subscription.updatedAt };
        subscriptions[subscription.id] = record;
        user.subscriptions = subscriptions;
        user.trialEndsAt = Math.min(user.trialEndsAt, subscription.trialEndsAt, shared?.trialEndsAt ?? Infinity);
        tx.set(ref, { ...user, entitlement: access(user, now) });
        tx.set(ownerRef, record);
        if (emailRef) tx.set(emailRef, { trialEndsAt: user.trialEndsAt });
        return record;
      });
    },
    async claimTrialWelcomeNotice(uid, now) {
      return db.runTransaction(async tx => {
        const ref = userRef(uid);
        const user = (await tx.get(ref)).data();
        if (!user || user.trialWelcomeNoticeAt != null || access(user, now).state !== 'trial') {
          return false;
        }
        tx.update(ref, { trialWelcomeNoticeAt: now });
        return true;
      });
    },
    async reserve(order, now) {
      await db.runTransaction(async tx => {
        const ref = userRef(order.uid);
        const user = (await tx.get(ref)).data();
        const day = Math.floor(now / 86400000);
        const count = user.checkoutDay === day ? user.checkoutCount ?? 0 : 0;
        if (count >= 10) throw new Error('checkout-limit');
        tx.create(db.doc('rochaBillingCheckouts/' + order.id), order);
        tx.update(ref, { checkoutDay: day, checkoutCount: count + 1 });
      });
    },
    async order(id) {
      return (await db.doc('rochaBillingCheckouts/' + id).get()).data();
    },
    async apply(order, paymentId, payment, now) {
      return db.runTransaction(async tx => {
        const ref = userRef(order.uid);
        const paymentRef = db.doc('rochaBillingPayments/' + paymentId);
        const user = (await tx.get(ref)).data();
        const owner = (await tx.get(paymentRef)).data();
        if (!user || (owner && (owner.uid !== order.uid || owner.orderId !== order.id))) {
          throw new Error('payment-owner');
        }
        const old = user.payments[paymentId];
        if (old?.kind === 'recurring' && (old.invoiceId !== payment.invoiceId ||
            old.subscriptionId !== payment.subscriptionId)) throw new Error('invoice-owner');
        if (old && JSON.stringify(old) === JSON.stringify(payment)) return access(user, now);
        if (old && (old.updatedAt > payment.updatedAt ||
            (old.updatedAt === payment.updatedAt && ['refunded', 'charged_back', 'in_mediation'].includes(old.status) && payment.status === 'approved'))) {
          return access(user, now);
        }
        if (!old && Object.keys(user.payments).length >= 200) throw new Error('ledger-limit');
        user.payments[paymentId] = payment;
        const entitlement = access(user, now);
        tx.set(ref, { ...user, entitlement });
        tx.set(paymentRef, { uid: order.uid, orderId: order.id, ...payment });
        return entitlement;
      });
    },
  };
}
