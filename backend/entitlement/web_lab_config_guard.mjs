// Pure laboratory guard for a future Rocha+ Web configuration.
// Never imports production site config, initializes Firebase, or makes HTTP requests.
export const LAB_PROJECT = 'rocha-plus-homologacao';
export function validateLabWebConfig(config, { subscriptionLab = false, entitlementUrl = '' } = {}) {
  const fail = () => { throw new Error('rocha-web-lab-config-rejected'); };
  if (!config || typeof config !== 'object' || Array.isArray(config)) fail();
  const { projectId, authDomain, appId, apiKey } = config;
  if (projectId !== LAB_PROJECT || authDomain !== LAB_PROJECT + '.firebaseapp.com' ||
      typeof appId !== 'string' || !/^1:[0-9]+:web:[0-9a-f]+$/.test(appId) ||
      typeof apiKey !== 'string' || !/^AIza[0-9A-Za-z_-]{20,}$/.test(apiKey)) fail();
  if (subscriptionLab !== false || entitlementUrl !== '') fail();
  // This guard does not certify origin domains, IAM, or that credentials belong to this project.
  return Object.freeze({ projectId: LAB_PROJECT, subscriptionLab: false,
    entitlementUrl: '', paymentLinksEnabled: false, checkoutEnabled: false,
    productionWritesEnabled: false, validatedFormatOnly: true });
}
