// Server-side, read-only adoption of the EXISTING Spark clock. No new trial.
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
export function createExistingRightsReader({auth,db,canonicalDb=db}) {
 return async uid=>{
  const u=await auth.getUser(uid),g=u.providerData?.filter(p=>p.providerId==='google.com');
  if(u.uid!==uid||u.disabled||!u.emailVerified||g?.length!==1||!/^\d{1,128}$/.test(g[0].uid))return null;
  const [canonical,spark]=await Promise.all([canonicalDb.doc('rochaCentralLabAccounts/'+hash(uid)).get(),db.doc('rochaSparkAccounts/'+g[0].uid).get()]);
  const c=canonical.data(),s=spark.data();
  if(c&&c.uid!==uid)return null;
  const original=s?.trialStartedAt?.toMillis?.();
  if(c?.trialStartedAt!=null&&original!=null&&c.trialStartedAt!==original)return null;
  // Old paidUntil without a normalized period must be reviewed, never silently
  // imported, stacked or overwritten. This endpoint has no adoption writer.
  if(s?.paidUntil!=null&&!c?.legacyPaidReviewed)return null;
  return c?{...c,trialStartedAt:original??c.trialStartedAt}:s?{uid,trialStartedAt:original,periods:[]}:null;
 };
}
