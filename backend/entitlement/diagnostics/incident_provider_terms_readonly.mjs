// Private target inputs; official GETs only. No raw personal data or credentials in output.
import { cert } from 'firebase-admin/app';
const report = {readOnly:true,writes:0,contractVerified:false,appSessionVerified:false,payments:[]};
const iso = v => typeof v === 'string' && Number.isFinite(Date.parse(v)) ? new Date(v).toISOString() : null;
try {
  const ids = JSON.parse(process.env.INCIDENT_PAYMENT_IDS_JSON || 'null');
  const email = process.env.INCIDENT_TARGET_EMAIL?.trim().toLowerCase();
  if (!Array.isArray(ids) || ids.length < 1 || ids.length > 5 || !ids.every(id => /^\d{1,30}$/.test(id)) || !email) throw Error('inputs');
  const token = process.env.MP_RECEIVING_ACCESS_TOKEN;
  if (!token) throw Error('credential');
  async function get(path) {
    const r = await fetch('https://api.mercadopago.com' + path, {method:'GET',redirect:'error',signal:AbortSignal.timeout(20000),headers:{Authorization:`Bearer ${token}`}});
    if (!r.ok) throw Error('provider-http-' + r.status);
    return r.json();
  }
  const merchant = await get('/users/me');
  if (String(merchant.id) !== process.env.EXPECTED_RECEIVING_MERCHANT_ID || merchant.tags?.includes('test_user')) throw Error('merchant');
  for (const [index,id] of ids.entries()) {
    const p = await get('/v1/payments/' + id);
    if (String(p.id) !== id || String(p.collector_id) !== String(merchant.id) || p.payer?.email?.trim().toLowerCase() !== email) throw Error('ownership');
    const text = [p.description, ...(p.additional_info?.items || []).map(i=>i.title)].filter(x=>typeof x==='string').join(' ').toLowerCase();
    const monthly = /\bmensal\b|\bmonthly\b/.test(text), annual = /\banual\b|\bannual\b/.test(text);
    const entry={index,approved:p.status==='approved' && p.status_detail==='accredited',
      live:p.live_mode===true,regularPayment:p.operation_type==='regular_payment',refunded:p.transaction_amount_refunded!==0,
      createdAt:iso(p.date_created),approvedAt:iso(p.date_approved),updatedAt:iso(p.date_last_updated),
      providerProductLabel:monthly!==annual?(monthly?'monthly':'annual'):'not-unambiguous',
      externalReferencePresent:typeof p.external_reference==='string' && p.external_reference.length>0,
      metadataPresent:!!p.metadata && Object.keys(p.metadata).length>0,
      notificationUrlPresent:typeof p.notification_url==='string' && p.notification_url.length>0,
      preapprovalReferencePresent:!!(p.metadata?.preapproval_id || p.point_of_interaction?.transaction_data?.subscription_id),
      // Payment expiry is not subscription expiry. Never derive entitlement from it.
      contractualPeriodVerified:false,automaticRenewalVerified:false};
    const ref=p.metadata?.preapproval_id || p.point_of_interaction?.transaction_data?.subscription_id;
    if (typeof ref==='string' && /^[a-zA-Z0-9_-]{8,100}$/.test(ref)) {
      try {
        const subscription=await get('/preapproval/'+ref);
        const recurring=subscription.auto_recurring||{};
        entry.subscription={lookupConfirmed:subscription.id===ref,
          merchantMatches:String(subscription.collector_id)===String(merchant.id),
          payerMatches:subscription.payer_email?.trim().toLowerCase()===email,
          payerEmailPresent:typeof subscription.payer_email==='string' && subscription.payer_email.length>0,
          payerIdPresent:subscription.payer_id!=null,
          payerIdMatchesPayment:subscription.payer_id!=null && p.payer?.id!=null && String(subscription.payer_id)===String(p.payer.id),
          planReferencePresent:typeof subscription.preapproval_plan_id==='string' && subscription.preapproval_plan_id.length>0,
          status:['authorized','pending','paused','cancelled'].includes(subscription.status)?subscription.status:'other',
          startDate:iso(recurring.start_date),endDate:iso(recurring.end_date),nextPaymentDate:iso(subscription.next_payment_date),
          frequency:Number.isSafeInteger(recurring.frequency)?recurring.frequency:null,
          frequencyType:['months','years','days'].includes(recurring.frequency_type)?recurring.frequency_type:null,
          currencyBRL:recurring.currency_id==='BRL',
          reasonPlanLabel:/\bmensal\b/i.test(subscription.reason||'')?'monthly':/\banual\b/i.test(subscription.reason||'')?'annual':'not-unambiguous'};
      } catch (_) {entry.subscription={error:'linked-subscription-read-not-confirmed'};}
    }
    report.payments.push(entry);
  }
  // Read deployed function configuration and bounded delivery logs. Never print env values or raw logs.
  const key = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '{}');
  if (key.project_id!=='rocha-plus' || key.type!=='service_account') throw Error('firebase-project');
  const credential = cert(key), {access_token} = await credential.getAccessToken();
  const headers = {Authorization:`Bearer ${access_token}`,'Content-Type':'application/json'};
  const funcs = await fetch('https://cloudfunctions.googleapis.com/v2/projects/rocha-plus/locations/-/functions', {method:'GET',headers,signal:AbortSignal.timeout(20000)});
  report.deploymentReadHttp = funcs.status;
  if (funcs.ok) {
    const data = await funcs.json();
    report.deploymentInventoryComplete = !data.nextPageToken && !data.unreachable?.length;
    report.relevantFunctions = (data.functions || []).filter(f=>/billing|webhook|entitlement|payment/i.test(f.name.split('/').pop())).map(f=>({
      kind:/webhook/i.test(f.name)?'webhook':/entitlement/i.test(f.name)?'entitlement':'billing',
      active:f.state==='ACTIVE',
      receivingCredentialBound:(f.serviceConfig?.secretEnvironmentVariables||[]).some(v=>v.key==='MP_RECEIVING_ACCESS_TOKEN'),
      legacyCredentialBound:(f.serviceConfig?.secretEnvironmentVariables||[]).some(v=>v.key==='MP_ACCESS_TOKEN'),
      signatureSecretBound:(f.serviceConfig?.secretEnvironmentVariables||[]).some(v=>v.key==='MP_WEBHOOK_SECRET')
    }));
  }
  const filter = 'resource.labels.project_id="rocha-plus" AND timestamp>="2026-10-20T00:00:00Z" AND (' + ids.map(id=>'SEARCH("'+id+'")').join(' OR ') + ')';
  const logs = await fetch('https://logging.googleapis.com/v2/entries:list', {method:'POST',headers,signal:AbortSignal.timeout(20000),body:JSON.stringify({resourceNames:['projects/rocha-plus'],filter,pageSize:50,orderBy:'timestamp desc'})});
  report.logReadHttp = logs.status;
  if (logs.ok) { const data=await logs.json(); report.matchingLogCount=(data.entries||[]).length; report.logPageComplete=!data.nextPageToken; }
} catch (_) { report.error='provider-or-cloud-read-not-confirmed'; process.exitCode=1; }
console.log(JSON.stringify(report,null,2));
