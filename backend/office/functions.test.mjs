import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { rochaOfficeLicense } from './functions.mjs';

test('managed function refuses requests without Google authorization through its real HTTP entry point', async t => {
  const previous = process.env.GOOGLE_CLOUD_PROJECT;
  process.env.GOOGLE_CLOUD_PROJECT = 'rocha-plus';
  t.after(() => {
    if (previous === undefined) delete process.env.GOOGLE_CLOUD_PROJECT;
    else process.env.GOOGLE_CLOUD_PROJECT = previous;
  });
  const server = createServer(rochaOfficeLicense);
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const url = `http://127.0.0.1:${server.address().port}/v1/office/me`;
  for (const authorization of ['', 'Bearer malformed-token']) {
    const response = await fetch(url, { headers: authorization ? { authorization } : {}, signal: AbortSignal.timeout(3000) });
    assert.equal(response.status, 401);
    assert.equal((await response.json()).allowed, false);
    assert.match(response.headers.get('cache-control'), /no-store/);
  }
});
