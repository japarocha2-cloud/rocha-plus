'use strict';

// Experimental entitlement API. Deploy only to the intended Firebase project.
// Payment records are server-owned; no client can grant themselves paid access.
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
const {defineSecret} = require('firebase-functions/params');
const {createMercadoPagoWebhookHandler} = require('./mercadopago_webhook');
const {reconcileAndGrant} = require('./reconcile_and_grant');
const mpReceivingToken = defineSecret('MP_RECEIVING_ACCESS_TOKEN');
const mpWebhookSecret = defineSecret('MP_WEBHOOK_SECRET');

const TRIAL_MS = 7 * 24 * 60 * 60 * 1000;

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
      const now = admin.firestore.Timestamp.now();
      const trialUntil = admin.firestore.Timestamp.fromMillis(now.toMillis() + TRIAL_MS);
      const initial = {trialStartedAt: now, trialUntil, createdAt: now};
      tx.create(doc, initial);
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
  const inbox = {
    begin: ({notificationId, paymentId, action}) => db.runTransaction(async tx => {
      const ref = db.collection('mercadoPagoWebhookInbox').doc(notificationId);
      const snap = await tx.get(ref);
      if (snap.exists) {
        if (snap.data().paymentId !== paymentId) throw new Error('notification-conflict');
        return snap.data();
      }
      const row = {provider: 'mercadopago', paymentId, action, status: 'received',
        createdAt: admin.firestore.Timestamp.now()};
      tx.create(ref, row);
      return row;
    }),
    finish: ({notificationId, status, reason}) => db
      .collection('mercadoPagoWebhookInbox').doc(notificationId)
      .set({status, reason, updatedAt: admin.firestore.Timestamp.now()}, {merge: true}),
  };
  const handler = createMercadoPagoWebhookHandler({
    secret: () => mpWebhookSecret.value(), inbox,
    reconcilePayment: ({paymentId}) => reconcileAndGrant({
      db, admin, paymentId, accessToken: mpReceivingToken.value(),
    }),
  });
  await handler(req, res);
});
