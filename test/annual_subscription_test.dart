import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';
import 'package:rocha_plus/src/billing/subscription_screen.dart';
import 'package:rocha_plus/src/billing/subscription_documents.dart';
void main() {
  test('annual backend entitlement restores period and expires without granting from UI', () async {
    final controller = BillingController('tester', beta: false, transport: (action, {token}) async => {
      'active': true, 'state': 'SUBSCRIPTION_STATE_CANCELED', 'basePlanId': 'yearly',
      'expiresAt': DateTime.now().millisecondsSinceEpoch + 60000, 'autoRenewing': false,
    });
    await controller.refresh();
    expect(controller.allowed, isTrue); expect(controller.basePlanId, 'yearly');
    expect(controller.autoRenewing, isFalse);
    controller.apply({'active': false, 'state': 'SUBSCRIPTION_STATE_EXPIRED', 'expiresAt': 1, 'basePlanId': 'yearly'});
    expect(controller.allowed, isFalse); controller.dispose();
  });
  testWidgets('founder prices and drafts fit narrow screen with large text; beta has no purchases', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = BillingController('tester');
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!),
      home: SubscriptionScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('Fundador mensal: R\$ 4,90/mês'), findsOneWidget);
    expect(find.text('Fundador anual: R\$ 53,90 por 12 meses'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing); expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Central de Ajuda'), 250);
    await tester.tap(find.text('Central de Ajuda')); await tester.pumpAndSettle();
    expect(find.byType(SubscriptionDocumentScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cancelar'); await tester.pumpAndSettle();
    expect(find.textContaining('Se eu cancelar'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzzzz'); await tester.pumpAndSettle();
    expect(find.text('Nenhuma resposta encontrada.'), findsOneWidget);
    await tester.pageBack(); await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); controller.dispose();
  });
  testWidgets('all legal documents load offline', (tester) async {
    for (final document in subscriptionDocuments.where((d) => !d.searchable)) {
      await tester.pumpWidget(MaterialApp(home: SubscriptionDocumentScreen(key: ValueKey(document.asset), document: document)));
      await tester.pumpAndSettle();
      expect(find.text('Documento indisponível. Tente novamente.'), findsNothing);
      expect(find.byType(SelectableText), findsWidgets); expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
