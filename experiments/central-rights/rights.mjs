// One server-owned contract for phone, Android TV and Roku. No trial creation.
export const DAY=86400000;
const integer=n=>Number.isSafeInteger(n)&&n>0;
export function resolveRights(snapshot,uid,now,{allowLab=false}={}) {
 if(!integer(now)||!uid||!snapshot||snapshot.uid!==uid)return {state:'unknown',active:false,expiresAt:null};
 if(snapshot.revokedAt!=null)return {state:'revoked',active:false,expiresAt:null};
 const starts=snapshot.trialStartedAt;
 if(starts!=null&&(!integer(starts)||starts>now))return {state:'unknown',active:false,expiresAt:null};
 // The original server timestamp is adopted. Reading never starts a new clock.
 const trialEnd=starts==null?0:starts+7*DAY;
 let until=0,hadPaid=false;
 for(const p of snapshot.periods??[]) {
  if(p.uid!==uid||p.verified!==true||!integer(p.start)||!integer(p.end)||p.end<=p.start)return {state:'unknown',active:false,expiresAt:null};
  hadPaid=true;
  if(p.status==='approved'&&p.refundedCents===0&&p.start<=now)until=Math.max(until,p.end);
 }
 if(until>now)return {state:'paid',active:true,expiresAt:until,plan:(snapshot.periods??[]).find(p=>p.end===until&&p.status==='approved'&&p.refundedCents===0&&p.start<=now)?.plan??null};
 if(trialEnd>now)return {state:'trial',active:true,expiresAt:trialEnd,plan:null};
 const lab=snapshot.labGrant;
 if(allowLab&&lab?.uid===uid&&lab.scope==='homologation'&&integer(lab.start)&&integer(lab.end)&&lab.end-lab.start<=DAY&&lab.start<=now&&lab.end>now)return {state:'lab',active:true,expiresAt:lab.end,plan:null};
 return {state:snapshot.pendingReconciliation?'reconciliation_pending':hadPaid?'subscription_expired':starts!=null?'trial_expired':'unknown',active:false,expiresAt:null,plan:null};
}
export function rightsPacket(rights,uid,device,now,scope,playbackAllowed=false) {
 const until=rights.active?Math.min(now+60000,rights.expiresAt):now;
 return {contractVersion:1,environment:'central-rights-lab',scope,state:rights.state,reason:rights.state,uid,device_id:device,active:rights.active,allowed:rights.active,
  plan:rights.plan??null,serverTime:now,accessUntil:until,grantUntil:rights.expiresAt,expiresAt:rights.expiresAt?new Date(rights.expiresAt).toISOString():null,playbackAllowed};
}
export function validatePacket(p,{uid,device,scope,elapsedMs=0}) {
 if(!p||p.contractVersion!==1||p.environment!=='central-rights-lab'||p.uid!==uid||p.device_id!==device||p.scope!==scope||p.allowed!==true||p.active!==true||
  !(scope==='homologation'?p.state==='lab':['paid','trial'].includes(p.state))||!integer(p.serverTime)||!integer(p.accessUntil)||!integer(p.grantUntil)||p.grantUntil<p.accessUntil||
  !Number.isFinite(elapsedMs)||elapsedMs<0||p.accessUntil-p.serverTime>60000)return 0;
 return Math.max(0,p.accessUntil-p.serverTime-elapsedMs);
}
