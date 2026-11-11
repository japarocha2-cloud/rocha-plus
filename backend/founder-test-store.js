// Emulator-only persistence for the planning simulator; not a billing entitlement source.
import { founderRenewal } from './founder-sandbox.js';
const projectId = 'demo-rocha-billing';
const plans = { monthly: 490, yearly: 5390 };
const eventTypes = new Set(['cancel', 'reactivate-before-expiry', 'expire', 'payment-failure', 'change-plan', 'return', 'renew']);
function guard(db) {
  if (db.projectId !== projectId || process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080')
    throw new Error('founder-simulator-requires-demo-emulator');
}
function userRef(db, uid) {
  guard(db);
  if (typeof uid !== 'string' || !uid || uid.includes('/') || uid.length > 128)
    throw new Error('invalid-test-user');
  return db.doc('founderTestUsers/' + uid);
}
export function createFounderTestStore(db, now = Date.now) {
  guard(db);
  return {
    async read(uid) { return (await userRef(db, uid).get()).data() ?? null; },
    async enroll(uid, basePlanId) {
      const ref = userRef(db, uid);
      if (!Object.hasOwn(plans, basePlanId)) throw new Error('invalid-test-plan');
      return db.runTransaction(async tx => {
        const existing = await tx.get(ref);
        // Never overwrite prior history or allow enrollment to recover a lost benefit.
        if (existing.exists) throw new Error('test-user-already-enrolled');
        const state = { eligible: true, lost: false, canceled: false, reviewRequired: false,
          basePlanId, priceCents: plans[basePlanId], revision: 0, updatedAt: now() };
        tx.set(ref, state); return state;
      });
    },
    async apply(uid, { id, type, expectedRevision }) {
      const ref = userRef(db, uid);
      if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(id) ||
          !eventTypes.has(type) || !Number.isSafeInteger(expectedRevision) || expectedRevision < 0)
        throw new Error('invalid-test-event');
      const auditRef = ref.collection('events').doc(id);
      return db.runTransaction(async tx => {
        const record = await tx.get(ref), event = await tx.get(auditRef);
        if (!record.exists) throw new Error('test-user-not-enrolled');
        const previous = record.data();
        if (event.exists) {
          const saved = event.data();
          if (saved.type !== type || saved.expectedRevision !== expectedRevision)
            throw new Error('test-event-id-reused');
          return previous; // Replay cannot restore an older state.
        }
        if (previous.revision !== expectedRevision) throw new Error('stale-test-event');
        const timestamp = now();
        const next = { ...founderRenewal(previous, type), revision: previous.revision + 1, updatedAt: timestamp };
        tx.set(ref, next);
        tx.create(auditRef, { type, expectedRevision, resultingRevision: next.revision, recordedAt: timestamp });
        return next;
      });
    },
  };
}
