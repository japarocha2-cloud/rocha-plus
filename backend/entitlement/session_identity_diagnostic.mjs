// Prepared server-side verifier only. Not deployed/routed; accepts a token only
// in memory from the SAME client session over an approved trusted transport.
import {createHash} from 'node:crypto';
const fingerprint=value=>createHash('sha256').update(value).digest('hex').slice(0,12);
export function createSessionIdentityDiagnostic({verifyToken,readUser,projectId,targetUid,targetGoogleSubject,now=Date.now}) {
  if (!projectId || !targetUid || !targetGoogleSubject) throw Error('independent-target-required');
  return async authorization=>{
    const fail=()=>({readOnly:true,writes:0,identityVerified:false,deviceSessionVerified:false,error:'session-not-confirmed'});
    const match=/^Bearer (\S+)$/.exec(authorization||'');
    if (!match) return fail();
    try {
      const claims=await verifyToken(match[1],true);
      if (!claims?.uid || claims.sub!==claims.uid || claims.aud!==projectId ||
          claims.iss!==`https://securetoken.google.com/${projectId}` ||
          claims.email_verified!==true || claims.firebase?.sign_in_provider!=='google.com' ||
          !Number.isSafeInteger(claims.iat) || claims.iat*1000>now()+30000) return fail();
      const user=await readUser(claims.uid);
      const google=user?.providerData?.filter(p=>p.providerId==='google.com');
      const identities=claims.firebase?.identities?.['google.com'];
      if (user?.uid!==claims.uid || user.disabled!==false || user.emailVerified!==true ||
          google?.length!==1 || typeof google[0].uid!=='string' ||
          !Array.isArray(identities) || !identities.includes(google[0].uid)) return fail();
      return {readOnly:true,writes:0,identityVerified:true,revocationChecked:true,
        projectMatchesRecovery:true,uidFingerprint:fingerprint(user.uid),
        googleFingerprint:fingerprint(google[0].uid),
        uidMatchesRecovery:user.uid===targetUid,googleMatchesRecovery:google[0].uid===targetGoogleSubject,
        recentToken:now()-claims.iat*1000<=300000,
        deviceSessionVerified:false,installedBuildVerified:false,backendVerified:false,
        limitation:'verified-bearer-identity-does-not-attest-installed-package-or-request-origin'};
    } catch (_) {return fail();}
  };
}
