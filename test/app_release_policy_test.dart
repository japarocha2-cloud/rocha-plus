import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/app_release_policy.dart';

void main() {
  test('commercial release requires server-controlled subscription access', () {
    expect(RochaReleasePolicy.stage, RochaReleaseStage.official);
    expect(RochaReleasePolicy.loginRequired, isTrue);
    expect(RochaReleasePolicy.paidSubscriptionRequired, isTrue);
    expect(RochaReleasePolicy.betaAccessIsFree, isFalse);
  });
}
