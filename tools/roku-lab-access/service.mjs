import {randomBytes,createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const norm=s=>typeof s==='string'?s.trim().toLowerCase():'';
const idOk=s=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s);
export function createLabAccessService({config,verifyIdentity,getAccount,now=Date.now,random=randomBytes}) {
 const pairs=new Map(),codes=new Map(),sessions=new Map(),phones=new Map(),tvs=new Map(),streams=new Map(),rates=new Map();
 const env='roku-lab',alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
 const reply=(status,body)=>({status,body});
 const valid=()=>config?.environment===env&&config?.scope==='homologation'&&config?.enabled===true&&norm(config.allowedEmail)&&Number.isSafeInteger(config.notBefore)&&Number.isSafeInteger(config.expiresAt)&&config.expiresAt>config.notBefore&&config.expiresAt-config.notBefore<=86400000&&now()>=config.notBefore&&now()<config.expiresAt;
 const sweep=()=>{for(const[k,p]of pairs)if(p.expires<=now()){codes.delete(p.code);pairs.delete(k);}for(const[k,s]of streams)if(s.until<=now())streams.delete(k);for(const[k,r]of rates)if(r.until<=now())rates.delete(k);if(!valid()){sessions.clear();streams.clear();}};
 async function owner(auth){if(typeof auth!=='string'||!auth.startsWith('Bearer '))throw Error('identity');
 const i=await verifyIdentity(auth.slice(7),true);
 if(!i?.uid||i.email_verified!==true||norm(i.email)!==norm(config.allowedEmail)||!['google.com','apple.com'].includes(i.firebase?.sign_in_provider))throw Error('identity');
 const u=await getAccount(i.uid);
 if(!u||u.disabled||u.emailVerified!==true||norm(u.email)!==norm(config.allowedEmail))throw Error('identity');
 return {uid:i.uid,authTime:i.auth_time};}
 const packet=(s,play=false)=>{const active=[...streams.values()].filter(x=>x.uid===s.uid&&x.until>now());let own=active.find(x=>x.session===s.key);if(play){if(!own&&active.length>=2)return null;streams.set(s.key,{uid:s.uid,session:s.key,until:Math.min(config.expiresAt,now()+60000)});}else streams.delete(s.key);return {environment:env,scope:'homologation',state:'lab',active:true,uid:s.uid,device_id:s.device,playbackAllowed:play,serverTime:now(),accessUntil:Math.min(config.expiresAt,now()+60000),grantUntil:config.expiresAt};};
 return async function handle({method='POST',body={},authorization='',address='local'}) {
 sweep();if(!valid())return reply(503,{error:'lab_authorization_not_configured'});
 if(method!=='POST')return reply(405,{error:'method'});
 try{
 if(body.action==='start'){
 const key=hash(address),r=rates.get(key);if(r?.count>=5&&r.until>now())return reply(429,{error:'slow_down'});
 rates.set(key,{count:(r?.count||0)+1,until:r?.until||now()+600000});
 const secret=random(32).toString('hex'),code=[...random(8)].map(x=>alphabet[x%alphabet.length]).join('');
 if(codes.has(code))return reply(503,{error:'retry'});pairs.set(hash(secret),{code,expires:Math.min(config.expiresAt,now()+600000)});codes.set(code,hash(secret));
 return reply(200,{environment:env,user_code:code,device_code:secret,expires_in:600,interval:5});}
 if(body.action==='register_mobile'||body.action==='approve'){
 let ownerIdentity;try{ownerIdentity=await owner(authorization);}catch{return reply(403,{error:'verified_owner_required'});}
 const {uid,authTime}=ownerIdentity;if(!idOk(body.mobile_id))return reply(400,{error:'mobile_id_required'});
 if(body.action==='register_mobile'){const old=phones.get(uid);if(!Number.isSafeInteger(authTime)||authTime*1000>now()||now()-authTime*1000>300000||(old&&old.key!==hash(body.mobile_id)&&authTime<=old.authTime))return reply(403,{error:'fresh_mobile_signin_required'});phones.set(uid,{key:hash(body.mobile_id),authTime});streams.delete("mobile:"+hash(uid));return reply(200,{status:'mobile_linked',environment:env});}
 if(phones.get(uid)?.key!==hash(body.mobile_id))return reply(403,{error:'mobile_replaced'});
 const pk=codes.get(body.user_code),p=pairs.get(pk);if(!p||p.expires<=now())return reply(410,{error:'code_expired'});
 if(p.uid&&p.uid!==uid)return reply(409,{error:'code_already_bound'});
 const accountTVs=tvs.get(uid)||new Set();
 if(!accountTVs.has(pk)&&accountTVs.size>=2)return reply(409,{error:'two_tvs_limit'});
 p.uid=uid;accountTVs.add(pk);tvs.set(uid,accountTVs);return reply(200,{status:'approved',environment:env});}
 if(body.action==='mobile_playback'||body.action==='mobile_stop'){let ownerIdentity;try{ownerIdentity=await owner(authorization);}catch{return reply(403,{error:'verified_owner_required'});}const {uid}=ownerIdentity;if(!idOk(body.mobile_id)||phones.get(uid)?.key!==hash(body.mobile_id))return reply(403,{error:'mobile_replaced'});const access=packet({key:'mobile:'+hash(uid),uid,device:'mobile'},body.action==='mobile_playback');return access?reply(200,access):reply(409,{error:'two_streams_limit'});}
 if(body.action==='poll'){
 if(!idOk(body.device_code))return reply(400,{error:'invalid_device'});
 const key=hash(body.device_code),p=pairs.get(key);if(!p||p.expires<=now())return reply(410,{error:'code_expired'});
 if(!p.uid)return reply(202,{status:'pending',environment:env});
 if(!p.session){p.session=random(32).toString('hex');const sk=hash(p.session);sessions.set(sk,{key:sk,uid:p.uid,device:key});}
 const s=sessions.get(hash(p.session)),access=packet(s);if(!access)return reply(409,{error:'two_streams_limit'});
 return reply(200,{...access,session_token:p.session,status:'approved'});}
 if(body.action==='status'||body.action==='logout'){
 const s=sessions.get(hash(authorization.replace(/^Bearer /,'')));if(!s)return reply(401,{error:'invalid_lab_session'});
 if(body.action==='logout'){sessions.delete(s.key);streams.delete(s.key);tvs.get(s.uid)?.delete(s.device);return reply(200,{status:'logged_out'});}
 const access=packet(s,body.playback_active===true);return access?reply(200,access):reply(409,{error:'two_streams_limit'});}
 return reply(400,{error:'invalid_action'});
 }catch{return reply(503,{error:'lab_unavailable'});}
 };
}
// Prepared single-process LAB adapter only. No billing writer, paid state or production deployment.
