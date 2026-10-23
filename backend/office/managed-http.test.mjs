import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { createHttpHandler } from './http_server.mjs';

test('managed HTTP uses original bytes after middleware consumed the stream', async t => {
  let calls = 0;
  const handler = createHttpHandler({ access: async ({ body }) => { calls++; return body; } });
  const server = createServer(async (req, res) => {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    req.rawBody = Buffer.concat(chunks);
    req.body = { spoofed: true }; // Deliberately disagree with the raw JSON.
    await handler(req, res);
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const url = `http://127.0.0.1:${server.address().port}/v1/office/access`;
  const send = body => fetch(url, { method: 'POST', body, signal: AbortSignal.timeout(2000) });
  const accepted = await send('{"actual":true}');
  assert.equal(accepted.status, 200);
  assert.deepEqual(await accepted.json(), { actual: true });
  for (const [body, status] of [['not-json', 400], ['[]', 400], ['null', 400], ['x'.repeat(8193), 413]]) {
    const response = await send(body);
    assert.equal(response.status, status);
    assert.equal((await response.json()).allowed, false);
  }
  assert.equal(calls, 1);
});
