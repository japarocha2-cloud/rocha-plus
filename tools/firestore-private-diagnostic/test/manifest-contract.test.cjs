'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

test('isolated Firebase manifest points only at the diagnostic codebase', () => {
  const config = JSON.parse(fs.readFileSync(path.join(root, 'firebase.json')));
  assert.deepEqual(config.functions.map(item => ({source: item.source, codebase: item.codebase})), [
    {source: '.', codebase: 'firestore-private-diagnostic'},
  ]);
  assert.deepEqual(config.functions[0].predeploy, [
    'node "$RESOURCE_DIR/validate-deploy-config.cjs" "$RESOURCE_DIR/deployment.review.json" "$RESOURCE_DIR/.env.rocha-plus-homologacao"',
    'npm --prefix "$RESOURCE_DIR" test',
    'npm --prefix "$RESOURCE_DIR" run check',
  ]);
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json')));
  assert.equal(packageJson.main, 'functions-firestore-diagnostic/index.js');
  assert.equal(packageJson.engines.node, '22');
});

test('generated endpoint remains private, bounded and tied to a reviewed runtime identity parameter', () => {
  const exported = require('../functions-firestore-diagnostic/index.js').firestoreReadIsolationDiagnostic;
  const endpoint = exported.__endpoint;
  assert.equal(endpoint.platform, 'gcfv2');
  assert.deepEqual(endpoint.region, ['southamerica-east1']);
  assert.deepEqual(endpoint.httpsTrigger.invoker, ['private']);
  assert.equal(endpoint.maxInstances, 1);
  assert.equal(endpoint.serviceAccountEmail.name, 'DIAGNOSTIC_RUNTIME_SERVICE_ACCOUNT');
});

test('predeploy validates configuration, not unobservable phase-2 isolation claims', () => {
  const validator = fs.readFileSync(path.join(root, 'validate-deploy-config.cjs'), 'utf8');
  assert.doesNotMatch(validator, /runtimeNamedDatabaseAccessReviewed/);
  assert.doesNotMatch(validator, /runtimeDefaultDatabaseDeniedReviewed/);
});
