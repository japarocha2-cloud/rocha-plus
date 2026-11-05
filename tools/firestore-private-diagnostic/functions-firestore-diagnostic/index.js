'use strict';

// Deployment wrapper only. This package is intentionally not imported by the
// application's functions/index.js and must not be deployed without authorization.
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {defineString} = require('firebase-functions/params');
const functionsLogger = require('firebase-functions/logger');
const {onRequest} = require('firebase-functions/v2/https');
const {createOperatorAuthenticator} = require('./operator-auth');
const {createDiagnosticHandler} = require('./diagnostic');
const {createIsolationProof, NAMED_DATABASE, SENTINEL_PATH} = require('./isolation-proof');

const diagnosticAudience = defineString('DIAGNOSTIC_AUDIENCE');
const diagnosticCallerEmail = defineString('DIAGNOSTIC_CALLER_EMAIL');
const diagnosticRuntimeServiceAccount = defineString('DIAGNOSTIC_RUNTIME_SERVICE_ACCOUNT');

const app = initializeApp();
const namedDb = getFirestore(app, NAMED_DATABASE);
const defaultDb = getFirestore(app);

function readSentinel(db) {
  return db.doc(SENTINEL_PATH).get();
}

const authenticate = createOperatorAuthenticator({
  audience: () => diagnosticAudience.value(),
  allowedEmails: () => [diagnosticCallerEmail.value()],
});
const runIsolationProof = createIsolationProof({
  readNamedSentinel: () => readSentinel(namedDb),
  readDefaultSentinel: () => readSentinel(defaultDb),
});
const handler = createDiagnosticHandler({
  authenticate,
  runIsolationProof,
  projectId: process.env.GCLOUD_PROJECT,
  logger: {
    info: entry => functionsLogger.info('firestore_private_isolation_diagnostic', entry),
    error: entry => functionsLogger.error('firestore_private_isolation_diagnostic', entry),
  },
});

exports.firestoreReadIsolationDiagnostic = onRequest({
  region: 'southamerica-east1',
  cors: false,
  invoker: 'private',
  maxInstances: 1,
  serviceAccount: diagnosticRuntimeServiceAccount,
}, handler);
