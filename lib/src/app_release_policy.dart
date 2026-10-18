enum RochaReleaseStage { beta, official }

class RochaReleasePolicy {
  const RochaReleasePolicy._();

  // The commercial branch grants access only through server-confirmed trial or payment.
  static const RochaReleaseStage stage = RochaReleaseStage.official;

  static bool get loginRequired => true;
  static bool get paidSubscriptionRequired =>
      stage == RochaReleaseStage.official;
  static bool get betaAccessIsFree =>
      stage == RochaReleaseStage.beta && !paidSubscriptionRequired;
}
