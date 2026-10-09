import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { onRequest } from 'firebase-functions/v2/https';
import { GoogleAuth } from 'google-auth-library';
import { createHash } from 'node:crypto';
import { productId, accountId, entitlement, assertOwner } from './policy.js';
initializeApp();
const db = getFirestore();
const google = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
const packageName = 'com.rochaplus.app';
const tokenKey = token => createHash('sha256').update(token).digest('hex');
async function readPlay(token) {
  const client = await google.getClient();
  const { data } = await client.request({ url:
    'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
    packageName + '/purchases/subscriptionsv2/tokens/' + encodeURIComponent(token) });
  return data;
}
async function verify(uid, token) {
  const purchase = await readPlay(token);
  assertOwner(purchase, uid);
  const result = entitlement(purchase);
  // Production purchases remain rejected until separate, explicit launch approval.
  if (!result.testPurchase) throw new Error('real-billing-disabled');
  const ownerRef = db.doc('billingTokens/' + tokenKey(token));
  const userRef = db.doc('billingUsers/' + uid);
  const linkedRef = purchase.linkedPurchaseToken
    ? db.doc('billingTokens/' + tokenKey(purchase.linkedPurchaseToken)) : null;
  await db.runTransaction(async tx => {
    const owner = await tx.get(ownerRef);
    const linked = linkedRef ? await tx.get(linkedRef) : null;
    const user = await tx.get(userRef);
    if ((owner.exists && owner.data().uid !== uid) ||
        (linked?.exists && linked.data().uid !== uid)) throw new Error('token-owned');
    tx.set(ownerRef, { uid });
    // Token stays private to Admin SDK; no client reads or writes.
    if (!user.exists || (result.expiresAt ?? 0) >= (user.data().expiresAt ?? 0)) {
      tx.set(userRef, { token, expiresAt: result.expiresAt ?? 0 });
    }
  });
  if (result.active && purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
    const client = await google.getClient();
    await client.request({ method: 'POST', data: {}, url:
      'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' +
      packageName + '/purchases/subscriptions/' + productId + '/tokens/' +
      encodeURIComponent(token) + ':acknowledge' });
  }
  return result;
}
export const billing = onRequest({ maxInstances: 5, timeoutSeconds: 30 }, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (req.method !== 'POST') { res.status(405).json({ error: 'method' }); return; }
  try {
    const bearer = /^Bearer (.+)$/.exec(req.headers.authorization ?? '');
    if (!bearer) { res.status(401).json({ error: 'auth' }); return; }
    const { uid } = await getAuth().verifyIdToken(bearer[1], true);
    if (req.body?.action === 'account') { res.json({ accountId: accountId(uid) }); return; }
    let token;
    if (req.body?.action === 'verify') {
      token = req.body.token;
      if (typeof token !== 'string' || token.length < 10 || token.length > 4096) {
        res.status(400).json({ error: 'token' }); return;
      }
    } else if (req.body?.action === 'entitlement') {
      const record = await db.doc('billingUsers/' + uid).get();
      token = record.data()?.token;
      if (!token) { res.json({ active: false, state: 'NONE', expiresAt: null }); return; }
    } else { res.status(400).json({ error: 'action' }); return; }
    // Re-query Play on every refresh: renewals, cancellation, hold, revocation and expiry.
    res.json(await verify(uid, token));
  } catch (_) {
    // Do not log tokens, Authorization headers or raw publisher errors.
    res.status(403).json({ error: 'verification-unavailable', active: false });
  }
});

export const billingNotifications = onMessagePublished(
  { topic: 'rocha-play-billing', retry: true, timeoutSeconds: 30 },
  async event => {
    const notification = event.data.message.json;
    if (notification.packageName !== packageName) return;
    const token = notification.subscriptionNotification?.purchaseToken;
    if (typeof token !== 'string' || token.length > 4096) return;
    const owner = await db.doc('billingTokens/' + tokenKey(token)).get();
    if (!owner.exists) return; // Client verification binds new purchases first.
    // Pub/Sub IAM authenticates delivery. Notification state is never trusted.
    // A retry queries current Play state; no event can manufacture entitlement.
    const purchase = await readPlay(token);
    assertOwner(purchase, owner.data().uid);
    const result = entitlement(purchase);
    if (!result.testPurchase) return;
    await verify(owner.data().uid, token);
  });
