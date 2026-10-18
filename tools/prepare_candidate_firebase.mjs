// Configure only the isolated Android registration. Never modify production apps,
// Auth providers, Firestore, accounts, subscriptions, API restrictions or IAM.
import {sign} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

export const candidatePackage = 'com.rochaplus.soultvtest';
const base = 'https://firebase.googleapis.com/v1beta1/';
const normalized = value => String(value || '').replaceAll(':', '').toLowerCase();

export function candidateDefines(services, original, sha1) {
  if (services.project_info?.project_id !== 'rocha-plus') throw Error('unexpected-project');
  const client = services.client?.find(c =>
    c.client_info?.android_client_info?.package_name === candidatePackage);
  if (!client || !client.client_info.mobilesdk_app_id || !client.api_key?.[0]?.current_key)
    throw Error('candidate-config-missing');
  const oauth = client.oauth_client || [];
  if (!oauth.some(c => c.client_type === 1 &&
      c.android_info?.package_name === candidatePackage &&
      normalized(c.android_info?.certificate_hash) === normalized(sha1)))
    throw Error('candidate-android-oauth-missing');
  if (!oauth.some(c => c.client_type === 3 &&
      c.client_id === original.ROCHA_GOOGLE_SERVER_CLIENT_ID))
    throw Error('google-server-client-mismatch');
  return {...original,
    ROCHA_FIREBASE_PROJECT_ID: 'rocha-plus',
    ROCHA_FIREBASE_APP_ID: client.client_info.mobilesdk_app_id,
    ROCHA_FIREBASE_API_KEY: client.api_key[0].current_key,
    ROCHA_FIREBASE_SENDER_ID: String(services.project_info.project_number)};
}

async function main() {
  const account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || 'null');
  if (account?.project_id !== 'rocha-plus' || account.type !== 'service_account' ||
      !account.client_email?.endsWith('@rocha-plus.iam.gserviceaccount.com'))
    throw Error('missing-or-invalid-firebase-admin-secret');
  const original = JSON.parse(readFileSync(process.env.ROCHA_FIREBASE_FILE, 'utf8'));
  if (original.ROCHA_FIREBASE_PROJECT_ID !== 'rocha-plus') throw Error('unexpected-project');
  const now = Math.floor(Date.now() / 1000);
  const encode = v => Buffer.from(JSON.stringify(v)).toString('base64url');
  const unsigned = `${encode({alg:'RS256',typ:'JWT'})}.${encode({iss:account.client_email,
    scope:'https://www.googleapis.com/auth/firebase', aud:'https://oauth2.googleapis.com/token',
    iat:now,exp:now+3600})}`;
  const assertion = unsigned + '.' + sign('RSA-SHA256', Buffer.from(unsigned),
    account.private_key).toString('base64url');
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {method:'POST',
    body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),
    signal:AbortSignal.timeout(30000)});
  if (!tokenResponse.ok) throw Error(`admin-auth-http-${tokenResponse.status}`);
  const {access_token: token} = await tokenResponse.json();
  if (!token) throw Error('admin-auth-no-token');
  const api = async (path, method='GET', body) => {
    if (process.env.ROCHA_CANDIDATE_READ_ONLY === 'true' && method !== 'GET')
      throw Error('read-only-mode-rejects-firebase-mutation');
    if (!/^(projects\/rocha-plus\/androidApps(?:\/|\?|$)|operations\/)/.test(path))
      throw Error('resource-outside-candidate-project');
    const response = await fetch(base + path, {method,
      headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
      body:body ? JSON.stringify(body) : undefined, signal:AbortSignal.timeout(30000)});
    if (!response.ok) {
      const result = await response.json().catch(() => ({}));
      const reason = result.error?.details?.find(d => d.reason)?.reason || 'request-failed';
      throw Error(`firebase-management-http-${response.status}-${reason}`);
    }
    return response.json();
  };
  const apps = [];
  let page;
  do {
    const result = await api('projects/rocha-plus/androidApps?pageSize=100' +
      (page ? '&pageToken=' + encodeURIComponent(page) : ''));
    apps.push(...(result.apps || [])); page = result.nextPageToken;
  } while (page);
  const readOnly = process.env.ROCHA_CANDIDATE_READ_ONLY === 'true';
  let app = apps.find(a => a.packageName === candidatePackage);
  if (!app && readOnly) throw Error('existing-candidate-registration-required');
  if (!app) {
    console.log('Registering isolated test package; production registration unchanged.');
    let op = await api('projects/rocha-plus/androidApps', 'POST', {
      packageName:candidatePackage, displayName:'Rocha+ Canais Teste'});
    for (let i=0; !op.done && i<40; i++) {
      await new Promise(resolve => setTimeout(resolve,1500));
      op = await api(op.name);
    }
    if (!op.done || op.error || op.response?.packageName !== candidatePackage)
      throw Error('candidate-registration-not-completed');
    app = op.response;
  }
  const name = `projects/rocha-plus/androidApps/${app.appId}`;
  const certs = execFileSync('keytool', ['-list','-v','-storetype','PKCS12',
    '-keystore', process.env.ROCHA_SIGNING_FILE, '-alias', process.env.ROCHA_KEY_ALIAS,
    '-storepass:env','ROCHA_KEYSTORE_PASSWORD'], {encoding:'utf8',
    env:{...process.env, LC_ALL:'C'}});
  const sha1 = certs.match(/SHA1:\s*([A-F0-9:]+)/i)?.[1];
  const sha256 = certs.match(/SHA256:\s*([A-F0-9:]+)/i)?.[1];
  if (!sha1 || !sha256) throw Error('signing-certificate-unavailable');
  const existing = (await api(name+'/sha')).certificates || [];
  for (const [certType, shaHash] of [['SHA_1',sha1],['SHA_256',sha256]]) {
    if (!existing.some(c => c.certType === certType && normalized(c.shaHash) === normalized(shaHash))) {
      if (readOnly) throw Error('existing-candidate-signing-certificate-required');
      await api(name+'/sha','POST',{certType,shaHash});
    }
  }
  let defines;
  for (let i=0;i<10;i++) {
    const result = await api(name+'/config');
    const services = JSON.parse(Buffer.from(result.configFileContents,'base64').toString());
    try { defines = candidateDefines(services,original,sha1); break; }
    catch(e) {
      if (e.message !== 'candidate-android-oauth-missing' || i===9) throw e;
      await new Promise(resolve => setTimeout(resolve,2000));
    }
  }
  writeFileSync(process.env.ROCHA_FIREBASE_FILE, JSON.stringify(defines), {mode:0o600});
  console.log('Candidate Firebase config, signing SHA and Google OAuth mapping verified. Values omitted.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href)
  main().catch(error => { console.error('Candidate Firebase setup stopped:',
    /^[a-z][a-z0-9-]+$/.test(error.message) ? error.message : 'configuration-or-network-error');
    process.exitCode=1; });
