// Rehearse the real reconciliation against current documents. All writes stay
// in this process; the underlying Firestore receives document GETs only.
export function readOnlyFirestore(db) {
  const documents = new Map();
  const writes = new Set();
  function copy(value) {
    if (value == null || typeof value !== 'object') return value;
    if (value instanceof Date) return new Date(value);
    // Firestore Timestamp is immutable and must retain toMillis().
    if (typeof value.toMillis === 'function') return value;
    if (Array.isArray(value)) return value.map(copy);
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, copy(item)]));
  }
  async function get(ref) {
    if (!documents.has(ref.path)) {
      const snapshot = await db.doc(ref.path).get();
      documents.set(ref.path, snapshot.exists ? snapshot.data() : undefined);
    }
    const value = documents.get(ref.path);
    return { exists: value !== undefined, data: () => copy(value) };
  }
  const doc = path => ({ path, get() { return get(this); } });
  return {
    doc,
    // Callers reconcile a single account sequentially. This is a preview, not
    // a concurrency emulator or a durable snapshot of the remote database.
    async runTransaction(fn) {
      const pending = new Map();
      const tx = {
        get,
        set(ref, value) { pending.set(ref.path, copy(value)); },
        create(ref, value) {
          if (!documents.has(ref.path) || documents.get(ref.path) !== undefined || pending.has(ref.path)) {
            throw Error('preview-create-conflict');
          }
          pending.set(ref.path, copy(value));
        },
        update(ref, value) {
          const previous = pending.get(ref.path) ?? documents.get(ref.path);
          if (previous === undefined) throw Error('preview-update-missing');
          pending.set(ref.path, { ...copy(previous), ...copy(value) });
        },
      };
      const result = await fn(tx);
      for (const [path, value] of pending) { documents.set(path, value); writes.add(path); }
      return result;
    },
    summary() { return { documentsRead: documents.size, documentsWithStagedWrites: writes.size }; },
  };
}
