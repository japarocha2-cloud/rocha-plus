enum RochaReleaseStage { beta, official }

class RochaReleasePolicy {
  const RochaReleasePolicy._();

  // During beta, authenticated testers have full access without a paid plan.
  // Commercial subscription enforcement is reserved for the official release.
  static const RochaReleaseStage stage = RochaReleaseStage.beta;

  static bool get loginRequired => true;
  static bool get paidSubscriptionRequired =>
      stage == RochaReleaseStage.official;
  static bool get betaAccessIsFree =>
      stage == RochaReleaseStage.beta && !paidSubscriptionRequired;
}
