import {createLabAccessService} from './service.mjs';
export function createFirebaseLabAdapter({auth,config,now}) {
 if(!config?.identityProjectId||auth?.app?.options?.projectId!==config.identityProjectId)throw Error('Explicit identity project mismatch');
 const handle=createLabAccessService({config,now,verifyIdentity:(t,r)=>auth.verifyIdToken(t,r),getAccount:uid=>auth.getUser(uid)});
 return {
  handle,
  async auditAccountReadOnly(email) {
   try {const u=await auth.getUserByEmail(email);return {readOnly:true,registration:'found',disabled:u.disabled===true,emailVerified:u.emailVerified===true,providers:u.providerData.map(p=>p.providerId),payment:'not_checked',commercialAccessGranted:false};}
   catch(e){if(e.code==='auth/user-not-found')return {readOnly:true,registration:'not_found',payment:'not_checked',commercialAccessGranted:false};throw Error('Account lookup unavailable; do not infer missing account or payment');}
  },
  async https(req,res) {
   if(req.secure!==true)return res.status(400).json({error:'https_required'});
   res.set('Cache-Control','no-store');
   const result=await handle({method:req.method,body:req.body,authorization:req.headers.authorization,address:req.ip});
   return res.status(result.status).json(result.body);
  }
 };
}
// Preparation only: injected Admin Auth reads identity; no createUser/updateUser,
// Firestore writes, custom claims, billing operations or automatic deployment.
