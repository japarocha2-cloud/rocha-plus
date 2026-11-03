import assert from 'node:assert/strict';
import {createCheckoutPreparation,createContractResolver} from './contracts.mjs';
export async function runContractTests(){
 const reservations=new Map();const store={reserve:async r=>{if(reservations.has(r.reference))throw Error('duplicate');reservations.set(r.reference,r);},reservation:async r=>reservations.get(r),reviewedPayment:async()=>null};
 const uid='fixture',ref='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';let approved=false;
 const prepare=()=>createCheckoutPreparation({verifyIdentity:async()=>({uid,email:'fixture@example.test',email_verified:true}),store,newId:()=>ref,
  catalog:{fixture:{amountCents:1000,months:1,policyApproved:approved,periodPolicy:'independent-calendar-months-from-approval'}}});
 await assert.rejects(prepare()({authorization:'Bearer fixture',plan:'fixture'}));approved=true;
 const intent=await prepare()({authorization:'Bearer fixture',plan:'fixture'});assert.equal(intent.providerCheckoutCreated,false);assert(!JSON.stringify(intent).includes('example.test'));
 const resolve=createContractResolver({store});
 const payment={id:'1001',payer:{id:'3003',email:'fixture@example.test'},external_reference:ref,date_approved:'2026-01-31T12:00:00.000Z'};
 const contract=await resolve(payment);assert.equal(contract.uid,uid);assert.equal(new Date(contract.end).toISOString(),'2026-02-28T12:00:00.000Z');
 assert.equal(await resolve({...payment,external_reference:'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb'}),null);
 assert.equal(await resolve({...payment,payer:{id:'3003',email:'other@example.test'}}),null);
 assert.equal(await resolve({...payment,external_reference:null}),null);
 return {passed:6,failed:0,tests:['unapproved policy refused','intent does not create checkout/charge or expose email','server reservation binds UID and calendar period','unreserved reference rejected','different payer rejected','historical payment without reviewed contract stays pending'],commercialWrites:0};
}
