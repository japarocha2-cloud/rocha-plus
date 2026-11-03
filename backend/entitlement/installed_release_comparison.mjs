// Offline comparison only. Never authenticates a customer, touches a device or grants access.
export function compareInstalledRelease({release,metadata}) {
 const result={readOnly:true,writes:0,customerSessionVerified:false,liveAccessRestored:false,readyForProductionWrite:false,
  declaredVersionCode:release?.build_number??null,reportedVersionCode:metadata?.versionCode??null,
  reportedArtifactMatch:false,compiledBackendCandidate:null,automaticPaymentsInKnownRelease:release?.automatic_payments===true,
  nextEvidence:[]};
 if(!release||!/^\d+$/.test(String(release.build_number))||!release.outputs||release.billing_mode!=='spark_trial'){
  result.nextEvidence.push('trusted-release-evidence-required');return result;
 }
 if(!metadata||!Number.isSafeInteger(metadata.versionCode)||metadata.versionCode<1){result.nextEvidence.push('installed-version-code-required');return result;}
 const matches=(Array.isArray(metadata.apkHashes)?metadata.apkHashes:[]).filter(h=>h?.component==='base'&&typeof h.sha256==='string'&&/^[a-f0-9]{64}$/.test(h.sha256));
 const known=Object.entries(release.outputs).filter(([name,o])=>name.endsWith('.apk')&&/^[a-f0-9]{64}$/.test(o?.sha256??''));
 const found=known.filter(([,o])=>matches.some(h=>h.sha256===o.sha256));
 if(String(metadata.versionCode)!==String(release.build_number)){result.nextEvidence.push('version-differs-from-known-release');return result;}
 if(found.length!==1){result.nextEvidence.push(matches.length?'no-exact-known-apk-hash-or-split-delivery':'authorized-apk-hash-comparison-required');return result;}
 result.reportedArtifactMatch=true;result.matchedOutput=found[0][0];result.compiledBackendCandidate='spark_firestore_google_subject';
 result.nextEvidence.push('same-installed-session-identity-and-live-backend-still-required','fresh-private-spark-baseline-required');
 return result;
}
