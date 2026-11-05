'use strict';

function createDiagnosticHandler({authenticate, readProbe}) {
  if (typeof authenticate !== 'function' || typeof readProbe !== 'function') {
    throw new TypeError('authenticate and readProbe are required');
  }
  return async function diagnostic(req, res) {
    res.set('Cache-Control', 'no-store');
    if (req.method !== 'POST') return res.status(405).json({ok: false, code: 'method_not_allowed'});
    let identity;
    try {
      identity = await authenticate(req);
    } catch (_) {
      return res.status(401).json({ok: false, code: 'unauthenticated'});
    }
    try {
      const result = await readProbe(identity);
      return res.status(200).json({ok: true, result});
    } catch (error) {
      if (error?.code === 'AUTHORIZATION_DENIED') {
        return res.status(403).json({ok: false, code: 'forbidden'});
      }
      console.error('Firestore isolation diagnostic failed', error?.code || 'unknown');
      return res.status(503).json({ok: false, code: 'diagnostic_unavailable'});
    }
  };
}

module.exports = {createDiagnosticHandler};
