'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeTrial, googleSubjectOf} = require('./trial_anchor');
const DAY = 86400000;
const NOW = Date.parse('2026-11-14T12:00:00Z');

// In-memory Firestore/transaction double. Enforces reads-before-writes.
function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed));
  const log = [];
  const db = {collection: c => ({doc: id => ({key: c + '/' + id})})};
  const tx = {
    wrote: false,
    get: async ref => {
      assert.equal(tx.wrote, false, 'read after write');
      return {exists: store.has(ref.key), data: () => store.get(ref.key)};
    },
    create: (ref, data) => {
      assert.equal(store.has(ref.key), false, 'create over existing ' + ref.key);
      tx.wrote = true; store.set(ref.key, data); log.push(ref.key);
    },
  };
  return {db, tx, store, log};
}
const ms = v => (v && typeof v.toMillis === 'function' ? v.toMillis() : v);
const ts = v => ({toMillis: () => v});
const run = (f, uid, subject) => initializeTrial({db: f.db, tx: f.tx,
  entitlementRef: {key: 'entitlements/' + uid}, uid, subject, nowMs: NOW, toTimestamp: ts});

test('Spark trial started 5 days ago leaves 2 days', async () => {
  const f = fakeDb({'rochaSparkAccounts/s1': {trialStartedAt: ts(NOW - 5 * DAY)}});
  const r = await run(f, 'u1', 's1');
  assert.equal(ms(r.trialStartedAt), NOW - 5 * DAY);
  assert.equal(ms(r.trialUntil), NOW + 2 * DAY);
  assert.equal(ms(f.store.get('entitlements/u1').trialUntil), NOW + 2 * DAY);
  assert.equal(ms(f.store.get('trialAnchors/s1').trialStartedAt), NOW - 5 * DAY);
  assert.deepEqual(Object.keys(f.store.get('trialAnchors/s1')), ['trialStartedAt'], 'no UID linkage');
});

test('recreated uid with same subject reuses the anchor start', async () => {
  const f = fakeDb();
  await run(f, 'u1', 's2');
  f.tx.wrote = false;
  const later = initializeTrial({db: f.db, tx: f.tx, entitlementRef: {key: 'entitlements/u2'},
    uid: 'u2', subject: 's2', nowMs: NOW + 3 * DAY, toTimestamp: ts});
  const r = await later;
  assert.equal(ms(r.trialStartedAt), NOW);
  assert.equal(ms(r.trialUntil), NOW + 7 * DAY);
  assert.equal(ms(f.store.get('trialAnchors/s2').trialStartedAt), NOW);
});

test('future or invalid Spark trialStartedAt is ignored', async () => {
  for (const bad of [ts(NOW + DAY), 'yesterday', null, {}, NaN, ts(NaN)]) {
    const f = fakeDb({'rochaSparkAccounts/s3': {trialStartedAt: bad}});
    const r = await run(f, 'u3', 's3');
    assert.equal(ms(r.trialStartedAt), NOW);
    assert.equal(ms(f.store.get('trialAnchors/s3').trialStartedAt), NOW);
  }
});

test('no Google identity behaves as before and writes no anchor', async () => {
  for (const subject of [undefined, null, '', 'a/b', 42]) {
    const f = fakeDb({'rochaSparkAccounts/x': {trialStartedAt: ts(NOW - 5 * DAY)}});
    const r = await run(f, 'u4', subject);
    assert.equal(ms(r.trialStartedAt), NOW);
    assert.equal(ms(r.trialUntil), NOW + 7 * DAY);
    assert.deepEqual(f.log, ['entitlements/u4']);
  }
});

test('existing anchor is never overwritten and older Spark start still wins', async () => {
  const f = fakeDb({
    'trialAnchors/s5': {trialStartedAt: ts(NOW - 2 * DAY)},
    'rochaSparkAccounts/s5': {trialStartedAt: ts(NOW - 4 * DAY)},
  });
  const r = await run(f, 'u5', 's5');
  assert.equal(ms(r.trialStartedAt), NOW - 4 * DAY);
  assert.deepEqual(f.log, ['entitlements/u5']);
  assert.equal(ms(f.store.get('trialAnchors/s5').trialStartedAt), NOW - 2 * DAY);
});

test('never extends: trial start is never later than now', async () => {
  const f = fakeDb({'trialAnchors/s6': {trialStartedAt: ts(NOW + 9 * DAY)}});
  const r = await run(f, 'u6', 's6');
  assert.equal(ms(r.trialStartedAt), NOW);
});

test('googleSubjectOf reads the verified token identity safely', () => {
  assert.equal(googleSubjectOf({firebase: {identities: {'google.com': ['abc']}}}), 'abc');
  for (const t of [null, {}, {firebase: {}}, {firebase: {identities: {'google.com': []}}},
    {firebase: {identities: {'google.com': [7]}}}, {firebase: {identities: {'google.com': ['a/b']}}}]) {
    assert.equal(googleSubjectOf(t), null);
  }
});
