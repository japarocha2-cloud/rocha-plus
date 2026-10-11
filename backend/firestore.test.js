import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc } from 'firebase/firestore';
import { createStore, tokenKey } from './store.js';
import { createFounderTestStore } from './founder-test-store.js';
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
    await t.test('founder simulator refuses a non-demo project and missing emulator', async () => {
      assert.throws(() => createFounderTestStore({projectId:'rocha-production'}));
      const host = process.env.FIRESTORE_EMULATOR_HOST;
      try {
        delete process.env.FIRESTORE_EMULATOR_HOST;
        assert.throws(() => createFounderTestStore(db));
      } finally { process.env.FIRESTORE_EMULATOR_HOST = host; }
    });
    await t.test('monthly and annual founder test records survive a new store instance', async () => {
      const founders = createFounderTestStore(db);
      assert.equal((await founders.enroll('founder-monthly','monthly')).priceCents,490);
      assert.equal((await founders.enroll('founder-annual','yearly')).priceCents,5390);
      const restored = await createFounderTestStore(db).read('founder-annual');
      assert.equal(restored.basePlanId,'yearly'); assert.equal(restored.eligible,true);
      await assert.rejects(founders.enroll('wrong-plan','unexpected'));
      await assert.rejects(founders.enroll('../other','yearly'));
      await assert.rejects(founders.apply('not-enrolled',{id:'fake',type:'renew',expectedRevision:0}));
    });
    await t.test('cancel then expiry permanently loses founder benefit across restore and re-enrollment', async () => {
      const founders = createFounderTestStore(db);
      await founders.enroll('founder-lost','yearly');
      assert.equal((await founders.apply('founder-lost',{id:'cancel',type:'cancel',expectedRevision:0})).eligible,true);
      const expired = await founders.apply('founder-lost',{id:'expire',type:'expire',expectedRevision:1});
      assert.equal(expired.eligible,false); assert.equal(expired.lost,true);
      const restarted = createFounderTestStore(db);
      assert.equal((await restarted.read('founder-lost')).lost,true);
      assert.equal((await restarted.apply('founder-lost',{id:'return',type:'return',expectedRevision:2})).eligible,false);
      await assert.rejects(restarted.enroll('founder-lost','yearly'));
      assert.equal((await restarted.read('founder-lost')).lost,true);
    });
    await t.test('resume before expiry and eligible renewal preserve original annual price', async () => {
      const founders = createFounderTestStore(db);
      await founders.enroll('founder-continuous','yearly');
      await founders.apply('founder-continuous',{id:'cancel',type:'cancel',expectedRevision:0});
      const resumed = await founders.apply('founder-continuous',{id:'resume',type:'reactivate-before-expiry',expectedRevision:1});
      assert.equal(resumed.canceled,false); assert.equal(resumed.eligible,true);
      const renewed = await founders.apply('founder-continuous',{id:'renew',type:'renew',expectedRevision:2});
      assert.equal(renewed.priceCents,5390); assert.equal(renewed.lost,false);
    });
    await t.test('late replay and conflicting event IDs cannot overwrite expired founder history', async () => {
      const founders = createFounderTestStore(db);
      await founders.enroll('founder-replay','monthly');
      const cancel = {id:'cancel',type:'cancel',expectedRevision:0};
      await founders.apply('founder-replay',cancel);
      assert.equal((await founders.apply('founder-replay',cancel)).revision,1);
      await founders.apply('founder-replay',{id:'expiry',type:'expire',expectedRevision:1});
      const replay = await founders.apply('founder-replay',cancel);
      assert.equal(replay.lost,true); assert.equal(replay.revision,2);
      await assert.rejects(founders.apply('founder-replay',{id:'cancel',type:'renew',expectedRevision:0}));
      await assert.rejects(founders.apply('founder-replay',{id:'outdated',type:'reactivate-before-expiry',expectedRevision:0}));
      const events = await db.collection('founderTestUsers/founder-replay/events').get();
      assert.equal(events.size,2);
    });
    await t.test('concurrent test events from the same revision have one winner', async () => {
      const founders = createFounderTestStore(db);
      await founders.enroll('founder-concurrent','yearly');
      const results = await Promise.allSettled([
        founders.apply('founder-concurrent',{id:'first',type:'cancel',expectedRevision:0}),
        founders.apply('founder-concurrent',{id:'second',type:'renew',expectedRevision:0}),
      ]);
      assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
      assert.equal((await founders.read('founder-concurrent')).revision,1);
    });
    await t.test('unresolved payment and migration remain marked for review without changing the price', async () => {
      const founders = createFounderTestStore(db);
      await founders.enroll('founder-review','yearly');
      await founders.apply('founder-review',{id:'failure',type:'payment-failure',expectedRevision:0});
      const state = await founders.apply('founder-review',{id:'migration',type:'change-plan',expectedRevision:1});
      assert.equal(state.reviewRequired,true); assert.equal(state.priceCents,5390);
      assert.equal(state.basePlanId,'yearly');
    });
    await t.test('test founder records and event history reject anonymous, owner and other clients', async () => {
      for (const context of [env.unauthenticatedContext(),env.authenticatedContext('founder-replay'),env.authenticatedContext('attacker')]) {
        const client=context.firestore();
        for (const path of ['founderTestUsers/founder-replay','founderTestUsers/founder-replay/events/cancel']) {
          await assertFails(getDoc(doc(client,path)));
          await assertFails(setDoc(doc(client,path),{eligible:true,lost:false}));
          await assertFails(deleteDoc(doc(client,path)));
        }
      }
    });
  } finally { await env.cleanup(); await db.terminate(); await deleteApp(app); }
});
