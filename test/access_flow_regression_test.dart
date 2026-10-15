import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/billing/billing_repository.dart';
import 'package:rocha_plus/src/billing/subscription_gate.dart';
import 'package:rocha_plus/src/billing/trial_welcome_dialog.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';

BillingAccess grant({String state = 'trial', bool accepted = true,
    Duration remaining = const Duration(days: 3)}) => BillingAccess(
  active: state != 'expired', state: state,
  remaining: state == 'expired' ? Duration.zero : remaining,
  trialRemainingDays: state == 'trial' ? 3 : 0,
  trialWelcomeNoticeAccepted: accepted);

class ControlledBilling implements BillingRepository {
  final List<Completer<BillingAccess>> requests = [];
  BillingAccess? response;
  int claims = 0;
  Completer<bool>? acceptanceGate;
  @override
  Future<BillingAccess> status() {
    if (response != null) return Future.value(response);
    final request = Completer<BillingAccess>();
    requests.add(request);
    return request.future;
  }
  @override
  Future<bool> claimTrialWelcomeNotice() async {
    claims++;
    return acceptanceGate == null ? true : await acceptanceGate!.future;
  }
  @override
  Future<Uri> checkout(String plan) => throw StateError('No checkout in access tests');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Widget gate(String uid, ControlledBilling repository) => MaterialApp(
    home: SubscriptionGate(uid: uid, repository: repository, onSignOut: () async {}));
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  void noCheckoutOrHome() {
    expect(find.byType(SubscriptionScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byKey(const ValueKey('access-verification')), findsOneWidget);
  }
  testWidgets('slow first login stays neutral then welcome precedes Home', (tester) async {
    final r = ControlledBilling();
    await tester.pumpWidget(gate('new', r));
    await tester.pump(const Duration(seconds: 4));
    noCheckoutOrHome();
    r.requests.single.complete(grant(accepted: false));
    await settle(tester);
    expect(find.byType(TrialWelcomeDialog), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SubscriptionScreen), findsNothing);
    tester.widget<TrialWelcomeDialog>(find.byType(TrialWelcomeDialog)).onAccepted!();
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(r.claims, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('trial Home waits for server acceptance and retries without repeating notice', (tester) async {
    final r = ControlledBilling()..response = grant(accepted: false)
      ..acceptanceGate = Completer<bool>();
    await tester.pumpWidget(gate('A', r));
    await settle(tester);
    tester.widget<TrialWelcomeDialog>(find.byType(TrialWelcomeDialog)).onAccepted!();
    await settle(tester);
    noCheckoutOrHome();
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    r.acceptanceGate!.completeError(const BillingFailure('Offline'));
    await settle(tester);
    noCheckoutOrHome();
    r.acceptanceGate = Completer<bool>();
    await tester.tap(find.text('Tentar novamente'));
    await settle(tester);
    noCheckoutOrHome();
    r.acceptanceGate!.complete(true);
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final state in ['trial', 'paid', 'expired']) {
    testWidgets('restored $state session resolves before choosing screen', (tester) async {
      final r = ControlledBilling();
      await tester.pumpWidget(gate('restored', r));
      noCheckoutOrHome();
      r.requests.single.complete(grant(state: state));
      await settle(tester);
      expect(find.byType(TrialWelcomeDialog), findsNothing);
      expect(find.byType(HomeScreen), state == 'expired' ? findsNothing : findsOneWidget);
      expect(find.byType(SubscriptionScreen), state == 'expired' ? findsOneWidget : findsNothing);
      if (state == 'expired') {
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.byType(HomeScreen), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('failed server lookup is neutral with retry, never checkout', (tester) async {
    final r = ControlledBilling();
    await tester.pumpWidget(gate('A', r));
    r.requests.single.completeError(const BillingFailure('Sem conexão'));
    await settle(tester);
    noCheckoutOrHome();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    noCheckoutOrHome();
    r.requests.last.complete(grant(state: 'paid'));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late account A response cannot grant B access on same gate', (tester) async {
    final a = ControlledBilling(), b = ControlledBilling();
    await tester.pumpWidget(gate('A', a));
    await tester.pumpWidget(gate('B', b));
    a.requests.single.complete(grant(state: 'paid'));
    await settle(tester);
    noCheckoutOrHome();
    b.requests.single.complete(grant(state: 'expired'));
    await settle(tester);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('switching accounts removes private player route immediately', (tester) async {
    final a = ControlledBilling()..response = grant(state: 'paid');
    final b = ControlledBilling();
    await tester.pumpWidget(gate('A', a));
    await settle(tester);
    Navigator.of(tester.element(find.byType(HomeScreen))).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Private player'))));
    await settle(tester);
    expect(find.text('Private player'), findsOneWidget);
    await tester.pumpWidget(gate('B', b));
    await settle(tester);
    expect(find.text('Private player'), findsNothing);
    noCheckoutOrHome();
    b.requests.single.complete(grant(state: 'expired'));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sign-out during welcome cannot leave a dialog over next account', (tester) async {
    final a = ControlledBilling()..response = grant(accepted: false);
    final b = ControlledBilling();
    await tester.pumpWidget(gate('A', a));
    await settle(tester);
    expect(find.byType(TrialWelcomeDialog), findsOneWidget);
    await tester.pumpWidget(gate('B', b));
    await settle(tester);
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    noCheckoutOrHome();
    b.requests.single.complete(grant(state: 'expired'));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reinstall with empty local preferences respects server acceptance', (tester) async {
    final r = ControlledBilling()..response = grant();
    await tester.pumpWidget(gate('A', r));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(gate('A', r));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TrialWelcomeDialog), findsNothing);
    expect(r.claims, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reopening expired account does not recover Home or trial notice', (tester) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final r = ControlledBilling()..response = grant(state: 'expired');
      await tester.pumpWidget(gate('A', r));
      await settle(tester);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(TrialWelcomeDialog), findsNothing);
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('resume refresh removes nested player when expired', (tester) async {
    final r = ControlledBilling()..response = grant(state: 'paid');
    await tester.pumpWidget(gate('A', r));
    await settle(tester);
    Navigator.of(tester.element(find.byType(HomeScreen))).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Private player'))));
    await settle(tester);
    r.response = grant(state: 'expired');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('Private player'), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
