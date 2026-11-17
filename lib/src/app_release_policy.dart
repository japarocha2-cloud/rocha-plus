enum RochaReleaseStage { beta, official }

class RochaReleasePolicy {
  const RochaReleasePolicy._();

  // During beta, authenticated testers have full access without a paid plan.
  // Commercial subscription enforcement is reserved for the official release,
  // selected only by the explicit build flag below. The build tooling
  // (tools/commercial_release_config.py) refuses this flag unless the
  // production entitlement and checkout endpoints are configured too.
  static const commercialRelease = bool.fromEnvironment('ROCHA_COMMERCIAL_RELEASE');
  static const RochaReleaseStage stage =
      commercialRelease ? RochaReleaseStage.official : RochaReleaseStage.beta;
  // Explicit opt-in for an isolated signed subscription experiment only.
  static const experimentalSubscriptionEnforcement =
      bool.fromEnvironment('ROCHA_EXPERIMENTAL_SUBSCRIPTIONS');

  static bool get loginRequired => true;
  static bool get paidSubscriptionRequired =>
      stage == RochaReleaseStage.official || experimentalSubscriptionEnforcement;
  static bool get betaAccessIsFree =>
      stage == RochaReleaseStage.beta && !paidSubscriptionRequired;
}
