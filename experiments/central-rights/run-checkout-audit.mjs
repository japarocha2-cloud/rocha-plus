import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {inspectCheckoutOrigins} from './checkout-audit.mjs';
const require=createRequire(new URL('../../billing/package.json',import.meta.url));
const {cert,initializeApp}=require('firebase-admin/app'),{getAuth}=require('firebase-admin/auth');
try {
 const raw=await fetch('https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/55461ffea352aa26eec1c5e02cfd595db0ddcc00/backend/entitlement/diagnostics/paid_account_readonly.mjs',{signal:AbortSignal.timeout(15000)});
 const source=await raw.text();if(!raw.ok||createHash('sha256').update(source).digest('hex')!=='0f8c246f30743538464f7e854689edbb7a43d2817a963103eacd93b1b4df1d8b')throw Error('scope');
 const email=source.match(/const email = '([^']+)';/)?.[1],ids=source.match(/Object.entries\(\{ monthly: '(\d+)', annual: '(\d+)' \}\)/);if(!email||!ids)throw Error('scope');
 const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'null');if(key?.project_id!=='rocha-plus'||key.type!=='service_account')throw Error('project');initializeApp({credential:cert(key),projectId:'rocha-plus'});
 const user=await getAuth().getUserByEmail(email);if(user.disabled||!user.emailVerified||user.email?.toLowerCase()!==email)throw Error('identity');
 const token=process.env.MP_RECEIVING_ACCESS_TOKEN||process.env.MP_ACCESS_TOKEN;if(!token)throw Error('credential');
 const getProvider=async p=>{if(!/^\/(users\/me|v1\/payments\/\d{1,30}|merchant_orders\/\d{1,30}|checkout\/preferences\/[a-zA-Z0-9_-]{5,200})$/.test(p))throw Error('path');const r=await fetch('https://api.mercadopago.com'+p,{method:'GET',redirect:'error',signal:AbortSignal.timeout(15000),headers:{Authorization:'Bearer '+token}});if(!r.ok)throw Error('provider');return r.json();};
 const merchant=await getProvider('/users/me'),payments=[];
 for(const id of [ids[1],ids[2]]){const p=await getProvider('/v1/payments/'+id);if(String(p.id)!==id||String(p.collector_id)!==String(merchant.id)||p.payer?.email?.toLowerCase()!==email)throw Error('binding');payments.push(p);}
 const result=await inspectCheckoutOrigins({payments,getProvider,offers:[{url:'https://mpago.la/32m6qxz',months:1},{url:'https://mpago.la/1CKFRB2',months:12}],resolveShortLink:async url=>{const r=await fetch(url,{method:'HEAD',redirect:'manual',signal:AbortSignal.timeout(10000)});const loc=r.headers.get('location');const next=loc?new URL(loc,url):null;return {status:r.status,preference:next?.hostname==='www.mercadopago.com.br'?next.searchParams.get('pref_id'):null};}});
 console.log('CHECKOUT_ORIGINS '+JSON.stringify(result));
}catch{console.log('CHECKOUT_ORIGINS '+JSON.stringify({readOnly:true,writes:0,status:'not_confirmed',commercialAccessGranted:false}));process.exitCode=1;}
