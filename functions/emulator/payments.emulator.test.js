'use strict';
// Firestore EMULATOR integration for the payment fixes (fronts A and B).
// Demo project, simulated data only. Real: index.js handlers, Firestore
// transactions, webhook inbox/leases and the unified firestore.rules.
// Replaced in-process: ID-token verification and the provider payment lookup.
//
// Run from the repository root (config is NOT firebase.json, so deploy ignores it):
//   npx --yes firebase-tools@latest emulators:exec --only firestore \
//     --project demo-rocha-pagamento-lab --config firebase.emulator.json \
//     'node --test functions/emulator/payments.emulator.test.js'
const test = require('node:test');
const assert = require('node:assert/strict');
const {createHmac} = require('node:crypto');

const PROJECT = 'demo-rocha-pagamento-lab';
const HOST = '127.0.0.1:8087';
if (process.env.FIRESTORE_EMULATOR_HOST !== HOST || process.env.GCLOUD_PROJECT !== PROJECT ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  throw Error('isolated-emulator-required');
}
const SECRET = 'fixture-webhook-secret-2026';
process.env.ROCHA_WEBHOOK_RECONCILIATION_ENABLED = 'true';
process.env.MP_WEBHOOK_SECRET = SECRET;
process.env.MP_RECEIVING_ACCESS_TOKEN = 'fixture-not-a-real-token';
delete process.env.ROCHA_CHECKOUT_ENABLED;

// Network guard: only the local emulator; provider lookups answered from fixtures.
const localFetch = global.fetch;
const providerPayments = {};
global.fetch = async (url, init) => {
  const u = new URL(String(url));
  if (u.host === HOST) return localFetch(url, init);
  if (u.host === 'api.mercadopago.com' && u.pathname.startsWith('/v1/payments/')) {
    const p = providerPayments[u.pathname.split('/').pop()];
    return {ok: !!p, status: p ? 200 : 404, json: async () => ({...p})};
  }
  throw Error('network-blocked: ' + u.host);
};

const admin = require('firebase-admin');
const fns = require('../index.js'); // calls admin.initializeApp() for the demo project
const db = admin.firestore();
const tokens = {};
// admin.auth() returns the same cached Auth instance that index.js uses.
admin.auth().verifyIdToken = async t => {
  if (!tokens[t]) throw Error('invalid token'); return tokens[t];
};
const google = (uid, subject) => ({uid, firebase: {identities: {'google.com': [subject]},
  sign_in_provider: 'google.com'}});

const DAY = 86400000;
const ts = '1793746800';
function response() {
  return {headers: {}, statusCode: 0, body: null, set(k, v) { this.headers[k] = v; return this; },
    setHeader(k, v) { this.headers[k] = v; }, getHeader(k) { return this.headers[k]; },
    status(c) { this.statusCode = c; return this; }, json(v) { this.body = v; return this; },
    send(v) { this.body = v; return this; }, end() { return this; }, on() {}};
}
async function entitlement(token) {
  const req = {method: 'GET', headers: {authorization: 'Bearer ' + token},
    get: h => (h.toLowerCase() === 'authorization' ? 'Bearer ' + token : undefined)};
  const res = response(); await fns.entitlement(req, res); return res;
}
async function deliver(paymentId, notificationId) {
  const manifest = 'id:' + paymentId + ';request-id:rq-1;ts:' + ts + ';';
  const headers = {'x-request-id': 'rq-1',
    'x-signature': 'ts=' + ts + ',v1=' + createHmac('sha256', SECRET).update(manifest).digest('hex')};
  const req = {method: 'POST', headers, get: h => headers[h.toLowerCase()],
    query: {'data.id': paymentId}, body: {id: notificationId, type: 'payment', data: {id: paymentId}}};
  const res = response(); await fns.mercadoPagoWebhook(req, res); return res;
}
const pay = (id, amount, approvedIso) => ({id, status: 'approved', status_detail: 'accredited',
  live_mode: true, collector_id: 999, transaction_amount: amount, transaction_amount_refunded: 0,
  currency_id: 'BRL', date_approved: approvedIso});
const claim = (uid, plan, cents) => ({uid, reviewed: true, plan, currency: 'BRL', amountCents: cents,
  merchantId: '999'});
const iso = v => (v?.toDate ? v.toDate().toISOString() : v);
async function reset() {
  await localFetch(`http://${HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: 'DELETE'});
  for (const k of Object.keys(providerPayments)) delete providerPayments[k];
}
async function startTrial(uid) {
  tokens['t-' + uid] = google(uid, 'g-' + uid);
  assert.equal((await entitlement('t-' + uid)).statusCode, 200);
}

// ---------------- Front A: trial never restarts ----------------
test('update from the current app keeps the trial already started (5 days ago -> 2 left)', async () => {
  await reset();
  const started = Date.now() - 5 * DAY;
  await db.doc('rochaSparkAccounts/g-1').set({trialStartedAt: admin.firestore.Timestamp.fromMillis(started),
    welcomeAcceptedAt: null});
  tokens.a = google('uid-update', 'g-1');
  const res = await entitlement('a');
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.reason, 'trial');
  const ent = (await db.doc('entitlements/uid-update').get()).data();
  assert.equal(ent.trialUntil.toMillis(), started + 7 * DAY);
  assert.equal((await entitlement('a')).statusCode, 200); // second call never resets
  assert.equal((await db.doc('entitlements/uid-update').get()).data().trialUntil.toMillis(),
    started + 7 * DAY);
});

test('reinstall with a recreated Firebase UID reuses the same trial start', async () => {
  await reset();
  tokens.first = google('uid-old', 'g-2');
  await entitlement('first');
  const first = (await db.doc('entitlements/uid-old').get()).data().trialUntil.toMillis();
  tokens.second = google('uid-recreated', 'g-2');
  await entitlement('second');
  assert.equal((await db.doc('entitlements/uid-recreated').get()).data().trialUntil.toMillis(), first);
  const anchor = (await db.doc('trialAnchors/g-2').get()).data();
  assert.deepEqual(Object.keys(anchor), ['trialStartedAt']);
});

// ---------------- Front B: provider confirmation recognised ----------------
test('approved before the claim: 503 (provider retries), then recognised on redelivery', async () => {
  await reset();
  await startTrial('u1');
  providerPayments['5001'] = pay('5001', 7.9, '2026-11-01T10:00:00Z');
  const early = await deliver('5001', '101');
  assert.equal(early.statusCode, 503);
  const inbox = (await db.doc('mercadoPagoWebhookInbox/101').get()).data();
  assert.equal(inbox.status, 'retryable_failure');
  assert.equal(inbox.attempts, 1);
  await db.doc('payment_claims/5001').set(claim('u1', 'monthly', 790));
  const later = await deliver('5001', '101');
  assert.equal(later.statusCode, 200);
  assert.equal(iso((await db.doc('entitlements/u1').get()).data().paidUntil), '2026-12-01T10:00:00.000Z');
});

test('monthly + annual in both orders give 13 months (stacked policy)', async () => {
  const results = [];
  for (const order of [['6001', '6002'], ['6002', '6001']]) {
    await reset();
    await startTrial('u2');
    providerPayments['6001'] = pay('6001', 7.9, '2026-01-20T10:00:00Z');
    providerPayments['6002'] = pay('6002', 86.9, '2026-02-10T10:00:00Z');
    await db.doc('payment_claims/6001').set(claim('u2', 'monthly', 790));
    await db.doc('payment_claims/6002').set(claim('u2', 'annual', 8690));
    for (const id of order) assert.equal((await deliver(id, id + '0')).statusCode, 200);
    results.push(iso((await db.doc('entitlements/u2').get()).data().paidUntil));
  }
  assert.deepEqual(results, ['2027-02-20T10:00:00.000Z', '2027-02-20T10:00:00.000Z']);
});

test('duplicate notification does not extend access', async () => {
  await reset();
  await startTrial('u3');
  providerPayments['7001'] = pay('7001', 7.9, '2026-11-01T10:00:00Z');
  await db.doc('payment_claims/7001').set(claim('u3', 'monthly', 790));
  assert.equal((await deliver('7001', '701')).statusCode, 200);
  const first = iso((await db.doc('entitlements/u3').get()).data().paidUntil);
  const dup = await deliver('7001', '701');
  assert.equal(dup.statusCode, 200);
  assert.equal(dup.body.duplicate, true);
  assert.equal((await deliver('7001', '702')).statusCode, 200); // new notice, same payment
  assert.equal(iso((await db.doc('entitlements/u3').get()).data().paidUntil), first);
});

test('missing claim: 9 deliveries retry (503), the 10th is parked for review (200)', async () => {
  await reset();
  await startTrial('u4');
  providerPayments['8001'] = pay('8001', 7.9, '2026-11-01T10:00:00Z');
  for (let i = 1; i <= 9; i++) assert.equal((await deliver('8001', '801')).statusCode, 503, `try ${i}`);
  const tenth = await deliver('8001', '801');
  assert.equal(tenth.statusCode, 200);
  const inbox = (await db.doc('mercadoPagoWebhookInbox/801').get()).data();
  assert.equal(inbox.status, 'review_required');
  assert.equal(inbox.reason, 'payment_association_timeout');
  assert.equal(inbox.attempts, 10);
});

test('missing claim first seen more than 48 hours ago is parked for review (200)', async () => {
  await reset();
  await startTrial('u5');
  providerPayments['9001'] = pay('9001', 7.9, '2026-11-01T10:00:00Z');
  await db.doc('mercadoPagoWebhookInbox/901').set({provider: 'mercadopago', paymentId: '9001',
    status: 'retryable_failure', attempts: 2,
    firstSeenAt: admin.firestore.Timestamp.fromMillis(Date.now() - 49 * 3600000)});
  const res = await deliver('9001', '901');
  assert.equal(res.statusCode, 200);
  assert.equal((await db.doc('mercadoPagoWebhookInbox/901').get()).data().reason,
    'payment_association_timeout');
});

// ---------------- Unified rules (client access through the emulator) ----------------
function clientToken(uid, subject, verified = true) {
  const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return b64({alg: 'none', typ: 'JWT'}) + '.' + b64({iss: 'https://securetoken.google.com/' + PROJECT,
    aud: PROJECT, sub: uid, user_id: uid, iat: now, exp: now + 3600, auth_time: now,
    email_verified: verified, firebase: {sign_in_provider: 'google.com',
      identities: {'google.com': [subject]}}}) + '.';
}
async function clientGet(path, token) {
  return (await localFetch(`http://${HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${path}`,
    {headers: {Authorization: 'Bearer ' + token}})).status;
}
test('unified rules: app rules preserved, payment collections closed to clients', async () => {
  await reset();
  await db.doc('rochaSparkAccounts/g-9').set({trialStartedAt: admin.firestore.Timestamp.now(),
    welcomeAcceptedAt: null});
  for (const p of ['entitlements/uid-9', 'trialAnchors/g-9', 'payment_claims/1', 'payment_events/1',
    'checkout_orders/1', 'mercadoPagoWebhookInbox/1', 'mercadoPagoWebhookLocks/1',
    'rochaBillingUsers/1']) await db.doc(p).set({fixture: true});
  const owner = clientToken('uid-9', 'g-9');
  const other = clientToken('uid-x', 'g-x');
  assert.equal(await clientGet('rochaSparkAccounts/g-9', owner), 200, 'Spark owner read preserved');
  assert.equal(await clientGet('rochaSparkAccounts/g-9', other), 403);
  assert.equal(await clientGet('users/uid-9/favorites/' + 'a'.repeat(64), owner), 404, 'favorites rule preserved');
  assert.equal(await clientGet('users/uid-9/favorites/' + 'a'.repeat(64), other), 403);
  for (const p of ['entitlements/uid-9', 'trialAnchors/g-9', 'payment_claims/1', 'payment_events/1',
    'checkout_orders/1', 'mercadoPagoWebhookInbox/1', 'mercadoPagoWebhookLocks/1', 'rochaBillingUsers/1']) {
    assert.equal(await clientGet(p, owner), 403, p + ' closed');
  }
});
