import { accountId, assertOwner, entitlement } from './policy.js';
export const packageName = 'com.rochaplus.app';
export function validToken(token) {
  return typeof token === 'string' && token.length >= 10 && token.length <= 4096;
}
export function createBillingService({ store, readPlay, acknowledge, verifyIdentity, now = Date.now }) {
  async function checked(uid, token) {
    if (!validToken(token)) throw new Error('token');
    const purchase = await readPlay(token);
    assertOwner(purchase, uid);
    const result = entitlement(purchase, now());
    if (!result.testPurchase) throw new Error('real-billing-disabled');
    return { purchase, result };
  }
  async function verify(uid, token) {
    const { purchase, result } = await checked(uid, token);
    await store.claim(uid, token, purchase.linkedPurchaseToken);
    if (result.active && purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
      await acknowledge(token);
    }
    return result;
  }
  async function current(uid) {
    const tokens = await store.tokens(uid);
    if (!tokens.length) return { active: false, state: 'NONE', expiresAt: null };
    const results = [];
    for (const token of tokens) {
      if (await store.owner(token) !== uid) throw new Error('token-owned');
      try {
        results.push(await verify(uid, token));
      } catch (error) {
        // Play returns 410 once an old token is no longer queryable. It cannot
        // grant access; transient/auth/configuration errors must fail closed.
        if (error.response?.status !== 410) throw error;
      }
    }
    results.sort((a, b) => Number(b.active) - Number(a.active) ||
      (b.expiresAt ?? 0) - (a.expiresAt ?? 0));
    return results[0] ?? { active: false, state: 'NONE', expiresAt: null };
  }
  async function handle({ method, authorization, body }) {
    if (method !== 'POST') return { status: 405, body: { error: 'method' } };
    const bearer = /^Bearer (.+)$/.exec(authorization ?? '');
    if (!bearer) return { status: 401, body: { error: 'auth' } };
    let uid;
    try { ({ uid } = await verifyIdentity(bearer[1], true)); }
    catch (_) { return { status: 401, body: { error: 'auth' } }; }
    if (typeof uid !== 'string' || !uid) return { status: 401, body: { error: 'auth' } };
    try {
      if (body?.action === 'account') return { status: 200, body: { accountId: accountId(uid) } };
      if (!['verify', 'entitlement'].includes(body?.action)) {
        return { status: 400, body: { error: 'action' } };
      }
      if (body.action === 'verify') {
        if (!validToken(body.token)) return { status: 400, body: { error: 'token' } };
        await verify(uid, body.token);
      }
      // Always select across server-bound tokens; restore order cannot revoke
      // a newer active purchase or revive an expired/revoked one.
      return { status: 200, body: await current(uid) };
    } catch (_) {
      return { status: 403, body: { error: 'verification-unavailable', active: false } };
    }
  }
  async function notification(message) {
    if (message?.packageName !== packageName) return;
    const token = message.subscriptionNotification?.purchaseToken;
    if (!validToken(token)) return;
    const uid = await store.owner(token);
    if (!uid) return;
    await verify(uid, token); // Current Publisher state, never notificationType.
  }
  return { handle, notification, current, verify };
}
