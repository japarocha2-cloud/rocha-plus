import assert from 'node:assert/strict';
import {auditPaymentBoundary} from './audit.mjs';
export async function runAuditTests(){
 const labels=[]; const now=1793640000000;
 const user={uid:'fixture-account',email:'fixture@example.test',emailVerified:true,disabled:false,providerData:[{providerId:'google.com',uid:'123456789'}]};
 let reads=0,providerReads=0;
 const options={auth:{getUserByEmail:async()=>user},db:{doc:p=>({get:async()=>{reads++;return {exists:p.startsWith('rochaSparkAccounts/'),data:()=>undefined,readTime:{toMillis:()=>now}};}})},
 email:user.email,paymentIds:['11','22'],expectedMerchant:'33',getProvider:async p=>{providerReads++;return p==='/users/me'?{id:'33'}:{id:p.split('/').at(-1),status:'approved',operation_type:'regular_payment',live_mode:true,collector_id:'33',payer:{email:user.email},date_approved:new Date(now-1000).toISOString(),transaction_amount_refunded:0};}};
 const r=await auditPaymentBoundary(options);assert.equal(r.writes,0);assert.equal(r.commercialAccessGranted,false);assert.equal(reads,12);assert.equal(providerReads,3);labels.push('read-only exact account and two payments');
 assert(!JSON.stringify(r).includes(user.uid));assert(!JSON.stringify(r).includes(user.email));assert(!JSON.stringify(r).includes(user.providerData[0].uid));labels.push('no personal or financial identifiers in output');
 await assert.rejects(auditPaymentBoundary({...options,paymentIds:['11','11']}));labels.push('duplicate scope rejected');
 await assert.rejects(auditPaymentBoundary({...options,auth:{getUserByEmail:async()=>({...user,disabled:true})}}));labels.push('disabled account rejected');
 await assert.rejects(auditPaymentBoundary({...options,expectedMerchant:'44'}));labels.push('wrong receiving merchant rejected');
 await assert.rejects(auditPaymentBoundary({...options,getProvider:async p=>p==='/users/me'?{id:'33'}:{id:'99'}}));labels.push('provider resource mismatch rejected');
 return {passed:labels.length,failed:0,tests:labels};
}
