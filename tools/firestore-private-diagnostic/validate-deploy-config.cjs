'use strict';

const fs = require('node:fs');
const crypto = require('node:crypto');
const process = require('node:process');

const EXPECTED = Object.freeze({
  projectId: 'rocha-plus-homologacao',
  region: 'southamerica-east1',
  functionName: 'firestoreReadIsolationDiagnostic',
  codebase: 'firestore-private-diagnostic',
  databaseId: 'rocha-payments-test',
});
const BOOTSTRAP_AUDIENCE = 'urn:rocha-plus:firestore-private-diagnostic:bootstrap-deny-all';
const SERVICE_ACCOUNT = /^[a-z0-9][a-z0-9-]{4,28}[a-z0-9]@rocha-plus-homologacao\.iam\.gserviceaccount\.com$/;

function fail(message) {
  throw new Error(`deployment configuration rejected: ${message}`);
}

function exactServiceUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch (_) {
    fail('audience must be an absolute URL');
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    fail('audience must be a credential-free HTTPS URL without query or fragment');
  }
  if (!(url.hostname.endsWith('.run.app') || url.hostname.endsWith('.cloudfunctions.net'))) {
    fail('audience must be a Google-managed Cloud Run or Cloud Run functions URL');
  }
  if (value.endsWith('/')) fail('audience must not contain a trailing slash');
  return value;
}

function validateDeploymentConfig(config) {
  if (!config || typeof config !== 'object' || Array.isArray(config)) fail('JSON object required');
  const expectedKeys = new Set([
    ...Object.keys(EXPECTED), 'deploymentStage', 'audience', 'callerServiceAccount',
    'runtimeServiceAccount', 'invokerPrincipal', 'allowUnauthenticated',
  ]);
  for (const key of Object.keys(config)) if (!expectedKeys.has(key)) fail(`unknown field ${key}`);
  for (const [key, value] of Object.entries(EXPECTED)) {
    if (config[key] !== value) fail(`${key} must equal ${value}`);
  }
  if (!['bootstrap', 'verification'].includes(config.deploymentStage)) {
    fail('deploymentStage must be bootstrap or verification');
  }
  if (config.deploymentStage === 'bootstrap') {
    if (config.audience !== BOOTSTRAP_AUDIENCE) {
      fail('bootstrap must use the deny-all bootstrap audience');
    }
  } else {
    exactServiceUrl(config.audience);
  }
  if (!SERVICE_ACCOUNT.test(config.callerServiceAccount)) fail('caller service account is invalid');
  if (!SERVICE_ACCOUNT.test(config.runtimeServiceAccount)) fail('runtime service account is invalid');
  if (config.callerServiceAccount === config.runtimeServiceAccount) {
    fail('caller and runtime service accounts must be distinct');
  }
  if (config.invokerPrincipal !== `serviceAccount:${config.callerServiceAccount}`) {
    fail('invoker principal must be the reviewed caller service account');
  }
  if (config.allowUnauthenticated !== false) fail('public access must remain disabled');
  return Object.freeze({...config});
}

function validateRuntimeEnvironment(content, config) {
  const values = {};
  for (const original of content.split(/\r?\n/)) {
    const line = original.trim();
    if (!line || line.startsWith('#')) continue;
    const match = /^([A-Z][A-Z0-9_]*)=(\S+)$/.exec(line);
    if (!match) fail('runtime environment contains an invalid line');
    if (Object.hasOwn(values, match[1])) fail(`duplicate runtime environment field ${match[1]}`);
    values[match[1]] = match[2];
  }
  const expected = {
    DIAGNOSTIC_AUDIENCE: config.audience,
    DIAGNOSTIC_CALLER_EMAIL: config.callerServiceAccount,
    DIAGNOSTIC_RUNTIME_SERVICE_ACCOUNT: config.runtimeServiceAccount,
  };
  if (Object.keys(values).length !== Object.keys(expected).length) {
    fail('runtime environment must contain exactly the three diagnostic fields');
  }
  for (const [key, value] of Object.entries(expected)) {
    if (values[key] !== value) fail(`runtime environment ${key} does not match reviewed configuration`);
  }
  return Object.freeze({...values});
}

function main(argv) {
  if (argv.length !== 2) {
    fail('usage: node validate-deploy-config.cjs deployment.review.json .env.rocha-plus-homologacao');
  }
  const config = JSON.parse(fs.readFileSync(argv[0], 'utf8'));
  const valid = validateDeploymentConfig(config);
  validateRuntimeEnvironment(fs.readFileSync(argv[1], 'utf8'), valid);
  const configurationDigest = crypto.createHash('sha256')
    .update(JSON.stringify(valid, Object.keys(valid).sort()))
    .digest('hex');
  process.stdout.write(JSON.stringify({
    valid: true,
    deploymentStage: valid.deploymentStage,
    projectId: valid.projectId,
    functionName: valid.functionName,
    databaseId: valid.databaseId,
    configurationDigest,
  }) + '\n');
}

if (require.main === module) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}

module.exports = {BOOTSTRAP_AUDIENCE, validateDeploymentConfig, validateRuntimeEnvironment};
