export function buildConfig(env) {
  for (const flag of ['ROCHA_OFFICE_COMMERCIAL', 'ROCHA_OFFICE_PORTAL_ENABLED']) {
    if (env[flag] !== undefined && !['true', 'false'].includes(env[flag])) throw new Error('Explicit Office build flag required');
  }
  const commercial = env.ROCHA_OFFICE_COMMERCIAL === 'true';
  const enabled = commercial || env.ROCHA_OFFICE_PORTAL_ENABLED === 'true';
  if (!enabled) return { commercial: false, enabled: false };
  const endpoint = env.ROCHA_OFFICE_LICENSE_URL, portalUrl = env.ROCHA_OFFICE_PORTAL_URL;
  for (const raw of [endpoint, portalUrl]) {
    const url = new URL(raw);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) throw new Error('Office requires fixed HTTPS configuration');
  }
  const firebase = JSON.parse(env.ROCHA_OFFICE_FIREBASE_JSON ?? '{}');
  if (!firebase.apiKey || !firebase.authDomain || firebase.projectId !== 'rocha-plus') throw new Error('Experimental Rocha Firebase Web configuration required');
  // Publish only documented Web config keys, never copy an arbitrary Secret object.
  const firebaseConfig = Object.fromEntries(['apiKey', 'authDomain', 'projectId', 'appId', 'messagingSenderId'].filter(k => firebase[k]).map(k => [k, firebase[k]]));
  return { commercial, enabled, endpoint, portalUrl, firebase: firebaseConfig };
}
