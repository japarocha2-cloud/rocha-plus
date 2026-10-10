import { createHash } from 'node:crypto';
export const tokenKey = token => createHash('sha256').update(token).digest('hex');
export function createStore(db) {
  return {
    async tokens(uid) {
      const record = await db.doc('billingUsers/' + uid).get();
      const data = record.data();
      // Migrate the first candidate's single-token representation on next claim.
      return data?.tokens ?? (data?.token ? [data.token] : []);
    },
    async owner(token) {
      return (await db.doc('billingTokens/' + tokenKey(token)).get()).data()?.uid;
    },
    async claim(uid, token, linkedToken) {
      const ref = db.doc('billingTokens/' + tokenKey(token));
      const userRef = db.doc('billingUsers/' + uid);
      const linkedRef = linkedToken ? db.doc('billingTokens/' + tokenKey(linkedToken)) : null;
      await db.runTransaction(async tx => {
        const owner = await tx.get(ref);
        const linked = linkedRef ? await tx.get(linkedRef) : null;
        const user = await tx.get(userRef);
        if ((owner.exists && owner.data().uid !== uid) ||
            (linked?.exists && linked.data().uid !== uid)) throw new Error('token-owned');
        const data = user.data();
        const tokens = [...new Set([...(data?.tokens ?? (data?.token ? [data.token] : [])), token])];
        if (tokens.length > 20) throw new Error('token-limit');
        tx.set(ref, { uid });
        tx.set(userRef, { tokens });
      });
    },
  };
}
