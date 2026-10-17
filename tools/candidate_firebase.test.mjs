import test from 'node:test';
import assert from 'node:assert/strict';
import {candidateDefines, candidatePackage} from './prepare_candidate_firebase.mjs';

function fixture() {
  return {project_info:{project_id:'rocha-plus', project_number:'123'},client:[{
    client_info:{mobilesdk_app_id:'test-android-app',
      android_client_info:{package_name:candidatePackage}},
    api_key:[{current_key:'fixture-value'}],oauth_client:[
      {client_type:1,android_info:{package_name:candidatePackage,certificate_hash:'aabb'}},
      {client_type:3,client_id:'fixture-web-client'}]}]};
}
const original={ROCHA_GOOGLE_SERVER_CLIENT_ID:'fixture-web-client'};
test('candidate build uses its own registration and the existing server client',()=>{
  const result=candidateDefines(fixture(),original,'AA:BB');
  assert.equal(result.ROCHA_FIREBASE_APP_ID,'test-android-app');
  assert.equal(result.ROCHA_FIREBASE_SENDER_ID,'123');
  assert.equal(result.ROCHA_GOOGLE_SERVER_CLIENT_ID,original.ROCHA_GOOGLE_SERVER_CLIENT_ID);
});
test('wrong package, signing certificate, project or web OAuth client stops the build',()=>{
  const pkg=fixture();pkg.client[0].client_info.android_client_info.package_name='com.rochaplus.app';
  assert.throws(()=>candidateDefines(pkg,original,'aabb'),/candidate-config-missing/);
  assert.throws(()=>candidateDefines(fixture(),original,'ccdd'),/candidate-android-oauth-missing/);
  const project=fixture();project.project_info.project_id='other';
  assert.throws(()=>candidateDefines(project,original,'aabb'),/unexpected-project/);
  assert.throws(()=>candidateDefines(fixture(),{ROCHA_GOOGLE_SERVER_CLIENT_ID:'wrong'},'aabb'),
    /google-server-client-mismatch/);
});
