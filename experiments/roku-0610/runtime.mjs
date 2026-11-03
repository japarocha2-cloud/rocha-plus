import {createDeviceService} from './devices.mjs';
// Dependency injection only; no SDK initialization, cloud writes or listener.
export function createRoku0610Runtime({store,identity,readRights,config}){
 if(config?.enabled!==true)return async()=>({status:503,body:{error:'not_configured'}});
 if(config.environment!=='central-rights-lab'||config.scope!=='homologation'||config.publicServiceEnabled!==false||store?.projectId==='rocha-plus'||store?.projectId==='rocha-plus-candidate'||!store?.projectId)throw Error('isolated-runtime-required');
 return createDeviceService({enabled:true,scope:'homologation',store,verifyIdentity:(t,r)=>identity.verifyIdToken(t,r),getAccount:u=>identity.getUser(u),loadRights:readRights,adminPolicyApproved:config.adminPolicyApproved===true});
}
