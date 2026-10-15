// Run on a trusted existing server/cron. No scheduler or paid service is created.
// Default is a read-only readiness check; --apply performs a reconciliation pass.
import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { parseArgs } from 'node:util';
import { createProvider } from '../provider.js';
import { checkedPlan, subscriptionIdValid } from '../recurring.js';
import { createRecurringService } from '../recurring_service.js';
import { createSparkRecurringStore, sparkIdentity } from '../spark_recurring_store.js';

let stage = 'configuration';
try {
  const { values } = parseArgs({ options: { project: { type: 'string' }, uid: { type: 'string' },
    all: { type: 'boolean', default: false }, apply: { type: 'boolean', default: false },
    collector: { type: 'string' }, 'monthly-plan': { type: 'string' }, 'annual-plan': { type: 'string' } } });
  const planIds = { monthly: values['monthly-plan'], annual: values['annual-plan'] };
  if (values.project !== 'rocha-plus' || values.collector !== '1981204845' ||
      !!values.uid === values.all || !Object.values(planIds).every(subscriptionIdValid) ||
      planIds.monthly === planIds.annual || !process.env.MP_ACCESS_TOKEN?.trim()) throw Error('configuration');
  const token = process.env.MP_ACCESS_TOKEN.trim();
  stage = 'merchant';
  const response = await fetch('https://api.mercadopago.com/users/me', {
    method: 'GET', redirect: 'error', signal: AbortSignal.timeout(15000),
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' } });
  if (response.status !== 200) throw Error('merchant');
  const merchant = await response.json();
  if (String(merchant.id) !== values.collector || merchant.site_id !== 'MLB' ||
      merchant.tags?.includes('test_user')) throw Error('merchant');
  const provider = createProvider({ accessToken: token, webhookSecret: '' });
  const config = { collectorId: values.collector, liveMode: true, planIds, now: Date.now() };
  for (const plan of Object.keys(planIds)) {
    stage = 'plan-fetch-' + plan;
    const commercialPlan = await provider.plan(planIds[plan]);
    stage = 'plan-validate-' + plan;
    checkedPlan(commercialPlan, plan, config);
  }
  // A GitHub Actions secret may supply the service account without writing its key to disk.
  // Never print credentials or service-account fields in logs.
  let firebaseCredential = applicationDefault();
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    let serviceAccount;
    try { serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON); }
    catch (_) { throw Error('invalid-firebase-secret'); }
    if (serviceAccount?.type !== 'service_account' ||
        serviceAccount.project_id !== values.project ||
        typeof serviceAccount.client_email !== 'string' ||
        !serviceAccount.client_email.endsWith('@rocha-plus.iam.gserviceaccount.com') ||
        typeof serviceAccount.private_key !== 'string') {
      throw Error('invalid-firebase-secret');
    }
    firebaseCredential = cert(serviceAccount);
  }
  stage = 'firebase-initialize';
  initializeApp({ credential: firebaseCredential, projectId: values.project });
  const auth = getAuth(), db = getFirestore();
  const store = createSparkRecurringStore({ db, auth, collectorId: values.collector,
    liveMode: true, timestamp: time => Timestamp.fromMillis(time) });
  const service = createRecurringService({ store, provider, ...config, now: Date.now, projectAccess: store.project });
  const counts = { checked: 0, reconciled: 0, skipped: 0, notConfirmed: 0 };
  async function visit(uid) {
    try {
      const identity = await sparkIdentity(auth, uid);
      const spark = (await db.doc('rochaSparkAccounts/' + identity.subject).get()).data();
      if (!spark) { counts.skipped++; return; }
      counts.checked++;
      if (values.apply) { await service.reconcileAccount(uid, identity.email); counts.reconciled++; }
    } catch (_) { counts.notConfirmed++; }
  }
  stage = 'account-readiness';
  if (values.uid) await visit(values.uid);
  else {
    let pageToken;
    for (let page = 0; page < 10; page++) {
      const result = await auth.listUsers(100, pageToken);
      for (const account of result.users) {
        if (account.disabled || !account.emailVerified ||
            !account.providerData.some(p => p.providerId === 'google.com')) { counts.skipped++; continue; }
        await visit(account.uid);
      }
      pageToken = result.pageToken;
      if (!pageToken) break;
      if (page === 9) throw Error('account-limit');
    }
  }
  console.log(JSON.stringify({ code: values.apply ? 'spark-reconciliation-pass' : 'spark-readiness-check',
    readOnly: !values.apply, ...counts }));
  if (counts.notConfirmed) process.exitCode = 1;
} catch (_) {
  // A failure may follow partial commits. Never claim the database is unchanged.
  console.error(JSON.stringify({ code: 'spark-reconciliation-not-confirmed', stage, readOnly: !process.argv.includes('--apply') })); process.exitCode = 1;
}
