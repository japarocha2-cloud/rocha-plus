// Uses the existing secret in its native Actions job; never exports/copies its value.
// The private customer diagnostic is neither imported nor invoked.
import {cert} from 'firebase-admin/app';
import {probeCredentialPolicy} from '../credential_policy_probe.mjs';
try {
  const key=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON||'{}');
  if(key.type!=='service_account' || key.project_id!=='rocha-plus') throw Error('credential');
  const credential=cert(key),access=await credential.getAccessToken();
  const report=await probeCredentialPolicy({credentialProject:key.project_id,request:async(url,body)=>{
    try {
      const r=await fetch(url,{method:body?'POST':'GET',redirect:'error',signal:AbortSignal.timeout(15000),
        headers:{Authorization:'Bearer '+access.access_token,'Content-Type':'application/json'},
        ...(body?{body:JSON.stringify(body)}:{})});
      let data;try{data=await r.json();}catch(_){data={};}
      return {http:r.status,data};
    }catch(_){return {http:null,data:{}};}
  }});
  console.log(JSON.stringify(report));
}catch(_) {
  console.log(JSON.stringify({readOnly:true,customerQueries:0,documentQueries:0,paymentQueries:0,blocked:'credential-or-infrastructure-not-confirmed'}));
  process.exitCode=1;
}
