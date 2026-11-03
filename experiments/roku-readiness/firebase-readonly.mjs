import {createRequire} from 'node:module';
const require=createRequire(new URL('../../billing/package.json',import.meta.url));
// Fixed scope: configuration metadata and effective permissions only. No users/payment reads or writes.
const projects=['rocha-plus','rocha-plus-homologacao'];
try {
 const {initializeApp,cert}=require('firebase-admin/app');
 const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'null');
 if(key?.project_id!=='rocha-plus'||key.type!=='service_account')throw Error('project');
 const app=initializeApp({credential:cert(key),projectId:'rocha-plus'});
 const access=(await app.options.credential.getAccessToken()).access_token;
 async function read(url,body){const r=await fetch(url,{method:body?'POST':'GET',redirect:'error',signal:AbortSignal.timeout(15000),headers:{Authorization:'Bearer '+access,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});return {status:r.status,data:r.ok?await r.json():null};}
 const config=await read('https://identitytoolkit.googleapis.com/admin/v2/projects/rocha-plus/config');
 const google=await read('https://identitytoolkit.googleapis.com/admin/v2/projects/rocha-plus/defaultSupportedIdpConfigs/google.com');
 const permissions=['firebaseauth.configs.get','firebaseauth.users.get','datastore.entities.get','datastore.entities.create','datastore.entities.update','datastore.entities.delete'];
 const result={readOnly:true,writes:0,accountReads:0,paymentReads:0,identity:{project:'rocha-plus',configStatus:config.status,authorizedDomains:config.data?.authorizedDomains??null,googleStatus:google.status,googleEnabled:typeof google.data?.enabled==='boolean'?google.data.enabled:null},projects:[]};
 for(const project of projects){
  const metadata=await read('https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)');
  // testIamPermissions is a permission-check POST, not a policy mutation.
  const iam=await read('https://cloudresourcemanager.googleapis.com/v1/projects/'+project+':testIamPermissions',{permissions});
  result.projects.push({project,databaseStatus:metadata.status,type:metadata.data?.type??null,iamStatus:iam.status,effectivePermissions:iam.data?.permissions??null});
 }
 console.log('READINESS_AUDIT '+JSON.stringify(result));
}catch{console.log('READINESS_AUDIT '+JSON.stringify({readOnly:true,writes:0,status:'credentials_or_api_not_confirmed'}));process.exitCode=1;}
