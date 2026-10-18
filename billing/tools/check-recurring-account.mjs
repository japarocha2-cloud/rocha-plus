// Read-only administrator audit. No charge, cancellation, renewal or Firestore write.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createProvider } from '../provider.js';
import { checkedSubscription, checkedRecurringPayment, normalizeEmail } from '../recurring.js';
import { userKey } from '../store.js';
import { access } from '../policy.js';
const args = process.argv.slice(2);
const value = name => args.includes(name) ? args[args.indexOf(name) + 1] : null;
const projectId = value('--project'), uid = value('--uid');
const collectorId = value('--collector');
const planIds = { monthly: value('--monthly-plan'), annual: value('--annual-plan') };
if (![projectId, uid, collectorId, planIds.monthly, planIds.annual, process.env.MP_ACCESS_TOKEN].every(Boolean)) {
  throw new Error('Provide project, UID, collector and both existing plan IDs; set MP_ACCESS_TOKEN securely in this process.');
}
initializeApp({ credential: applicationDefault(), projectId });
const account = await getAuth().getUser(uid);
if (!account.emailVerified || !account.email || account.disabled) throw new Error('Verified active login required.');
const email = normalizeEmail(account.email);
const provider = createProvider({ accessToken: process.env.MP_ACCESS_TOKEN, webhookSecret: '' });
const now = Date.now(), config = { collectorId, planIds, liveMode: args.includes('--live'), now };
const user = (await getFirestore().doc('rochaBillingUsers/' + userKey(uid)).get()).data();
const results = await provider.subscriptions(email, planIds);
const checks = [];
for (const item of results) {
  const sub = checkedSubscription(await provider.subscription(item.id), config);
  if (sub.email !== email) continue;
  const owner = (await getFirestore().doc('rochaBillingSubscriptions/' + sub.id).get()).data();
  let approvedCurrentCycles = 0;
  for (const invoice of await provider.invoices(sub.id)) {
    if (!invoice.payment?.id) continue;
    const full = await provider.invoice(String(invoice.id));
    const checked = checkedRecurringPayment(full, await provider.payment(String(full.payment.id)), sub, config);
    if (checked.status === 'approved' && checked.refundedCents === 0 && checked.periodEnd > now) approvedCurrentCycles++;
  }
  checks.push({ plan: sub.plan, mercadoPagoStatus: sub.status,
    storedUidBinding: owner?.uid === uid ? 'matches' : owner ? 'another-account' : 'missing', approvedCurrentCycles });
}
console.log(JSON.stringify({ readOnly: true, providerSubscriptions: checks,
  appRecord: user ? access(user, now) : 'missing', livePaymentVerified: config.liveMode }, null, 2));
