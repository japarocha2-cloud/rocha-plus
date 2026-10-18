import { randomBytes, createHash } from 'node:crypto';
export const keyOf = value => createHash('sha256').update(value).digest('hex');
export function createPairingService({ store, verifyIdentity, mintToken, apiKey, now = Date.now, random = randomBytes }) {
 const reply = (status, body) => ({status, body});
 const codePattern = /^[A-HJ-NP-Z2-9]{8}$/;
 const secretPattern = /^[a-f0-9]{64}$/;
 const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
 return async function handle({method, body = {}, authorization = '', address = ''}) {
  if (method !== 'POST') return reply(405,{error:'method_not_allowed'});
  if (!apiKey) return reply(503,{error:'service_unavailable'});
  try {
   if (body.action === 'start') {
    if (!await store.throttle('start:'+keyOf(address), 5, now())) return reply(429,{error:'slow_down'});
    for (let attempt=0;attempt<5;attempt++) {
     const deviceCode = random(32).toString('hex');
     const userCode = [...random(8)].map(n=>alphabet[n % alphabet.length]).join('');
     const record = {key:keyOf(deviceCode),codeKey:keyOf(userCode),expires:now()+600000,uid:null};
     if (await store.create(record)) return reply(200,{device_code:deviceCode,user_code:userCode,expires_in:600,interval:5,firebase_api_key:apiKey});
    }
    return reply(503,{error:'try_again'});
   }
   if (body.action === 'approve') {
    if (!codePattern.test(body.user_code ?? '')) return reply(400,{error:'invalid_code'});
    if (!authorization.startsWith('Bearer ')) return reply(401,{error:'authentication_required'});
    let identity;
    try {identity = await verifyIdentity(authorization.slice(7),true);} catch {return reply(401,{error:'invalid_identity'});}
    if (!identity.uid || !['google.com','apple.com'].includes(identity.firebase?.sign_in_provider)) return reply(403,{error:'verified_account_required'});
    if (!await store.throttle('approve:'+keyOf(identity.uid), 10, now())) return reply(429,{error:'slow_down'});
    const outcome = await store.approve(keyOf(body.user_code),identity.uid,now());
    if (outcome !== 'approved') return reply(outcome === 'conflict' ? 409 : 410,{error:outcome});
    return reply(200,{status:'approved'});
   }
   if (['poll','complete'].includes(body.action)) {
    if (!secretPattern.test(body.device_code ?? '')) return reply(400,{error:'invalid_device'});
    const key = keyOf(body.device_code);
    if (!await store.throttle('poll:'+key, 20, now(),60000)) return reply(429,{error:'slow_down'});
    const record = await store.read(key);
    if (!record || record.expires <= now()) return reply(410,{error:'expired'});
    if (!record.uid) return reply(202,{status:'pending'});
    if (body.action === 'poll') {
     // Tokens are created on demand and never persisted in Firestore or logged.
     const token = await mintToken(record.uid,{roku_device:key});
     return reply(200,{status:'approved',custom_token:token});
    }
    let identity;
    try {identity=await verifyIdentity(authorization.replace(/^Bearer /,''),true);} catch {return reply(401,{error:'invalid_identity'});}
    if (identity.uid !== record.uid || identity.roku_device !== key) return reply(403,{error:'wrong_device'});
    await store.remove(record);
    return reply(200,{status:'complete'});
   }
   return reply(400,{error:'invalid_action'});
  } catch { return reply(503,{error:'service_unavailable'}); }
 };
}
