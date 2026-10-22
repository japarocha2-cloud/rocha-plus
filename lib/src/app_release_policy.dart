enum RochaReleaseStage { beta, official }

class RochaReleasePolicy {
  const RochaReleasePolicy._();

  // During beta, authenticated testers have full access without a paid plan.
  // Commercial subscription enforcement is reserved for the official release.
  static const RochaReleaseStage stage = RochaReleaseStage.beta;
  // Explicit opt-in for an isolated signed subscription experiment only.
  static const experimentalSubscriptionEnforcement =
      bool.fromEnvironment('ROCHA_EXPERIMENTAL_SUBSCRIPTIONS');

  static bool get loginRequired => true;
  static bool get paidSubscriptionRequired =>
      stage == RochaReleaseStage.official || experimentalSubscriptionEnforcement;
  static bool get betaAccessIsFree =>
      stage == RochaReleaseStage.beta && !paidSubscriptionRequired;
}
