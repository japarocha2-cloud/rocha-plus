import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { createStore, tokenKey } from './store.js';
const projectId = 'demo-rocha-billing';
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080') {
  throw new Error('Tests require localhost Firestore emulator; no production fallback');
}
test('Firestore transactions and private billing rules', async t => {
  const app = initializeApp({projectId}, 'billing-tests');
  const db = getFirestore(app);
  const env = await initializeTestEnvironment({ projectId,
    firestore: { host: '127.0.0.1', port: 8080,
      rules: await readFile(new URL('./firestore.rules', import.meta.url), 'utf8') } });
  const store = createStore(db);
  try {
    await t.test('concurrent ownership claims have exactly one winner', async () => {
      const token='concurrent-test-token';
      const results=await Promise.allSettled([
        store.claim('one',token),store.claim('two',token)]);
      assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
      const owner=await store.owner(token);
      assert.ok(['one','two'].includes(owner));
      assert.deepEqual(await store.tokens(owner),[token]);
      assert.deepEqual(await store.tokens(owner==='one'?'two':'one'),[]);
    });
    await t.test('duplicate claim is idempotent; restore preserves both tokens', async () => {
      await store.claim('restore','restore-token-one');
      await store.claim('restore','restore-token-two');
      await store.claim('restore','restore-token-one');
      assert.deepEqual(await store.tokens('restore'),['restore-token-one','restore-token-two']);
    });
    await t.test('linked token ownership is checked atomically', async () => {
      await store.claim('linked-owner','linked-existing-token');
      await assert.rejects(store.claim('attacker','linked-new-token','linked-existing-token'));
      assert.equal(await store.owner('linked-new-token'),undefined);
    });
    await t.test('single-token candidate migrates without losing old ownership', async () => {
      await db.doc('billingUsers/legacy').set({token:'legacy-token-old',expiresAt:1});
      await db.doc('billingTokens/'+tokenKey('legacy-token-old')).set({uid:'legacy'});
      await store.claim('legacy','legacy-token-new');
      assert.deepEqual(await store.tokens('legacy'),['legacy-token-old','legacy-token-new']);
    });
    await t.test('anonymous and authenticated clients cannot read or write billing data', async () => {
      for (const context of [env.unauthenticatedContext(),env.authenticatedContext('one')]) {
        const client=context.firestore();
        for (const path of ['billingUsers/one','billingTokens/'+tokenKey('concurrent-test-token')]) {
          await assertFails(getDoc(doc(client,path)));
          await assertFails(setDoc(doc(client,path),{uid:'attacker',tokens:['fake']}));
        }
      }
    });
  } finally { await env.cleanup(); await db.terminate(); await deleteApp(app); }
});
