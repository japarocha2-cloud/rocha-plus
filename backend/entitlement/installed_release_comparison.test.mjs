import assert from 'node:assert/strict';
import {compareInstalledRelease} from './installed_release_comparison.mjs';
export function runInstalledReleaseComparisonTests(){
 const passed=[];const test=(name,fn)=>{fn();passed.push(name);};
 const release={build_number:'3538',billing_mode:'spark_trial',automatic_payments:false,outputs:{'app-release.apk':{sha256:'a'.repeat(64)},'app-arm64-v8a-release.apk':{sha256:'b'.repeat(64)},'app-release.aab':{sha256:'c'.repeat(64)}}};
 const metadata={versionCode:3538,apkHashes:[{component:'base',sha256:'a'.repeat(64)}]};
 test('unknown installed version cannot identify backend',()=>assert.equal(compareInstalledRelease({release}).reportedArtifactMatch,false));
 test('version alone cannot identify APK/backend',()=>{const r=compareInstalledRelease({release,metadata:{versionCode:3538}});assert(!r.reportedArtifactMatch);assert.equal(r.compiledBackendCandidate,null);});
 test('exact universal APK comparison identifies only compiled candidate, never customer session/access',()=>{const r=compareInstalledRelease({release,metadata});assert(r.reportedArtifactMatch);assert.equal(r.compiledBackendCandidate,'spark_firestore_google_subject');assert.equal(r.customerSessionVerified,false);assert.equal(r.readyForProductionWrite,false);assert.equal(r.liveAccessRestored,false);});
 test('ARM64 output matched independently',()=>assert.equal(compareInstalledRelease({release,metadata:{...metadata,apkHashes:[{component:'base',sha256:'b'.repeat(64)}]}}).matchedOutput,'app-arm64-v8a-release.apk'));
 test('mismatched version blocks even matching reported hash',()=>assert(!compareInstalledRelease({release,metadata:{...metadata,versionCode:538}}).reportedArtifactMatch));
 test('split package or AAB hash does not falsely identify installed APK',()=>{for(const apkHashes of [[{component:'split',sha256:'a'.repeat(64)}],[{component:'base',sha256:'c'.repeat(64)}]])assert(!compareInstalledRelease({release,metadata:{...metadata,apkHashes}}).reportedArtifactMatch);});
 test('unknown release or malformed hash rejected',()=>{assert(!compareInstalledRelease({release:{},metadata}).reportedArtifactMatch);assert(!compareInstalledRelease({release,metadata:{...metadata,apkHashes:[{component:'base',sha256:'bad'}]}}).reportedArtifactMatch);});
 test('private identifiers and tokens never echoed in result',()=>{const r=compareInstalledRelease({release,metadata:{...metadata,email:'private-email',token:'private-token',uid:'private-uid'}});for(const secret of ['private-email','private-token','private-uid'])assert(!JSON.stringify(r).includes(secret));assert.equal(r.writes,0);});
 return {passed:passed.length,failed:0,tests:passed,fixtureOnly:true,cloudCalls:0,deviceCalls:0};
}
