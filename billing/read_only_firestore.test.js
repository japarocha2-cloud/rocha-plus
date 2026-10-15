import test from 'node:test';
import assert from 'node:assert/strict';
import { readOnlyFirestore } from './read_only_firestore.js';

function fixture() {
  const source = new Map([['accounts/A', { count: 1, started: new Date(1000) }]]);
  let gets = 0;
  const db = readOnlyFirestore({
    doc(path) { return { async get() { gets++; return { exists: source.has(path), data: () => source.get(path) }; } }; },
    runTransaction() { throw Error('remote writes forbidden'); },
  });
  return { db, source, gets: () => gets };
}

test('preview reads current documents and stages repeated transactions without remote writes', async () => {
  const f = fixture(), ref = f.db.doc('accounts/A');
  for (let i = 0; i < 2; i++) await f.db.runTransaction(async tx => {
    const value = (await tx.get(ref)).data();
    assert.equal(value.started.toMillis?.() ?? value.started.getTime(), 1000);
    tx.update(ref, { count: value.count + 1 });
  });
  assert.equal((await ref.get()).data().count, 3);
  assert.equal(f.source.get(ref.path).count, 1);
  assert.equal(f.gets(), 1);
  assert.deepEqual(f.db.summary(), { documentsRead: 1, documentsWithStagedWrites: 1 });
});

test('preview preserves create/update constraints and rolls back a failed transaction', async () => {
  const { db, source } = fixture(), existing = db.doc('accounts/A'), missing = db.doc('accounts/B');
  await assert.rejects(db.runTransaction(async tx => { await tx.get(existing); tx.create(existing, {}); }));
  await assert.rejects(db.runTransaction(async tx => {
    await tx.get(existing); tx.update(existing, { count: 5 }); throw Error('abort');
  }));
  assert.equal((await existing.get()).data().count, 1);
  await db.runTransaction(async tx => { await tx.get(missing); tx.create(missing, { count: 2 }); });
  assert.equal((await missing.get()).data().count, 2);
  assert.equal(source.has(missing.path), false);
});

test('snapshot data cannot mutate cached state and Timestamp methods survive staging', async () => {
  const timestamp = Object.freeze({ toMillis: () => 123 });
  const db = readOnlyFirestore({ doc: () => ({ get: async () => ({ exists: true,
    data: () => ({ nested: { value: 1 }, timestamp }) }) }) });
  const ref = db.doc('A');
  const data = (await ref.get()).data(); data.nested.value = 99;
  assert.equal((await ref.get()).data().nested.value, 1);
  await db.runTransaction(async tx => { await tx.get(ref); tx.update(ref, { timestamp }); });
  assert.equal((await ref.get()).data().timestamp.toMillis(), 123);
});
