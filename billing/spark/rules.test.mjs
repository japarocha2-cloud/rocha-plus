import { readFile } from 'node:fs/promises';
import test, { before, after, beforeEach } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs, serverTimestamp, Timestamp } from 'firebase/firestore';
let env;
const owner = (uid='firebase-A', google='111') => env.authenticatedContext(uid, {
  email_verified: true, firebase: {identities: {'google.com':[google]}, sign_in_provider:'google.com'},
}).firestore();
const record = db => doc(db, 'rochaSparkAccounts/111');
const trial = () => ({trialStartedAt:serverTimestamp(), welcomeAcceptedAt:null});
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-rocha-spark',
  firestore:{host:'127.0.0.1',port:8089,rules:await readFile('firestore.rules','utf8')}});});
after(async()=>env?.cleanup());
beforeEach(async()=>env.clearFirestore());
test('verified Google owner can create one trial, with server time',async()=>{
  const db=owner();await assertSucceeds(setDoc(record(db),trial()));
  await assertSucceeds(getDoc(record(db)));
  await assertFails(setDoc(record(db),trial()));
});
test('anonymous, unverified and other Google accounts cannot access another record',async()=>{
  await assertSucceeds(setDoc(record(owner()),trial()));
  await assertFails(getDoc(record(env.unauthenticatedContext().firestore())));
  const unverified=env.authenticatedContext('firebase-A',{email_verified:false,
    firebase:{identities:{'google.com':['111']}}}).firestore();
  await assertFails(getDoc(record(unverified)));
  await assertFails(getDoc(record(owner('firebase-B','222'))));
  await assertFails(setDoc(record(owner('firebase-B','222')),trial()));
});
test('deleting and resetting a trial and choosing client time are forbidden',async()=>{
  const db=owner();await assertFails(setDoc(record(db),{
    trialStartedAt:Timestamp.fromMillis(0),welcomeAcceptedAt:null}));
  await assertSucceeds(setDoc(record(db),trial()));
  await assertFails(deleteDoc(record(db)));
  await assertFails(updateDoc(record(db),{trialStartedAt:serverTimestamp()}));
});
test('clients cannot create or extend paid access',async()=>{
  const db=owner();await assertFails(setDoc(record(db),{...trial(),paidUntil:serverTimestamp()}));
  await assertSucceeds(setDoc(record(db),trial()));
  await assertFails(updateDoc(record(db),{paidUntil:Timestamp.fromMillis(Date.now()+86400000)}));
});
test('acceptance can be recorded only once and cannot be cleared',async()=>{
  const db=owner();await assertSucceeds(setDoc(record(db),trial()));
  await assertSucceeds(updateDoc(record(db),{welcomeAcceptedAt:serverTimestamp()}));
  await assertFails(updateDoc(record(db),{welcomeAcceptedAt:null}));
  await assertFails(updateDoc(record(db),{welcomeAcceptedAt:Timestamp.fromMillis(0)}));
});
test('recreated Firebase UID for the same Google account preserves trial and acceptance',async()=>{
  const first=owner();await assertSucceeds(setDoc(record(first),trial()));
  await assertSucceeds(updateDoc(record(first),{welcomeAcceptedAt:serverTimestamp()}));
  const recreated=owner('recreated-uid','111');
  const result=await assertSucceeds(getDoc(record(recreated)));
  if(!result.data().welcomeAcceptedAt)throw Error('Acceptance lost');
  await assertFails(setDoc(record(recreated),trial()));
});
test('no collection enumeration and acceptance cannot overwrite admin payment fields',async()=>{
  await env.withSecurityRulesDisabled(async ctx=>setDoc(record(ctx.firestore()),{
    trialStartedAt:Timestamp.fromMillis(1),welcomeAcceptedAt:null,paidUntil:Timestamp.fromMillis(999999)}));
  const db=owner();await assertFails(getDocs(collection(db,'rochaSparkAccounts')));
  await assertSucceeds(updateDoc(record(db),{welcomeAcceptedAt:serverTimestamp()}));
  const data=(await getDoc(record(db))).data();
  if(data.paidUntil.toMillis()!==999999)throw Error('Payment overwritten');
});
test('existing favorites permissions are preserved',async()=>{
  const db=owner(),path='users/firebase-A/favorites/'+'a'.repeat(64);
  await assertSucceeds(setDoc(doc(db,path),{name:'Canal',url:'https://example.org/live.m3u8',
    group:'TV aberta',logo:null,addedAt:serverTimestamp()}));
  await assertSucceeds(getDoc(doc(db,path)));
  await assertFails(getDoc(doc(owner('firebase-B','222'),path)));
});
test('REST protocol returns server readTime and supports atomic acceptance transforms',async()=>{
  const project='demo-rocha-spark',now=Math.floor(Date.now()/1000);
  const payload={sub:'rest-A',user_id:'rest-A',aud:project,iss:'https://securetoken.google.com/'+project,
    iat:now,exp:now+3600,email_verified:true,firebase:{identities:{'google.com':['111']},sign_in_provider:'google.com'}};
  const token=Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url')+'.'+
    Buffer.from(JSON.stringify(payload)).toString('base64url')+'.';
  const base='projects/'+project+'/databases/(default)',name=base+'/documents/rochaSparkAccounts/111';
  const post=async(operation,body)=>fetch('http://127.0.0.1:8089/v1/'+base+'/documents:'+operation,{
    method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body)});
  let reply=await post('batchGet',{documents:[name]});
  if(reply.status!==200)throw Error('REST read '+await reply.text());
  let result=await reply.json();
  if(!Array.isArray(result)||result.length!==1||!result[0].readTime||result[0].missing!==name)throw Error('Missing server readTime');
  reply=await post('commit',{writes:[{update:{name,fields:{welcomeAcceptedAt:{nullValue:null}}},
    updateTransforms:[{fieldPath:'trialStartedAt',setToServerValue:'REQUEST_TIME'}],currentDocument:{exists:false}}]});
  if(reply.status!==200)throw Error('REST create '+await reply.text());
  result=await (await post('batchGet',{documents:[name]})).json();
  const version=result[0].found.updateTime;
  reply=await post('commit',{writes:[{transform:{document:name,fieldTransforms:[
    {fieldPath:'welcomeAcceptedAt',setToServerValue:'REQUEST_TIME'}]},currentDocument:{updateTime:version}}]});
  if(reply.status!==200)throw Error('REST accept '+await reply.text());
  result=await (await post('batchGet',{documents:[name]})).json();
  if(!result[0].found.fields.welcomeAcceptedAt.timestampValue||!result[0].found.fields.trialStartedAt.timestampValue)
    throw Error('Acceptance lost original trial');
});
