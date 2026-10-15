// Read-only diagnostic for the preselected test subscriber.
// No billing store methods, Firestore writes, checkout, or credentials in output.
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { createProvider } from '../provider.js';
const email = 'andressarocha9706@gmail.com';
const plans = {
  monthly: '0b66f85cf2914aa88b9f1eadfa8b81a9',
  annual: 'bb0c2c90ff3d45a6a8203b69fbabf871'
};
let stage = 'setup';
try {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const token = process.env.MP_ACCESS_TOKEN;
  if (!raw || !token) throw Error('missing-secrets');
  const key = JSON.parse(raw);
  if (key.project_id !== 'rocha-plus' || key.type !== 'service_account') throw Error('project');
  initializeApp({credential:cert(key), projectId:'rocha-plus'});
  stage = 'firebase';
  const user = await getAuth().getUserByEmail(email);
  const google = user.providerData?.filter(p=>p.providerId==='google.com');
  if (user.disabled || !user.emailVerified || google?.length !== 1 ||
      user.email.toLowerCase() !== email) throw Error('identity');
  const account = await getFirestore().doc('rochaSparkAccounts/' + google[0].uid).get();
  if (!account.exists) throw Error('spark-account');
  stage = 'mercado-pago';
  const provider = createProvider({accessToken:token, webhookSecret:''});
  const subscriptions = await provider.subscriptions(email, plans);
  // Report only aggregate metadata, never personal IDs or secret values.
  const statuses = {};
  for (const s of subscriptions) {
    const status = String(s.status ?? 'unknown');
    statuses[status] = (statuses[status] ?? 0) + 1;
  }
  console.log(JSON.stringify({ok:true,readOnly:true,stage:'complete',
    accountVerified:true,subscriptionCount:subscriptions.length,statuses,
    paidAccessNotEstablishedByThisCheck:true}));
} catch (_) {
  console.error(JSON.stringify({ok:false,readOnly:true,stage,code:'subscriber-audit-not-confirmed'}));
  process.exitCode=1;
}
