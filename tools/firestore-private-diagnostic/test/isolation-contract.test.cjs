'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {correlationFor, createDiagnosticHandler} = require('../functions-firestore-diagnostic/diagnostic');
const {
  SENTINEL_PATH,
  classifyFirestoreError,
  createIsolationProof,
} = require('../functions-firestore-diagnostic/isolation-proof');

function failure(code) {
  return async () => { throw Object.assign(new Error('sensitive provider detail'), {code}); };
}

test('classifies permission, missing database, configuration and network errors separately', () => {
  assert.equal(classifyFirestoreError({code: 7}), 'permission_denied');
  assert.equal(classifyFirestoreError({code: 'firestore/permission-denied'}), 'permission_denied');
  assert.equal(classifyFirestoreError({code: 5}), 'database_not_found');
  assert.equal(classifyFirestoreError({code: 'failed-precondition'}), 'configuration_error');
  assert.equal(classifyFirestoreError({code: 14}), 'network_error');
  assert.equal(classifyFirestoreError({code: 'unexpected'}), 'unknown_error');
});

test('proves isolation only when the named database is readable and default is denied', async () => {
  const run = createIsolationProof({
    readNamedSentinel: async () => ({exists: false}),
    readDefaultSentinel: failure('permission-denied'),
  });
  assert.deepEqual(await run(), {
    verdict: 'proven',
    sentinelPath: SENTINEL_PATH,
    namedDatabase: {database: 'rocha-payments-test', outcome: 'accessible', sentinelExists: false},
    defaultDatabase: {database: '(default)', outcome: 'permission_denied'},
  });
});

test('does not approve isolation when the default database is readable', async () => {
  const run = createIsolationProof({
    readNamedSentinel: async () => ({exists: true}),
    readDefaultSentinel: async () => ({exists: false}),
  });
  const result = await run();
  assert.equal(result.verdict, 'not_proven');
  assert.equal(result.defaultDatabase.outcome, 'accessible');
});

test('does not approve a non-permission failure from the default database', async () => {
  const run = createIsolationProof({
    readNamedSentinel: async () => ({exists: false}),
    readDefaultSentinel: failure('unavailable'),
  });
  const result = await run();
  assert.equal(result.verdict, 'not_proven');
  assert.equal(result.defaultDatabase.outcome, 'network_error');
});

for (const [label, code, expected] of [
  ['named permission denial', 'permission-denied', 'permission_denied'],
  ['named database missing', 'not-found', 'database_not_found'],
  ['named configuration failure', 'failed-precondition', 'configuration_error'],
  ['named network failure', 'unavailable', 'network_error'],
]) {
  test(`${label} is reported and never treated as approval`, async () => {
    const run = createIsolationProof({
      readNamedSentinel: failure(code),
      readDefaultSentinel: failure('permission-denied'),
    });
    const result = await run();
    assert.equal(result.verdict, 'not_proven');
    assert.equal(result.namedDatabase.outcome, expected);
    assert.equal(JSON.stringify(result).includes('sensitive provider detail'), false);
  });
}

function responseRecorder() {
  return {
    headers: {}, statusCode: null, body: null,
    set(name, value) { this.headers[name] = value; return this; },
    status(value) { this.statusCode = value; return this; },
    json(value) { this.body = value; return this; },
  };
}

function loggerRecorder() {
  const entries = [];
  return {entries, info: entry => entries.push(entry), error: entry => entries.push(entry)};
}

test('uses a valid Cloud trace ID for correlation without logging credentials or identity', async () => {
  const traceId = '0123456789abcdef0123456789abcdef';
  const logger = loggerRecorder();
  const handler = createDiagnosticHandler({
    authenticate: async () => ({sub: 'private-subject', email: 'private@example.com'}),
    runIsolationProof: async () => ({
      verdict: 'proven',
      namedDatabase: {outcome: 'accessible'},
      defaultDatabase: {outcome: 'permission_denied'},
    }),
    logger,
    projectId: 'demo-project',
  });
  const req = {method: 'POST', headers: {
    authorization: 'Bearer secret.jwt.value',
    'x-cloud-trace-context': `${traceId}/123;o=1`,
  }};
  const res = responseRecorder();
  await handler(req, res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.headers['X-Diagnostic-Correlation-ID'], traceId);
  assert.equal(logger.entries[0]['logging.googleapis.com/trace'], `projects/demo-project/traces/${traceId}`);
  const observable = JSON.stringify({body: res.body, logs: logger.entries});
  assert.equal(observable.includes('secret.jwt.value'), false);
  assert.equal(observable.includes('private-subject'), false);
  assert.equal(observable.includes('private@example.com'), false);
});

test('generates an opaque correlation ID when the trace header is absent or malformed', () => {
  const expected = '11111111-2222-4333-8444-555555555555';
  assert.deepEqual(correlationFor({headers: {'x-cloud-trace-context': 'invalid'}}, {
    projectId: 'demo-project', randomUUID: () => expected,
  }), {correlationId: expected, 'logging.googleapis.com/trace': undefined});
});

test('failed authentication never reaches either Firestore probe', async () => {
  let runs = 0;
  const logger = loggerRecorder();
  const handler = createDiagnosticHandler({
    authenticate: async () => { throw new Error('invalid token'); },
    runIsolationProof: async () => { runs += 1; },
    logger,
    randomUUID: () => 'correlation-id',
  });
  const res = responseRecorder();
  await handler({method: 'POST', headers: {}}, res);
  assert.equal(res.statusCode, 401);
  assert.equal(res.body.code, 'unauthenticated');
  assert.equal(runs, 0);
});

test('an unproven result returns 409 rather than success', async () => {
  const logger = loggerRecorder();
  const handler = createDiagnosticHandler({
    authenticate: async () => ({}),
    runIsolationProof: async () => ({
      verdict: 'not_proven',
      namedDatabase: {outcome: 'network_error'},
      defaultDatabase: {outcome: 'permission_denied'},
    }),
    logger,
    randomUUID: () => 'correlation-id',
  });
  const res = responseRecorder();
  await handler({method: 'POST', headers: {}}, res);
  assert.equal(res.statusCode, 409);
  assert.equal(res.body.ok, false);
  assert.equal(res.body.code, 'isolation_not_proven');
});

test('an unexpected handler failure returns a sanitized 503', async () => {
  const logger = loggerRecorder();
  const handler = createDiagnosticHandler({
    authenticate: async () => ({}),
    runIsolationProof: async () => { throw new Error('provider secret detail'); },
    logger,
    randomUUID: () => 'correlation-id',
  });
  const res = responseRecorder();
  await handler({method: 'POST', headers: {}}, res);
  assert.equal(res.statusCode, 503);
  assert.equal(res.body.code, 'diagnostic_unavailable');
  assert.equal(JSON.stringify({body: res.body, logs: logger.entries}).includes('provider secret detail'), false);
});
