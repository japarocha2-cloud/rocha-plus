import { createHash } from 'node:crypto';
import { checkedAsaasBinding } from './asaas_policy.js';

const key = value => createHash('sha256').update(value).digest('hex');
const fail = () => { throw new Error('asaas-sandbox-ledger'); };
export function createAsaasSandboxStore({ db }) {
  function bindingRef(id) { return db.doc('rochaAsaasSandboxBindings/' + key(id)); }
  return {
    environment: 'sandbox',
    async binding(id) { return (await bindingRef(id).get()).data() ?? null; },
    // Trusted server setup only. A binding cannot be moved to another account,
    // price or period after creation. No email-based or callback-based claiming.
    async bindPayment(value) {
      checkedAsaasBinding(value);
      const binding = Object.fromEntries(['environment', 'plan', 'uid', 'paymentId',
        'subscriptionId', 'customerId', 'amountCents', 'externalReference', 'dueDate',
        'periodStart', 'periodEnd'].map(field => [field, value[field]]));
      return db.runTransaction(async tx => {
        const ref = bindingRef(binding.paymentId), previous = (await tx.get(ref)).data();
        if (previous && (Object.keys(previous).length !== Object.keys(binding).length ||
            Object.keys(binding).some(field => previous[field] !== binding[field]))) fail();
        if (!previous) tx.create(ref, binding);
        return { created: !previous };
      });
    },
    async record({ eventId, decision, now }) {
      if (typeof eventId !== 'string' || !eventId || eventId.length > 245 ||
          decision?.environment !== 'sandbox' || !['paid', 'pending', 'revoked'].includes(decision.status) ||
          !Number.isFinite(now)) fail();
      return db.runTransaction(async tx => {
        const ref = bindingRef(decision.paymentId);
        const binding = (await tx.get(ref)).data();
        checkedAsaasBinding(binding);
        for (const field of ['uid', 'paymentId', 'subscriptionId', 'customerId', 'amountCents',
          'periodStart', 'periodEnd']) if (binding[field] !== decision[field]) fail();
        const eventRef = db.doc('rochaAsaasSandboxEvents/' + key(eventId));
        const userRef = db.doc('rochaAsaasSandboxUsers/' + key(binding.uid));
        const previousEvent = (await tx.get(eventRef)).data();
        const user = (await tx.get(userRef)).data() ?? { uid: binding.uid, payments: {} };
        if (user.uid !== binding.uid || typeof user.payments !== 'object' ||
            !user.payments || Array.isArray(user.payments)) fail();
        const paymentKey = key(binding.paymentId);
        if (previousEvent) {
          if (previousEvent.paymentId !== binding.paymentId || previousEvent.uid !== binding.uid) fail();
          return { changed: false, duplicate: true, paidUntil: user.paidUntil ?? null };
        }
        const previous = user.payments[paymentKey];
        // A stale paid snapshot cannot undo a refund, even when separate workers
        // finish out of order. Reversals require explicit review in a later phase.
        const status = previous?.status === 'revoked' || decision.status === 'revoked'
          ? 'revoked' : previous?.status === 'paid' ? 'paid' : decision.status;
        const payments = { ...user.payments, [paymentKey]: { paymentId: binding.paymentId,
          subscriptionId: binding.subscriptionId, status, periodStart: binding.periodStart,
          periodEnd: binding.periodEnd, updatedAt: now } };
        if (Object.keys(payments).length > 200) fail();
        const paidUntil = Math.max(0, ...Object.values(payments)
          .filter(p => p.status === 'paid' && p.periodStart <= now && p.periodEnd > now)
          .map(p => p.periodEnd)) || null;
        tx.set(userRef, { uid: binding.uid, environment: 'sandbox', payments, paidUntil });
        tx.create(eventRef, { eventId, uid: binding.uid, paymentId: binding.paymentId, recordedAt: now });
        return { changed: true, duplicate: false, paidUntil };
      });
    },
  };
}
