'use strict';

const NAMED_DATABASE = 'rocha-payments-test';
const DEFAULT_DATABASE = '(default)';
const SENTINEL_PATH = '_diagnostics/firestore-read-isolation';

const ERROR_CODES = new Map([
  ['7', 'permission_denied'],
  ['permission-denied', 'permission_denied'],
  ['permission_denied', 'permission_denied'],
  ['5', 'database_not_found'],
  ['not-found', 'database_not_found'],
  ['not_found', 'database_not_found'],
  ['3', 'configuration_error'],
  ['9', 'configuration_error'],
  ['16', 'configuration_error'],
  ['invalid-argument', 'configuration_error'],
  ['failed-precondition', 'configuration_error'],
  ['unauthenticated', 'configuration_error'],
  ['4', 'network_error'],
  ['14', 'network_error'],
  ['deadline-exceeded', 'network_error'],
  ['unavailable', 'network_error'],
]);

function normalizedErrorCode(error) {
  const value = error?.code;
  if (typeof value === 'number') return String(value);
  if (typeof value !== 'string') return '';
  return value.toLowerCase().replace(/^firestore\//, '').replace(/^grpc\//, '');
}

function classifyFirestoreError(error) {
  return ERROR_CODES.get(normalizedErrorCode(error)) ?? 'unknown_error';
}

async function probe(database, readSentinel) {
  try {
    const snapshot = await readSentinel();
    return {database, outcome: 'accessible', sentinelExists: snapshot?.exists === true};
  } catch (error) {
    return {database, outcome: classifyFirestoreError(error)};
  }
}

function createIsolationProof({readNamedSentinel, readDefaultSentinel}) {
  if (typeof readNamedSentinel !== 'function' || typeof readDefaultSentinel !== 'function') {
    throw new TypeError('both sentinel readers are required');
  }
  return async function runIsolationProof() {
    const [namedDatabase, defaultDatabase] = await Promise.all([
      probe(NAMED_DATABASE, readNamedSentinel),
      probe(DEFAULT_DATABASE, readDefaultSentinel),
    ]);
    const verdict = namedDatabase.outcome === 'accessible' &&
      defaultDatabase.outcome === 'permission_denied' ? 'proven' : 'not_proven';
    return {verdict, sentinelPath: SENTINEL_PATH, namedDatabase, defaultDatabase};
  };
}

module.exports = {
  DEFAULT_DATABASE,
  NAMED_DATABASE,
  SENTINEL_PATH,
  classifyFirestoreError,
  createIsolationProof,
};
