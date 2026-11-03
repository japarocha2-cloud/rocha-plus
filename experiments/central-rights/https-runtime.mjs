import {createServer} from 'node:https';
import {randomBytes} from 'node:crypto';
import {readFile} from 'node:fs/promises';
export async function createHttpsRuntime({key,cert,handle,publicFirebaseConfig=null,origin}) {
 const uri=new URL(origin);
 if(uri.protocol!=='https:'||uri.username||uri.password||uri.pathname!=='/'||uri.search||uri.hash)throw Error('https-origin');
 const page=await readFile(new URL('./mobile-approval.html',import.meta.url),'utf8');
 return createServer({key,cert,minVersion:'TLSv1.2'},async(req,res)=>{
  res.setHeader('Cache-Control','no-store, private');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
  const json=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(body));};
  if(!req.socket.encrypted)return json(400,{error:'https_required'});
  if(req.headers.origin&&req.headers.origin!==uri.origin)return json(403,{error:'origin'});
  if(req.method==='GET'&&req.url==='/approve'){
   const nonce=randomBytes(24).toString('base64');
   res.setHeader('Content-Security-Policy',"default-src 'none'; script-src 'nonce-"+nonce+"' https://www.gstatic.com; connect-src 'self' https://*.googleapis.com https://*.firebaseapp.com https://www.gstatic.com; frame-src https://accounts.google.com https://*.firebaseapp.com; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");
   res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});
   return res.end(page.replaceAll('NONCE_VALUE',nonce).replace('PUBLIC_CONFIG_VALUE',JSON.stringify(publicFirebaseConfig).replaceAll('<','\\u003c')));
  }
  if(req.url!=='/v1/access')return json(404,{error:'path'});
  if(req.method!=='POST')return json(405,{error:'method'});
  if(!/^application\/json(?:\s*;.*)?$/i.test(req.headers['content-type']??''))return json(415,{error:'content_type'});
  let chunks=[],size=0;
  try{
   for await(const chunk of req){size+=chunk.length;if(size>8192){chunks=[];return json(413,{error:'size'});}chunks.push(chunk);}
   let body;try{body=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{return json(400,{error:'json'});}
   if(!body||typeof body!=='object'||Array.isArray(body))return json(400,{error:'json'});
   const r=await handle({method:req.method,body,authorization:req.headers.authorization??'',address:req.socket.remoteAddress});json(r.status,r.body);
  }catch{if(!res.headersSent)json(503,{error:'unavailable'});}
 });
}
export async function listenLoopback(server,port=0) {
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});return server.address();
}
