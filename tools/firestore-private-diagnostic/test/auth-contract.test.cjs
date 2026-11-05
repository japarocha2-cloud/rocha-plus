'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');
const {verifyGoogleIdToken} = require('../verify-owner-token.cjs');
const {createOperatorAuthenticator} = require('../functions-firestore-diagnostic/operator-auth');
const {createDiagnosticHandler} = require('../functions-firestore-diagnostic/diagnostic');

const NOW = 1_800_000_000;
const AUDIENCE = 'https://diagnostic-example.a.run.app';
const EMAIL = 'diagnostic-caller@example.iam.gserviceaccount.com';
const {privateKey, publicKey} = crypto.generateKeyPairSync('rsa', {modulusLength: 2048});
const jwk = publicKey.export({format: 'jwk'});
jwk.kid = 'test-key';
jwk.use = 'sig';
jwk.alg = 'RS256';

function token(overrides = {}, signingKey = privateKey) {
  const header = Buffer.from(JSON.stringify({alg: 'RS256', kid: 'test-key', typ: 'JWT'})).toString('base64url');
  const claims = Buffer.from(JSON.stringify({
    iss: 'https://accounts.google.com', aud: AUDIENCE, sub: '1234567890',
    email: EMAIL, email_verified: true, iat: NOW - 10, exp: NOW + 300,
    ...overrides,
  })).toString('base64url');
  const signed = `${header}.${claims}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(signed), signingKey).toString('base64url');
  return `${signed}.${signature}`;
}

const verifyOptions = {audience: AUDIENCE, allowedEmails: [EMAIL], jwks: [jwk], now: NOW, clockSkewSeconds: 0};

test('accepts a valid Google-signed, audience-bound authorized identity', async () => {
  const claims = await verifyGoogleIdToken(token(), verifyOptions);
  assert.equal(claims.email, EMAIL);
});

test('rejects an incompatible audience even with a valid signature', async () => {
  await assert.rejects(verifyGoogleIdToken(token({aud: 'oauth-client.apps.googleusercontent.com'}), verifyOptions), /audience/);
});

test('rejects an expired token', async () => {
  await assert.rejects(verifyGoogleIdToken(token({exp: NOW - 1}), verifyOptions), /expired/);
});

test('rejects an invalid signature', async () => {
  const other = crypto.generateKeyPairSync('rsa', {modulusLength: 2048}).privateKey;
  await assert.rejects(verifyGoogleIdToken(token({}, other), verifyOptions), /signature/);
});

test('rejects an unauthorized identity', async () => {
  await assert.rejects(verifyGoogleIdToken(token({email: 'other@example.iam.gserviceaccount.com'}), verifyOptions), /identity/);
});

test('rejects a non-Google issuer and a missing subject', async () => {
  await assert.rejects(verifyGoogleIdToken(token({iss: 'https://issuer.example'}), verifyOptions), /issuer/);
  await assert.rejects(verifyGoogleIdToken(token({sub: ''}), verifyOptions), /subject/);
});

test('enforces an authorized-party allowlist when configured', async () => {
  await assert.rejects(verifyGoogleIdToken(token({azp: 'unexpected-client'}), {
    ...verifyOptions,
    allowedAuthorizedParties: ['approved-client'],
  }), /authorized party/);
});

test('authenticator rejects multiple or ambiguous Authorization values', async () => {
  const authenticate = createOperatorAuthenticator({audience: AUDIENCE, allowedEmails: [EMAIL]});
  await assert.rejects(authenticate({headers: {authorization: ['Bearer a.b.c', 'Bearer d.e.f']}}), /ambiguous/);
  await assert.rejects(authenticate({headers: {authorization: 'Bearer a.b.c, Bearer d.e.f'}}), /ambiguous/);
});

function responseRecorder() {
  return {
    statusCode: null, body: null,
    set() {},
    status(value) { this.statusCode = value; return this; },
    json(value) { this.body = value; return this; },
  };
}

test('authorization denial is 403 and performs no successful response', async () => {
  const error = Object.assign(new Error('denied'), {code: 'AUTHORIZATION_DENIED'});
  const handler = createDiagnosticHandler({authenticate: async () => ({sub: '123'}), readProbe: async () => { throw error; }});
  const res = responseRecorder();
  await handler({method: 'POST'}, res);
  assert.equal(res.statusCode, 403);
  assert.deepEqual(res.body, {ok: false, code: 'forbidden'});
});

test('failed authentication never reaches the Firestore probe', async () => {
  let reads = 0;
  const handler = createDiagnosticHandler({
    authenticate: async () => { throw new Error('invalid token'); },
    readProbe: async () => { reads += 1; },
  });
  const res = responseRecorder();
  await handler({method: 'POST'}, res);
  assert.equal(res.statusCode, 401);
  assert.equal(reads, 0);
});
