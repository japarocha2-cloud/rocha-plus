import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {inspectStoredRights} from './stored-rights-audit.mjs';
import {access} from '../../billing/policy.js';
const require=createRequire(new URL('../../billing/package.json',import.meta.url));
const {cert,initializeApp}=require('firebase-admin/app'),{getAuth}=require('firebase-admin/auth'),{getFirestore}=require('firebase-admin/firestore');
try {
 const r=await fetch('https://raw.githubusercontent.com/japarocha2-cloud/rocha-plus/55461ffea352aa26eec1c5e02cfd595db0ddcc00/backend/entitlement/diagnostics/paid_account_readonly.mjs',{signal:AbortSignal.timeout(15000)});
 if(!r.ok)throw Error('source');
 const source=await r.text();
 if(createHash('sha256').update(source).digest('hex')!=='0f8c246f30743538464f7e854689edbb7a43d2817a963103eacd93b1b4df1d8b')throw Error('source');
 const email=source.match(/const email = '([^']+)';/)?.[1];
 const ids=source.match(/Object.entries\(\{ monthly: '(\d+)', annual: '(\d+)' \}\)/);
 if(!email||!ids)throw Error('scope');
 const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'null');
 if(key?.type!=='service_account'||key.project_id!=='rocha-plus')throw Error('credential');
 initializeApp({credential:cert(key),projectId:'rocha-plus'});
 const report=await inspectStoredRights({auth:getAuth(),db:getFirestore(),email,paymentIds:[ids[1],ids[2]],computeAccess:access});
 console.log('ROKU_READONLY_RIGHTS '+JSON.stringify(report));
} catch {console.log('ROKU_READONLY_RIGHTS '+JSON.stringify({readOnly:true,writes:0,status:'not_confirmed',commercialAccessGranted:false}));process.exitCode=1;}
