import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/app_release_policy.dart';

void main() {
  test('beta stays free unless subscription experiment is explicitly enabled', () {
    const experiment = bool.fromEnvironment('ROCHA_EXPERIMENTAL_SUBSCRIPTIONS');
    expect(RochaReleasePolicy.stage, RochaReleaseStage.beta);
    expect(RochaReleasePolicy.loginRequired, isTrue);
    expect(RochaReleasePolicy.paidSubscriptionRequired, experiment);
    expect(RochaReleasePolicy.betaAccessIsFree, !experiment);
  });
}
