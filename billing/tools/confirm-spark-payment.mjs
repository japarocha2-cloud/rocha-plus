// Explicit administrative confirmation, dry-run by default. Never put secrets in arguments.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { parseArgs } from 'node:util';
import { createProvider } from '../provider.js';
import { confirmSparkPayment } from '../spark_payment_confirmation.js';

try {
  const { values } = parseArgs({ options: {
    project: { type: 'string' }, uid: { type: 'string' }, subscription: { type: 'string' },
    invoice: { type: 'string' }, collector: { type: 'string' },
    'monthly-plan': { type: 'string' }, 'annual-plan': { type: 'string' },
    live: { type: 'boolean', default: false }, apply: { type: 'boolean', default: false },
  } });
  if (values.project !== 'rocha-plus' ||
      ![values.uid, values.subscription, values.invoice, values.collector,
        values['monthly-plan'], values['annual-plan'], process.env.MP_ACCESS_TOKEN].every(Boolean)) {
    throw new Error('spark-confirmation-configuration-required');
  }
  initializeApp({ credential: applicationDefault(), projectId: values.project });
  const result = await confirmSparkPayment({ db: getFirestore(), auth: getAuth(),
    provider: createProvider({ accessToken: process.env.MP_ACCESS_TOKEN, webhookSecret: '' }),
    uid: values.uid, subscriptionId: values.subscription, invoiceId: values.invoice,
    config: { collectorId: values.collector, planIds: { monthly: values['monthly-plan'],
      annual: values['annual-plan'] }, liveMode: values.live, now: Date.now() },
    apply: values.apply, timestamp: value => Timestamp.fromMillis(value) });
  console.log(JSON.stringify(result, null, 2));
} catch (error) {
  const code = /^spark-confirmation-[a-z-]+$/.test(error.message ?? '')
    ? error.message : 'spark-confirmation-verification-failed';
  // A transport error can occur after a commit; never assert that nothing changed.
  console.error(JSON.stringify({ outcome: 'not-confirmed', error: code }));
  process.exitCode = 1;
}
