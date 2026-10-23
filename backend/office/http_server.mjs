import { createServer } from 'node:http';
import { AccessError } from './service.mjs';
import { createRequestBudget } from './request-budget.mjs';

function parseJson(buffer) {
  if (buffer.length > 8192) throw new AccessError(413, 'Request too large');
  let body;
  try { body = buffer.length ? JSON.parse(buffer.toString('utf8')) : {}; }
  catch { throw new AccessError(400, 'Invalid JSON'); }
  if (!body || Array.isArray(body) || typeof body !== 'object') throw new AccessError(400, 'Invalid JSON object');
  return body;
}

function jsonBody(req) {
  // Functions Framework has already consumed the stream. Verify raw bytes;
  // never trust a middleware-supplied object or wait for a second end event.
  if (Buffer.isBuffer(req.rawBody)) return Promise.resolve().then(() => parseJson(req.rawBody));
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
      try {
        resolve(parseJson(Buffer.concat(chunks)));
      } catch (error) { reject(error); }
    });
    req.on('error', () => reject(new AccessError(400, 'Invalid request')));
    req.on('aborted', () => reject(new AccessError(400, 'Request aborted')));
  });
}

/** HTTP boundary only. Firebase verification remains in the production adapter. */
export function createHttpHandler({ access, allowedOrigins = [], requestBudget = createRequestBudget() }) {
  const origins = new Set(allowedOrigins);
  for (const origin of origins) {
    if (origin === 'null') continue; // Optional Electron file origin; bearer + device proof remain mandatory.
    const url = new URL(origin);
    if (url.protocol !== "https:" || url.origin !== origin) throw new Error("Exact HTTPS Office origin required");
  }
  if (typeof access !== 'function') throw new TypeError('Access service required');
  return async (req, res) => {
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
      const budget = requestBudget(req.url);
      if (!budget.allowed) {
        res.setHeader('Retry-After', String(budget.retryAfter));
        req.resume();
        throw new AccessError(429, 'Too many requests');
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
  };
}

export function createHttpServer(options) {
  const server = createServer(createHttpHandler(options));
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  return server;
}
