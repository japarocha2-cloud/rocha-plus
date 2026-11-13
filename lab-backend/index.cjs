'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const {getFirestore} = require('firebase-admin/firestore');
const {createHandler} = require('./handler.cjs');
admin.initializeApp();
exports.entitlementReadOnly = onRequest({region: 'southamerica-east1',
  invoker: 'public', cors: false, maxInstances: 2}, createHandler({
  auth: admin.auth(),
  sandbox: true,
  db: getFirestore('rocha-payments-test'),
  projectId: () => process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
}));
