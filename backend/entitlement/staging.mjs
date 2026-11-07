export function assertStagingProject(env) {
  const project = env.GOOGLE_CLOUD_PROJECT;
  if (!project || project === 'rocha-plus' ||
      !env.ROCHA_STAGING_PROJECT_ID ||
      project !== env.ROCHA_STAGING_PROJECT_ID) {
    throw new Error('Experimental entitlement requires a distinct, matching staging Firebase project');
  }
  return project;
}
