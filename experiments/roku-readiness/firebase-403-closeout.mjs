import {createRequire} from 'node:module';
const require=createRequire(new URL('../../billing/package.json', import.meta.url));
const SERVICE='https://firestore.googleapis.com/v1/projects/rocha-plus-homologacao/databases/(default)';
const PERMISSION_API='https://serviceusage.googleapis.com/v1/projects/rocha-plus-homologacao/services/firestore.googleapis.com';
const safe=(x,n=320)=>typeof x==='string'?x.slice(0,n).replace(/(?:Bearer|token|private[_-]?key|authorization)\\s*[:=]?\\s*[^\\s,;}]+/gi,'[redacted]').replace(/https?:\\/\\/\\S+/g,'[url]').replace(/\\b[A-Za-z0-9_-]{60,}\\b/g,'[redacted]'):null;
async function probe(label,url,access){
 const response=await fetch(url,{method:'GET',redirect:'error',signal:AbortSignal.timeout(15000),headers:{Authorization:'Bearer '+access}});
 let body={};try{body=await response.json()}catch{}
 const info={label,project:'rocha-plus-homologacao',databaseId:label==='firestore-metadata'?'(default)':null,httpStatus:response.status};
 if(response.ok){info.confirmed=true;info.databaseType=body.type??null;info.serviceState=body.state??null}
 else {info.confirmed=false;info.errorStatus=safe(body?.error?.status,80);info.errorMessage=safe(body?.error?.message);info.errorReasons=Array.isArray(body?.error?.details)?body.error.details.map(d=>safe(d.reason,80)).filter(Boolean).slice(0,4):[]}
 return info;
}
try {
 const {initializeApp,cert}=require('firebase-admin/app');
 const json=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'null');
 if(json?.type!=='service_account'||json.project_id!=='rocha-plus'||!/^[-a-z0-9._]+@[-a-z0-9.]+\\.gserviceaccount\\.com$/.test(json.client_email||''))throw Error('invalid-ci-identity');
 const app=initializeApp({credential:cert(json),projectId:'rocha-plus'});
 const access=(await app.options.credential.getAccessToken()).access_token;
 const checks=[await probe('firestore-metadata',SERVICE,access),await probe('firestore-api-state',PERMISSION_API,access)];
 console.log('LAB403_CLOSEOUT '+JSON.stringify({readOnly:true,writes:0,ciPrincipal:json.client_email,credentialProject:json.project_id,checks}));
}catch(e){console.log('LAB403_CLOSEOUT '+JSON.stringify({readOnly:true,writes:0,status:'not_confirmed',failure:safe(e?.message,100)}));process.exitCode=1}
