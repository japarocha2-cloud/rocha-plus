// Administrative entitlement for the owner's verified Google account.
// No recurring charge, no client-side flag, and no changes to trial/favorites.
// Defaults to a read-only diagnostic. --apply must be explicitly supplied.
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { parseArgs } from 'node:util';

const OWNER_EMAIL = 'japarocha2@gmail.com';
const EXPIRY = Date.UTC(2099, 0, 1);
const millis = value => value?.toMillis?.() ?? (value instanceof Date ? value.getTime() : NaN);

try {
  const { values } = parseArgs({ options: {
    project: { type: 'string' },
    apply: { type: 'boolean', default: false },
  } });
  if (values.project !== 'rocha-plus') throw Error('configuration');
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) throw Error('secret-unavailable');
  const key = JSON.parse(raw);
  if (key?.type !== 'service_account' || key.project_id !== values.project ||
      typeof key.private_key !== 'string' ||
      !key.client_email?.endsWith('@rocha-plus.iam.gserviceaccount.com')) throw Error('invalid-secret');
  initializeApp({ credential: cert(key), projectId: values.project });
  const auth = getAuth(), db = getFirestore();
  const user = await auth.getUserByEmail(OWNER_EMAIL);
  const google = user.providerData?.filter(p => p.providerId === 'google.com');
  if (!user.uid || user.disabled || !user.emailVerified ||
      user.email?.trim().toLowerCase() !== OWNER_EMAIL ||
      google?.length !== 1 || !/^\d{1,128}$/.test(google[0].uid ?? '')) {
    throw Error('verified-owner-identity-required');
  }
  const ref = db.doc('rochaSparkAccounts/' + google[0].uid);
  const snapshot = await ref.get();
  if (!snapshot.exists || !Number.isFinite(millis(snapshot.data().trialStartedAt))) {
    throw Error('existing-spark-account-required');
  }
  const current = snapshot.data().paidUntil;
  if (current != null && !Number.isFinite(millis(current))) throw Error('invalid-paid-until');
  if (values.apply) {
    await db.runTransaction(async tx => {
      const doc = await tx.get(ref);
      if (!doc.exists || !Number.isFinite(millis(doc.data().trialStartedAt))) {
        throw Error('existing-spark-account-required');
      }
      const old = doc.data().paidUntil;
      if (old != null && !Number.isFinite(millis(old))) throw Error('invalid-paid-until');
      // Keep an existing billing projection consistent with the administrative grant.
      // Never overwrite an externally modified paidUntil or change a subscription ledger.
      const projectionRef = db.doc('rochaSparkBillingProjections/' + google[0].uid);
      const state = (await tx.get(projectionRef)).data();
      const currentMillis = old == null ? null : millis(old);
      if (state && (state.googleSubject !== google[0].uid || state.uid !== user.uid ||
          currentMillis !== state.lastPaidUntil)) throw Error('billing-projection-review-required');
      const target = Math.max(currentMillis || 0, EXPIRY);
      tx.update(ref, { paidUntil: Timestamp.fromMillis(target) });
      if (state) {
        tx.update(projectionRef, {
          baselinePaidUntil: Math.max(state.baselinePaidUntil || 0, target),
          lastPaidUntil: target,
        });
      }
    });
  }
  console.log(JSON.stringify({ ok:true, mode: values.apply ? 'owner-access-applied' : 'owner-readiness',
    readOnly: !values.apply, ownerVerified: true }));
} catch (_) {
  console.error(JSON.stringify({ ok:false, code:'owner-access-not-confirmed' }));
  process.exitCode = 1;
}
