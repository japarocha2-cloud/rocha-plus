'use strict';
// Dedicated integration: real Firestore Emulator -> actual endpoint -> gate snapshots.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const {createSandbox, assertIsolation} = require('../../functions/sandbox/reconcile');
assertIsolation(process.env);
const sdkRequire = Module.createRequire(path.resolve('functions/package.json'));
const admin = sdkRequire('firebase-admin');
const {Timestamp} = admin.firestore;
const DAY = 86400000;
const START = Date.parse('2026-09-01T12:00:00Z');
const UID = 'sandbox-trial-gate';
let now = START;
const snapshots = [];
const payments = new Map([
  ['123', {id: '123', transaction_amount: 4.5}],
  ['456', {id: '456', transaction_amount: 49.5}],
].map(([id, value]) => [id, {...value, live_mode: false, status: 'approved',
  status_detail: 'accredited', collector_id: 999, currency_id: 'BRL',
  transaction_amount_refunded: 0, date_approved: '2026-09-08T12:00:00Z',
  date_last_updated: '2026-09-08T12:00:01Z'}]));
global.fetch = async () => { throw new Error('Outbound provider requests forbidden'); };

async function main() {
  const sandbox = await createSandbox({accessToken: 'TEST-fictional-only',
    fetchImpl: async (url, options) => {
      assert.equal(options.method, 'GET');
      const id = String(url).split('/').pop();
      assert.ok(payments.has(id));
      return {ok: true, json: async () => structuredClone(payments.get(id))};
    }});
  try {
    const {db, collections: c} = sandbox;
    const filename = path.resolve('functions/index.js');
    const compiled = new Module(filename, module);
    const firestore = () => ({collection(name) {
      assert.equal(name, 'entitlements');
      return db.collection(c.entitlements);
    }, runTransaction: callback => db.runTransaction(callback, {maxAttempts: 10})});
    firestore.Timestamp = {now: () => Timestamp.fromMillis(now), fromMillis: Timestamp.fromMillis};
    compiled.require = name => {
      if (name === 'firebase-functions/v2/https') return {onRequest: (_, handler) => handler};
      if (name === 'firebase-admin') return {initializeApp() {}, firestore,
        auth: () => ({verifyIdToken: async (token, revoked) => {
          assert.equal(token, 'fictional-token');
          assert.equal(revoked, true);
          return {uid: UID};
        }})};
      throw new Error('Unexpected endpoint dependency');
    };
    compiled._compile('module.exports = function(Date) { const exports = {};\n' +
      fs.readFileSync(filename, 'utf8') + '\nreturn exports; };', filename);
    const endpoint = compiled.exports(class extends Date {static now() {return now;}}).entitlement;
    async function read() {
      let status = 200;
      let body;
      const res = {set() {}, status(value) {status = value; return res;},
        json(value) {body = JSON.parse(JSON.stringify(value)); return res;}};
      await endpoint({method: 'GET', get: () => 'Bearer fictional-token'}, res);
      assert.equal(status, 200);
      assert.equal(body.uid, UID);
      return body;
    }
    async function record(name, allowed, reason) {
      const response = await read();
      assert.equal(response.allowed, allowed, name);
      assert.equal(response.reason, reason, name);
      snapshots.push({name, serverNow: now, response});
    }
    const initial = await Promise.all(Array.from({length: 4}, () => read()));
    for (const row of initial) {
      assert.equal(row.allowed, true);
      assert.equal(row.trialStartedAt, '2026-09-01T12:00:00.000Z');
      assert.equal(row.expiresAt, '2026-09-08T12:00:00.000Z');
    }
    assert.equal((await db.collection(c.entitlements).get()).size, 1);
    const original = (await db.collection(c.entitlements).doc(UID).get()).data();
    assert.equal(original.trialUntil.toMillis() - original.trialStartedAt.toMillis(), 7 * DAY);
    await record('initial', true, 'trial');
    now = START + 7 * DAY - 1;
    await record('one-ms-before', true, 'trial');
    now++;
    await record('exact-expiry', false, 'expired');
    now++;
    await record('after-expiry', false, 'expired');
    for (const [id, plan, amountCents] of [['123', 'monthly', 450], ['456', 'annual', 4950]]) {
      await db.collection(c.claims).doc(id).set({uid: UID, reviewed: true,
        plan, amountCents, merchantId: '999', currency: 'BRL'});
    }
    await sandbox.reconcile('123');
    await record('fictional-renewal', true, 'paid');
    assert.equal(snapshots.at(-1).response.expiresAt, '2026-10-08T12:00:00.000Z');
    await sandbox.reconcile('456');
    await record('independent-annual', true, 'paid');
    payments.set('123', {...payments.get('123'), status: 'refunded',
      date_last_updated: '2026-09-08T12:01:00Z'});
    await Promise.all([sandbox.reconcile('123'), sandbox.reconcile('123')]);
    await record('monthly-refund-preserves-annual', true, 'paid');
    assert.equal(snapshots.at(-1).response.expiresAt, '2027-09-08T12:00:00.000Z');
    payments.set('456', {...payments.get('456'), status: 'refunded',
      date_last_updated: '2026-09-08T12:02:00Z'});
    await sandbox.reconcile('456');
    await record('last-refund-blocks', false, 'expired');
    const final = (await db.collection(c.entitlements).doc(UID).get()).data();
    assert.ok(final.trialStartedAt.isEqual(original.trialStartedAt));
    assert.ok(final.trialUntil.isEqual(original.trialUntil));
    assert.equal((await db.collection(c.events).get()).size, 2);
    for (const name of ['entitlements', 'payment_claims', 'payment_events']) {
      assert.equal((await db.collection(name).get()).size, 0);
    }
    fs.writeFileSync('qa/trial-sandbox/evidence.json', JSON.stringify({
      project: 'demo-rocha-sandbox', firstRequests: 4, trialDocuments: 1,
      trialDurationMs: 7 * DAY, providerNetworkCalls: 0, snapshots,
      transactions: sandbox.evidence()}, null, 2));
    console.log('PASS: 8 endpoint snapshots, 4 concurrent first reads, one 604800000ms trial; no provider HTTP');
  } finally {
    await sandbox.close();
  }
}
main().catch(error => {console.error(error); process.exitCode = 1;});
