import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createAccessService, recordKey } from './service.mjs';
import { createHttpServer } from './http_server.mjs';

// No client-provided project, token verifier, admin flag or entitlement data.
if (!process.env.GOOGLE_CLOUD_PROJECT || !process.env.ROCHA_PLANS_JSON) {
  throw new Error('Configure experimental GOOGLE_CLOUD_PROJECT and ROCHA_PLANS_JSON');
}
// This adapter is experimental. Require a distinct, explicitly named staging project.
const configuredProject = process.env.GOOGLE_CLOUD_PROJECT;
if (configuredProject === 'rocha-plus' ||
    !process.env.ROCHA_STAGING_PROJECT_ID ||
    configuredProject !== process.env.ROCHA_STAGING_PROJECT_ID) {
  throw new Error('Experimental entitlement requires a distinct, matching staging Firebase project');
}
if (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Production adapter refuses emulator authentication/storage overrides');
}
initializeApp({ credential: applicationDefault(), projectId: process.env.GOOGLE_CLOUD_PROJECT });
const db = getFirestore();
const store = {
  transact(uid, paymentId, callback) {
    return db.runTransaction(async tx => {
      const accountRef = db.collection('rochaEntitlements').doc(recordKey(uid));
      const paymentRef = paymentId ? db.collection('rochaPayments').doc(paymentId) : null;
      // All reads precede writes. Firestore retries contention atomically.
      const account = await tx.get(accountRef);
      const payments = await tx.get(db.collection('rochaPayments').where('uid', '==', uid));
      const payment = paymentRef ? await tx.get(paymentRef) : null;
      return callback({ account: account.exists ? account.data() : null,
        payments: payments.docs.map(doc => doc.data()),
        payment: payment?.exists ? payment.data() : null,
        setAccount: data => tx.create(accountRef, data),
        setPayment: data => tx.set(paymentRef, data),
        audit: (action, data) => tx.create(db.collection('rochaAccessAudit').doc(`${paymentId}-${action}`), data),
      });
    });
  },
};
const access = createAccessService({
  verifyToken: (token, checkRevoked) => getAuth().verifyIdToken(token, checkRevoked),
  store, plans: JSON.parse(process.env.ROCHA_PLANS_JSON),
});
// Bind only to loopback. An independently configured HTTPS gateway is mandatory.
const server = createHttpServer({ access });
server.listen(Number(process.env.PORT ?? 8080), '127.0.0.1');
