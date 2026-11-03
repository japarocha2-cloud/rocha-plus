import {createDeviceService} from './devices.mjs';
import {createExistingRightsReader} from './read-source.mjs';
import {firestoreDeviceStore} from './firestore-adapters.mjs';
// Dependency injection only. Does not read/export CI secrets or deploy anything.
export function createFirebaseRuntime({identityAuth,commercialReadDb,labDb,config}) {
 if(config?.identityProjectId!=='rocha-plus'||identityAuth?.app?.options?.projectId!==config.identityProjectId||commercialReadDb?.projectId!=='rocha-plus')throw Error('identity-project');
 if(config.environment!=='central-rights-lab'||config.publicServiceEnabled===true)throw Error('isolated-runtime-required');
 if(config.enabled!==true)return async()=>({status:503,body:{error:'central_rights_not_configured'}});
 const existing=createExistingRightsReader({auth:identityAuth,db:commercialReadDb,canonicalDb:labDb});
 const store=firestoreDeviceStore(labDb,{projectId:config.labProjectId,enableExperimentalWrites:config.enabled===true});
 return createDeviceService({enabled:config.enabled===true,scope:'homologation',store,
  verifyIdentity:(token,revoked)=>identityAuth.verifyIdToken(token,revoked),getAccount:uid=>identityAuth.getUser(uid),
  loadRights:async uid=>{
   const u=await identityAuth.getUser(uid),snapshot=await existing(uid),g=config.authorization;
   const base=snapshot?{...snapshot,labGrant:undefined}:null;
   if(!base||!g?.allowedEmail||u.email?.toLowerCase()!==g.allowedEmail.toLowerCase()||!g.enabled||!Number.isSafeInteger(g.notBefore)||!Number.isSafeInteger(g.expiresAt)||g.expiresAt-g.notBefore>86400000)return base;
   return {...base,labGrant:{uid,scope:'homologation',start:g.notBefore,end:g.expiresAt}};
  }});
}
