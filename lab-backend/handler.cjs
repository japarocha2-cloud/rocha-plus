'use strict';

// A separate LAB endpoint. Never initializes trials or writes account records.
exports.createHandler = ({auth, db, projectId, now = Date.now}) => async (req, res) => {
  res.set('Cache-Control', 'no-store');
  if (projectId() !== 'rocha-plus-homologacao') return res.status(503).json({allowed: false});
  if (req.method !== 'GET') return res.status(405).json({allowed: false});
  const bearer = req.get('authorization') || '';
  if (!/^Bearer \S+$/.test(bearer)) return res.status(401).json({allowed: false});
  let claims;
  try { claims = await auth.verifyIdToken(bearer.slice(7), true); }
  catch (_) { return res.status(401).json({allowed: false}); }
  const uid = claims?.uid;
  if (typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/') ||
      !['google.com', 'apple.com'].includes(claims.firebase?.sign_in_provider)) {
    return res.status(401).json({allowed: false});
  }
  try {
    const time = now();
    if (!Number.isSafeInteger(time) || time <= 0) return res.status(503).json({allowed: false});
    if (claims.rochaAdmin === true) {
      return res.status(200).json({uid, readOnly: true, allowed: true, reason: 'admin', validForMs: 60000});
    }
    const snapshot = await db.collection('entitlements').doc(uid).get();
    // An absent document denies access. A GET must never create a trial.
    const data = snapshot.exists ? snapshot.data() : {};
    function timestamp(value) {
      if (value == null) return 0;
      if (typeof value.toMillis !== 'function') throw new Error('invalid timestamp');
      const n = value.toMillis();
      if (!Number.isSafeInteger(n) || n < 0) throw new Error('invalid timestamp');
      return n;
    }
    const trial = timestamp(data.trialUntil), paid = timestamp(data.paidUntil);
    const until = Math.max(trial, paid);
    return res.status(200).json({uid, readOnly: true, allowed: until > time,
      reason: paid > time ? 'paid' : trial > time ? 'trial' : 'expired',
      validForMs: Math.max(0, Math.min(60000, until - time))});
  } catch (_) { return res.status(503).json({allowed: false}); }
};
