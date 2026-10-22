import { createServer } from 'node:http';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { AccessError, createAccessService, recordKey } from './service.mjs';

// No client-provided project, token verifier, admin flag or entitlement data.
if (!process.env.GOOGLE_CLOUD_PROJECT || !process.env.ROCHA_PLANS_JSON) {
  throw new Error('Configure experimental GOOGLE_CLOUD_PROJECT and ROCHA_PLANS_JSON');
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
const server = createServer(async (req, res) => {
  // Bind only to loopback. An independently configured HTTPS gateway is mandatory.
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store, private');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  try {
    let content = '';
    for await (const chunk of req) {
      content += chunk;
      if (Buffer.byteLength(content) > 8192) throw new AccessError(413, 'Request too large');
    }
    let body;
    try { body = content ? JSON.parse(content) : {}; }
    catch { throw new AccessError(400, 'Invalid JSON'); }
    if (!body || Array.isArray(body) || typeof body !== 'object') throw new AccessError(400, 'Invalid JSON object');
    const result = await access({ method: req.method, path: req.url,
      authorization: req.headers.authorization, body });
    res.writeHead(200); res.end(JSON.stringify(result));
  } catch (error) {
    const status = error instanceof AccessError ? error.status : 503;
    res.writeHead(status);
    res.end(JSON.stringify({ allowed: false, error: status === 503 ? 'Service unavailable' : error.message }));
  }
});
server.requestTimeout = 15_000;
server.headersTimeout = 10_000;
server.listen(Number(process.env.PORT ?? 8080), '127.0.0.1');
