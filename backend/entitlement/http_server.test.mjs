import test from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { once } from 'node:events';
import { createHttpServer } from './http_server.mjs';
import { createAccessService, DAY } from './service.mjs';

// Real loopback sockets and the real rules; token verification/storage are doubles.
async function fixture(t, { storageFails = false } = {}) {
  let time = Date.UTC(2026, 9, 22);
  const accounts = new Map(), payments = new Map(), audit = [];
  const tokens = {
    user: { uid: 'buyer', firebase: { sign_in_provider: 'google.com' } },
    admin: { uid: 'operator', rochaAdmin: true,
      firebase: { sign_in_provider: 'google.com' } },
  };
  const access = createAccessService({
    verifyToken: async (token, revoked) => {
      assert.equal(revoked, true);
      if (!tokens[token]) throw new Error('Invalid fixture token');
      return tokens[token];
    },
    store: { async transact(uid, paymentId, callback) {
      if (storageFails) throw new Error('PRIVATE database failure details');
      const nextAccounts = structuredClone(accounts);
      const nextPayments = structuredClone(payments);
      const nextAudit = structuredClone(audit);
      const result = await callback({
        account: nextAccounts.get(uid), payment: nextPayments.get(paymentId),
        payments: [...nextPayments.values()].filter(p => p.uid === uid),
        setAccount: value => nextAccounts.set(uid, value),
        setPayment: value => nextPayments.set(paymentId, value),
        audit: (action, value) => nextAudit.push({ action, ...value }),
      });
      accounts.clear(); for (const [key, value] of nextAccounts) accounts.set(key, value);
      payments.clear(); for (const [key, value] of nextPayments) payments.set(key, value);
      audit.splice(0, audit.length, ...nextAudit);
      return result;
    } },
    plans: { monthly: { amountCents: 450, days: 30 } }, now: () => time,
  });
  const server = createHttpServer({ access });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  });
  function send({ path = '/v1/entitlement', method = 'GET', token = 'user',
    body, chunks } = {}) {
    return new Promise((resolve, reject) => {
      const req = request({ host: '127.0.0.1', port: server.address().port,
        path, method, agent: false,
        headers: { 'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}) } }, res => {
        const data = [];
        res.on('data', chunk => data.push(chunk));
        res.on('error', reject);
        res.on('end', () => {
          try { resolve({ status: res.statusCode, headers: res.headers,
            body: JSON.parse(Buffer.concat(data).toString('utf8')) }); }
          catch (error) { reject(error); }
        });
      });
      req.on('error', reject);
      for (const chunk of chunks ?? (body === undefined ? [] : [body])) req.write(chunk);
      req.end();
    });
  }
  return { send, accounts, payments, audit, advance: days => { time += days * DAY; } };
}

const evidence = {
  uid: 'buyer', provider: 'manual-test', transactionId: 'TEST-transaction',
  evidenceReference: 'TEST-only-bank-record', plan: 'monthly',
  amountCents: 450, currency: 'BRL',
};

test('HTTP entitlement contract derives UID and expires at seven days', async t => {
  const f = await fixture(t);
  const first = await f.send();
  assert.equal(first.status, 200);
  assert.equal(first.body.uid, 'buyer');
  assert.equal(first.body.allowed, true);
  assert.match(first.headers['cache-control'], /no-store/);
  assert.match(first.headers['content-type'], /^application\/json/);
  assert.equal(first.headers['x-content-type-options'], 'nosniff');
  f.advance(7);
  assert.equal((await f.send()).body.allowed, false);
  assert.equal(f.accounts.size, 1);
});

test('HTTP missing or invalid token cannot create trial', async t => {
  const f = await fixture(t);
  for (const token of [null, 'forged']) {
    const response = await f.send({ token });
    assert.equal(response.status, 401);
    assert.equal(response.body.allowed, false);
    assert.match(response.headers['cache-control'], /no-store/);
  }
  assert.equal(f.accounts.size, 0);
});

test('HTTP administrator confirmation and refund change access after expiration', async t => {
  const f = await fixture(t);
  await f.send(); f.advance(8);
  const command = { path: '/v1/admin/confirm', method: 'POST', body: JSON.stringify(evidence) };
  assert.equal((await f.send(command)).status, 403);
  assert.equal(f.payments.size, 0);
  const accepted = await f.send({ ...command, token: 'admin' });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.duplicate, false);
  assert.equal((await f.send({ ...command, token: 'admin' })).body.duplicate, true);
  assert.equal(f.audit.length, 1);
  assert.equal((await f.send()).body.allowed, true);
  const refund = await f.send({ path: '/v1/admin/refund', method: 'POST', token: 'admin',
    body: JSON.stringify(evidence) });
  assert.equal(refund.status, 200);
  assert.equal((await f.send()).body.allowed, false);
});

test('HTTP invalid JSON or non-object body is denied before rules run', async t => {
  const f = await fixture(t);
  for (const body of ['{broken', 'null', '[]', 'true']) {
    const response = await f.send({ method: 'POST', body });
    assert.equal(response.status, 400);
    assert.equal(response.body.allowed, false);
  }
  assert.equal(f.accounts.size, 0);
});

test('HTTP body above byte limit returns JSON 413 without granting access', async t => {
  const f = await fixture(t);
  const response = await f.send({ method: 'POST', body: JSON.stringify({ data: 'x'.repeat(9000) }) });
  assert.equal(response.status, 413);
  assert.equal(response.body.allowed, false);
  assert.equal(f.accounts.size, 0);
});

test('HTTP split UTF-8 payment evidence is reconstructed without corruption', async t => {
  const f = await fixture(t);
  const reference = 'TEST-comprovação-ação';
  const body = Buffer.from(JSON.stringify({ ...evidence, evidenceReference: reference }));
  const offset = body.indexOf(Buffer.from('ç')) + 1;
  const response = await f.send({ path: '/v1/admin/confirm', method: 'POST', token: 'admin',
    chunks: [body.subarray(0, offset), body.subarray(offset)] });
  assert.equal(response.status, 200);
  assert.equal([...f.payments.values()][0].evidenceReference, reference);
});

test('HTTP storage failure returns 503 without exposing internal details or allowing access', async t => {
  const f = await fixture(t, { storageFails: true });
  const response = await f.send();
  assert.equal(response.status, 503);
  assert.deepEqual(response.body, { allowed: false, error: 'Service unavailable' });
  assert.equal(JSON.stringify(response.body).includes('PRIVATE'), false);
});

test('HTTP unknown routes and incomplete payment evidence never create grants', async t => {
  const f = await fixture(t);
  assert.equal((await f.send({ path: '/v1/payment/pending', method: 'POST' })).status, 404);
  const response = await f.send({ path: '/v1/admin/confirm', method: 'POST', token: 'admin',
    body: JSON.stringify({ ...evidence, evidenceReference: '' }) });
  assert.equal(response.status, 400);
  assert.equal(response.body.allowed, false);
  assert.equal(f.payments.size, 0);
});

test('HTTP payment before first login does not restart seven-day trial later', async t => {
  const f = await fixture(t);
  const paid = await f.send({ method: 'POST', path: '/v1/admin/confirm',
    token: 'admin', body: JSON.stringify(evidence) });
  assert.equal(paid.status, 200);
  f.advance(38);
  const lateLogin = await f.send();
  assert.equal(lateLogin.status, 200);
  assert.equal(lateLogin.body.allowed, false);
  assert.equal(f.accounts.size, 1);
});
