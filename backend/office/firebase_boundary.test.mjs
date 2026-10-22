import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { request } from 'node:http';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { createHttpServer } from './http_server.mjs';
import { createOfficeService } from './service.mjs';

// Actual Firebase Admin rejection checks, no account credentials or remote data.
// These are deliberately invalid JWTs, never examples of usable ID tokens.
function invalidJwt(overrides) {
  const now = Math.floor(Date.now() / 1000);
  const json = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${json({ alg: 'RS256', typ: 'JWT', kid: 'test-only' })}.${json({
    aud: 'rocha-entitlement-negative-tests',
    iss: 'https://securetoken.google.com/rocha-entitlement-negative-tests',
    sub: 'test-buyer', iat: now, exp: now + 3600, auth_time: now,
    firebase: { sign_in_provider: 'google.com' }, ...overrides,
  })}.invalid-signature`;
}

async function rejectionFixture(t) {
  const app = initializeApp({ projectId: 'rocha-entitlement-negative-tests' }, randomUUID());
  let storageCalls = 0;
  const rejected = [];
  const access = createOfficeService({
    verifyToken: async (token, checkRevoked) => {
      assert.equal(checkRevoked, true);
      try { return await getAuth(app).verifyIdToken(token, checkRevoked); }
      catch (error) { rejected.push(error.code); throw error; }
    },
    store: { transact: () => {
      storageCalls++;
      throw new Error('Invalid token must not reach storage');
    } },
  });
  const server = createHttpServer({ access });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await deleteApp(app);
  });
  const send = token => new Promise((resolve, reject) => {
    const req = request({ host: '127.0.0.1', port: server.address().port,
      path: '/v1/office/me', agent: false,
      headers: { Authorization: `Bearer ${token}` } }, res => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { raw += chunk; });
      res.on('error', reject);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(raw) }); }
        catch (error) { reject(error); }
      });
    });
    req.on('error', reject);
    req.end();
  });
  return { send, rejected, storageCalls: () => storageCalls };
}

test('real Firebase SDK rejects malformed tokens through the HTTP boundary', async t => {
  const f = await rejectionFixture(t);
  const response = await f.send('TEST-NOT-A-JWT');
  assert.equal(response.status, 401);
  assert.deepEqual(response.body, { allowed: false, error: 'Unauthorized' });
  assert.equal(f.storageCalls(), 0);
  assert.equal(f.rejected.length, 1);
  assert.match(f.rejected[0], /^auth\//);
});

test('real Firebase SDK rejects wrong audience and issuer before any grant', async t => {
  const f = await rejectionFixture(t);
  for (const token of [invalidJwt({ aud: 'another-project' }),
    invalidJwt({ iss: 'https://securetoken.google.com/another-project' })]) {
    const response = await f.send(token);
    assert.equal(response.status, 401);
    assert.equal(response.body.allowed, false);
  }
  assert.equal(f.storageCalls(), 0);
  assert.equal(f.rejected.length, 2);
  assert.ok(f.rejected.every(code => code.startsWith('auth/')));
});
