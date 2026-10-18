// Automated fixtures only: no physical TV, video decoder or live channel.
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';
import 'package:rocha_plus/src/billing/billing_repository.dart';

class TimedAccessFixture implements BillingRepository {
  Duration elapsed = Duration.zero;
  final Duration deadline;
  final String state;
  int requests = 0;
  TimedAccessFixture(this.state, this.deadline);
  @override
  Future<BillingAccess> status() async {
    requests++;
    final remaining = deadline - elapsed;
    return BillingAccess(active: remaining > Duration.zero,
      state: remaining > Duration.zero ? state : 'expired',
      remaining: remaining > Duration.zero ? remaining : Duration.zero,
      trialRemainingDays: remaining > Duration.zero ? 1 : 0,
      trialWelcomeNoticeAccepted: true);
  }
  @override
  Future<bool> claimTrialWelcomeNotice() async => false;
  @override
  Future<Uri> checkout(String plan) => throw StateError('No checkout in endurance fixtures');
}

void main() {
  for (final state in ['trial', 'paid']) {
    testWidgets('30 virtual minutes: $state remains allowed through every refresh', (tester) async {
      final repository = TimedAccessFixture(state, const Duration(days: 1));
      final controller = BillingController(repository);
      await controller.initialize();
      for (var minute = 1; minute <= 30; minute++) {
        repository.elapsed = Duration(minutes: minute);
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
        expect(controller.allowed, isTrue, reason: '$state at virtual minute $minute');
        expect(controller.error, isNull);
      }
      expect(repository.requests, greaterThanOrEqualTo(31));
      controller.dispose();
      await tester.pump();
    });
  }

  testWidgets('virtual server deadline closes access and never creates a new trial', (tester) async {
    final repository = TimedAccessFixture('trial', const Duration(minutes: 10));
    final controller = BillingController(repository);
    await controller.initialize();
    for (var minute = 1; minute <= 12; minute++) {
      repository.elapsed = Duration(minutes: minute);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(controller.allowed, minute < 10, reason: 'virtual minute $minute');
    }
    expect(controller.access!.state, 'expired');
    controller.dispose();
    await tester.pump();
  });

}
