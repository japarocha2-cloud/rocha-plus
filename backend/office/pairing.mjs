import { createPublicKey, randomBytes, timingSafeEqual, verify } from 'node:crypto';
import { AccessError, deviceKey, recordKey, PRODUCT } from './service.mjs';
const fail = (status, message) => { throw new AccessError(status, message); };
const opaque = s => typeof s === 'string' && /^[\w-]{43}$/.test(s);
const equal = (a, b) => timingSafeEqual(Buffer.from(recordKey(a)), Buffer.from(recordKey(b)));

// OAuth takes place in the system browser, never in an embedded Google WebView.
// Only the installation with the private key + polling secret can redeem approval.
export function createPairingService({ verifyToken, store, licenseStore, mintSession,
  portalUrl, now = Date.now, random = () => randomBytes(32).toString('base64url') }) {
  const portal = new URL(portalUrl);
  if (portal.protocol !== 'https:' || portal.username || portal.password || portal.search || portal.hash) {
    throw new Error('HTTPS pairing portal required');
  }
  return async ({ method, path, authorization, body = {} }) => {
    if (method !== 'POST') fail(404, 'Not found');
    const timestamp = now();
    if (!Number.isSafeInteger(timestamp) || timestamp <= 0) fail(503, 'Clock unavailable');
    if (path === '/v1/office/pair/start') {
      const key = deviceKey(body.publicKey);
      if (!['Android', 'Windows', 'Navegador'].includes(body.label)) fail(400, 'Invalid installation label');
      const id = random(), secret = random(), code = random().slice(0, 8).toUpperCase();
      const record = { id, secretHash: recordKey(secret), codeHash: recordKey(code),
        publicKey: key.jwk, deviceId: key.id, label: body.label,
        expiresAtMs: timestamp + 120_000, used: false, approved: false };
      record.message = JSON.stringify({ product: PRODUCT, id, deviceId: key.id, nonce: random() });
      await store.transact(id, state => { if (state.record) fail(409, 'Pairing collision'); state.set(record); });
      const target = new URL(portal); target.hash = `pair=${id}`;
      return { id, secret, code, message: record.message, expiresAtMs: record.expiresAtMs, expiresInMs: 120_000, approvalUrl: target.href };
    }
    if (!opaque(body.id)) fail(400, 'Invalid pairing');
    if (path === '/v1/office/pair/approve') {
      if (typeof authorization !== 'string' || !/^Bearer \S+$/.test(authorization)) fail(401, 'Google sign-in required');
      let actor;
      try { actor = await verifyToken(authorization.slice(7), true); } catch { fail(401, 'Google sign-in required'); }
      if (actor?.firebase?.sign_in_provider !== 'google.com' || actor.email_verified !== true ||
          typeof actor.uid !== 'string' || !actor.uid || !Number.isSafeInteger(actor.auth_time) || actor.auth_time <= 0) fail(401, 'Verified Google sign-in required');
      const licensed = await licenseStore.transact(actor.uid, {}, state => state.payments.some(p => p.product === PRODUCT && p.status === 'confirmed'));
      if (!licensed) fail(403, 'Payment approval required');
      if (typeof body.code !== 'string' || !/^[A-Z0-9_-]{8}$/.test(body.code)) fail(400, 'Enter the code displayed in Office');
      return store.transact(body.id, state => {
        const r = state.record;
        if (!r || r.used || r.expiresAtMs <= timestamp) fail(410, 'Pairing expired');
        if (!equal(recordKey(body.code), r.codeHash)) fail(403, 'Code does not match Office');
        if (r.approved && r.uid !== actor.uid) fail(409, 'Pairing already approved');
        state.set({ ...r, approved: true, uid: actor.uid, googleAuthTime: actor.auth_time });
        return { approved: true, label: r.label, email: actor.email ?? '' };
      });
    }
    if (path !== '/v1/office/pair/finish') fail(404, 'Not found');
    if (!opaque(body.secret) || typeof body.signature !== 'string' || !/^[\w-]{86}$/.test(body.signature)) fail(400, 'Invalid pairing proof');
    const record = await store.transact(body.id, state => {
      const r = state.record;
      if (!r || r.used || r.expiresAtMs <= timestamp) fail(410, 'Pairing expired');
      if (!equal(recordKey(body.secret), r.secretHash)) fail(403, 'Pairing proof failed');
      let valid = false;
      try { valid = verify('sha256', Buffer.from(r.message),
        { key: createPublicKey({ key: r.publicKey, format: 'jwk' }), dsaEncoding: 'ieee-p1363' }, Buffer.from(body.signature, 'base64url')); } catch {}
      if (!valid) fail(403, 'Pairing proof failed');
      if (!r.approved) return null;
      state.set({ ...r, used: true }); return r;
    });
    if (!record) return { pending: true };
    // Tokens never appear in redirect URLs, audit entries or persistent pairings.
    const customToken = await mintSession({ uid: record.uid, deviceId: record.deviceId,
      googleAuthTime: record.googleAuthTime });
    if (typeof customToken !== 'string' || !customToken) fail(503, 'Session unavailable');
    return { pending: false, customToken };
  };
}
