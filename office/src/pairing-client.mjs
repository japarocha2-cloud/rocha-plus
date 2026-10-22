export async function pairInstallation({ endpoint, portalUrl, device, openBrowser, showCode,
  signal, fetch = globalThis.fetch, pause = ms => new Promise(resolve => setTimeout(resolve, ms)), now = () => performance.now() }) {
  const base = new URL(endpoint), portal = new URL(portalUrl);
  if ([base, portal].some(u => u.protocol !== 'https:' || u.username || u.password || u.search || u.hash)) throw new Error('HTTPS configuration required');
  async function request(path, body) {
    if (signal?.aborted) throw new Error('Login cancelled');
    const response = await fetch(`${base.href.replace(/\/$/, '')}/v1/office/pair/${path}`, {
      method: 'POST', cache: 'no-store', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(12_000)]) : AbortSignal.timeout(12_000),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error ?? 'Google login failed');
    return result;
  }
  const label = typeof navigator !== 'undefined' && /Android/.test(navigator.userAgent) ? 'Android' : 'Windows';
  const started = await request('start', { publicKey: device.publicKey, label });
  const url = new URL(started.approvalUrl);
  if (url.origin !== portal.origin || url.pathname !== portal.pathname || url.search || url.hash !== `#pair=${started.id}` ||
      !/^[A-Z0-9_-]{8}$/.test(started.code) || !Number.isSafeInteger(started.expiresAtMs) ||
      !Number.isSafeInteger(started.expiresInMs) || started.expiresInMs < 1 || started.expiresInMs > 120_000) throw new Error('Invalid login destination');
  const deadline = now() + started.expiresInMs;
  showCode(started.code);
  const signature = await device.sign(started.message);
  await openBrowser(url.href);
  while (now() < deadline) {
    const result = await request('finish', { id: started.id, secret: started.secret, signature });
    if (signal?.aborted) throw new Error('Login cancelled');
    if (result.pending === false && typeof result.customToken === 'string' && result.customToken) return result.customToken;
    if (result.pending !== true) throw new Error('Invalid Google login response');
    await pause(2_000);
  }
  throw new Error('Código expirado. Entre com Google novamente.');
}
