'use strict';
// Separate test-only path. No import from the production write/reconciliation modules.
const {randomUUID} = require('node:crypto');
const {entitlementFromLedger} = require('../entitlement_periods');
const PROJECT = 'demo-rocha-sandbox';
const COLLECTIONS = Object.freeze({claims: 'sandbox_payment_claims',
  events: 'sandbox_payment_events', entitlements: 'sandbox_entitlements'});

function assertIsolation(env) {
  if (env.GCLOUD_PROJECT !== PROJECT ||
      !/^127\.0\.0\.1:[1-9]\d{0,4}$/.test(env.FIRESTORE_EMULATOR_HOST || '') ||
      Number(env.FIRESTORE_EMULATOR_HOST.split(':')[1]) > 65535) {
    throw new Error('Sandbox requires its demo project and loopback Firestore Emulator');
  }
}
function sandboxToken(token) {
  if (typeof token !== 'string' || !/^TEST-[A-Za-z0-9-]+$/.test(token)) {
    throw new Error('Explicit TEST sandbox credential required');
  }
}
function timestamp(value) {
  if (typeof value !== 'string' || !/Z$|[+-]\d\d:\d\d$/.test(value) ||
      !Number.isFinite(Date.parse(value))) throw new Error('Invalid provider timestamp');
  return Date.parse(value);
}
async function fetchSandboxPayment(id, token, fetchImpl = global.fetch) {
  sandboxToken(token);
  if (!/^\d+$/.test(String(id))) throw new Error('Invalid sandbox payment ID');
  const response = await fetchImpl('https://api.mercadopago.com/v1/payments/' + id, {
    method: 'GET', redirect: 'error', signal: AbortSignal.timeout(12000),
    headers: {Authorization: 'Bearer ' + token, Accept: 'application/json'},
  });
  if (!response.ok) throw new Error('Sandbox provider lookup failed');
  const raw = await response.json();
  // Missing/null live_mode is NOT sandbox evidence. Never coerce the field.
  if (raw.live_mode !== false || String(raw.id) !== String(id)) {
    throw new Error('Sandbox mode or payment identity mismatch');
  }
  timestamp(raw.date_last_updated);
  return raw;
}
async function createSandbox({accessToken, fetchImpl = global.fetch, env = process.env}) {
  assertIsolation(env);
  // SDK also reads process.env: a caller-supplied map cannot redirect the actual SDK.
  assertIsolation(process.env);
  if (env.FIRESTORE_EMULATOR_HOST !== process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Sandbox emulator configuration mismatch');
  }
  sandboxToken(accessToken);
  const admin = require('firebase-admin');
  const app = admin.initializeApp({projectId: PROJECT}, 'sandbox-' + randomUUID());
  const db = app.firestore();
  db.settings({host: env.FIRESTORE_EMULATOR_HOST, ssl: false});
  let operations = 0;
  let attempts = 0;
  async function reconcile(id) {
    const raw = await fetchSandboxPayment(id, accessToken, fetchImpl);
    const updatedMs = timestamp(raw.date_last_updated);
    operations++;
    return db.runTransaction(async tx => {
      attempts++;
      const claimSnap = await tx.get(db.collection(COLLECTIONS.claims).doc(String(id)));
      const claim = claimSnap.data();
      if (!claimSnap.exists || claim.reviewed !== true ||
          typeof claim.uid !== 'string' || !/^sandbox-[A-Za-z0-9_-]+$/.test(claim.uid) ||
          !['monthly', 'annual'].includes(claim.plan) || claim.currency !== 'BRL' ||
          !Number.isSafeInteger(claim.amountCents) || claim.amountCents <= 0 ||
          typeof claim.merchantId !== 'string' || !/^\d+$/.test(claim.merchantId) ||
          String(raw.collector_id) !== claim.merchantId || raw.currency_id !== 'BRL' ||
          typeof raw.transaction_amount !== 'number' ||
          !Number.isFinite(raw.transaction_amount) ||
          Math.abs(raw.transaction_amount * 100 - claim.amountCents) > 1e-6) {
        throw new Error('Sandbox payment does not match independently reviewed claim');
      }
      const eventRef = db.collection(COLLECTIONS.events).doc(String(id));
      const accountRef = db.collection(COLLECTIONS.entitlements).doc(claim.uid);
      const [existing, account, ledger] = await Promise.all([
        tx.get(eventRef), tx.get(accountRef),
        tx.get(db.collection(COLLECTIONS.events).where('uid', '==', claim.uid)),
      ]);
      if (!account.exists) throw new Error('Sandbox trial must already exist');
      const records = ledger.docs.map(doc => {
        const row = doc.data();
        if (row.liveMode !== false || row.uid !== claim.uid || String(row.paymentId) !== doc.id) {
          throw new Error('Sandbox ledger identity or mode conflict');
        }
        return row;
      });
      const previous = existing.data();
      if (existing.exists && (previous.uid !== claim.uid || previous.liveMode !== false ||
          String(previous.paymentId) !== String(id))) throw new Error('Sandbox ownership conflict');
      if (existing.exists && (!Number.isFinite(previous.providerUpdatedMs) ||
          previous.plan !== claim.plan)) throw new Error('Sandbox ledger metadata conflict');
      const terminal = existing.exists && ['refunded', 'charged_back'].includes(previous.status);
      if (existing.exists && (updatedMs < previous.providerUpdatedMs ||
          terminal && !['refunded', 'charged_back'].includes(raw.status))) {
        return {ignored: true, reason: 'stale-or-terminal', previouslyRecorded: true};
      }
      const approved = raw.status === 'approved' && raw.status_detail === 'accredited' &&
        raw.transaction_amount_refunded === 0;
      if (approved) timestamp(raw.date_approved);
      const updated = {uid: claim.uid, paymentId: String(id), provider: 'mercadopago',
        liveMode: false, reviewed: true, plan: claim.plan, status: raw.status || 'unknown',
        eligibleForReview: approved, approvalDate: raw.date_approved || null,
        amount: raw.transaction_amount, currency: 'BRL', merchantId: claim.merchantId,
        providerUpdatedMs: updatedMs, checkedAt: admin.firestore.Timestamp.now()};
      const expiration = entitlementFromLedger(claim.uid,
        [...records.filter(row => row.paymentId !== String(id)), updated]);
      tx.set(eventRef, updated);
      tx.set(accountRef, {paidUntil: expiration
        ? admin.firestore.Timestamp.fromDate(new Date(expiration)) : null}, {merge: true});
      return {paidUntil: expiration, previouslyRecorded: existing.exists, ignored: false};
    }, {maxAttempts: 10});
  }
  return {db, reconcile, collections: COLLECTIONS,
    evidence: () => ({operations, attempts, retries: attempts - operations}),
    async close() { await db.terminate(); await app.delete(); }};
}
module.exports = {assertIsolation, sandboxToken, fetchSandboxPayment, createSandbox, PROJECT, COLLECTIONS};
