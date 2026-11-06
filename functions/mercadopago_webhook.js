'use strict';

const {createHmac, timingSafeEqual, randomUUID} = require('node:crypto');

const PAYMENT_ID = /^[0-9]{1,30}$/;
const NOTIFICATION_ID = /^[0-9]{1,30}$/;
const REQUEST_ID = /^[A-Za-z0-9._-]{1,200}$/;
const HASH_HEX = /^[a-f0-9]{64}$/i;

function header(req, name) {
  if (typeof req.get === 'function') return req.get(name);
  return req.headers?.[name.toLowerCase()];
}

function parseSignature(value) {
  if (typeof value !== 'string' || value.length > 512) return null;
  const fields = new Map();
  for (const part of value.split(',')) {
    const split = part.indexOf('=');
    if (split < 1) return null;
    const key = part.slice(0, split).trim();
    const item = part.slice(split + 1).trim();
    if (!['ts', 'v1'].includes(key) || fields.has(key)) return null;
    fields.set(key, item);
  }
  const ts = fields.get('ts'), v1 = fields.get('v1');
  if (!/^[0-9]{10,16}$/.test(ts || '') || !HASH_HEX.test(v1 || '')) return null;
  return {ts, v1};
}

/** Mercado Pago manifest: id:<data.id>;request-id:<x-request-id>;ts:<ts>; */
function verifyWebhookSignature({signature, requestId, dataId, secret}) {
  if (typeof secret !== 'string' || secret.length < 16 ||
      !REQUEST_ID.test(requestId || '') || !PAYMENT_ID.test(dataId || '')) return false;
  const parsed = parseSignature(signature);
  if (!parsed) return false;
  const manifest = 'id:' + dataId + ';request-id:' + requestId + ';ts:' + parsed.ts + ';';
  const expected = createHmac('sha256', secret).update(manifest).digest();
  const supplied = Buffer.from(parsed.v1, 'hex');
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

function associationPending(error) {
  return [
    'independently reviewed UID and plan required',
    'unverified account association',
    'payment does not match reviewed claim',
    'payment ownership conflict',
    'payment ledger document identity mismatch',
    'account trial must be initialized first',
  ].includes(error?.message);
}

function reply(res, status, body) {
  return res.status(status).json(body);
}

/**
 * Payment-only callback. A verified callback is just a signal: reconcilePayment
 * must re-fetch the canonical payment from Mercado Pago and use server-owned claims.
 * The inbox dependency persists event state; no client-provided status grants access.
 */
function createMercadoPagoWebhookHandler({secret, reconcilePayment, inbox}) {
  if (!reconcilePayment || typeof inbox?.begin !== 'function' ||
      typeof inbox?.finish !== 'function') throw new Error('webhook-dependencies-required');

  return async function mercadoPagoWebhook(req, res) {
    if (req.method !== 'POST') return reply(res, 405, {received: false});

    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const query = req.query && typeof req.query === 'object' ? req.query : {};
    const eventType = body.type || query.type || query.topic;
    if (eventType !== 'payment') return reply(res, 200, {received: true, ignored: true});

    const dataId = typeof query['data.id'] === 'string' ? query['data.id'] : '';
    const bodyId = body.data?.id == null ? null : String(body.data.id);
    const notificationId = body.id == null ? '' : String(body.id);
    const requestId = header(req, 'x-request-id');
    const signature = header(req, 'x-signature');
    if (!PAYMENT_ID.test(dataId) || !NOTIFICATION_ID.test(notificationId) ||
        (bodyId != null && bodyId !== dataId) || !REQUEST_ID.test(requestId || '')) {
      return reply(res, 400, {received: false});
    }

    const key = typeof secret === 'function' ? secret() : secret;
    if (!verifyWebhookSignature({signature, requestId, dataId, secret: key})) {
      return reply(res, 401, {received: false});
    }

    const action = body.action === 'payment.created' || body.action === 'payment.updated'
      ? body.action : 'payment.notification';
    let receipt;
    try {
      receipt = await inbox.begin({notificationId, paymentId: dataId, action});
    } catch (_) {
      return reply(res, 503, {received: false});
    }
    if (receipt?.status === 'processed') {
      return reply(res, 200, {received: true, duplicate: true});
    }
    if (receipt?.status === 'busy') {
      return reply(res, 503, {received: false, retry: true});
    }

    try {
      await reconcilePayment({paymentId: dataId});
      await inbox.finish({notificationId, paymentId: dataId, status: 'processed', reason: null, token: receipt?.token});
      return reply(res, 200, {received: true, processed: true});
    } catch (error) {
      if (associationPending(error)) {
        try {
          await inbox.finish({notificationId, paymentId: dataId, status: 'review_required',
            reason: 'payment_account_association_required', token: receipt?.token});
        } catch (_) {
          return reply(res, 503, {received: false});
        }
        // A durable inbox record allows a trusted reconciliation worker to resume.
        return reply(res, 200, {received: true, reviewRequired: true});
      }
      try {
        await inbox.finish({notificationId, paymentId: dataId, status: 'retryable_failure',
          reason: 'provider_or_storage_failure', token: receipt?.token});
      } catch (_) { /* provider retry remains the recovery mechanism */ }
      return reply(res, 503, {received: false});
    }
  };
}



/** Firestore inbox with a per-payment lease to serialize simultaneous notices.
 * Expired leases can be recovered after a function crash; all data stays server-side.
 */
function createFirestoreWebhookInbox({db, admin, leaseMs = 120000,
  collectionName = 'mercadoPagoWebhookInbox', lockCollectionName = 'mercadoPagoWebhookLocks'}) {
  const collection = db.collection(collectionName);
  const locks = db.collection(lockCollectionName);
  return {
    begin: ({notificationId, paymentId, action}) => db.runTransaction(async tx => {
      const eventRef = collection.doc(notificationId);
      const lockRef = locks.doc(paymentId);
      const [eventSnap, lockSnap] = await Promise.all([tx.get(eventRef), tx.get(lockRef)]);
      if (eventSnap.exists && eventSnap.data().paymentId !== paymentId) {
        throw new Error('notification-conflict');
      }
      const event = eventSnap.exists ? eventSnap.data() : null;
      if (event?.status === 'processed') return event;
      const now = admin.firestore.Timestamp.now();
      if (lockSnap.exists && lockSnap.data().leaseUntil?.toMillis?.() > now.toMillis()) {
        return {status: 'busy'};
      }
      const token = randomUUID();
      const leaseUntil = admin.firestore.Timestamp.fromMillis(now.toMillis() + leaseMs);
      tx.set(eventRef, {provider: 'mercadopago', paymentId, action, status: 'processing',
        token, startedAt: now, leaseUntil}, {merge: true});
      tx.set(lockRef, {paymentId, notificationId, token, leaseUntil});
      return {status: 'processing', token};
    }),
    finish: ({notificationId, paymentId, status, reason, token}) => db.runTransaction(async tx => {
      const eventRef = collection.doc(notificationId);
      const lockRef = locks.doc(paymentId);
      const [eventSnap, lockSnap] = await Promise.all([tx.get(eventRef), tx.get(lockRef)]);
      if (!eventSnap.exists || !lockSnap.exists || lockSnap.data().token !== token ||
          lockSnap.data().notificationId !== notificationId) throw new Error('webhook-lease-lost');
      const now = admin.firestore.Timestamp.now();
      tx.set(eventRef, {status, reason: reason || null, updatedAt: now,
        token: admin.firestore.FieldValue.delete(), leaseUntil: admin.firestore.FieldValue.delete()}, {merge: true});
      tx.delete(lockRef);
    }),
  };
}

module.exports = {createMercadoPagoWebhookHandler, createFirestoreWebhookInbox, verifyWebhookSignature};