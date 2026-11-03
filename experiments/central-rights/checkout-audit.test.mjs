import assert from 'node:assert/strict';
import {inspectCheckoutOrigins} from './checkout-audit.mjs';
export async function runCheckoutAuditTests(){
 const payment={id:'1001',order:{id:'2002'},currency_id:'BRL',transaction_amount:10};
 const options={payments:[payment],offers:[{url:'https://mpago.la/fixture',months:1}],resolveShortLink:async()=>({status:302,preference:'fixture-pref'}),getProvider:async p=>p.startsWith('/merchant_orders/')?{id:'2002',payments:[{id:'1001'}],preference_id:'fixture-pref'}:{id:'fixture-pref',items:[{currency_id:'BRL',unit_price:10,quantity:1}]}};
 const r=await inspectCheckoutOrigins(options);assert.equal(r.results[0].officialLinkMatched,true);assert.equal(r.results[0].automaticDurationEstablished,false);assert.equal(r.writes,0);
 const blocked=await inspectCheckoutOrigins({...options,resolveShortLink:async()=>({status:403,preference:null})});assert.equal(blocked.results[0].officialLinkMatched,null);
 const missing=await inspectCheckoutOrigins({...options,payments:[{id:'1001'}]});assert.equal(missing.results[0].orderVerified,false);
 const mismatch=await inspectCheckoutOrigins({...options,getProvider:async()=>({id:'2002',payments:[{id:'other'}]})});assert.equal(mismatch.results[0].lookup,'not_confirmed');
 const failure=await inspectCheckoutOrigins({...options,getProvider:async()=>{throw Error('network');}});assert.equal(failure.results[0].reason,'provider-read-unavailable');
 assert(!JSON.stringify(r).includes('1001'));assert(!JSON.stringify(r).includes('2002'));assert(!JSON.stringify(r).includes('fixture-pref'));
 return {passed:6,failed:0,tests:['read-only bound order and preference','403 is unknown, not mismatch','missing order does not invent period','wrong payment/order rejected','provider failure sanitized','no payment/order/preference identifiers in report']};
}
