// Infrastructure-only probe: no customer/Auth/document/payment queries.
// Never return principal identifiers, rule sources, tokens or provider payloads.
import {createHash} from 'node:crypto';
const permissionNames=['datastore.entities.get','datastore.entities.create','datastore.entities.update',
  'datastore.entities.delete','firebaserules.releases.get','firebaserules.rulesets.get'];
const safeResponse=result=>({http:Number.isInteger(result?.http)?result.http:null,
  reasons:(result?.data?.error?.details||[]).map(x=>x.reason).filter(x=>typeof x==='string' && /^[A-Z_]{1,80}$/.test(x))});
export async function probeCredentialPolicy({credentialProject,request}) {
  const report={readOnly:true,customerQueries:0,documentQueries:0,paymentQueries:0,
    projectMatchesExpected:credentialProject==='rocha-plus',leastPrivilegeConfirmed:false};
  if(!report.projectMatchesExpected)return {...report,blocked:'unexpected-credential-project'};
  const metadata=await request('https://firestore.googleapis.com/v1/projects/rocha-plus/databases/(default)');
  report.database={...safeResponse(metadata),edition:['STANDARD','ENTERPRISE'].includes(metadata?.data?.databaseEdition)?metadata.data.databaseEdition:null};
  const iam=await request('https://cloudresourcemanager.googleapis.com/v1/projects/rocha-plus:testIamPermissions',{permissions:permissionNames});
  report.iam={...safeResponse(iam),scope:'limited-project-permission-probe'};
  if(iam.http===200) {
    const granted=new Set(iam.data?.permissions||[]);
    report.iam.documentGet=granted.has('datastore.entities.get');
    report.iam.documentCreate=granted.has('datastore.entities.create');
    report.iam.documentUpdate=granted.has('datastore.entities.update');
    report.iam.documentDelete=granted.has('datastore.entities.delete');
    report.iam.writePermissionDetected=['datastore.entities.create','datastore.entities.update','datastore.entities.delete'].some(p=>granted.has(p));
  }
  const release=await request('https://firebaserules.googleapis.com/v1/projects/rocha-plus/releases/cloud.firestore');
  report.rules={release: safeResponse(release),exactReviewedSparkSource:false};
  const name=release.data?.rulesetName;
  if(release.http===200 && typeof name==='string' && /^projects\/rocha-plus\/rulesets\/[A-Za-z0-9_-]+$/.test(name)) {
    const rules=await request('https://firebaserules.googleapis.com/v1/'+name);
    report.rules.source=safeResponse(rules);
    const files=rules.data?.source?.files;
    if(rules.http===200 && Array.isArray(files) && files.length===1 && typeof files[0].content==='string') {
      const content=files[0].content;
      const hash=createHash('sha1').update('blob '+Buffer.byteLength(content)+'\0'+content).digest('hex');
      report.rules.exactReviewedSparkSource=hash==='8752a9513863819eb2b4b8ae424a5280b5a3164b';
    }
  }
  return report;
}
