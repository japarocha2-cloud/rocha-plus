import {randomBytes,createHash} from 'node:crypto';
import {resolveRights,rightsPacket} from './rights.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const id=s=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s);
const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
// The store must serialize the complete callback. A memory adapter is fixture-only.
export function createDeviceService({store,verifyIdentity,getAccount,loadRights,now=Date.now,random=randomBytes,scope='commercial',enabled=false}) {
 if(!['commercial','homologation'].includes(scope))throw Error('scope');
 const reply=(status,body)=>({status,body});
 async function identity(header){
  const match=/^Bearer (\S+)$/.exec(header??'');if(!match)throw Error('auth');
  const c=await verifyIdentity(match[1],true),u=await getAccount(c?.uid);
  if(!c?.uid||c.email_verified!==true||!['google.com','apple.com'].includes(c.firebase?.sign_in_provider)||u?.uid!==c.uid||u.disabled||u.emailVerified!==true)throw Error('auth');
  return c;
 }
 return async function handle({method='POST',body={},authorization='',address='loopback'}) {
  if(!enabled)return reply(503,{error:'central_rights_not_configured'});
  if(method!=='POST')return reply(405,{error:'method'});
  try {
   let actor;if(['register_mobile','approve','mobile_playback','mobile_stop','entitlement'].includes(body.action)){try{actor=await identity(authorization);}catch{return reply(401,{error:'auth'});}}
   const t=now();if(!Number.isSafeInteger(t)||t<=0)throw Error('clock');
   return await store.transact('devices',async old=>{
    const s=old??{pairs:{},sessions:{},accounts:{},rates:{}};
    for(const [k,p]of Object.entries(s.pairs))if(p.until<=t)delete s.pairs[k];
    for(const [k,v]of Object.entries(s.sessions))if(v.until<=t){delete s.sessions[k];const a=s.accounts[v.uid];if(a){a.tvs=a.tvs.filter(d=>d!==v.device);delete a.streams[v.device];}}
    for(const [k,r]of Object.entries(s.rates))if(r.until<=t)delete s.rates[k];
    for(const a of Object.values(s.accounts))for(const [k,stream]of Object.entries(a.streams))if(stream.until<=t)delete a.streams[k];
    const done=(status,payload)=>({value:s,result:reply(status,payload)});
    if(body.action==='start'){
     const ip=hash(address),rate=s.rates[ip]??{count:0,until:t+600000};if(rate.count>=5)return done(429,{error:'slow_down'});
     if(Object.keys(s.pairs).length>=128||Object.keys(s.sessions).length>=128)return done(503,{error:'capacity'});
     rate.count++;s.rates[ip]=rate;const secret=random(32).toString('hex'),code=[...random(8)].map(x=>alphabet[x%alphabet.length]).join('');
     if(s.pairs[code])return done(503,{error:'retry'});s.pairs[code]={device:hash(secret),until:t+600000};
     return done(200,{contractVersion:1,environment:'central-rights-lab',device_code:secret,device_id:hash(secret),user_code:code,expires_in:600,interval:5});
    }
    let session,uid=actor?.uid;
    if(['poll','status','logout'].includes(body.action)){
     if(body.action==='poll'){
      if(!id(body.device_code))return done(400,{error:'device'});
      const pair=Object.values(s.pairs).find(p=>p.device===hash(body.device_code));if(!pair)return done(410,{error:'code_expired'});
      if(!pair.uid)return done(202,{environment:'central-rights-lab',status:'pending'});
      // The session secret was created on first poll and is recoverable only
      // while this short-lived pairing record remains valid.
      if(!pair.token){pair.token=random(32).toString('hex');s.sessions[hash(pair.token)]={uid:pair.uid,device:pair.device,issuedAt:t,until:t+86400000};}
      session=s.sessions[hash(pair.token)];uid=session.uid;session={...session,key:hash(pair.token),token:pair.token};
     }else{const token=/^Bearer (\S+)$/.exec(authorization)?.[1];if(!id(token))return done(401,{error:'session'});const raw=s.sessions[hash(token)];if(!raw)return done(401,{error:'session'});session={...raw,key:hash(token)};uid=session.uid;}
    }
    if(!uid)return done(400,{error:'action'});
    const a=s.accounts[uid]??{phone:null,tvs:[],streams:{}};s.accounts[uid]=a;
    if(body.action==='logout'){delete s.sessions[session.key];a.tvs=a.tvs.filter(d=>d!==session.device);delete a.streams[session.device];for(const [c,p]of Object.entries(s.pairs))if(p.device===session.device)delete s.pairs[c];return done(200,{status:'logged_out'});}
    // Account disable and global revocation invalidate leases at each refresh.
    const account=await getAccount(uid);
    const revokedBefore=Date.parse(account?.tokensValidAfterTime??'');
    if(account?.uid!==uid||account.disabled||account.emailVerified!==true||(session&&Number.isFinite(revokedBefore)&&session.issuedAt<revokedBefore)){
     if(session){delete a.streams[session.device];delete s.sessions[session.key];}return done(401,{error:'account_unavailable'});
    }
    const snapshot=await loadRights(uid);
    const rights=resolveRights(scope==='homologation'&&snapshot?{...snapshot,periods:[],trialStartedAt:null}:snapshot,uid,t,{allowLab:scope==='homologation'});
    // Homologation grants never masquerade as paid/trial in the LAB transport.
    if(scope==='homologation'&&rights.state!=='lab')rights.active=false;
    if(!rights.active){if(session)delete a.streams[session.device];return done(403,rightsPacket(rights,uid,session?.device??'mobile',t,scope));}
    if(body.action==='register_mobile'){
     if(!id(body.mobile_id)||!Number.isSafeInteger(actor.auth_time)||actor.auth_time*1000>t||t-actor.auth_time*1000>300000||
      (a.phone&&a.phone.id!==hash(body.mobile_id)&&actor.auth_time<=a.phone.authTime))return done(403,{error:'fresh_mobile_signin_required'});
     if(a.phone?.id!==hash(body.mobile_id))delete a.streams.mobile;
     a.phone={id:hash(body.mobile_id),authTime:actor.auth_time};return done(200,{status:'mobile_linked'});
    }
    if(['approve','mobile_playback','mobile_stop','entitlement'].includes(body.action)){
     if(!id(body.mobile_id)||a.phone?.id!==hash(body.mobile_id))return done(403,{error:'mobile_replaced'});
    }
    if(body.action==='approve'){
     const p=s.pairs[body.user_code];if(!p)return done(410,{error:'code_expired'});
     if(p.uid&&p.uid!==uid)return done(409,{error:'bound'});
     if(!a.tvs.includes(p.device)){if(a.tvs.length>=2)return done(409,{error:'two_tvs_limit'});a.tvs.push(p.device);}
     p.uid=uid;return done(200,{status:'approved'});
    }
    const device=session?.device??'mobile',playing=body.action==='mobile_playback'||(body.action==='status'&&body.playback_active===true);
    if(playing){if(!a.streams[device]&&Object.keys(a.streams).length>=2)return done(409,{error:'two_streams_limit'});a.streams[device]={until:Math.min(t+60000,rights.expiresAt)};}
    else if(body.action!=='poll')delete a.streams[device];
    return done(200,{...rightsPacket(rights,uid,device,t,scope,playing),...(session?.token?{session_token:session.token,status:'approved'}:{})});
   });
  }catch{return reply(503,{error:'central_rights_unavailable'});}
 };
}
