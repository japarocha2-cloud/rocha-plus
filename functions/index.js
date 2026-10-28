'use strict';

// Experimental entitlement API. Deploy only to the intended Firebase project.
// Payment records are server-owned; no client can grant themselves paid access.
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
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
    const reason = paidMs > nowMs ? 'paid' : trialMs > nowMs ? 'trial' : 'expired';
    // Dates describe server-owned records; clients must still use `allowed`.
    const iso = ms => Number.isFinite(ms) && ms > 0 && ms <= 8640000000000000
      ? new Date(ms).toISOString() : null;
    const expiresAt = iso(reason === 'paid' ? paidMs : reason === 'trial'
      ? trialMs : Math.max(trialMs, paidMs));
    // No payment link, paid status or secrets are accepted from the client.
    return res.status(200).json({uid, allowed,
      reason, expiresAt, trialStartedAt: iso(data.trialStartedAt?.toMillis?.() ?? 0)});
  } catch (error) {
    console.error('Entitlement query failed', error?.code || 'unknown');
    return res.status(503).json({allowed: false});
  }
});
