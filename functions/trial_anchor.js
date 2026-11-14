'use strict';
// Trial start anchoring. A missing entitlement must not grant a fresh 7 days to a
// person who already started a trial (legacy Spark app, or a recreated Firebase UID).
// The start is the OLDEST of: now, rochaSparkAccounts/{subject}.trialStartedAt (valid,
// not in the future) and trialAnchors/{subject}. Existing entitlements are never touched.
const TRIAL_MS = 7 * 24 * 60 * 60 * 1000;

function googleSubjectOf(decoded) {
  const s = decoded?.firebase?.identities?.['google.com']?.[0];
  return typeof s === 'string' && s.length > 0 && s.length <= 128 && !s.includes('/') ? s : null;
}
function validSubject(s) {
  return typeof s === 'string' && s.length > 0 && s.length <= 128 && !s.includes('/');
}
function millisOf(v, nowMs) {
  let m = null;
  if (v && typeof v.toMillis === 'function') m = v.toMillis();
  else if (v instanceof Date) m = v.getTime();
  else if (typeof v === 'number') m = v;
  return Number.isFinite(m) && m > 0 && m <= nowMs ? m : null;
}

// Must run inside a transaction that already read the entitlement and found it missing.
// All reads happen before any write.
async function initializeTrial({db, tx, entitlementRef, uid, subject, nowMs, toTimestamp}) {
  let startMs = nowMs;
  let anchorRef = null;
  let anchorExists = true;
  if (validSubject(subject)) {
    anchorRef = db.collection('trialAnchors').doc(subject);
    const sparkRef = db.collection('rochaSparkAccounts').doc(subject);
    const [anchor, spark] = await Promise.all([tx.get(anchorRef), tx.get(sparkRef)]);
    anchorExists = anchor.exists;
    for (const m of [millisOf(spark.exists ? spark.data()?.trialStartedAt : null, nowMs),
      millisOf(anchor.exists ? anchor.data()?.trialStartedAt : null, nowMs)]) {
      if (m !== null && m < startMs) startMs = m;
    }
  }
  const trialStartedAt = toTimestamp(startMs);
  const initial = {trialStartedAt, trialUntil: toTimestamp(startMs + TRIAL_MS),
    createdAt: toTimestamp(nowMs)};
  tx.create(entitlementRef, initial);
  if (anchorRef && !anchorExists) tx.create(anchorRef, {trialStartedAt});
  return initial;
}
module.exports = {initializeTrial, googleSubjectOf, TRIAL_MS};
