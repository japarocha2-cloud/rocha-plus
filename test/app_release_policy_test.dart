import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/app_release_policy.dart';

void main() {
  test('beta requires login but never a paid subscription', () {
    expect(RochaReleasePolicy.stage, RochaReleaseStage.beta);
    expect(RochaReleasePolicy.loginRequired, isTrue);
    expect(RochaReleasePolicy.paidSubscriptionRequired, isFalse);
    expect(RochaReleasePolicy.betaAccessIsFree, isTrue);
  });
}
