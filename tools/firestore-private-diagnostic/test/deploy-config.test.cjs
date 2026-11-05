'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  BOOTSTRAP_AUDIENCE,
  validateDeploymentConfig,
  validateRuntimeEnvironment,
} = require('../validate-deploy-config.cjs');

function validConfig() {
  return {
    projectId: 'rocha-plus-homologacao',
    region: 'southamerica-east1',
    functionName: 'firestoreReadIsolationDiagnostic',
    codebase: 'firestore-private-diagnostic',
    databaseId: 'rocha-payments-test',
    deploymentStage: 'verification',
    audience: 'https://firestorereadisolationdiagnostic-example.a.run.app',
    callerServiceAccount: 'diagnostic-caller@rocha-plus-homologacao.iam.gserviceaccount.com',
    runtimeServiceAccount: 'diagnostic-runtime@rocha-plus-homologacao.iam.gserviceaccount.com',
    invokerPrincipal: 'serviceAccount:diagnostic-caller@rocha-plus-homologacao.iam.gserviceaccount.com',
    allowUnauthenticated: false,
  };
}

test('accepts an exact, private verification-stage deployment configuration', () => {
  assert.equal(validateDeploymentConfig(validConfig()).databaseId, 'rocha-payments-test');
});

test('accepts a fail-closed bootstrap before the definitive service URL exists', () => {
  const config = {...validConfig(), deploymentStage: 'bootstrap', audience: BOOTSTRAP_AUDIENCE};
  const valid = validateDeploymentConfig(config);
  const environment = [
    `DIAGNOSTIC_AUDIENCE=${BOOTSTRAP_AUDIENCE}`,
    `DIAGNOSTIC_CALLER_EMAIL=${config.callerServiceAccount}`,
    `DIAGNOSTIC_RUNTIME_SERVICE_ACCOUNT=${config.runtimeServiceAccount}`,
  ].join('\n');
  assert.equal(validateRuntimeEnvironment(environment, valid).DIAGNOSTIC_AUDIENCE,
    BOOTSTRAP_AUDIENCE);
});

for (const [label, change] of [
  ['public access', {allowUnauthenticated: true}],
  ['wrong database', {databaseId: '(default)'}],
  ['non-Google audience', {audience: 'https://example.com'}],
  ['audience query', {audience: 'https://example.a.run.app?token=secret'}],
  ['unknown deployment stage', {deploymentStage: 'ready'}],
  ['service URL during bootstrap', {deploymentStage: 'bootstrap'}],
  ['bootstrap sentinel during verification', {audience: BOOTSTRAP_AUDIENCE}],
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
