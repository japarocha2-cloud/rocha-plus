import {X509Certificate} from 'node:crypto';
// Pure inspection. Never binds a socket, loads a private key, grants access or writes cloud data.
export function inspectPreparation(config,observed={},now=Date.now()) {
 const missing=[];const need=(ok,code)=>{if(!ok)missing.push(code);};
 need(config?.enabled===false&&config?.publicServiceEnabled===false,'activation_must_remain_disabled');
 need(config?.environment==='central-rights-lab'&&config?.scope==='homologation','isolated_scope');
 need(config?.identityProjectId==='rocha-plus','identity_project');
 need(typeof config?.labProjectId==='string'&&config.labProjectId.length>0&&!['rocha-plus','rocha-plus-candidate'].includes(config.labProjectId),'separate_lab_project');
 let origin;try{origin=new URL(config.origin);need(origin.protocol==='https:'&&!origin.username&&!origin.password&&origin.pathname==='/'&&!origin.search&&!origin.hash&&!origin.hostname.endsWith('.invalid'),'trusted_https_origin');}catch{missing.push('trusted_https_origin');}
 need(observed.hostIsolated===true,'isolated_host_not_confirmed');
 need(observed.networkReachable?.roku===true&&observed.networkReachable?.mobile===true&&observed.networkReachable?.android===true,'device_network_not_confirmed');
 need(observed.identityProject===config?.identityProjectId&&observed.labProject===config?.labProjectId,'projects_not_confirmed');
 need(observed.commercialReadOnly===true&&observed.labTransactions===true,'iam_boundary_not_confirmed');
 need(origin&&Array.isArray(observed.authorizedDomains)&&observed.authorizedDomains.includes(origin.hostname),'auth_domain_not_confirmed');
 need(observed.googleEnabled===true,'google_provider_not_confirmed');
 let certificateValid=false;try{const cert=new X509Certificate(observed.publicCertificatePem);certificateValid=!!origin&&!!cert.checkHost(origin.hostname)&&Date.parse(cert.validFrom)<=now&&Date.parse(cert.validTo)>now&&!cert.ca;}catch{/* public cert absent or invalid */}
 need(certificateValid,'certificate_name_or_validity');
 need(['roku','mobile','android'].every(k=>observed.tlsTrusted?.[k]===true),'device_tls_trust_not_confirmed');
 const g=config?.authorization;
 need(g?.enabled===false,'grant_must_remain_disabled');
 // A planning record is not a grant. Approval is reviewed separately and never applied here.
 need(g?.ownerApproved===true&&typeof g?.accountReference==='string'&&g.accountReference.length>0&&Number.isSafeInteger(g?.notBefore)&&Number.isSafeInteger(g?.expiresAt)&&g.expiresAt>g.notBefore&&g.expiresAt-g.notBefore<=86400000&&g.notBefore<=now&&g.expiresAt>now,'exact_authorization_not_ready');
 return {environment:'central-rights-lab',inspectionOnly:true,activationAllowed:false,readyToRequestActivation:missing.length===0,missing:[...new Set(missing)],routes:['GET /approve','POST /v1/access'],paymentsEnabled:false};
}
const operations=new Set(['start','approve','poll','status','entitlement','mobile_playback','mobile_stop','logout']);
export function diagnosticEvent(input) {
 // Allowlist only: request bodies, URLs, UID, code, email and tokens never pass through.
 return {operation:operations.has(input?.operation)?input.operation:'unknown',status:Number.isInteger(input?.status)&&input.status>=100&&input.status<=599?input.status:0,elapsedMs:Number.isFinite(input?.elapsedMs)&&input.elapsedMs>=0?Math.min(Math.round(input.elapsedMs),60000):0,environment:'central-rights-lab'};
}
