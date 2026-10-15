import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const src = readFileSync(new URL('./tools/reconcile-spark-payments.mjs', import.meta.url), 'utf8');
test('bulk apply is disabled', () => {
  assert.ok(src.includes('values.apply && values.all'));
  assert.ok(src.includes('bulk-apply-disabled'));
});
test('owner account is excluded from the runner', () => {
  assert.ok(src.includes('identity.email ==='));
  assert.ok(src.includes('counts.skipped++'));
});
