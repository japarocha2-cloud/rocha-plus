import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const file = fileURLToPath(new URL('./tools/reconcile-spark-payments.mjs', import.meta.url));
const source = readFileSync(file, 'utf8');

test('Spark reconciliation runner parses in Node', () => {
  execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
});

test('Spark runner requires explicit --apply for writes', () => {
  assert.match(source, /apply: \{ type: 'boolean', default: false \}/);
  assert.match(source, /if \(values\.apply\) \{ await service\.reconcileAccount/);
  assert.match(source, /readOnly: !values\.apply/);
});

test('Spark runner restricts project and production collector', () => {
  assert.match(source, /values\.project !== 'rocha-plus'/);
  assert.match(source, /values\.collector !== '1981204845'/);
  assert.match(source, /planIds\.monthly === planIds\.annual/);
});

test('Spark runner accepts admin JSON only for its intended Firebase project', () => {
  assert.match(source, /process\.env\.FIREBASE_SERVICE_ACCOUNT_JSON/);
  assert.match(source, /serviceAccount\.project_id !== values\.project/);
  assert.match(source, /firebaseCredential = cert\(serviceAccount\)/);
  assert.doesNotMatch(source, /console\.(?:log|error)\([^\n]*(?:private_key|FIREBASE_SERVICE_ACCOUNT_JSON)/);
});
