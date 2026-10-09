import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, setDoc, getDoc, getDocs, deleteDoc, serverTimestamp } from 'firebase/firestore';
let env;
const id = 'a'.repeat(64), other = 'b'.repeat(64);
const data = () => ({name:'Canal A',url:'https://example.com/a.m3u8',
  group:'Geral',logo:null,addedAt:serverTimestamp()});
const path = (uid, key = id) => 'users/'+uid+'/favorites/'+key;
before(async () => { env = await initializeTestEnvironment({
  projectId:'demo-rocha-favorites',firestore:{host:'127.0.0.1',port:8080,
    rules:await readFile('../backend/firestore.rules','utf8')}}); });
beforeEach(async ()=>env.clearFirestore());
after(async ()=>env.cleanup());
test('same UID across sessions can save, restore list and delete',async ()=>{
  const first=env.authenticatedContext('alice').firestore();
  const second=env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(first,path('alice')),data()));
  await assertSucceeds(getDoc(doc(second,path('alice'))));
  const snapshot=await assertSucceeds(getDocs(collection(second,'users/alice/favorites')));
  if(snapshot.size!==1) throw Error('favorite not restored');
  await assertSucceeds(deleteDoc(doc(second,path('alice'))));
});
test('different account cannot read, list, write or delete another account favorites',async ()=>{
  const alice=env.authenticatedContext('alice').firestore();
  const bob=env.authenticatedContext('bob').firestore();
  await setDoc(doc(alice,path('alice')),data());
  await assertFails(getDoc(doc(bob,path('alice'))));
  await assertFails(getDocs(collection(bob,'users/alice/favorites')));
  await assertFails(setDoc(doc(bob,path('alice')),data()));
  await assertFails(deleteDoc(doc(bob,path('alice'))));
  await assertSucceeds(setDoc(doc(bob,path('bob')),data()));
});
test('anonymous access denied',async ()=>{
  const db=env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(db,path('alice')),data()));
  await assertFails(getDoc(doc(db,path('alice'))));
  await assertFails(deleteDoc(doc(db,path('alice'))));
});
test('reject malformed ID, unsafe URL, oversized values, extra fields and forged time',async ()=>{
  const db=env.authenticatedContext('alice').firestore();
  for(const invalid of [{...data(),url:'javascript:alert(1)'},{...data(),name:''},
    {...data(),name:'x'.repeat(301)},{...data(),url:'https://x/'+ 'x'.repeat(4096)},
    {...data(),logo:'file:///secret'},{...data(),isAdmin:true},{...data(),addedAt:new Date(0)}]) {
    await assertFails(setDoc(doc(db,path('alice')),invalid));
  }
  await assertFails(setDoc(doc(db,path('alice','bad-id')),data()));
});
test('per-channel additions preserve both favorites and deletion targets one channel',async ()=>{
  const db=env.authenticatedContext('alice').firestore();
  await Promise.all([setDoc(doc(db,path('alice')),data()),setDoc(doc(db,path('alice',other)),data())]);
  const both=await getDocs(collection(db,'users/alice/favorites'));
  if(both.size!==2) throw Error('overwritten favorites');
  await deleteDoc(doc(db,path('alice')));
  await assertSucceeds(getDoc(doc(db,path('alice',other))));
  const remaining=await getDocs(collection(db,'users/alice/favorites'));
  if(remaining.size!==1) throw Error('wrong deletion scope');
});
test('favorites permissions do not open billing or arbitrary documents',async ()=>{
  const db=env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db,'users/alice/entitlements/play'),{active:true}));
  await assertFails(getDoc(doc(db,'privateBillingTokens/token')));
});

test('billing expiry does not erase or prevent access to account favorites', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'billingUsers/alice'),
      {active:false, expiresAt:1, state:'SUBSCRIPTION_STATE_EXPIRED'});
  });
  const db=env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db,path('alice')),data()));
  const saved=await assertSucceeds(getDocs(collection(db,'users/alice/favorites')));
  if(saved.size!==1) throw Error('expired account lost favorites');
  for(const protectedPath of ['billingUsers/alice','billingTokens/test-token']) {
    await assertFails(getDoc(doc(db,protectedPath)));
    await assertFails(setDoc(doc(db,protectedPath),{active:true,uid:'alice'}));
  }
});
test('documented favorites rules stay identical to backend rules',async()=>{
  if(await readFile('firestore.rules','utf8') !== await readFile('../backend/firestore.rules','utf8')) {
    throw Error('security rules copies diverged');
  }
});
