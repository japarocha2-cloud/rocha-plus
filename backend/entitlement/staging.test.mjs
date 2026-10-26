import test from 'node:test';
import assert from 'node:assert/strict';
import { assertStagingProject } from './staging.mjs';

test('rejects live Rocha+ Firebase project even when staging variable matches', () => {
  assert.throws(() => assertStagingProject({
    GOOGLE_CLOUD_PROJECT: 'rocha-plus', ROCHA_STAGING_PROJECT_ID: 'rocha-plus',
  }), /distinct, matching staging/);
});

test('rejects absent or mismatched staging environment', () => {
  for (const env of [
    {},
    { GOOGLE_CLOUD_PROJECT: 'rocha-stage' },
    { GOOGLE_CLOUD_PROJECT: 'rocha-stage', ROCHA_STAGING_PROJECT_ID: 'another-project' },
  ]) assert.throws(() => assertStagingProject(env), /distinct, matching staging/);
});

test('accepts only matching non-production staging project', () => {
  assert.equal(assertStagingProject({
    GOOGLE_CLOUD_PROJECT: 'rocha-stage', ROCHA_STAGING_PROJECT_ID: 'rocha-stage',
  }), 'rocha-stage');
});
