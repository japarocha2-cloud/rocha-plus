// Incident-only reads. Never call an application endpoint that may initialize a trial.
import { createHash } from 'node:crypto';
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const fingerprint = value => createHash('sha256').update(value).digest('hex');
const date = value => {
  const ms = value?.toMillis?.();
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
};
const report = { readOnly: true, writes: 0, appSessionVerified: false, checkedAt: new Date().toISOString() };
try {
  const key = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '{}');
  if (key.type !== 'service_account' || key.project_id !== 'rocha-plus') throw Error('wrong-project');
  initializeApp({ credential: cert(key), projectId: 'rocha-plus' });
  const auth = getAuth(), db = getFirestore();
  const email = process.env.INCIDENT_TARGET_EMAIL?.trim().toLowerCase();
  const paymentIds = JSON.parse(process.env.INCIDENT_PAYMENT_IDS_JSON || 'null');
  if (!email || email.length > 254 || !email.includes('@') ||
      !Array.isArray(paymentIds) || paymentIds.length < 1 || paymentIds.length > 5 ||
      !paymentIds.every(id => typeof id === 'string' && /^\d{1,30}$/.test(id)) ||
      new Set(paymentIds).size !== paymentIds.length) throw Error('private-inputs-missing');
  const user = await auth.getUserByEmail(email);
  if (user.email?.toLowerCase() !== email || user.disabled || !user.emailVerified) throw Error('identity-not-verified');
  const google = user.providerData.filter(p => p.providerId === 'google.com');
  if (google.length !== 1 || !/^\d{1,128}$/.test(google[0].uid)) throw Error('google-link-not-verified');
  const uid = user.uid, subject = google[0].uid;
  report.identity = { found: true, enabled: true, emailVerified: true,
    firebaseUidSha256: fingerprint(uid), googleSubjectSha256: fingerprint(subject),
    firebaseUidEqualsGoogleSubject: uid === subject,
    authCreatedAt: user.metadata.creationTime, lastSignInAt: user.metadata.lastSignInTime };
  const paths = {
    spark: 'rochaSparkAccounts/' + subject,
    entitlement: 'entitlements/' + uid,
    billingUser: 'rochaBillingUsers/' + fingerprint(uid),
    projection: 'rochaSparkBillingProjections/' + subject,
    billingIdentity: 'rochaSparkBillingIdentities/' + fingerprint(uid)
  };
  for (const [index, id] of paymentIds.entries()) {
    paths['claim-' + index] = 'payment_claims/' + id;
    paths['event-' + index] = 'payment_events/' + id;
    paths['billing-payment-' + index] = 'rochaBillingPayments/' + id;
    paths['manual-confirmation-' + index] = 'rochaSparkPaymentConfirmations/' + id;
  }
  report.documents = {};
  for (const [kind, path] of Object.entries(paths)) {
    const snap = await db.doc(path).get();
    const d = snap.data() || {};
    report.documents[kind] = { exists: snap.exists,
      uidPresent: typeof d.uid === 'string', uidMatchesSelected: d.uid === uid,
      googleSubjectPresent: typeof d.googleSubject === 'string', googleSubjectMatches: d.googleSubject === subject,
      paidUntilField: !Object.hasOwn(d, 'paidUntil') ? 'absent' :
        d.paidUntil === null ? 'null' : date(d.paidUntil) ? 'timestamp' : 'invalid',
      paidUntil: date(d.paidUntil), trialStartedAt: date(d.trialStartedAt),
      trialUntil: date(d.trialUntil), baselinePaidUntil: date(d.baselinePaidUntil),
      reviewed: d.reviewed === true,
      status: ['approved','pending','rejected','refunded','charged_back','cancelled'].includes(d.status) ? d.status : null,
      plan: ['monthly','annual'].includes(d.plan) ? d.plan : null,
      paymentEntries: d.payments && typeof d.payments === 'object' ? Object.keys(d.payments).length : null,
      subscriptionEntries: d.subscriptions && typeof d.subscriptions === 'object' ? Object.keys(d.subscriptions).length : null
    };
  }
  report.ledgerScopeComplete = false; // These exact paths do not inventory every experimental backend.
} catch (_) {
  report.error = 'identity-or-document-read-not-confirmed';
  process.exitCode = 1;
}
console.log(JSON.stringify(report, null, 2));
