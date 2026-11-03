import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {auditPaymentBoundary} from './audit.mjs';
const require=createRequire(new URL('../../billing/package.json',import.meta.url));
const {cert,initializeApp}=require('firebase-admin/app'),{getAuth}=require('firebase-admin/auth'),{getFirestore}=require('firebase-admin/firestore');
async function pinned(path,sha) {
 const r=await fetch('https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/55461ffea352aa26eec1c5e02cfd595db0ddcc00/'+path,{redirect:'error',signal:AbortSignal.timeout(15000)});
 if(!r.ok)throw Error('source');const s=await r.text();if(createHash('sha256').update(s).digest('hex')!==sha)throw Error('source');return s;
}
try {
 const source=await pinned('backend/entitlement/diagnostics/paid_account_readonly.mjs','0f8c246f30743538464f7e854689edbb7a43d2817a963103eacd93b1b4df1d8b');
 // Source is parsed as data, never evaluated. Personal identifiers are not logged.
 const email=source.match(/const email = '([^']+)';/)?.[1],ids=source.match(/Object.entries\(\{ monthly: '(\d+)', annual: '(\d+)' \}\)/);
 const wf=await pinned('.github/workflows/paid-account-readonly.yml','624ba6580745e3d22f12d67f58beb5124c62ad65502c8094450c91c19c3349a9');
 const merchant=wf.match(/EXPECTED_RECEIVING_MERCHANT_ID: '(\d+)'/)?.[1];
 if(!email||!ids||!merchant)throw Error('scope');
 const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'null');if(key?.project_id!=='rocha-plus'||key.type!=='service_account')throw Error('project');
 const app=initializeApp({credential:cert(key),projectId:'rocha-plus'}),db=getFirestore();
 const token=process.env.MP_RECEIVING_ACCESS_TOKEN||process.env.MP_ACCESS_TOKEN;if(!token)throw Error('credential');
 const getProvider=async p=>{if(!/^\/(users\/me|v1\/payments\/\d{1,30})$/.test(p))throw Error('provider-scope');const r=await fetch('https://api.mercadopago.com'+p,{method:'GET',redirect:'error',signal:AbortSignal.timeout(15000),headers:{Authorization:'Bearer '+token}});if(!r.ok)throw Error('provider');return r.json();};
 const result=await auditPaymentBoundary({auth:getAuth(),db,getProvider,email,paymentIds:[ids[1],ids[2]],expectedMerchant:merchant});
 const access=(await app.options.credential.getAccessToken()).access_token;
 async function gcp(url,body) {
  const r=await fetch(url,{method:body?'POST':'GET',redirect:'error',signal:AbortSignal.timeout(15000),headers:{Authorization:'Bearer '+access,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
  if(!r.ok)return {confirmed:false,httpStatus:r.status};return {confirmed:true,data:await r.json()};
 }
 // Both APIs are read-only. Never emit function environment variables or log payloads.
 const metadata=await gcp('https://firestore.googleapis.com/v1/projects/rocha-plus/databases/(default)');
 result.database={confirmed:metadata.confirmed,httpStatus:metadata.httpStatus??200,edition:metadata.data?.databaseEdition??'not_reported',type:metadata.data?.type??'not_reported'};
 const functions=await gcp('https://cloudfunctions.googleapis.com/v2/projects/rocha-plus/locations/southamerica-east1/functions');
 result.functionInventory={confirmed:functions.confirmed,httpStatus:functions.httpStatus??200,complete:functions.confirmed&&!functions.data?.nextPageToken,
  billingEndpointListed:functions.data?.functions?.some(f=>f.name.endsWith('/mercadoBilling'))??null,webhookListed:functions.data?.functions?.some(f=>f.name.endsWith('/mercadoWebhook'))??null};
 const logs=await gcp('https://logging.googleapis.com/v2/entries:list',{resourceNames:['projects/rocha-plus'],filter:'timestamp >= "2026-10-01T00:00:00Z" AND (resource.labels.function_name="mercadoWebhook" OR resource.labels.service_name="mercadowebhook")',pageSize:100,orderBy:'timestamp desc'});
 result.webhookLogCoverage={confirmed:logs.confirmed,httpStatus:logs.httpStatus??200,returnedEntries:logs.data?.entries?.length??null,complete:logs.confirmed&&!logs.data?.nextPageToken,individualDeliveryConfirmed:false};
 console.log('CENTRAL_AUDIT '+JSON.stringify(result));
} catch {console.log('CENTRAL_AUDIT '+JSON.stringify({readOnly:true,writes:0,status:'not_confirmed',commercialAccessGranted:false}));process.exitCode=1;}
