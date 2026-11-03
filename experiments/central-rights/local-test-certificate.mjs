import {generateKeyPairSync,randomBytes,sign} from 'node:crypto';
// Generates a throwaway localhost certificate in memory. No OS trust changes,
// persisted private key, rejectUnauthorized=false or production certificate.
const der=(tag,...parts)=>{const b=Buffer.concat(parts),n=b.length;let len;if(n<128)len=Buffer.from([n]);else{const a=[];for(let v=n;v;v>>>=8)a.unshift(v&255);len=Buffer.from([128+a.length,...a]);}return Buffer.concat([Buffer.from([tag]),len,b]);};
const seq=(...a)=>der(48,...a),utf=s=>der(12,Buffer.from(s));
const oid=hex=>der(6,Buffer.from(hex,'hex'));
const pem=(tag,b)=>'-----BEGIN '+tag+'-----\n'+b.toString('base64').match(/.{1,64}/g).join('\n')+'\n-----END '+tag+'-----\n';
const utc=d=>der(23,Buffer.from(d.toISOString().replace(/[-:T]/g,'').slice(2,14)+'Z'));
export function ephemeralTestTls(){
 const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 const algorithm=seq(oid('2a864886f70d01010b'),der(5)),name=seq(der(49,seq(oid('550403'),utf('localhost'))));
 const san=seq(oid('551d11'),der(4,seq(der(130,Buffer.from('localhost')),der(135,Buffer.from([127,0,0,1])))));
 const tbs=seq(der(160,der(2,Buffer.from([2]))),der(2,Buffer.concat([Buffer.from([0]),randomBytes(16)])),algorithm,name,
  seq(utc(new Date(Date.now()-60000)),utc(new Date(Date.now()+3600000))),name,publicKey.export({type:'spki',format:'der'}),der(163,seq(san)));
 return {key:privateKey.export({type:'pkcs8',format:'pem'}),cert:pem('CERTIFICATE',seq(tbs,algorithm,der(3,Buffer.from([0]),sign('RSA-SHA256',tbs,privateKey))))};
}
