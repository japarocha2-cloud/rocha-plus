'use strict';
// Live payments are always required in production. Mercado Pago SANDBOX payments
// (live_mode=false) are accepted only when ROCHA_PAYMENT_MODE=sandbox AND the
// function runs in the homologation project or a local demo-* emulator project.
const PRODUCTION_PROJECT = 'rocha-plus';
const SANDBOX_PROJECTS = new Set(['rocha-plus-homologacao']);

function runningProject(env) {
  return env.GCLOUD_PROJECT || env.GOOGLE_CLOUD_PROJECT || '';
}
function sandboxPaymentsAllowed(env = process.env) {
  const project = runningProject(env);
  if (env.ROCHA_PAYMENT_MODE !== 'sandbox' || project === PRODUCTION_PROJECT) return false;
  return SANDBOX_PROJECTS.has(project) || /^demo-[a-z0-9-]+$/.test(project);
}
function acceptedPaymentMode(liveMode, env = process.env) {
  return liveMode === true || (liveMode === false && sandboxPaymentsAllowed(env));
}
module.exports = {acceptedPaymentMode, sandboxPaymentsAllowed};
