import 'package:flutter/material.dart';
import 'src/billing/billing_repository.dart';
import 'src/billing/subscription_gate.dart';
import 'src/theme/rocha_theme.dart';

/// Isolated laboratory build. No live Firebase trial or payments.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RochaTrialLaboratory());
}

class RochaTrialLaboratory extends StatefulWidget {
  const RochaTrialLaboratory({super.key});
  @override
  State<RochaTrialLaboratory> createState() => _RochaTrialLaboratoryState();
}

class _RochaTrialLaboratoryState extends State<RochaTrialLaboratory> {
  final BillingRepository billing = TwoMinuteLaboratoryBilling();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rocha+ Laboratório',
    theme: RochaTheme.dark,
    debugShowCheckedModeBanner: false,
    home: SubscriptionGate(
      uid: 'laboratory-only',
      repository: billing,
      onSignOut: () async {},
    ),
  );
}

/// Exercises the real SubscriptionGate with a two-minute local entitlement.
/// The simulated user is never authenticated against production Firebase.
class TwoMinuteLaboratoryBilling implements BillingRepository {
  final DateTime startedAt = DateTime.now();
  @override
  Future<BillingAccess> status() async {
    final remaining = const Duration(minutes: 2) -
        DateTime.now().difference(startedAt);
    final active = remaining > Duration.zero;
    return BillingAccess(
      active: active,
      state: active ? 'trial' : 'expired',
      remaining: active ? remaining : Duration.zero,
      trialRemainingDays: active ? 1 : 0,
      trialWelcomeNoticeAccepted: true,
      expiresAt: active ? startedAt.add(const Duration(minutes: 2)) : null,
    );
  }
  @override
  Future<bool> claimTrialWelcomeNotice() async => false;
  @override
  Future<Uri> checkout(String plan) async =>
      throw const BillingFailure(
        'Ambiente de laboratório: pagamentos desativados.');
}
