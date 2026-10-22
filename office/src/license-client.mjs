// Only verified server responses grant access; no paid flag lives in localStorage.
const to64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes)))
  .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
export function indexedKeyStore(indexedDB = globalThis.indexedDB) {
  let database;
  const open = () => database ??= new Promise((resolve, reject) => {
    const request = indexedDB.open('rocha-office-installation', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('keys');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new Error('Installation storage unavailable'));
  });
  return {
    async loadOrCreate(generate) {
      const db = await open();
      // Generate outside the IDB transaction; read again inside the write
      // transaction to avoid two browser tabs registering different keys.
      const candidate = await generate();
      return new Promise((resolve, reject) => {
        const tx = db.transaction('keys', 'readwrite');
        const store = tx.objectStore('keys');
        const read = store.get('p256'); let keys;
        read.onsuccess = () => { keys = read.result ?? candidate; if (!read.result) store.put(keys, 'p256'); };
        tx.oncomplete = () => resolve(keys);
        tx.onerror = tx.onabort = () => reject(new Error('Installation storage unavailable'));
      });
    },
  };
}
export async function installation({ keyStore = indexedKeyStore(), crypto = globalThis.crypto } = {}) {
  const keys = await keyStore.loadOrCreate(() => crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign', 'verify']));
  return { publicKey: await crypto.subtle.exportKey('jwk', keys.publicKey),
    async sign(message) {
      return to64(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' },
        keys.privateKey, new TextEncoder().encode(message)));
    },
  };
}
export function officeClient({ endpoint, getToken, installation: device, fetch = globalThis.fetch }) {
  const base = new URL(endpoint);
  if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash) {
    throw new Error('HTTPS Office service required');
  }
  async function request(path, body, signal) {
    const token = await getToken();
    if (!token) throw new Error('Google sign-in required');
    const response = await fetch(`${base.href.replace(/\/$/, '')}/v1/office/${path}`, {
      method: body === undefined ? 'GET' : 'POST', cache: 'no-store', signal,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error ?? 'Office access denied');
    return result;
  }
  return { me: () => request('me'),
    async prove(action, { label = 'Office', download = false, platform } = {}) {
      if (!['activate', 'access', 'deactivate'].includes(action)) throw new Error('Invalid action');
      const signal = AbortSignal.timeout(12_000);
      const c = await request('challenge', { action, label, publicKey: device.publicKey }, signal);
      const result = await request(action, { challengeId: c.challengeId,
        signature: await device.sign(c.message), download, platform }, signal);
      if (action !== 'deactivate' && (result.allowed !== true || result.product !== 'rocha-office-basic')) {
        throw new Error('Office access denied');
      }
      return result;
    },
  };
}
