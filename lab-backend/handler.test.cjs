'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHandler} = require('./handler.cjs');
const time = 1800000000000;
const timestamp = n => ({toMillis: () => n});
async function call({data, exists = true, claims = {}, failAuth = false,
  project = 'rocha-plus-homologacao', method = 'GET', bearer = 'Bearer fixture', failRead = false} = {}) {
  const calls = [];
  const auth = {verifyIdToken: async (token, revoked) => {
    calls.push(['verify', revoked]);
    if (failAuth) throw new Error('revoked');
    return {uid: 'fixture', firebase: {sign_in_provider: 'google.com'}, ...claims};
  }};
  const db = {collection: name => {assert.equal(name, 'entitlements'); return {
    doc: uid => {assert.equal(uid, 'fixture'); return {get: async () => {
      calls.push(['read']); if (failRead) throw new Error('offline');
      return {exists, data: () => data || {}};
    }};},
  };}};
  const res = {set() {}, status(n) {this.code = n; return this;}, json(body) {this.body = body; return this;}};
  await createHandler({auth, db, projectId: () => project, now: () => time})(
    {method, get: () => bearer}, res);
  return {...res, calls};
}
test('missing record denies without a create/update/transaction API', async () => {
  const r = await call({exists: false});
  assert.equal(r.code, 200); assert.equal(r.body.allowed, false);
  assert.equal(r.body.readOnly, true); assert.deepEqual(r.calls, [['verify', true], ['read']]);
});
test('existing trial and paid access use server dates and bounded lifetime', async () => {
  for (const field of ['trialUntil', 'paidUntil']) {
    const data = {[field]: timestamp(time + 90000)};
    const r = await call({data});
    assert.equal(r.body.allowed, true); assert.equal(r.body.validForMs, 60000);
    assert.equal(r.body.reason, field === 'paidUntil' ? 'paid' : 'trial');
  }
});
test('exact expiry denies and does not renew', async () => {
  const r = await call({data: {trialUntil: timestamp(time)}});
  assert.equal(r.body.allowed, false); assert.equal(r.body.validForMs, 0);
});
test('revoked and anonymous tokens, malformed uid and absent bearer deny', async () => {
  for (const options of [{failAuth: true}, {claims: {firebase: {sign_in_provider: 'anonymous'}}},
    {claims: {uid: '../bad'}}, {bearer: ''}]) {
    const r = await call(options); assert.equal(r.code, 401);
    assert.ok(!r.calls.some(c => c[0] === 'read'));
  }
});
test('only a verified boolean admin claim grants exemption', async () => {
  const ok = await call({claims: {rochaAdmin: true}});
  assert.equal(ok.body.reason, 'admin'); assert.equal(ok.calls.length, 1);
  assert.equal((await call({claims: {rochaAdmin: 'true'}})).body.allowed, false);
});
test('wrong project and mutating methods never read accounts', async () => {
  for (const options of [{project: 'rocha-plus'}, {method: 'POST'}, {method: 'DELETE'}]) {
    const r = await call(options); assert.equal(r.body.allowed, false); assert.equal(r.calls.length, 0);
  }
});
test('storage errors and invalid dates deny', async () => {
  for (const options of [{failRead: true}, {data: {paidUntil: 'tomorrow'}},
    {data: {trialUntil: timestamp(NaN)}}]) {
    const r = await call(options); assert.equal(r.code, 503); assert.equal(r.body.allowed, false);
  }
});
