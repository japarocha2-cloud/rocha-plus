import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
const run = args => spawnSync(process.execPath, ['tools/reconcile-spark-payments.mjs', ...args], {
  cwd: new URL('.', import.meta.url), encoding: 'utf8',
  env: { ...process.env, MP_ACCESS_TOKEN: 'local-placeholder-not-a-secret' },
  timeout: 10000
});
const required = ['--project','rocha-plus','--collector','1981204845',
  '--monthly-plan','0b66f85cf2914aa88b9f1eadfa8b81a9',
  '--annual-plan','bb0c2c90ff3d45a6a8203b69fbabf871'];
test('refuses all-account production update before contacting provider', () => {
  const result = run([...required,'--all','--apply']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /spark-reconciliation-not-confirmed/);
  assert.match(result.stderr, /"stage":"configuration"/);
});
test('refuses mismatched target UID before contacting provider', () => {
  const result = run([...required,'--uid','test-user-A','--confirm-uid','test-user-B','--apply']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /spark-reconciliation-not-confirmed/);
  assert.match(result.stderr, /"stage":"configuration"/);
});
