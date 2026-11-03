// Deterministic integration fixture only; not a production datastore.
export function memoryStore() {
 const data=new Map();let tail=Promise.resolve();
 return {fixtureOnly:true,async transact(key,fn){
  let release;const previous=tail;tail=new Promise(r=>release=r);await previous;
  try{const old=data.get(key),result=await fn(structuredClone(old));if(result.commit!==false)data.set(key,structuredClone(result.value));return result.result;}finally{release();}
 },async read(key){return structuredClone(data.get(key));},async seed(key,value){data.set(key,structuredClone(value));}};
}
