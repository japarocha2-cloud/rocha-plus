import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';
import 'package:rocha_plus/src/billing/subscription_screen.dart';

void main() {
  test('commercial mode fails closed without a verified backend', () async {
    final controller = BillingController('tester', beta: false);
    expect(controller.allowed, false);
    await controller.refresh();
    expect(controller.allowed, false);
    expect(controller.error, isNotNull);
    controller.dispose();
  });
  test('beta never contacts the store or billing server', () async {
    final controller = BillingController('tester');
    await controller.initialize();
    await controller.restore();
    expect(controller.allowed, true);
    expect(controller.offers, isEmpty);
    expect(controller.accountId, isNull);
    controller.dispose();
  });
  testWidgets('beta explains price and eligibility without a purchase button', (tester) async {
    final controller = BillingController('tester');
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(controller: controller)));
    expect(find.text('Beta gratuito: sem cobrança e sem compra disponível.'), findsOneWidget);
    expect(find.text('Restaurar compras'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('verified access expires on a timer', (tester) async {
    final controller = BillingController('tester', beta: false);
    controller.apply({'active': true, 'state': 'SUBSCRIPTION_STATE_ACTIVE',
      'expiresAt': DateTime.now().millisecondsSinceEpoch + 1000, 'autoRenewing': true});
    expect(controller.active, true);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.active, false);
    expect(controller.allowed, false);
    expect(controller.state, 'SUBSCRIPTION_STATE_EXPIRED');
    controller.dispose();
  });
}

