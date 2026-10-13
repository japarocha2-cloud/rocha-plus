export function createStore(db) {
 const device = key => db.doc('rokuPairDevices/'+key);
 const code = key => db.doc('rokuPairCodes/'+key);
 return {
  async throttle(key,max,now,window=600000) {
   const ref=db.doc('rokuPairRates/'+key.replaceAll(':','_'));
   return db.runTransaction(async tx=>{
    const data=(await tx.get(ref)).data();
    const active=data && data.until>now;
    if (active && data.count>=max) return false;
    tx.set(ref,{count:active ? data.count+1 : 1,until:active ? data.until : now+window});return true;
   });
  },
  async create(record) {
   return db.runTransaction(async tx=>{
    const existing=await tx.get(code(record.codeKey));
    if (existing.exists && existing.data().expires>Date.now()) return false;
    tx.set(device(record.key),{...record,expiresAt:new Date(record.expires)});
    tx.set(code(record.codeKey),{key:record.key,expires:record.expires,expiresAt:new Date(record.expires)});return true;
   });
  },
  async approve(codeKey,uid,now) {
   return db.runTransaction(async tx=>{
    const entry=await tx.get(code(codeKey));
    if (!entry.exists || entry.data().expires<=now) return 'expired';
    const ref=device(entry.data().key);const snapshot=await tx.get(ref);const record=snapshot.data();
    if (!record || record.expires<=now) return 'expired';
    if (record.uid && record.uid!==uid) return 'conflict';
    tx.update(ref,{uid});return 'approved';
   });
  },
  async read(key) {return (await device(key).get()).data();},
  async remove(record) {
   const batch=db.batch();batch.delete(device(record.key));batch.delete(code(record.codeKey));await batch.commit();
  },
 };
}
