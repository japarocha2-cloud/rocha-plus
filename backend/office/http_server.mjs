import { createServer } from 'node:http';
import { AccessError } from './service.mjs';

function jsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let bytes = 0;
    let rejected = false;
    req.on('data', chunk => {
      bytes += chunk.length;
      if (bytes > 8192) {
        chunks.length = 0;
        if (!rejected) reject(new AccessError(413, 'Request too large'));
        rejected = true;
      } else if (!rejected) {
        chunks.push(chunk);
      }
    });
    req.on('end', () => {
      if (rejected) return;
      let body;
      try {
        const content = Buffer.concat(chunks).toString('utf8');
        body = content ? JSON.parse(content) : {};
      } catch {
        reject(new AccessError(400, 'Invalid JSON'));
        return;
      }
      if (!body || Array.isArray(body) || typeof body !== 'object') {
        reject(new AccessError(400, 'Invalid JSON object'));
        return;
      }
      resolve(body);
    });
    req.on('error', () => reject(new AccessError(400, 'Invalid request')));
    req.on('aborted', () => reject(new AccessError(400, 'Request aborted')));
  });
}

/** HTTP boundary only. Firebase verification remains in the production adapter. */
export function createHttpServer({ access, allowedOrigins = [] }) {
  const origins = new Set(allowedOrigins);
  for (const origin of origins) {
    if (origin === 'null') continue; // Optional Electron file origin; bearer + device proof remain mandatory.
    const url = new URL(origin);
    if (url.protocol !== "https:" || url.origin !== origin) throw new Error("Exact HTTPS Office origin required");
  }
  if (typeof access !== 'function') throw new TypeError('Access service required');
  const server = createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store, private');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    try {
      const origin = req.headers.origin;
      res.setHeader('Vary', 'Origin');
      if (origin) {
        if (!origins.has(origin) || (origin === 'null' && (req.url.includes('/admin/') || req.url === '/v1/office/pair/approve'))) throw new AccessError(403, 'Origin not allowed');
        res.setHeader('Access-Control-Allow-Origin', origin);
      }
      if (req.method === 'OPTIONS') {
        const requested = (req.headers['access-control-request-headers'] ?? '').toLowerCase().split(',').map(v => v.trim()).filter(Boolean);
        if (!origin || !['GET', 'POST'].includes(req.headers['access-control-request-method']) ||
            requested.some(name => !['authorization', 'content-type'].includes(name))) {
          throw new AccessError(403, 'Preflight not allowed');
        }
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST');
        res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
        res.writeHead(204); res.end(); return;
      }
      const body = await jsonBody(req);
      const result = await access({ method: req.method, path: req.url,
        authorization: req.headers.authorization, body });
      res.writeHead(200);
      res.end(JSON.stringify(result));
    } catch (error) {
      const status = error instanceof AccessError ? error.status : 503;
      if (!res.destroyed) {
        res.writeHead(status);
        res.end(JSON.stringify({ allowed: false,
          error: status === 503 ? 'Service unavailable' : error.message }));
      }
    }
  });
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  return server;
}
