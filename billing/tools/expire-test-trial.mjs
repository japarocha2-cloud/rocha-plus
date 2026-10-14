// Administrator-only physical test helper. Not exported as an HTTP endpoint.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { userKey } from '../store.js';
import { access } from '../policy.js';
const args = process.argv.slice(2);
const value = flag => args[args.indexOf(flag) + 1];
if (!args.includes('--project') || !args.includes('--test-uid') ||
    !value('--project') || !value('--test-uid')) {
  throw new Error('Use --project PROJECT --test-uid UID [--apply]. Defaults to read-only.');
}
initializeApp({ credential: applicationDefault(), projectId: value('--project') });
const db = getFirestore();
const ref = db.doc('rochaBillingUsers/' + userKey(value('--test-uid')));
const now = Date.now();
await db.runTransaction(async tx => {
  const user = (await tx.get(ref)).data();
  if (!user || user.uid !== value('--test-uid')) throw new Error('Existing test account required.');
  if (Object.keys(user.payments ?? {}).length) throw new Error('Use a test account without payment history.');
  if (!Number.isFinite(user.trialEndsAt)) throw new Error('Invalid trial deadline.');
  const next = { ...user, trialEndsAt: Math.min(user.trialEndsAt, now - 1) };
  console.log(JSON.stringify({ apply: args.includes('--apply'),
    before: access(user, now).state, after: access(next, now).state }));
  if (args.includes('--apply')) tx.update(ref, {
    trialEndsAt: next.trialEndsAt, physicalTestExpiredAt: now,
  });
});
