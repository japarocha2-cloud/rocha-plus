'use strict';

// Experimental entitlement API. Deploy only to the intended Firebase project.
// Payment records are server-owned; no client can grant themselves paid access.
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
const {defineSecret} = require('firebase-functions/params');
const {createMercadoPagoWebhookHandler, createFirestoreWebhookInbox} = require('./mercadopago_webhook');
const {reconcileAndGrant} = require('./reconcile_and_grant');
const {createCheckoutHandler} = require('./checkout');
const {bindCheckoutClaim} = require('./checkout_claim');
const {initializeTrial, googleSubjectOf} = require('./trial_anchor');
const mpReceivingToken = defineSecret('MP_RECEIVING_ACCESS_TOKEN');
const mpWebhookSecret = defineSecret('MP_WEBHOOK_SECRET');

exports.entitlement = onRequest({region: 'southamerica-east1', cors: false,
  maxInstances: 10, invoker: 'public'}, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (req.method !== 'GET') return res.status(405).json({allowed: false});
  const auth = req.get('authorization') || '';
  if (!auth.startsWith('Bearer ')) return res.status(401).json({allowed: false});
  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(auth.substring(7), true);
  } catch (_) {
    return res.status(401).json({allowed: false});
  }
  const uid = decoded.uid;
  if (!uid || uid.includes('/')) return res.status(401).json({allowed: false});
  try {
    const doc = db.collection('entitlements').doc(uid);
    const data = await db.runTransaction(async tx => {
      const snapshot = await tx.get(doc);
      if (snapshot.exists) return snapshot.data();
      // Anchor the trial to the stable Google subject so Spark users and recreated
      // UIDs do not receive a fresh 7 days. No Google identity: per-UID, as before.
      const now = admin.firestore.Timestamp.now();
      const initial = await initializeTrial({db, tx, entitlementRef: doc, uid,
        subject: googleSubjectOf(decoded), nowMs: now.toMillis(),
        toTimestamp: admin.firestore.Timestamp.fromMillis});
      return initial;
    });
    const nowMs = Date.now();
    const trialMs = data.trialUntil?.toMillis?.() ?? 0;
    const paidMs = data.paidUntil?.toMillis?.() ?? 0;
    const allowed = trialMs > nowMs || paidMs > nowMs;
    // No payment link, paid status or secrets are accepted from the client.
    return res.status(200).json({uid, allowed,
      reason: paidMs > nowMs ? 'paid' : trialMs > nowMs ? 'trial' : 'expired'});
  } catch (error) {
    console.error('Entitlement query failed', error?.code || 'unknown');
    return res.status(503).json({allowed: false});
  }
});


// Experimental signed Mercado Pago notification receiver. This export is code only;
// it is not deployed or configured in production by this change.
exports.mercadoPagoWebhook = onRequest({
  region: 'southamerica-east1', cors: false, maxInstances: 10, invoker: 'public',
  secrets: [mpReceivingToken, mpWebhookSecret],
}, async (req, res) => {
  // Pause the NEW homologation receiver independently of purchase creation.
  // Disabling checkout alone must not silently enable historical claim grants.
  // Return retryable 503 before inbox writes or provider calls; do not acknowledge
  // financial notifications as processed while this receiver is paused.
  if (process.env.ROCHA_WEBHOOK_RECONCILIATION_ENABLED !== 'true') {
    res.set('Cache-Control', 'no-store');
    return res.status(503).json({received: false, paused: true});
  }
  const inbox = createFirestoreWebhookInbox({db, admin});
  const handler = createMercadoPagoWebhookHandler({
    secret: () => mpWebhookSecret.value(), inbox,
    reconcilePayment: async ({paymentId}) => {
      const accessToken = mpReceivingToken.value();
      if (process.env.ROCHA_CHECKOUT_ENABLED === 'true') {
        await bindCheckoutClaim({db, paymentId, accessToken});
      }
      return reconcileAndGrant({db, admin, paymentId, accessToken});
    },
  });
  await handler(req, res);
});

exports.checkout = onRequest({
  region: 'southamerica-east1', cors: false, maxInstances: 10, invoker: 'public',
  secrets: [mpReceivingToken],
}, async (req, res) => createCheckoutHandler({
  verifyToken: token => admin.auth().verifyIdToken(token, true),
  token: () => mpReceivingToken.value(),
  config: () => ({
    enabled: process.env.ROCHA_CHECKOUT_ENABLED === 'true',
    merchantId: process.env.ROCHA_CHECKOUT_MERCHANT_ID,
    mode: process.env.ROCHA_CHECKOUT_MODE,
    notificationUrl: process.env.ROCHA_CHECKOUT_WEBHOOK_URL,
  }),
  createOrder: (id, data) => db.collection('checkout_orders').doc(id).create(data),
  savePreference: (id, preferenceId) => db.collection('checkout_orders').doc(id).update({preferenceId}),
})(req, res));

