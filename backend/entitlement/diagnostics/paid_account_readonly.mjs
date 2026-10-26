// Owner-requested single-account diagnostic. No payment or Firebase write APIs.
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const email = 'nadiarocha10@hotmail.com';
const now = Date.now();
const report = { readOnly: true, writes: 0, appLoginTested: false,
  accessGrantedByThisCheck: false, firebase: {}, mercadoPago: {} };
const millis = value => value?.toMillis?.() ?? null;
const safeStatus = value => ['approved', 'pending', 'rejected', 'refunded',
  'cancelled', 'charged_back', 'in_process', 'authorized', 'paused'].includes(value) ? value : 'other';

try {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) throw Error('missing-firebase-credential');
  const key = JSON.parse(raw);
  if (key.project_id !== 'rocha-plus' || key.type !== 'service_account') throw Error('wrong-project');
  initializeApp({ credential: cert(key), projectId: 'rocha-plus' });
  const user = await getAuth().getUserByEmail(email);
  if (user.email?.toLowerCase() !== email) throw Error('identity-mismatch');
  report.firebase = { accountFound: true, emailVerified: user.emailVerified,
    disabled: user.disabled, googleLinked: false, sparkAccountFound: false };
  const google = user.providerData.filter(p => p.providerId === 'google.com');
  report.firebase.googleLinked = google.length === 1;
  if (google.length === 1 && /^\d{1,128}$/.test(google[0].uid)) {
    const snapshot = await getFirestore().doc('rochaSparkAccounts/' + google[0].uid).get();
    report.firebase.sparkAccountFound = snapshot.exists;
    if (snapshot.exists) {
      const data = snapshot.data();
      const paidUntil = millis(data.paidUntil);
      report.firebase.paidUntil = Number.isFinite(paidUntil) ? new Date(paidUntil).toISOString() : null;
      report.firebase.paidAccessCurrent = Number.isFinite(paidUntil) && paidUntil > now;
    }
  }
} catch (error) {
  const codes = new Set(['missing-firebase-credential', 'wrong-project', 'identity-mismatch',
    'auth/user-not-found', 'auth/insufficient-permission', 'auth/invalid-credential']);
  report.firebase.error = codes.has(error.code) ? error.code :
    codes.has(error.message) ? error.message : 'firebase-read-not-confirmed';
}

try {
  const token = process.env.MP_ACCESS_TOKEN;
  if (!token) throw Error('missing-payment-credential');
  async function get(path, params = {}) {
    const url = new URL(path, 'https://api.mercadopago.com');
    for (const [key, value] of Object.entries(params)) url.searchParams.set(key, String(value));
    const response = await fetch(url, { method: 'GET', redirect: 'error',
      signal: AbortSignal.timeout(20000),
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' } });
    if (!response.ok) throw Error('provider-http-' + response.status);
    return response.json();
  }
  async function pages(path, params) {
    const result = [];
    for (let offset = 0; offset < 200; offset += 50) {
      const page = await get(path, { ...params, offset, limit: 50 });
      if (!Array.isArray(page.results) || !Number.isSafeInteger(page.paging?.total)) {
        throw Error('incomplete-provider-search');
      }
      result.push(...page.results);
      if (offset + 50 >= page.paging.total) return result;
    }
    throw Error('incomplete-provider-search');
  }
  const merchant = await get('/users/me');
  if (!/^\d+$/.test(String(merchant.id))) throw Error('merchant-not-confirmed');
  const subscriptions = await pages('/preapproval/search', { payer_email: email });
  const matched = subscriptions.filter(s => s.payer_email?.toLowerCase() === email &&
    String(s.collector_id) === String(merchant.id));
  report.mercadoPago = { merchantAuthenticated: true, subscriptionSearchReturned: subscriptions.length, subscriptionMatches: matched.length,
    searchComplete: true, payments: [], entitlementValidated: false };
  const seen = new Set();
  for (const subscription of matched) {
    if (!/^[a-zA-Z0-9_-]{8,100}$/.test(subscription.id)) throw Error('invalid-provider-reference');
    const invoices = await pages('/authorized_payments/search', { preapproval_id: subscription.id });
    for (const invoice of invoices) {
      const id = String(invoice.payment?.id ?? '');
      if (!/^\d{1,30}$/.test(id) || seen.has(id)) continue;
      seen.add(id);
      const payment = await get('/v1/payments/' + id);
      const payerMatches = payment.payer?.email?.toLowerCase() === email;
      const merchantMatches = String(payment.collector_id) === String(merchant.id);
      report.mercadoPago.payments.push({ status: safeStatus(payment.status),
        liveMode: payment.live_mode === true, payerMatches, merchantMatches,
        amount: typeof payment.transaction_amount === 'number' ? payment.transaction_amount : null,
        currency: payment.currency_id === 'BRL' ? 'BRL' : 'other',
        refunded: Number(payment.transaction_amount_refunded ?? 0) > 0,
        approvedAt: Number.isFinite(Date.parse(payment.date_approved)) ? new Date(payment.date_approved).toISOString() : null });
    }
  }
  const recent = await pages('/v1/payments/search', {
    sort: 'date_created', criteria: 'desc', range: 'date_created',
    begin_date: 'NOW-30DAYS', end_date: 'NOW', 'collector.id': merchant.id });
  report.mercadoPago.directPaymentWindow = 'last-30-days';
  report.mercadoPago.directSearchComplete = true;
  report.mercadoPago.directPayments = recent
    .filter(p => p.payer?.email?.toLowerCase() === email &&
      String(p.collector_id) === String(merchant.id))
    .map(p => ({ status: safeStatus(p.status), liveMode: p.live_mode === true,
      amount: typeof p.transaction_amount === 'number' ? p.transaction_amount : null,
      currency: p.currency_id === 'BRL' ? 'BRL' : 'other',
      refunded: Number(p.transaction_amount_refunded ?? 0) > 0,
      approvedAt: Number.isFinite(Date.parse(p.date_approved)) ? new Date(p.date_approved).toISOString() : null,
      titleMatchesRocha: String(p.description ?? '').toLowerCase().includes('rocha') }));
  // Zero matches do not disprove a payment made with another payer or merchant,
  // Pix or an avulso checkout. No automatic association or grant is attempted.
} catch (error) {
  const safe = /^(missing-payment-credential|provider-http-\d{3}|incomplete-provider-search|merchant-not-confirmed|invalid-provider-reference)$/;
  report.mercadoPago.error = safe.test(error.message) ? error.message : 'payment-read-not-confirmed';
  report.mercadoPago.searchComplete = false;
}
console.log(JSON.stringify(report, null, 2));
if (report.firebase.error || report.mercadoPago.error) process.exitCode = 1;
