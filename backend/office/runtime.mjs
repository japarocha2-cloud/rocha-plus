import { applicationDefault, getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createOfficeService, recordKey } from './service.mjs';
import { officeTokenVerifier } from './auth-boundary.mjs';
import { createPairingService } from './pairing.mjs';
import { createHttpHandler } from './http_server.mjs';
export function createOfficeRuntime() {
const projectId = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
if (projectId !== 'rocha-plus') throw new Error('Configure Rocha Office project');
if (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Production Office adapter refuses emulator overrides');
}
const app = getApps().some(app => app.name === 'rocha-office') ? getApp('rocha-office') : initializeApp({ credential: applicationDefault(), projectId }, 'rocha-office');
const auth = getAuth(app);
const db = getFirestore(app);
const store = { transact(uid, { paymentId, challengeId }, callback) {
  return db.runTransaction(async tx => {
    const accountRef = db.collection('rochaOfficeLicenses').doc(recordKey(uid));
    const paymentRef = paymentId ? db.collection('rochaOfficePayments').doc(paymentId) : null;
    const challengeRef = challengeId ? db.collection('rochaOfficeChallenges').doc(recordKey(challengeId)) : null;
    const account = await tx.get(accountRef);
    const payments = await tx.get(db.collection('rochaOfficePayments').where('uid', '==', uid));
    const payment = paymentRef ? await tx.get(paymentRef) : null;
    const challenge = challengeRef ? await tx.get(challengeRef) : null;
    return callback({ account: account.exists ? account.data() : null,
      payments: payments.docs.map(d => d.data()), payment: payment?.exists ? payment.data() : null,
      challenge: challenge?.exists ? challenge.data() : null,
      setAccount: data => tx.set(accountRef, data),
      setPayment: data => tx.set(paymentRef, data),
      setChallenge: data => tx.set(challengeRef, { ...data, expiresAt: new Date(data.expiresAtMs) }),
      audit: (action, data) => tx.create(db.collection('rochaOfficeAudit').doc(), { action, ...data }),
    });
  });
}};
const verifyToken = officeTokenVerifier({ verifyIdToken: (token, revoked) => auth.verifyIdToken(token, revoked), getUser: uid => auth.getUser(uid) });
const access = createOfficeService({
  verifyToken, store, findAccount: email => auth.getUserByEmail(email),
  // Commercial files are deliberately not public. No signer is enabled until
  // private artifacts are validated and a scoped server storage identity exists.
});
const pairing = process.env.ROCHA_OFFICE_PORTAL_URL ? createPairingService({
  verifyToken, licenseStore: store, portalUrl: process.env.ROCHA_OFFICE_PORTAL_URL,
  store: { transact(id, callback) {
    return db.runTransaction(async tx => {
      const ref = db.collection('rochaOfficePairings').doc(recordKey(id));
      const doc = await tx.get(ref);
      return callback({ record: doc.exists ? doc.data() : null,
        set: record => tx.set(ref, { ...record, expiresAt: new Date(record.expiresAtMs) }) });
    });
  } },
  mintSession: async ({ uid, deviceId, googleAuthTime }) => {
    const user = await auth.getUser(uid);
    const validAfter = Date.parse(user.tokensValidAfterTime);
    if (user.disabled || !Number.isFinite(validAfter) || googleAuthTime * 1000 < validAfter) throw new Error('Google approval revoked');
    return auth.createCustomToken(uid, { officeGoogleBridge: true, officeDeviceId: deviceId, officeGoogleAuthTime: googleAuthTime });
  },
}) : null;
return createHttpHandler({ access: req => req.path.startsWith('/v1/office/pair/') && pairing ? pairing(req) : access(req), allowedOrigins: JSON.parse(process.env.ROCHA_OFFICE_ORIGINS ?? '[]') });
}

