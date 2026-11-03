import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
export function assertExperimentalStore(db,{projectId,enableExperimentalWrites=false}={}) {
 if(!enableExperimentalWrites||!projectId||['rocha-plus','rocha-plus-candidate'].includes(projectId)||db.projectId!==projectId)throw Error('experimental-project-required');
}
// Intentionally not exported through billing/index.js or any deployed function.
export function firestorePaymentStore(db,config) {
 assertExperimentalStore(db,config);
 return {transact:async(key,fn)=>db.runTransaction(async tx=>{
  const ref=db.doc('rochaCentralLabPayments/'+hash(key)),prior=await tx.get(ref);
  const item=await fn(prior.data());
  const accountRef=item.period?db.doc('rochaCentralLabAccounts/'+hash(item.period.uid)):null;
  const account=accountRef?(await tx.get(accountRef)).data():null;
  if(account&&account.uid!==item.period.uid)throw Error('identity');
  if(item.period){const value=account??{uid:item.period.uid,periods:[]};value.periods=value.periods.filter(p=>p.paymentKey!==item.period.paymentKey);value.periods.push(item.period);tx.set(accountRef,value);}
  tx.set(ref,item.value);
  const alertRef=db.doc('rochaCentralLabReview/'+hash(key));
  tx.set(alertRef,{reviewRequired:item.value.reviewRequired===true,updatedAt:item.value.updated});
  return item.result;
 })};
}
export function firestoreDeviceStore(db,config) {
 assertExperimentalStore(db,config);
 return {transact:async(_key,fn)=>db.runTransaction(async tx=>{
  // Bounded small LAB: 128 pairs/sessions, not a production scaling design.
  const ref=db.doc('rochaCentralLabRuntime/devices'),snap=await tx.get(ref),item=await fn(snap.data());
  if(Buffer.byteLength(JSON.stringify(item.value))>700000)throw Error('capacity');
  if(item.commit!==false)tx.set(ref,item.value);return item.result;
 })};
}
