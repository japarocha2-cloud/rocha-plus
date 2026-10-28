'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const DAY = 86400000;
const START = Date.parse('2026-10-27T12:00:00Z');

// Execute the actual HTTP export with isolated SDK boundaries. No credentials,
// remote Firebase, account mutation or payment provider are used.
function harness({uid = 'lab-user', rejectToken = false, failStore = false} = {}) {
  let now = START;
  const records = new Map();
  const verified = [];
  let writes = 0;
  const timestamp = ms => ({toMillis: () => ms});
  const firestore = () => ({
    collection: name => {
      assert.equal(name, 'entitlements');
      return {doc: key => ({key})};
    },
    runTransaction: async callback => {
      if (failStore) throw Object.assign(new Error('unavailable'), {code: 'unavailable'});
      return callback({
        get: async ref => ({exists: records.has(ref.key), data: () => records.get(ref.key)}),
        create: (ref, data) => {
          assert.equal(records.has(ref.key), false);
          records.set(ref.key, data);
          writes++;
        },
      });
    },
  });
  firestore.Timestamp = {now: () => timestamp(now), fromMillis: timestamp};
  const admin = {
    initializeApp() {},
    firestore,
    auth: () => ({verifyIdToken: async (token, revoked) => {
      verified.push({token, revoked});
      if (rejectToken) throw new Error('invalid token');
      return {uid};
    }}),
  };
  const exported = {};
  vm.runInNewContext(fs.readFileSync(require.resolve('./index.js'), 'utf8'), {
    exports: exported,
    require: name => {
      if (name === 'firebase-admin') return admin;
      if (name === 'firebase-functions/v2/https') {
        return {onRequest: (options, handler) => handler};
      }
      throw new Error('Unexpected dependency');
    },
    Date: class extends Date { static now() { return now; } },
    console: {error() {}},
  }, {filename: 'index.js'});
  return {
    records, verified, timestamp,
    setNow: value => { now = value; },
    writes: () => writes,
    async request({method = 'GET', authorization = 'Bearer lab-token', ...extra} = {}) {
      const response = {statusCode: 200, headers: {}, body: undefined};
      const res = {
        set: (key, value) => {response.headers[key] = value;},
        status: code => {response.statusCode = code; return res;},
        json: value => {response.body = JSON.parse(JSON.stringify(value)); return res;},
      };
      await exported.entitlement({
        method, get: name => name === 'authorization' ? authorization : undefined,
        ...extra,
      }, res);
      assert.equal(response.headers['Cache-Control'], 'no-store');
      return response;
    },
  };
}

test('actual endpoint creates exactly seven days and repeated access never resets trial', async () => {
  const h = harness();
  const first = await h.request();
  assert.equal(first.statusCode, 200);
  assert.deepEqual(first.body, {uid: 'lab-user', allowed: true, reason: 'trial',
    expiresAt: '2026-11-03T12:00:00.000Z', trialStartedAt: '2026-10-27T12:00:00.000Z'});
  const record = h.records.get('lab-user');
  assert.equal(record.trialStartedAt.toMillis(), START);
  assert.equal(record.trialUntil.toMillis(), START + 7 * DAY);
  h.setNow(START + 6 * DAY);
  assert.equal((await h.request()).body.reason, 'trial');
  assert.equal(h.records.get('lab-user'), record);
  assert.equal(h.writes(), 1);
  assert.deepEqual(h.verified, [
    {token: 'lab-token', revoked: true}, {token: 'lab-token', revoked: true},
  ]);
});

test('actual endpoint denies exactly at trial expiry and does not recreate expired record', async () => {
  const h = harness();
  await h.request();
  h.setNow(START + 7 * DAY - 1);
  assert.equal((await h.request()).body.allowed, true);
  h.setNow(START + 7 * DAY);
  assert.deepEqual((await h.request()).body,
    {uid: 'lab-user', allowed: false, reason: 'expired',
      expiresAt: '2026-11-03T12:00:00.000Z', trialStartedAt: '2026-10-27T12:00:00.000Z'});
  h.setNow(START + 8 * DAY);
  assert.equal((await h.request()).body.allowed, false);
  assert.equal(h.writes(), 1);
});

test('actual endpoint distinguishes paid access and falls back to a still-valid trial', async () => {
  const h = harness();
  h.records.set('lab-user', {
    trialUntil: h.timestamp(START + 7 * DAY),
    paidUntil: h.timestamp(START + DAY),
  });
  assert.equal((await h.request()).body.reason, 'paid');
  assert.equal((await h.request()).body.expiresAt, '2026-10-28T12:00:00.000Z');
  h.setNow(START + DAY);
  assert.equal((await h.request()).body.reason, 'trial');
  assert.equal((await h.request()).body.expiresAt, '2026-11-03T12:00:00.000Z');
  h.setNow(START + 7 * DAY);
  assert.equal((await h.request()).body.reason, 'expired');
  assert.equal(h.writes(), 0);
});

test('actual endpoint returns no invented dates for an existing undated record', async () => {
  const h = harness();
  h.records.set('lab-user', {});
  assert.deepEqual((await h.request()).body, {
    uid: 'lab-user', allowed: false, reason: 'expired', expiresAt: null, trialStartedAt: null,
  });
  assert.equal(h.writes(), 0);
});

test('actual endpoint preserves valid paid access after trial expiry and denies at paid expiry', async () => {
  const h = harness();
  h.records.set('lab-user', {
    trialUntil: h.timestamp(START - DAY),
    paidUntil: h.timestamp(START + DAY),
  });
  assert.deepEqual((await h.request()).body,
    {uid: 'lab-user', allowed: true, reason: 'paid',
      expiresAt: '2026-10-28T12:00:00.000Z', trialStartedAt: null});
  h.setNow(START + DAY);
  assert.equal((await h.request()).body.allowed, false);
});

test('actual endpoint uses verified UID and ignores client-supplied payment or identity', async () => {
  const h = harness();
  h.records.set('lab-user', {trialUntil: h.timestamp(START)});
  const response = await h.request({
    body: {uid: 'other', allowed: true, paidUntil: '2099-01-01', reason: 'paid'},
    query: {uid: 'other', paid: 'true'},
  });
  assert.deepEqual(response.body, {uid: 'lab-user', allowed: false, reason: 'expired',
    expiresAt: '2026-10-27T12:00:00.000Z', trialStartedAt: null});
  assert.equal(h.records.has('other'), false);
  assert.equal(h.writes(), 0);
});

test('actual endpoint rejects missing, malformed, revoked tokens and invalid UID without writes', async () => {
  for (const authorization of ['', 'Basic token', 'bearer token']) {
    const h = harness();
    assert.equal((await h.request({authorization})).statusCode, 401);
    assert.equal(h.verified.length, 0);
    assert.equal(h.writes(), 0);
  }
  for (const options of [{rejectToken: true}, {uid: ''}, {uid: 'bad/path'}]) {
    const h = harness(options);
    assert.equal((await h.request()).statusCode, 401);
    assert.equal(h.writes(), 0);
  }
});

test('actual endpoint rejects mutations and fails closed on storage errors', async () => {
  const h = harness();
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
    const response = await h.request({method});
    assert.equal(response.statusCode, 405);
    assert.deepEqual(response.body, {allowed: false});
  }
  assert.equal(h.verified.length, 0);
  assert.equal(h.writes(), 0);
  const failed = harness({failStore: true});
  const response = await failed.request();
  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.body, {allowed: false});
  assert.equal(failed.writes(), 0);
});
