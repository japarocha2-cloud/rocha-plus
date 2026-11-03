import {memoryStore} from './memory-store.mjs';
// Serializes ledger+account together. Used for failures/concurrency fixtures.
export function fixturePaymentStore() {
 const store=memoryStore();
 return {fixtureOnly:true,read:key=>store.read(key),seed:(k,v)=>store.seed(k,v),transact:(_key,fn)=>store.transact('atomic-root',async root=>{
  const r=root??{payments:{},accounts:{},alerts:{}};const item=await fn(r.payments[_key]);
  if(item.commit===false)return {value:r,result:item.result};
  if(item.period){const p=item.period,account=r.accounts[p.uid]??{uid:p.uid,periods:[]};account.periods=account.periods.filter(x=>x.paymentKey!==p.paymentKey);account.periods.push(p);r.accounts[p.uid]=account;}
  r.payments[_key]=item.value;if(item.value?.reviewRequired)r.alerts[_key]={state:'reconciliation_pending'};else delete r.alerts[_key];
  return {value:r,result:item.result};
 }),snapshot:async uid=>(await store.read('atomic-root'))?.accounts[uid],alerts:async()=>(await store.read('atomic-root'))?.alerts??{}};
}
