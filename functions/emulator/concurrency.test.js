'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');

// Fail before initializing any SDK unless explicitly pointed at the local demo.
const PROJECT = 'demo-rocha-concurrency';
if (process.env.GCLOUD_PROJECT !== PROJECT ||
    !/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) {
  throw new Error('Requires loopback Firestore Emulator and demo-rocha-concurrency project');
}
const admin = require('firebase-admin');
const app = admin.initializeApp({projectId: PROJECT}, 'concurrency-test');
const db = app.firestore();
const {Timestamp} = admin.firestore;
const {reconcileAndGrant} = require('../reconcile_and_grant');
const START = Date.parse('2026-10-28T12:00:00Z');
const DAY = 86400000;

function endpoint() {
  let now = START;
  const filename = require.resolve('../index.js');
  const compiled = new Module(filename, module);
  const firestore = () => db;
  firestore.Timestamp = {now: () => Timestamp.fromMillis(now), fromMillis: Timestamp.fromMillis};
  // Compile in the SDK's JS realm: VM-created objects are rejected by Firestore's
  // plain-object validator. Only authentication and the server clock are fixtures.
  compiled.require = name => {
      if (name === 'firebase-functions/v2/https') return {onRequest: (_, handler) => handler};
      if (name === 'firebase-admin') return {initializeApp() {}, firestore,
        auth: () => ({verifyIdToken: async token => ({uid: token})})};
      throw new Error('Unexpected dependency');
  };
  // A local module parameter supplies Date without changing the SDK/global clock.
  const source = fs.readFileSync(filename, 'utf8');
  compiled._compile('module.exports = function(Date) { const exports = {};\n' +
    source + '\nreturn exports; };', filename);
  const exported = compiled.exports(class extends Date { static now() { return now; } });
  return {
    setNow(value) { now = value; },
    async read(uid) {
      let status = 200;
      let body;
      const res = {set() {}, status(code) { status = code; return res; },
        json(value) { body = JSON.parse(JSON.stringify(value)); return res; }};
      await exported.entitlement({method: 'GET', get: () => 'Bearer ' + uid}, res);
      assert.equal(status, 200);
      return body;
    },
  };
}

// Count SDK transaction callback invocations without replacing the transaction.
function observedDb() {
  let operations = 0;
  let attempts = 0;
  return {
    collection: name => db.collection(name),
    runTransaction(callback) {
      operations++;
      return db.runTransaction(tx => { attempts++; return callback(tx); }, {maxAttempts: 10});
    },
    evidence: () => ({operations, attempts, retries: attempts - operations}),
  };
}

const payment = (id, annual = false) => ({id, status: 'approved', status_detail: 'accredited',
  live_mode: true, collector_id: 999, transaction_amount: annual ? 49.5 : 4.5,
  transaction_amount_refunded: 0, currency_id: 'BRL', date_approved: '2026-10-27T10:00:00Z'});

test('real Firestore Emulator transactions preserve trials and concurrent reconciliation',
  {timeout: 180000}, async t => {
    t.after(async () => { await db.terminate(); await app.delete(); });
    const api = endpoint();
    await t.test('competing first reads persist one seven-day trial and deny at exact expiry', async () => {
      const responses = await Promise.all(Array.from({length: 4}, () => api.read('trial-race')));
      for (const response of responses) {
        assert.equal(response.allowed, true);
        assert.equal(response.trialStartedAt, '2026-10-28T12:00:00.000Z');
        assert.equal(response.expiresAt, '2026-11-04T12:00:00.000Z');
      }
      const before = (await db.doc('entitlements/trial-race').get()).data();
      assert.equal(before.trialUntil.toMillis() - before.trialStartedAt.toMillis(), 7 * DAY);
      api.setNow(START + 7 * DAY);
      assert.equal((await api.read('trial-race')).allowed, false);
      assert.deepEqual((await db.doc('entitlements/trial-race').get()).data(), before);
      api.setNow(START);
    });

    const payments = new Map([['123', payment('123')], ['456', payment('456', true)]]);
    const originalFetch = global.fetch;
    t.after(() => { global.fetch = originalFetch; });
    // Provider is a fixture boundary: no HTTP request or sandbox/live money moves.
    global.fetch = async url => {
      const match = /^https:\/\/api\.mercadopago\.com\/v1\/payments\/(123|456)$/.exec(String(url));
      assert.ok(match, 'unexpected outbound provider request');
      return {ok: true, json: async () => structuredClone(payments.get(match[1]))};
    };
    const originalTrial = {createdAt: Timestamp.fromMillis(START - 8 * DAY),
      trialStartedAt: Timestamp.fromMillis(START - 8 * DAY), trialUntil: Timestamp.fromMillis(START - DAY)};
    await db.doc('entitlements/paid-race').set(originalTrial);
    for (const [id, annual] of [['123', false], ['456', true]]) {
      await db.doc('payment_claims/' + id).set({uid: 'paid-race', reviewed: true,
        plan: annual ? 'annual' : 'monthly', currency: 'BRL',
        amountCents: annual ? 4950 : 450, merchantId: '999'});
    }
    const observed = observedDb();
    const run = paymentId => reconcileAndGrant({db: observed, admin, paymentId, accessToken: 'fixture-only'});
    const account = async () => (await db.doc('entitlements/paid-race').get()).data();
    const ledger = async () => (await db.collection('payment_events').where('uid', '==', 'paid-race').get()).docs;
    const preservedTrial = async () => {
      const data = await account();
      for (const key of Object.keys(originalTrial)) assert.ok(data[key].isEqual(originalTrial[key]));
    };

    await t.test('same payment in competing transactions creates one event without stacking', async () => {
      const results = await Promise.all([run('123'), run('123'), run('123')]);
      for (const result of results) assert.equal(result.paidUntil, '2026-11-27T10:00:00.000Z');
      assert.equal(results.filter(result => !result.previouslyRecorded).length, 1);
      assert.equal((await ledger()).length, 1);
      assert.equal((await account()).paidUntil.toDate().toISOString(), '2026-11-27T10:00:00.000Z');
      await preservedTrial();
    });
    await t.test('different payment IDs racing for one account preserve latest annual end', async () => {
      await Promise.all([run('123'), run('456')]);
      assert.equal((await ledger()).length, 2);
      assert.equal((await account()).paidUntil.toDate().toISOString(), '2027-10-27T10:00:00.000Z');
      const response = await api.read('paid-race');
      assert.equal(response.allowed, true);
      assert.equal(response.reason, 'paid');
      assert.equal(response.expiresAt, '2027-10-27T10:00:00.000Z');
      await preservedTrial();
    });
    await t.test('concurrent refund replay preserves independent annual access', async () => {
      payments.get('123').status = 'refunded';
      await Promise.all([run('123'), run('123'), run('456')]);
      assert.equal((await db.doc('payment_events/123').get()).data().status, 'refunded');
      assert.equal((await ledger()).length, 2);
      assert.equal((await account()).paidUntil.toDate().toISOString(), '2027-10-27T10:00:00.000Z');
      await preservedTrial();
    });
    await t.test('refunding last valid plan blocks access without restarting trial', async () => {
      payments.get('456').status = 'refunded';
      await Promise.all([run('456'), run('456')]);
      assert.equal((await db.doc('payment_events/456').get()).data().status, 'refunded');
      assert.equal((await account()).paidUntil, null);
      assert.equal((await ledger()).length, 2);
      assert.equal((await api.read('paid-race')).allowed, false);
      await preservedTrial();
    });
    t.diagnostic('Firestore SDK transaction evidence: ' + JSON.stringify(observed.evidence()));
  });
