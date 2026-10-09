import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { onRequest } from 'firebase-functions/v2/https';
import { GoogleAuth } from 'google-auth-library';
import { productId } from './policy.js';
import { createStore } from './store.js';
import { createBillingService, packageName } from './service.js';
initializeApp();
const google = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
const base = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + packageName;
const service = createBillingService({
  store: createStore(getFirestore()),
  verifyIdentity: (token, revoked) => getAuth().verifyIdToken(token, revoked),
  readPlay: async token => {
    const client = await google.getClient();
    const { data } = await client.request({ timeout: 10000,
      url: base + '/purchases/subscriptionsv2/tokens/' + encodeURIComponent(token) });
    return data;
  },
  acknowledge: async token => {
    const client = await google.getClient();
    await client.request({ method: 'POST', data: {}, timeout: 10000,
      url: base + '/purchases/subscriptions/' + productId + '/tokens/' +
        encodeURIComponent(token) + ':acknowledge' });
  },
});
export const billing = onRequest({ maxInstances: 5, timeoutSeconds: 120 }, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  const result = await service.handle({
    method: req.method, authorization: req.headers.authorization, body: req.body,
  });
  // Never return or log tokens, raw Publisher responses or credentials.
  res.status(result.status).json(result.body);
});
export const billingNotifications = onMessagePublished(
  { topic: 'rocha-play-billing', retry: true, timeoutSeconds: 120, maxInstances: 5 },
  async event => {
    let message;
    try { message = event.data.message.json; } catch (_) { return; }
    // IAM authenticates the Pub/Sub trigger. Invalid messages are discarded;
    // temporary Publisher/Firestore failures throw for retry.
    await service.notification(message);
  });
