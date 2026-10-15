import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const runner=fileURLToPath(new URL('./tools/grant-owner-access.mjs',import.meta.url));
const src=readFileSync(runner,'utf8');

test('owner access command has valid Node syntax',()=>{
  execFileSync(process.execPath,['--check',runner],{stdio:'pipe'});
});
test('no write without explicit --apply',()=>{
  assert.match(src,/apply: \{ type: 'boolean', default: false \}/);
  assert.match(src,/if \(values\.apply\) \{/);
  assert.match(src,/tx\.update\(ref, \{ paidUntil:/);
});
test('owner is a verified, active Google identity in this project',()=>{
  assert.match(src,/OWNER_EMAIL = 'japarocha2@gmail.com'/);
  assert.match(src,/values\.project !== 'rocha-plus'/);
  assert.match(src,/!user\.emailVerified/);
  assert.match(src,/user\.disabled/);
  assert.match(src,/google\?\.length !== 1/);
});
test('cannot silently change existing paid projection',()=>{
  assert.match(src,/billing-projection-review-required/);
  assert.match(src,/existing-spark-account-required/);
});
