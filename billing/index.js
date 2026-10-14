import { createPairingService } from './pairing/service.mjs';
import { createStore as createPairingStore } from './pairing/store.mjs';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { defineBoolean, defineSecret, defineString } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import { createStore } from './store.js';
import { createProvider } from './provider.js';
import { createRecurringService } from './recurring_service.js';
initializeApp();
const accessToken = defineSecret('MP_ACCESS_TOKEN');
const webhookSecret = defineSecret('MP_WEBHOOK_SECRET');
const collectorId = defineString('MP_COLLECTOR_ID', { default: '' });
const monthlyPlanId = defineString('MP_MONTHLY_PLAN_ID', { default: '' });
const annualPlanId = defineString('MP_ANNUAL_PLAN_ID', { default: '' });
const liveMode = defineBoolean('MP_LIVE_MODE', { default: false });
const paymentsEnabled = defineBoolean('MP_PAYMENTS_ENABLED', { default: false });
function service() {
  const provider = createProvider({ accessToken: accessToken.value(),
    webhookSecret: webhookSecret.value() });
  return createRecurringService({ store: createStore(getFirestore()), provider,
    verifySignature: provider.verifySignature,
    verifyIdentity: (token, revoked) => getAuth().verifyIdToken(token, revoked),
    collectorId: collectorId.value(), planIds: { monthly: monthlyPlanId.value(), annual: annualPlanId.value() }, liveMode: liveMode.value(), paymentsEnabled: paymentsEnabled.value() });
}
const options = { region: 'southamerica-east1', maxInstances: 3, timeoutSeconds: 30,
  secrets: [accessToken, webhookSecret], cors: true };
export const mercadoBilling = onRequest(options, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  try {
    const result = await service().handle({ method: req.method,
      authorization: req.headers.authorization, body: req.body });
    res.status(result.status).json(result.body);
  } catch (_) { res.status(503).json({ error: 'billing-unavailable' }); }
});
export const mercadoWebhook = onRequest(options, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  try {
    const result = await service().webhook({ method: req.method,
      dataId: req.query['data.id'], body: req.body,
      signature: req.headers['x-signature'], requestId: req.headers['x-request-id'] });
    res.status(result.status).json(result.body);
  } catch (_) { res.status(503).json({ error: 'notification-unavailable' }); }
});

const clientKey = defineString('ROCHA_FIREBASE_WEB_API_KEY', { default: '' });
export const rokuPairing = onRequest({ region: 'southamerica-east1', maxInstances: 3,
  timeoutSeconds: 30, cors: true }, async (req, res) => {
  res.set('Cache-Control', 'no-store');
  const handle = createPairingService({ store: createPairingStore(getFirestore()),
    verifyIdentity: (token, revoked) => getAuth().verifyIdToken(token, revoked),
    mintToken: (uid, claims) => getAuth().createCustomToken(uid, claims), apiKey: clientKey.value() });
  const result = await handle({ method: req.method, body: req.body,
    authorization: req.headers.authorization, address: req.ip });
  res.status(result.status).json(result.body);
});
