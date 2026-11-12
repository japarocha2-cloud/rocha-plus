'use strict';
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const {createHandler} = require('./handler.cjs');
admin.initializeApp();
exports.entitlementReadOnly = onRequest({region: 'southamerica-east1',
  invoker: 'public', cors: false, maxInstances: 2}, createHandler({
  auth: admin.auth(), db: admin.firestore(),
  projectId: () => process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
}));
