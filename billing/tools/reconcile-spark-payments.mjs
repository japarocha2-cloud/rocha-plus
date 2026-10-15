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
import { readOnlyFirestore } from '../read_only_firestore.js';

let stage = 'configuration';
try {
  const { values } = parseArgs({ options: { project: { type: 'string' }, uid: { type: 'string' },
    all: { type: 'boolean', default: false }, apply: { type: 'boolean', default: false },
    preview: { type: 'boolean', default: false },
    'confirm-uid': { type: 'string' },
    collector: { type: 'string' }, 'monthly-plan': { type: 'string' }, 'annual-plan': { type: 'string' } } });
  const planIds = { monthly: values['monthly-plan'], annual: values['annual-plan'] };
  if (values.project !== 'rocha-plus' || values.collector !== '1981204845' ||
      !!values.uid === values.all || !Object.values(planIds).every(subscriptionIdValid) ||
      planIds.monthly === planIds.annual || !process.env.MP_ACCESS_TOKEN?.trim()) throw Error('configuration');
  // Production writes require an explicitly selected UID. Never mass-apply from --all.
  if (values.apply && values.all) throw Error('bulk-apply-disabled');
  if (values.preview && (values.apply || values.all)) throw Error('preview-requires-one-account');
  // Explicitly confirm the same exact Firebase UID when making production writes.
  if (values.apply && (!values.uid || values['confirm-uid'] !== values.uid)) throw Error('uid-confirmation-required');
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
    // The verified merchant's plan search is supported by this account.
    // Search by exact ID, then enforce all existing price, collector and schedule checks.
    const planResponse = await fetch('https://api.mercadopago.com/preapproval_plan/search?limit=100&offset=0', {
      method: 'GET', redirect: 'error', signal: AbortSignal.timeout(20000),
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }
    });
    if (!planResponse.ok) throw Error('plan-search');
    const planPage = await planResponse.json();
    if (!Array.isArray(planPage.results) || Number(planPage.paging?.total ?? 0) > 100) throw Error('plan-page');
    const matches = planPage.results.filter(p => p.id === planIds[plan]);
    if (matches.length !== 1) throw Error('plan-not-found-or-ambiguous');
    const commercialPlan = matches[0];
    stage = 'plan-validate-' + plan;
    try { checkedPlan(commercialPlan, plan, config); }
    catch (_) {
      const s = commercialPlan?.auto_recurring;
      const issues = {
        id: commercialPlan?.id !== planIds[plan],
        collector: String(commercialPlan?.collector_id) !== String(config.collectorId),
        status: commercialPlan?.status !== 'active',
        schedule: !s || s.currency_id !== 'BRL' ||
          Number(s.transaction_amount) !== (plan === 'monthly' ? 4.9 : 55) ||
          !((s.frequency_type === 'months' && Number(s.frequency) === (plan === 'monthly' ? 1 : 12)) ||
             (plan === 'annual' && s.frequency_type === 'years' && Number(s.frequency) === 1))
      };
      console.error(JSON.stringify({code:'commercial-plan-mismatch',plan,issues,readOnly:true}));
      throw Error('plan-validation');
    }
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
  const auth = getAuth(), db = values.preview ? readOnlyFirestore(getFirestore()) : getFirestore();
  const store = createSparkRecurringStore({ db, auth, collectorId: values.collector,
    liveMode: true, timestamp: time => Timestamp.fromMillis(time) });
  let projectionPreview;
  const service = createRecurringService({ store, provider, ...config, now: Date.now,
    projectAccess: async (uid, time) => {
      const result = await store.project(uid, time);
      if (values.preview) projectionPreview = result;
      return result;
    } });
  const counts = { checked: 0, reconciled: 0, previewed: 0, skipped: 0, notConfirmed: 0 };
  async function visit(uid) {
    try {
      const identity = await sparkIdentity(auth, uid);
      // The verified owner is exempt from billing and must not be reconciled.
      if (identity.email === 'japarocha2@gmail.com') { if (values.uid) throw Error('owner-exempt'); counts.skipped++; return; }
      const spark = (await db.doc('rochaSparkAccounts/' + identity.subject).get()).data();
      if (!spark) { if (values.uid) throw Error('target-account-missing'); counts.skipped++; return; }
      counts.checked++;
      if (values.apply) { await service.reconcileAccount(uid, identity.email); counts.reconciled++; }
      if (values.preview) { await service.reconcileAccount(uid, identity.email); counts.previewed++; }
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
  console.log(JSON.stringify({ code: values.apply ? 'spark-reconciliation-pass'
    : values.preview ? 'spark-reconciliation-preview' : 'spark-readiness-check',
    readOnly: !values.apply, ...counts,
    ...(values.preview ? { ...db.summary(), projectionPreview } : {}) }));
  if (counts.notConfirmed || (values.uid && counts.checked !== 1)) process.exitCode = 1;
} catch (_) {
  // A failure may follow partial commits. Never claim the database is unchanged.
  console.error(JSON.stringify({ code: 'spark-reconciliation-not-confirmed', stage, readOnly: !process.argv.includes('--apply') })); process.exitCode = 1;
}
