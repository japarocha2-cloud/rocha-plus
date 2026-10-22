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
export function createHttpServer({ access }) {
  if (typeof access !== 'function') throw new TypeError('Access service required');
  const server = createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store, private');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    try {
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
