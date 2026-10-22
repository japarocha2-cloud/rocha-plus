import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createOfficeService, recordKey } from './service.mjs';
import { createHttpServer } from './http_server.mjs';
if (!process.env.GOOGLE_CLOUD_PROJECT) throw new Error('Configure experimental GOOGLE_CLOUD_PROJECT');
if (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Production Office adapter refuses emulator overrides');
}
initializeApp({ credential: applicationDefault(), projectId: process.env.GOOGLE_CLOUD_PROJECT });
const db = getFirestore();
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
const access = createOfficeService({
  verifyToken: (token, checkRevoked) => getAuth().verifyIdToken(token, checkRevoked), store,
  // Commercial files are deliberately not public. No signer is enabled until
  // private artifacts are validated and a scoped server storage identity exists.
});
createHttpServer({ access, allowedOrigins: JSON.parse(process.env.ROCHA_OFFICE_ORIGINS ?? '[]') }).listen(Number(process.env.PORT ?? 8081), '127.0.0.1');
