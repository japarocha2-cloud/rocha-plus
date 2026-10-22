import { createHash, createPublicKey, randomBytes, verify } from 'node:crypto';

export const PRODUCT = 'rocha-office-basic';
export const PRICE_CENTS = 4990;
export class AccessError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export const recordKey = value => createHash('sha256').update(value).digest('hex');
const fail = (status, message) => { throw new AccessError(status, message); };
const text = (value, max = 200) => typeof value === 'string' && value.length > 0 && value.length <= max;
const actions = ['activate', 'access', 'deactivate'];
export function deviceKey(jwk) {
  if (!jwk || jwk.kty !== 'EC' || jwk.crv !== 'P-256' || jwk.d ||
      ![jwk.x, jwk.y].every(v => typeof v === 'string' && /^[\w-]{43}$/.test(v))) {
    fail(400, 'Invalid installation public key');
  }
  const normalized = { kty: 'EC', crv: 'P-256', x: jwk.x, y: jwk.y };
  try { createPublicKey({ key: normalized, format: 'jwk' }); }
  catch { fail(400, 'Invalid installation public key'); }
  return { jwk: normalized, id: recordKey(JSON.stringify(normalized)) };
}
const licensed = state => state.payments.some(p => p.product === PRODUCT && p.status === 'confirmed');

/** transact must atomically read/write UID, payment, challenge and audit records. */
export function createOfficeService({ verifyToken, store, now = Date.now,
  random = () => randomBytes(32).toString('base64url'), issueDownload, findAccount }) {
  async function identity(header) {
    if (typeof header !== 'string' || !/^Bearer \S+$/.test(header)) fail(401, 'Unauthorized');
    let actor;
    try { actor = await verifyToken(header.slice(7), true); } catch { fail(401, 'Unauthorized'); }
    const provider = actor?.firebase?.sign_in_provider;
    const google = provider === 'google.com' || (provider === 'custom' &&
      actor.officeGoogleBridge === true && /^[a-f0-9]{64}$/.test(actor.officeDeviceId ?? ''));
    if (!text(actor?.uid, 128) || !google || actor.email_verified !== true) fail(401, 'Verified Google account required');
    return actor;
  }
  return async ({ method, path, authorization, body = {} }) => {
    const actor = await identity(authorization);
    const timestamp = now();
    if (!Number.isSafeInteger(timestamp) || timestamp <= 0) fail(503, 'Clock unavailable');
    if (path === '/v1/office/me' && method === 'GET') {
      return store.transact(actor.uid, {}, state => ({ product: PRODUCT, uid: actor.uid,
        licensed: licensed(state), deviceLimit: 2,
        devices: Object.entries(state.account?.devices ?? {}).map(([id, d]) =>
          ({ id, label: d.label, activatedAtMs: d.activatedAtMs })) }));
    }
    if (path === '/v1/office/challenge' && method === 'POST') {
      if (!actions.includes(body.action)) fail(400, 'Invalid action');
      const key = deviceKey(body.publicKey);
      if (actor.firebase.sign_in_provider === 'custom' && actor.officeDeviceId !== key.id) fail(403, 'Installation session mismatch');
      if (body.label !== undefined && !text(body.label, 80)) fail(400, 'Invalid installation label');
      const challengeId = random();
      const challenge = { uid: actor.uid, deviceId: key.id, publicKey: key.jwk,
        action: body.action, label: body.label ?? 'Office', nonce: random(),
        expiresAtMs: timestamp + 60_000, used: false };
      // Store the exact signed message; never accept a client replacement.
      challenge.message = JSON.stringify({ product: PRODUCT, uid: actor.uid,
        deviceId: key.id, action: body.action, challengeId, nonce: challenge.nonce });
      return store.transact(actor.uid, { challengeId }, state => {
        if (!licensed(state)) fail(403, 'Payment approval required');
        if (state.account?.revokedDevices?.[key.id]) fail(403, 'Installation revoked');
        state.setChallenge(challenge);
        return { challengeId, message: challenge.message, expiresAtMs: challenge.expiresAtMs };
      });
    }
    if (method === 'POST' && actions.some(action => path === `/v1/office/${action}`)) {
      if (!text(body.challengeId, 80) || !/^[\w-]{43}$/.test(body.challengeId) ||
          typeof body.signature !== 'string' || !/^[\w-]{86}$/.test(body.signature)) {
        fail(400, 'Invalid installation proof');
      }
      const action = path.split('/').at(-1);
      const result = await store.transact(actor.uid, { challengeId: body.challengeId }, state => {
        const c = state.challenge;
        if (!c || c.uid !== actor.uid || c.action !== action || c.used || c.expiresAtMs <= timestamp) {
          fail(403, 'Expired or invalid installation challenge');
        }
        let valid = false;
        try { valid = verify('sha256', Buffer.from(c.message),
          { key: createPublicKey({ key: c.publicKey, format: 'jwk' }), dsaEncoding: 'ieee-p1363' },
          Buffer.from(body.signature, 'base64url')); } catch {}
        if (!valid) fail(403, 'Installation proof failed');
        if (!licensed(state)) fail(403, 'Payment approval required');
        if (state.account?.revokedDevices?.[c.deviceId]) fail(403, 'Installation revoked');
        const devices = { ...state.account?.devices };
        if (action === 'activate') {
          if (!devices[c.deviceId] && Object.keys(devices).length >= 2) fail(409, 'Two installation limit reached');
          devices[c.deviceId] ??= { label: c.label, activatedAtMs: timestamp };
        } else if (!devices[c.deviceId]) fail(403, 'Installation is not active');
        if (action === 'deactivate') delete devices[c.deviceId];
        state.setChallenge({ ...c, used: true });
        if (action !== 'access') {
          state.setAccount({ ...state.account, uid: actor.uid, devices });
          state.audit(action, { uid: actor.uid, deviceId: c.deviceId, atMs: timestamp });
        }
        return { product: PRODUCT, uid: actor.uid, deviceId: c.deviceId,
          allowed: action !== 'deactivate', activeDevices: Object.keys(devices).length };
      });
      // File signing is server-owned; no public installers or arbitrary target URLs.
      if (action === 'access' && body.download === true) {
        if (!['android', 'windows'].includes(body.platform) || typeof issueDownload !== 'function') {
          fail(503, 'Commercial download unavailable');
        }
        const file = await issueDownload({ uid: actor.uid, deviceId: result.deviceId,
          platform: body.platform, expiresAtMs: timestamp + 60_000 });
        if (!file || typeof file.url !== 'string' || !file.url.startsWith('https://') ||
            file.expiresAtMs !== timestamp + 60_000) fail(503, 'Commercial download unavailable');
        return { ...result, download: file };
      }
      return result;
    }
    if (method !== 'POST' || !['/v1/office/admin/confirm', '/v1/office/admin/refund',
      '/v1/office/admin/revoke-device', '/v1/office/admin/lookup'].includes(path)) fail(404, 'Not found');
    if (actor.rochaOfficeAdmin !== true || actor.firebase.sign_in_provider !== 'google.com') fail(403, 'Office administrator required');
    if (path.endsWith('/lookup')) {
      if (!text(body.email, 254) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(body.email) || typeof findAccount !== 'function') fail(400, 'Valid Google email required');
      let buyer;
      try { buyer = await findAccount(body.email.trim().toLowerCase()); } catch { fail(404, 'Google account not found'); }
      if (!text(buyer?.uid, 128) || buyer.emailVerified !== true || buyer.disabled || !buyer.providerData?.some(p => p.providerId === 'google.com')) fail(404, 'Verified Google account not found');
      return store.transact(buyer.uid, {}, state => ({ uid: buyer.uid, email: buyer.email,
        licensed: licensed(state), devices: Object.entries(state.account?.devices ?? {}).map(([id, d]) => ({ id, label: d.label })) }));
    }
    if (!text(body.uid, 128) || !text(body.evidenceReference, 500)) fail(400, 'Evidence required');
    if (path.endsWith('/revoke-device')) {
      if (!text(body.deviceId, 64) || !/^[a-f0-9]{64}$/.test(body.deviceId)) fail(400, 'Invalid device');
      return store.transact(body.uid, {}, state => {
        const devices = { ...state.account?.devices };
        delete devices[body.deviceId]; state.setAccount({ ...state.account, uid: body.uid, devices,
          revokedDevices: { ...state.account?.revokedDevices, [body.deviceId]: timestamp } });
        state.audit('admin-revoke-device', { uid: body.uid, deviceId: body.deviceId,
          adminUid: actor.uid, atMs: timestamp, evidenceReference: body.evidenceReference });
        return { revoked: true };
      });
    }
    if (!text(body.provider, 40) || !text(body.transactionId)) fail(400, 'Invalid transaction');
    const paymentId = recordKey(JSON.stringify([body.provider, body.transactionId]));
    return store.transact(body.uid, { paymentId }, state => {
      const prior = state.payment;
      if (prior && (prior.uid !== body.uid || prior.product !== PRODUCT)) fail(409, 'Transaction already assigned');
      if (path.endsWith('/confirm')) {
        if (body.product !== PRODUCT || body.amountCents !== PRICE_CENTS || body.currency !== 'BRL') {
          fail(400, 'Office payment must be BRL 49.90');
        }
        if (prior) {
          if (prior.status !== 'confirmed') fail(409, 'Refunded transaction cannot be reused');
          return { status: 'confirmed', duplicate: true };
        }
        state.setPayment({ id: paymentId, uid: body.uid, product: PRODUCT,
          provider: body.provider, transactionId: body.transactionId,
          amountCents: PRICE_CENTS, currency: 'BRL', status: 'confirmed',
          confirmedAtMs: timestamp, confirmedBy: actor.uid, evidenceReference: body.evidenceReference });
        state.audit('confirmed', { uid: body.uid, paymentId, adminUid: actor.uid, atMs: timestamp });
        return { status: 'confirmed', duplicate: false };
      }
      if (!prior) fail(404, 'Payment not found');
      if (prior.status === 'refunded') return { status: 'refunded', duplicate: true };
      state.setPayment({ ...prior, status: 'refunded', refundedAtMs: timestamp,
        refundedBy: actor.uid, refundEvidenceReference: body.evidenceReference });
      // Every installation is removed when the final confirmed payment is refunded.
      if (!state.payments.some(p => p.id !== paymentId && p.status === 'confirmed' && p.product === PRODUCT)) {
        state.setAccount({ ...state.account, uid: body.uid, devices: {} });
      }
      state.audit('refunded', { uid: body.uid, paymentId, adminUid: actor.uid, atMs: timestamp });
      return { status: 'refunded', duplicate: false };
    });
  };
}
