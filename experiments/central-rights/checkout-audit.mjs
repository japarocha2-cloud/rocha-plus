// Read-only provider provenance. Never follows checkout forms or creates a charge.
export async function inspectCheckoutOrigins({payments,getProvider,offers,resolveShortLink}) {
 const results=[];
 for(const [index,p]of payments.entries()) {
  const r={reference:index===0?'monthly':'annual',orderPresent:!!p.order?.id,orderVerified:false,preferenceRead:false,officialLinkMatched:null,explicitPeriod:false,accountReference:false};
  try {
   if(!/^\d{1,30}$/.test(String(p.order?.id??''))){results.push(r);continue;}
   const order=await getProvider('/merchant_orders/'+p.order.id);
   if(String(order.id)!==String(p.order.id)||!Array.isArray(order.payments)||!order.payments.some(v=>String(v.id)===String(p.id)))throw Error('order-binding');
   r.orderVerified=true;
   if(typeof order.preference_id!=='string'||!/^[a-zA-Z0-9_-]{5,200}$/.test(order.preference_id))throw Error('preference-reference');
   const pref=await getProvider('/checkout/preferences/'+order.preference_id);
   if(String(pref.id)!==order.preference_id)throw Error('preference-resource');
   r.preferenceRead=true;r.accountReference=typeof pref.external_reference==='string'&&pref.external_reference.length>0;
   r.notificationConfiguredOnPreference=typeof pref.notification_url==='string'&&pref.notification_url.length>0;
   r.explicitPeriod=typeof pref.metadata?.period_start==='string'&&typeof pref.metadata?.period_end==='string';
   r.itemsMatchPayment=Array.isArray(pref.items)&&pref.items.length===1&&pref.items[0].currency_id===p.currency_id&&Number(pref.items[0].unit_price)*Number(pref.items[0].quantity)===Number(p.transaction_amount);
   const resolved=await resolveShortLink(offers[index].url);
   r.shortLinkHttpStatus=resolved.status;r.officialLinkMatched=resolved.preference?resolved.preference===pref.id:null;
   r.documentedOfferMonths=offers[index].months;
   r.automaticDurationEstablished=false; // metadata still requires contractual review
  }catch(e){r.lookup='not_confirmed';r.reason=['order-binding','preference-reference','preference-resource'].includes(e.message)?e.message:'provider-read-unavailable';}
  results.push(r);
 }
 return {readOnly:true,writes:0,commercialAccessGranted:false,results,limitation:'Offer duration is not a proof of billing start, migration, replacement or accumulation; no period inferred or applied.'};
}
