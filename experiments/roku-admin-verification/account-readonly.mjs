// Fixed owner-requested account; Auth read only, no claims or rights writers.
import {createRequire} from 'node:module';
const require=createRequire(new URL('../../billing/package.json',import.meta.url));
try{
 const {cert,initializeApp}=require('firebase-admin/app'),{getAuth}=require('firebase-admin/auth');
 const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'null');if(key?.project_id!=='rocha-plus')throw Error('project');
 initializeApp({credential:cert(key),projectId:'rocha-plus'});
 try{const u=await getAuth().getUserByEmail('rochaplus.app@gmail.com');
 console.log('ROKU_ADMIN_ACCOUNT '+JSON.stringify({readOnly:true,writes:0,project:'rocha-plus',exists:true,disabled:u.disabled===true,emailVerified:u.emailVerified===true,googleLinked:u.providerData?.some(p=>p.providerId==='google.com')===true,passwordLinked:u.providerData?.some(p=>p.providerId==='password')===true,rochaAdminClaim:u.customClaims?.rochaAdmin===true,loginTested:false,rokuAdminRecognitionTested:false}));
 }catch(e){if(e.code==='auth/user-not-found')console.log('ROKU_ADMIN_ACCOUNT '+JSON.stringify({readOnly:true,writes:0,exists:false,loginTested:false}));else throw e;}
}catch{console.log('ROKU_ADMIN_ACCOUNT '+JSON.stringify({readOnly:true,writes:0,accountNotConfirmed:true,loginTested:false}));process.exitCode=1;}
