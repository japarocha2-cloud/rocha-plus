import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign, webcrypto } from 'node:crypto';
import { once } from 'node:events';
import { createOfficeService, PRODUCT, deviceKey } from './service.mjs';
import { createHttpServer } from './http_server.mjs';
import { installation, officeClient } from '../../office/src/license-client.mjs';

const status = (promise, expected) => assert.rejects(promise, e => e.status === expected);
function device() {
  const keys = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  return { publicKey: keys.publicKey.export({ format: 'jwk' }),
    sign: message => sign('sha256', Buffer.from(message),
      { key: keys.privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url') };
}
function fixture(options = {}) {
  const tokens = {
    alice: { uid: 'alice-uid', email_verified: true, firebase: { sign_in_provider: 'google.com' } },
    bob: { uid: 'bob-uid', email_verified: true, firebase: { sign_in_provider: 'google.com' } },
    admin: { uid: 'operator', email_verified: true, firebase: { sign_in_provider: 'google.com' }, rochaOfficeAdmin: true },
    tvAdmin: { uid: 'tv-operator', email_verified: true, firebase: { sign_in_provider: 'google.com' }, rochaAdmin: true },
    fakeAdmin: { uid: 'operator', email_verified: true, firebase: { sign_in_provider: 'google.com' }, rochaOfficeAdmin: 'true' },
    unverified: { uid: 'alice-uid', email_verified: false, firebase: { sign_in_provider: 'google.com' } },
    apple: { uid: 'apple', email_verified: true, firebase: { sign_in_provider: 'apple.com' } },
  };
  let records = { accounts: new Map(), payments: new Map(), challenges: new Map(), audit: [] };
  let queue = Promise.resolve(), time = Date.UTC(2026, 9, 22); const calls = [];
  const store = { transact(uid, { paymentId, challengeId }, callback) {
    const task = queue.then(async () => {
      // Transactional in-memory double. This does not certify cloud Firestore.
      const next = structuredClone(records);
      const result = await callback({ account: next.accounts.get(uid), payment: next.payments.get(paymentId),
        payments: [...next.payments.values()].filter(p => p.uid === uid),
        challenge: next.challenges.get(challengeId),
        setAccount: data => next.accounts.set(uid, data), setPayment: data => next.payments.set(paymentId, data),
        setChallenge: data => next.challenges.set(challengeId, data),
        audit: (action, data) => next.audit.push({ action, ...data }),
      }); records = next; return result;
    }); queue = task.catch(() => {}); return task;
  }};
  const access = createOfficeService({ store, now: () => time, ...options,
    verifyToken: async (token, revoked) => { calls.push(revoked); if (!tokens[token]) throw Error('invalid token'); return tokens[token]; } });
  const req = (path, body, token = 'alice', method = 'POST') => access({ method, path: `/v1/office/${path}`, body, authorization: `Bearer ${token}` });
  const payment = { uid: 'alice-uid', product: PRODUCT, provider: 'mercadopago', transactionId: 'verified-payment-reference',
    amountCents: 4990, currency: 'BRL', evidenceReference: 'MANUAL-TEST-bank-statement' };
  const approve = (body = {}, token = 'admin') => req('admin/confirm', { ...payment, ...body }, token);
  const refund = (body = {}) => req('admin/refund', { ...payment, ...body }, 'admin');
  const me = (token = 'alice', body = {}) => req('me', body, token, 'GET');
  const challenge = (d, action = 'activate', token = 'alice') => req('challenge', { action, publicKey: d.publicKey, label: 'Installation' }, token);
  const complete = (d, c, action = 'activate', body = {}, token = 'alice') => req(action, { challengeId: c.challengeId, signature: d.sign(c.message), ...body }, token);
  const prove = async (d, action = 'activate', body = {}, token = 'alice') => complete(d, await challenge(d, action, token), action, body, token);
  return { access, req, approve, refund, me, challenge, complete, prove, payment, calls,
    tokens, records: () => records, advance: ms => { time += ms; } };
}

test('only verified Google ID tokens are accepted, with revocation checking', async () => {
  const f = fixture();
  for (const token of ['expired', 'unverified', 'apple']) await status(f.me(token), 401);
  await status(f.access({ method: 'GET', path: '/v1/office/me' }), 401);
  assert.ok(f.calls.every(Boolean)); assert.equal(f.records().accounts.size, 0);
});
test('client paid/UID flags, TV administrator and string administrator cannot grant Office', async () => {
  const f = fixture(); assert.equal((await f.me('alice', { uid: 'bob-uid', licensed: true })).licensed, false);
  for (const token of ['alice', 'tvAdmin', 'fakeAdmin']) await status(f.approve({}, token), 403);
  await status(f.challenge(device()), 403); assert.equal(f.records().payments.size, 0);
});
test('approval checks exact bundle, price, currency and evidence; no individual module licenses', async () => {
  const f = fixture();
  for (const body of [{ product: 'documents' }, { amountCents: 499 }, { currency: 'USD' }, { evidenceReference: '' }]) {
    await status(f.approve(body), 400);
  }
  await f.approve(); const result = await f.me(); assert.equal(result.product, PRODUCT);
  assert.equal(result.licensed, true); assert.equal(result.deviceLimit, 2);
});
test('payment retry is idempotent and cannot grant another Google account', async () => {
  const f = fixture(); await f.approve(); assert.equal((await f.approve()).duplicate, true);
  await status(f.approve({ uid: 'bob-uid' }), 409);
  assert.equal((await f.me('bob')).licensed, false); assert.equal(f.records().audit.length, 1);
});
test('exactly two installations even when three keys activate concurrently', async () => {
  const f = fixture(); await f.approve();
  const results = await Promise.allSettled([device(), device(), device()].map(d => f.prove(d)));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 2);
  assert.equal(results.filter(r => r.status === 'rejected' && r.reason.status === 409).length, 1);
  assert.equal((await f.me()).devices.length, 2);
});
test('same installation retry does not consume another device slot', async () => {
  const f = fixture(), d = device(); await f.approve(); await f.prove(d); await f.prove(d);
  assert.equal((await f.me()).devices.length, 1);
});
test('copied identifier/public key is insufficient without private key proof', async () => {
  const f = fixture(), d = device(); await f.approve();
  const c = await f.challenge(d); await status(f.complete(device(), c), 403);
  assert.equal((await f.me()).devices.length, 0);
  assert.equal((await f.complete(d, c)).allowed, true);
});
test('challenge cannot be replayed, substituted for another action, or used after one minute', async () => {
  const f = fixture(), d = device(); await f.approve();
  const c = await f.challenge(d); await status(f.complete(d, c, 'access'), 403);
  await f.complete(d, c); await status(f.complete(d, c), 403);
  const expired = await f.challenge(d, 'access'); f.advance(60_000);
  await status(f.complete(d, expired, 'access'), 403);
});
test('account switched between challenge and proof cannot obtain access', async () => {
  const f = fixture(), d = device(); await f.approve(); const c = await f.challenge(d);
  await status(f.complete(d, c, 'activate', {}, 'bob'), 403);
  assert.equal((await f.me('bob')).devices.length, 0);
});
test('access requires an active installation; deactivation frees one slot', async () => {
  const f = fixture(), a = device(), b = device(), c = device(); await f.approve();
  await status(f.prove(a, 'access'), 403); await f.prove(a); await f.prove(b);
  await f.prove(a, 'deactivate'); await status(f.prove(a, 'access'), 403); await f.prove(c);
  assert.equal((await f.me()).devices.length, 2);
});
test('administrator revocation blocks old challenges and reactivation with stolen key', async () => {
  const f = fixture(), d = device(); await f.approve(); const active = await f.prove(d);
  const pending = await f.challenge(d, 'access');
  await f.req('admin/revoke-device', { uid: 'alice-uid', deviceId: active.deviceId, evidenceReference: 'lost-device' }, 'admin');
  await status(f.complete(d, pending, 'access'), 403); await status(f.prove(d), 403);
  assert.equal((await f.me()).devices.length, 0);
});
test('refund removes license and devices; old confirmed transaction cannot be reapproved', async () => {
  const f = fixture(), d = device(); await f.approve(); await f.prove(d); const c = await f.challenge(d, 'access');
  await f.refund(); assert.equal((await f.me()).licensed, false);
  assert.equal((await f.me()).devices.length, 0); await status(f.complete(d, c, 'access'), 403);
  await status(f.approve(), 409); assert.equal((await f.refund()).duplicate, true);
});
test('refunding one of multiple real confirmations preserves the other license', async () => {
  const f = fixture(); await f.approve(); await f.approve({ transactionId: 'second-bank-reference' });
  const d = device(); await f.prove(d); await f.refund();
  assert.equal((await f.me()).licensed, true); assert.equal((await f.me()).devices.length, 1);
});
test('download is denied without commercial private storage, even for approved account', async () => {
  const f = fixture(), d = device(); await f.approve(); await f.prove(d);
  await status(f.prove(d, 'access', { download: true, platform: 'android' }), 503);
});
test('server signs only a validated platform and sixty-second grant after device proof', async () => {
  const calls = [], f = fixture({ issueDownload: async args => { calls.push(args); return { url: 'https://private.example/temporary-file', expiresAtMs: args.expiresAtMs }; } });
  const d = device(); await f.approve(); await f.prove(d);
  const result = await f.prove(d, 'access', { download: true, platform: 'android', uid: 'bob-uid' });
  assert.equal(result.allowed, true); assert.equal(calls[0].uid, 'alice-uid');
  assert.equal(calls[0].platform, 'android');
  await status(f.prove(d, 'access', { download: true, platform: '../../etc/passwd' }), 503);
});
test('browser WebCrypto proof interoperates with real HTTP and server ECDSA verification', async t => {
  const f = fixture(); await f.approve(); const server = createHttpServer({ access: f.access });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const origin = `http://127.0.0.1:${server.address().port}`;
  let saved;
  const d = await installation({ crypto: webcrypto, keyStore: { loadOrCreate: async gen => saved ??= await gen() } });
  assert.equal(saved.privateKey.extractable, false);
  const client = officeClient({ endpoint: 'https://office.example', getToken: async () => 'alice', installation: d,
    fetch: (url, options) => fetch(url.replace('https://office.example', origin), options) });
  assert.equal((await client.me()).licensed, true);
  assert.equal((await client.prove('activate')).activeDevices, 1);
  assert.equal((await client.prove('access')).allowed, true);
  await client.prove('deactivate'); await assert.rejects(client.prove('access'));
});
test('HTTP errors return no-store denial and omit internal verifier errors', async t => {
  const f = fixture(); const server = createHttpServer({ access: f.access });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const url = `http://127.0.0.1:${server.address().port}/v1/office/me`;
  const res = await fetch(url, { headers: { Authorization: 'Bearer forged' } });
  assert.equal(res.status, 401); assert.match(res.headers.get('cache-control'), /no-store/);
  assert.equal((await res.json()).allowed, false);
});
test('browser origin allowlist supports authorization preflight and denies other sites', async t => {
  const f = fixture(); const server = createHttpServer({ access: f.access, allowedOrigins: ['https://office.example'] });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const url = `http://127.0.0.1:${server.address().port}/v1/office/me`;
  const preflight = await fetch(url, { method: 'OPTIONS', headers: { Origin: 'https://office.example',
    'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,content-type' } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'https://office.example');
  const other = await fetch(url, { headers: { Origin: 'https://attacker.example', Authorization: 'Bearer alice' } });
  assert.equal(other.status, 403); assert.equal(other.headers.get('access-control-allow-origin'), null);
  const ok = await fetch(url, { headers: { Origin: 'https://office.example', Authorization: 'Bearer alice' } });
  assert.equal(ok.status, 200); assert.equal(ok.headers.get('access-control-allow-origin'), 'https://office.example');
});
test('private installation key cannot be exported and service errors never grant client access', async () => {
  let keys;
  await installation({ crypto: webcrypto, keyStore: { loadOrCreate: async gen => keys = await gen() } });
  await assert.rejects(webcrypto.subtle.exportKey('jwk', keys.privateKey));
  const client = officeClient({ endpoint: 'https://office.example', getToken: async () => 'alice',
    installation: device(), fetch: async () => new Response('{"allowed":false}', { status: 503 }) });
  await assert.rejects(client.prove('access'));
});

test('paired session is scoped to its installation and cannot approve a purchase', async () => {
  const f = fixture(), d = device(); await f.approve();
  f.tokens.bridge = { uid: 'alice-uid', email_verified: true, firebase: { sign_in_provider: 'custom' },
    officeGoogleBridge: true, officeDeviceId: deviceKey(d.publicKey).id, rochaOfficeAdmin: true };
  assert.equal((await f.prove(d, 'activate', {}, 'bridge')).allowed, true);
  await status(f.prove(device(), 'activate', {}, 'bridge'), 403);
  await status(f.approve({}, 'bridge'), 403);
});
test('only Office operator can locate a verified Google buyer; supplied UID is ignored', async () => {
  const emails=[];
  const f=fixture({ findAccount: async email=>{emails.push(email);return {uid:'google-found',email,emailVerified:true,disabled:false,providerData:[{providerId:'google.com'}]};} });
  await status(f.req('admin/lookup',{email:'buyer@example.test'},'alice'),403);
  assert.equal(emails.length,0);
  const result=await f.req('admin/lookup',{email:'Buyer@Example.Test',uid:'forged'},'admin');
  assert.equal(result.uid,'google-found');assert.deepEqual(emails,['buyer@example.test']);
  assert.equal(result.licensed,false);
});
test('unverified or non-Google buyer lookup cannot create a license', async()=>{
  const f=fixture({findAccount:async()=>({uid:'x',emailVerified:false,providerData:[{providerId:'password'}]})});
  await status(f.req('admin/lookup',{email:'buyer@example.test'},'admin'),404);
  assert.equal(f.records().payments.size,0);
});
