import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:rocha_plus/src/billing/billing_repository.dart';
import 'package:rocha_plus/src/billing/commercial_config.dart';
import 'package:rocha_plus/src/billing/spark_billing_repository.dart';
import 'package:rocha_plus/src/billing/trial_welcome_dialog.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';

void main() {
  testWidgets('Asaas shows 5.50, retains annual, and cannot start a charge', (tester) async {
    expect(CommercialConfig.asaas, isTrue);
    var checkoutCalls = 0;
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      checkout: (_) async { checkoutCalls++; },
    )));
    expect(find.text(r'R$ 5,50'), findsOneWidget);
    expect(find.text(r'R$ 4,90'), findsNothing);
    expect(find.text(r'R$ 55,00'), findsOneWidget);
    expect(find.text('Assinaturas · Asaas'), findsOneWidget);
    expect(find.byKey(const ValueKey('asaas-setup-status')), findsOneWidget);
    for (final button in tester.widgetList<FilledButton>(find.byType(FilledButton))) {
      expect(button.onPressed, isNull);
    }
    expect(checkoutCalls, 0);
  });

  test('both repository paths reject checkout without any network requests', () async {
    final client = MockClient((_) async => throw StateError('Must not contact provider'));
    final repositories = <BillingRepository>[
      SparkBillingRepository(projectId: 'rocha-plus', accountId: '111',
        tokenProvider: () async => throw StateError('Must not request a token'), client: client),
      HttpBillingRepository(endpoint: 'https://example.invalid',
        tokenProvider: () async => throw StateError('Must not request a token'), client: client),
    ];
    for (final repository in repositories) {
      for (final plan in ['monthly', 'annual']) {
        await expectLater(repository.checkout(plan), throwsA(isA<BillingFailure>()
          .having((e) => e.message, 'message', CommercialConfig.setupMessage)));
      }
    }
  });

  testWidgets('trial artwork price and spoken price agree and acceptance works', (tester) async {
    tester.view.physicalSize = const Size(720, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    var accepted = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TrialWelcomeDialog(
      onAccepted: () => accepted = true,
    ))));
    await tester.pumpAndSettle();
    expect(find.text(r'Mensal R$ 5,50  •  Anual R$ 55,00'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Mensal R\$ 5,50')), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('asaas_trial_preview.png'));
    await tester.tap(find.byKey(const ValueKey('trial-welcome-accept')));
    expect(accepted, isTrue);
  });
}
