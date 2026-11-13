'use strict';

// A separate LAB endpoint. Never initializes trials or writes account records.
exports.createHandler = ({auth, db, projectId, sandbox = false, now = Date.now}) => async (req, res) => {
  let uid = null;
  const reply = (status, reason, validForMs = 0) => res.status(status).json({
    uid, readOnly: true, allowed: validForMs > 0, reason, validForMs,
  });

  res.set('Cache-Control', 'no-store');
  if (projectId() !== 'rocha-plus-homologacao') return reply(503, 'unavailable');
  if (req.method !== 'GET') return reply(405, 'method_not_allowed');
  const bearer = req.get('authorization') || '';
  if (!/^Bearer \S+$/.test(bearer)) return reply(401, 'unauthenticated');
  let claims;
  try { claims = await auth.verifyIdToken(bearer.slice(7), true); }
  catch (_) { return reply(401, 'unauthenticated'); }
  const tokenUid = claims?.uid;
  if (typeof tokenUid !== 'string' || !tokenUid || tokenUid.length > 128 || tokenUid.includes('/') ||
      !['google.com', 'apple.com'].includes(claims.firebase?.sign_in_provider)) {
    return reply(401, 'unauthenticated');
  }
  uid = tokenUid;
  try {
    const time = now();
    if (!Number.isSafeInteger(time) || time <= 0) return reply(503, 'unavailable');
    if (claims.rochaAdmin === true) {
      return reply(200, 'admin', 60000);
    }
    const collection = sandbox ? 'sandbox_entitlements' : 'entitlements';
    const snapshot = await db.collection(collection).doc(uid).get();
    // An absent document denies access. A GET must never create a trial.
    const data = snapshot.exists ? snapshot.data() : {};
    if (sandbox) {
      const paidUntil = typeof data.testPaidUntil === 'string'
        ? Date.parse(data.testPaidUntil) : NaN;
      const remaining = paidUntil - time;
      if (data.approved !== true || !Number.isFinite(remaining) || remaining <= 0) {
        return reply(200, 'expired');
      }
      return reply(200, 'paid', Math.max(1, Math.min(60000, remaining)));
    }
    function timestamp(value) {
      if (value == null) return 0;
      if (typeof value.toMillis !== 'function') throw new Error('invalid timestamp');
      const n = value.toMillis();
      if (!Number.isSafeInteger(n) || n < 0) throw new Error('invalid timestamp');
      return n;
    }
    const trial = timestamp(data.trialUntil), paid = timestamp(data.paidUntil);
    const until = Math.max(trial, paid);
    return reply(200, paid > time ? 'paid' : trial > time ? 'trial' : 'expired',
      Math.max(0, Math.min(60000, until - time)));
  } catch (_) { return reply(503, 'unavailable'); }
};
