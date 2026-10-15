import assert from 'node:assert/strict';
export function memoryDb() {
  const data = new Map(); let queue = Promise.resolve();
  return { data, doc: path => ({path, get: async()=>({exists:data.has(path),
    data:()=>data.has(path)?structuredClone(data.get(path)):undefined})}),
    runTransaction(fn) {
      const run = queue.then(async()=>{
        const writes=[];
        const result=await fn({
          get: async ref=>{ assert.equal(writes.length,0,'Firestore reads precede writes');
            const value=data.get(ref.path);return {exists:value!=null,data:()=>value&&structuredClone(value)}; },
          create:(ref,value)=>{if(data.has(ref.path))throw Error('exists');writes.push([ref.path,value]);},
          set:(ref,value)=>writes.push([ref.path,value]),
          update:(ref,value)=>writes.push([ref.path,{...data.get(ref.path),...value}]),
        });
        for(const [key,value] of writes)data.set(key,structuredClone(value));return result;
      });queue=run.catch(()=>{});return run;
    }};
}
