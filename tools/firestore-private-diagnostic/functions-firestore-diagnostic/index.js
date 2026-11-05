'use strict';

// Deployment wrapper only. This package is intentionally not imported by the
// application's functions/index.js and must not be deployed without authorization.
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const {createOperatorAuthenticator} = require('./operator-auth');
const {createDiagnosticHandler} = require('./diagnostic');

admin.initializeApp();
const db = admin.firestore();
const audience = process.env.DIAGNOSTIC_AUDIENCE;
const allowedEmail = process.env.DIAGNOSTIC_CALLER_EMAIL;

const authenticate = createOperatorAuthenticator({audience, allowedEmails: [allowedEmail]});
const handler = createDiagnosticHandler({
  authenticate,
  readProbe: async identity => {
    // A fixed non-financial sentinel read proves database reachability and cannot
    // enumerate or mutate customer, entitlement, or payment data.
    const snapshot = await db.collection('_diagnostics').doc('firestore-read-isolation').get();
    return {subject: identity.sub, sentinelExists: snapshot.exists};
  },
});

exports.firestoreReadIsolationDiagnostic = onRequest({
  region: 'southamerica-east1',
  cors: false,
  invoker: 'private',
  maxInstances: 1,
}, handler);
