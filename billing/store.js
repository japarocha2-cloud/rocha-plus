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
        if (snapshot.exists) return snapshot.data();
        const user = { uid, email: email ?? null, createdAt: now,
          trialEndsAt: now + TRIAL_MS, payments: {} };
        tx.create(ref, user);
        return user;
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
