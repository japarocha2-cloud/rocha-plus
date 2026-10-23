import { onRequest } from 'firebase-functions/v2/https';
import { createOfficeRuntime } from './runtime.mjs';

let handler;
// Runtime identity is supplied by Google. No downloaded service-account key.
// Lazy construction keeps deployment discovery independent of credentials.
export const rochaOfficeLicense = onRequest({
  region: 'southamerica-east1',
  memory: '256MiB',
  timeoutSeconds: 15,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 20,
  cpu: 1,
  invoker: 'public',
  cors: false,
}, async (req, res) => {
  try {
    handler ??= createOfficeRuntime();
    await handler(req, res);
  } catch {
    if (!res.headersSent) {
      res.setHeader('Cache-Control', 'no-store, private');
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.statusCode = 503;
      res.end(JSON.stringify({ allowed: false, error: 'Service unavailable' }));
    }
  }
});
