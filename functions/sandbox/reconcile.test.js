'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const fs = require('node:fs');
const {createSandbox, assertIsolation, fetchSandboxPayment, PROJECT} = require('./reconcile');
const fixture = id => ({id, live_mode: false, status: 'approved', status_detail: 'accredited',
  collector_id: 999, currency_id: 'BRL', transaction_amount: 4.5,
  transaction_amount_refunded: 0, date_approved: '2026-10-01T10:00:00Z',
  date_last_updated: '2026-10-01T10:00:01Z'});

test('sandbox rejects real credentials, remote databases, live/missing mode and ID mismatch', async () => {
  for (const env of [{}, {GCLOUD_PROJECT: 'rocha-plus', FIRESTORE_EMULATOR_HOST: '127.0.0.1:8086'},
    {GCLOUD_PROJECT: PROJECT, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443'},
    {GCLOUD_PROJECT: PROJECT, FIRESTORE_EMULATOR_HOST: '127.0.0.1:99999'}]) {
    assert.throws(() => assertIsolation(env));
  }
  let requests = 0;
  const noRequest = async () => { requests++; throw new Error('must not call provider'); };
  for (const token of ['', 'APP_USR-fixture', 'TEST-fixture\n']) {
    await assert.rejects(fetchSandboxPayment('123', token, noRequest), /credential/);
  }
  assert.equal(requests, 0);
  for (const change of [{live_mode: true}, {live_mode: null}, {live_mode: undefined}, {id: '999'}]) {
    await assert.rejects(fetchSandboxPayment('123', 'TEST-fixture', async () => ({ok: true,
      json: async () => ({...fixture('123'), ...change})})), /mode or payment identity/);
  }
});

test('production reconciler and eligibility guards remain live-only', () => {
  const {eligiblePayment} = require('../mercadopago_reconciliation');
  assert.equal(eligiblePayment({liveMode: false, status: 'approved', statusDetail: 'accredited',
    refundedAmount: 0, currency: 'BRL', amount: 4.5, dateApproved: '2026-10-01T10:00:00Z'}), false);
  // Pin the complete production write path, not just the mode predicate.
  const sha = file => createHash('sha256').update(fs.readFileSync(require.resolve(file))).digest('hex');
  assert.equal(sha('../reconcile_and_grant.js'), '6a0f76881536ca8500b2429284e9040fe7c321b3af41710acce07def53c8a4ec');
  assert.equal(sha('../mercadopago_reconciliation.js'), 'df95c818117a2f3dad370f5bd9fb32d00d4f77d836cfc83ee94706271c27011b');
});

test('sandbox purchase, renewal, refunds and replay with real local transactions', {timeout: 180000}, async t => {
  const payments = new Map([['123', fixture('123')], ['456', {...fixture('456'),
    date_approved: '2026-10-27T10:00:00Z', date_last_updated: '2026-10-27T10:00:01Z'}]]);
  const client = await createSandbox({accessToken: 'TEST-fixture', fetchImpl: async (url, options) => {
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    const match = /^https:\/\/api\.mercadopago\.com\/v1\/payments\/(123|456)$/.exec(String(url));
    assert.ok(match);
    return {ok: true, json: async () => structuredClone(payments.get(match[1]))};
  }});
  t.after(() => client.close());
  const {db, collections: c} = client;
  const {Timestamp} = require('firebase-admin').firestore;
  const trial = {trialStartedAt: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    trialUntil: Timestamp.fromDate(new Date('2026-09-08T00:00:00Z'))};
  const accountRef = db.collection(c.entitlements).doc('sandbox-account');
  await accountRef.set(trial);
  for (const id of ['123', '456']) await db.collection(c.claims).doc(id).set({
    uid: 'sandbox-account', reviewed: true, plan: 'monthly', merchantId: '999', currency: 'BRL', amountCents: 450,
  });
  const account = async () => (await accountRef.get()).data();
  const events = async () => (await db.collection(c.events).get()).docs;
  const run = id => client.reconcile(id);
  await t.test('purchase and concurrent duplicate delivery create exactly one payment event', async () => {
    const results = await Promise.all([run('123'), run('123'), run('123')]);
    assert.equal(results.filter(row => !row.previouslyRecorded).length, 1);
    assert.equal((await events()).length, 1);
    assert.equal((await account()).paidUntil.toDate().toISOString(), '2026-11-01T10:00:00.000Z');
  });
  await t.test('renewal uses new approval period and replay does not extend again', async () => {
    await Promise.all([run('123'), run('456')]);
    assert.equal((await run('456')).paidUntil, '2026-11-27T10:00:00.000Z');
    assert.equal((await events()).length, 2);
    assert.equal((await account()).paidUntil.toDate().toISOString(), '2026-11-27T10:00:00.000Z');
  });
  await t.test('refund replay retains independently valid renewal', async () => {
    payments.set('123', {...payments.get('123'), status: 'refunded', date_last_updated: '2026-10-28T10:00:00Z'});
    await Promise.all([run('123'), run('123'), run('456')]);
    assert.equal((await account()).paidUntil.toDate().toISOString(), '2026-11-27T10:00:00.000Z');
  });
  await t.test('stale approved response cannot resurrect a refunded payment', async () => {
    payments.set('123', fixture('123'));
    assert.equal((await run('123')).ignored, true);
    payments.set('123', {...fixture('123'), date_last_updated: '2026-10-28T11:00:00Z'});
    assert.equal((await run('123')).ignored, true);
    assert.equal((await db.collection(c.events).doc('123').get()).data().status, 'refunded');
  });
  await t.test('last refund removes paid access without restarting original expired trial', async () => {
    payments.set('456', {...payments.get('456'), status: 'refunded', date_last_updated: '2026-10-28T10:00:00Z'});
    await Promise.all([run('456'), run('456')]);
    const data = await account();
    assert.equal(data.paidUntil, null);
    assert.ok(data.trialStartedAt.isEqual(trial.trialStartedAt));
    assert.ok(data.trialUntil.isEqual(trial.trialUntil));
    assert.equal((await events()).length, 2);
  });
  await t.test('live response and wrong merchant cannot write sandbox or production collections', async () => {
    const before = await account();
    for (const change of [{live_mode: true}, {collector_id: 777}]) {
      payments.set('456', {...fixture('456'), ...change});
      await assert.rejects(run('456'));
      assert.deepEqual(await account(), before);
    }
    for (const name of ['entitlements', 'payment_claims', 'payment_events']) {
      assert.equal((await db.collection(name).get()).size, 0);
    }
  });
  t.diagnostic('Sandbox fixture / Firestore Emulator: ' + JSON.stringify(client.evidence()));
});
