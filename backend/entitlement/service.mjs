import { createHash } from 'node:crypto';

export const DAY = 86_400_000;
export class AccessError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const fail = (status, message) => { throw new AccessError(status, message); };
const text = (value, max = 200) => typeof value === 'string' && value.length > 0 && value.length <= max;
export const recordKey = value => createHash('sha256').update(value).digest('hex');

function paidThrough(payments) {
  return payments.filter(p => p.status === 'confirmed')
    .sort((a, b) => a.confirmedAtMs - b.confirmedAtMs || a.id.localeCompare(b.id))
    .reduce((until, p) => Math.max(until, p.confirmedAtMs) + p.days * DAY, 0);
}

/** store.transact serializes account + globally unique payment reads/writes. */
export function createAccessService({ verifyToken, store, plans, now = Date.now }) {
  const configuredPlans = new Map(Object.entries(plans ?? {}));
  for (const [, plan] of configuredPlans) {
    if (!Number.isSafeInteger(plan.amountCents) || plan.amountCents <= 0 ||
        !Number.isSafeInteger(plan.days) || plan.days < 1 || plan.days > 366) {
      throw new Error('Invalid server plan configuration');
    }
  }
  async function identity(header) {
    if (typeof header !== 'string' || !/^Bearer \S+$/.test(header)) fail(401, 'Unauthorized');
    let claims;
    try { claims = await verifyToken(header.slice(7), true); }
    catch { fail(401, 'Unauthorized'); }
    if (!text(claims?.uid, 128) ||
        !['google.com', 'apple.com'].includes(claims.firebase?.sign_in_provider)) {
      fail(401, 'Unauthorized');
    }
    return claims;
  }
  return async ({ method, path, authorization, body = {} }) => {
    const actor = await identity(authorization);
    const timestamp = now();
    if (!Number.isSafeInteger(timestamp) || timestamp <= 0) fail(503, 'Clock unavailable');
    if (method === 'GET' && path === '/v1/entitlement') {
      return store.transact(actor.uid, null, async state => {
        const account = state.account ?? {
          uid: actor.uid, trialStartedAtMs: timestamp, trialEndsAtMs: timestamp + 7 * DAY,
        };
        if (!state.account) state.setAccount(account);
        const expires = Math.max(account.trialEndsAtMs, paidThrough(state.payments));
        return { uid: actor.uid, allowed: expires > timestamp,
          expiresAt: new Date(expires).toISOString(), serverTime: new Date(timestamp).toISOString() };
      });
    }
    if (method !== 'POST' || !['/v1/admin/confirm', '/v1/admin/refund'].includes(path)) {
      fail(404, 'Not found');
    }
    if (actor.rochaAdmin !== true) fail(403, 'Administrator required');
    if (!text(body.uid, 128) || !text(body.provider, 40) || !text(body.transactionId) ||
        !text(body.evidenceReference, 500)) fail(400, 'Invalid payment evidence');
    // Provider transaction reference is global: replay into another account is rejected.
    const paymentId = recordKey(JSON.stringify([body.provider, body.transactionId]));
    return store.transact(body.uid, paymentId, async state => {
      const prior = state.payment;
      if (prior && prior.uid !== body.uid) fail(409, 'Transaction already belongs to another account');
      if (path.endsWith('/confirm')) {
        const plan = configuredPlans.get(body.plan);
        if (!plan || body.currency !== 'BRL' || body.amountCents !== plan.amountCents) {
          fail(400, 'Payment does not match a configured plan');
        }
        if (prior) {
          if (prior.status !== 'confirmed' || prior.plan !== body.plan ||
              prior.amountCents !== body.amountCents) fail(409, 'Transaction cannot be reused');
          return { status: 'confirmed', duplicate: true };
        }
        const payment = { id: paymentId, uid: body.uid, provider: body.provider,
          transactionId: body.transactionId, plan: body.plan, days: plan.days,
          amountCents: plan.amountCents, currency: 'BRL', status: 'confirmed',
          confirmedAtMs: timestamp, confirmedBy: actor.uid, evidenceReference: body.evidenceReference };
        // A paid-before-first-login account must not receive a fresh trial later.
        // Pin the seven-day clock when the first verified payment is recorded.
        if (!state.account) state.setAccount({
          uid: body.uid, trialStartedAtMs: timestamp,
          trialEndsAtMs: timestamp + 7 * DAY,
        });
        state.setPayment(payment);
        state.audit('confirmed', { adminUid: actor.uid, atMs: timestamp, paymentId, uid: body.uid });
        return { status: 'confirmed', duplicate: false };
      }
      if (!prior) fail(404, 'Confirmed transaction not found');
      if (prior.status === 'refunded') return { status: 'refunded', duplicate: true };
      state.setPayment({ ...prior, status: 'refunded', refundedAtMs: timestamp,
        refundedBy: actor.uid, refundEvidenceReference: body.evidenceReference });
      state.audit('refunded', { adminUid: actor.uid, atMs: timestamp, paymentId, uid: body.uid });
      return { status: 'refunded', duplicate: false };
    });
  };
}
