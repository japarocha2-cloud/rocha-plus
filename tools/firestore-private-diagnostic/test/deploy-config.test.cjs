'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {validateDeploymentConfig, validateRuntimeEnvironment} = require('../validate-deploy-config.cjs');

function validConfig() {
  return {
    projectId: 'rocha-plus-homologacao',
    region: 'southamerica-east1',
    functionName: 'firestoreReadIsolationDiagnostic',
    codebase: 'firestore-private-diagnostic',
    databaseId: 'rocha-payments-test',
    audience: 'https://firestorereadisolationdiagnostic-example.a.run.app',
    callerServiceAccount: 'diagnostic-caller@rocha-plus-homologacao.iam.gserviceaccount.com',
    runtimeServiceAccount: 'diagnostic-runtime@rocha-plus-homologacao.iam.gserviceaccount.com',
    invokerPrincipal: 'serviceAccount:diagnostic-caller@rocha-plus-homologacao.iam.gserviceaccount.com',
    allowUnauthenticated: false,
    runtimeNamedDatabaseAccessReviewed: true,
    runtimeDefaultDatabaseDeniedReviewed: true,
  };
}

test('accepts an exact, private and fully reviewed isolated deployment configuration', () => {
  assert.equal(validateDeploymentConfig(validConfig()).databaseId, 'rocha-payments-test');
});

for (const [label, change] of [
  ['public access', {allowUnauthenticated: true}],
  ['wrong database', {databaseId: '(default)'}],
  ['unreviewed named access', {runtimeNamedDatabaseAccessReviewed: false}],
  ['unreviewed default denial', {runtimeDefaultDatabaseDeniedReviewed: false}],
  ['non-Google audience', {audience: 'https://example.com'}],
  ['audience query', {audience: 'https://example.a.run.app?token=secret'}],
]) {
  test(`rejects ${label}`, () => {
    assert.throws(() => validateDeploymentConfig({...validConfig(), ...change}), /rejected/);
  });
}

test('rejects reuse of the runtime identity as the caller', () => {
  const config = validConfig();
  config.callerServiceAccount = config.runtimeServiceAccount;
  config.invokerPrincipal = `serviceAccount:${config.runtimeServiceAccount}`;
  assert.throws(() => validateDeploymentConfig(config), /distinct/);
});

test('runtime environment must match the reviewed audience and identities exactly', () => {
  const config = validConfig();
  const content = [
    `DIAGNOSTIC_AUDIENCE=${config.audience}`,
    `DIAGNOSTIC_CALLER_EMAIL=${config.callerServiceAccount}`,
    `DIAGNOSTIC_RUNTIME_SERVICE_ACCOUNT=${config.runtimeServiceAccount}`,
    '',
  ].join('\n');
  assert.equal(validateRuntimeEnvironment(content, config).DIAGNOSTIC_AUDIENCE, config.audience);
  assert.throws(() => validateRuntimeEnvironment(content.replace(config.audience,
    'https://other.a.run.app'), config), /does not match/);
});

test('runtime environment rejects extra fields', () => {
  const config = validConfig();
  const content = [
    `DIAGNOSTIC_AUDIENCE=${config.audience}`,
    `DIAGNOSTIC_CALLER_EMAIL=${config.callerServiceAccount}`,
    `DIAGNOSTIC_RUNTIME_SERVICE_ACCOUNT=${config.runtimeServiceAccount}`,
    'UNEXPECTED=value',
  ].join('\n');
  assert.throws(() => validateRuntimeEnvironment(content, config), /exactly/);
});
