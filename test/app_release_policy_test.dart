import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/app_release_policy.dart';

void main() {
  test('beta stays free unless subscription experiment is explicitly enabled', () {
    const experiment = bool.fromEnvironment('ROCHA_EXPERIMENTAL_SUBSCRIPTIONS');
    const commercial = bool.fromEnvironment('ROCHA_COMMERCIAL_RELEASE');
    expect(RochaReleasePolicy.commercialRelease, commercial);
    expect(RochaReleasePolicy.stage,
        commercial ? RochaReleaseStage.official : RochaReleaseStage.beta);
    expect(RochaReleasePolicy.loginRequired, isTrue);
    expect(RochaReleasePolicy.paidSubscriptionRequired, experiment || commercial);
    expect(RochaReleasePolicy.betaAccessIsFree, !(experiment || commercial));
  });
}
