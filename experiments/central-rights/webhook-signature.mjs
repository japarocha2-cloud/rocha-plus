import {createHmac,timingSafeEqual} from 'node:crypto';
// Experimental boundary follows the official SDK manifest. No insecure fallback.
export function verifySignature({secret,signature,requestId,dataId,now=Date.now()}) {
 if(typeof secret!=='string'||!secret||typeof signature!=='string'||typeof requestId!=='string'||!requestId||typeof dataId!=='string'||!dataId||!Number.isSafeInteger(now))return false;
 const values={};for(const part of signature.split(',')){const match=/^\s*(ts|v1)=([a-fA-F0-9]+)\s*$/.exec(part);if(!match||values[match[1]])return false;values[match[1]]=match[2];}
 if(!/^\d{10,16}$/.test(values.ts??'')||!/^[a-f0-9]{64}$/i.test(values.v1??''))return false;
 const raw=Number(values.ts),timestamp=values.ts.length===10?raw*1000:raw;
 if(!Number.isSafeInteger(timestamp)||Math.abs(now-timestamp)>300000)return false;
 const expected=createHmac('sha256',secret).update('id:'+dataId.toLowerCase()+';request-id:'+requestId+';ts:'+values.ts+';').digest();
 return timingSafeEqual(expected,Buffer.from(values.v1,'hex'));
}
