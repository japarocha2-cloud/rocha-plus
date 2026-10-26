import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';

void main() {
  Future<void> openSubscription(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Preview mode avoids loading live channels and all network requests.
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(previewOnly: true, accountUid: 'test-only-uid'),
    ));
    await tester.pumpAndSettle();
    if (size.width < 900) {
      await tester.tap(find.byTooltip('Abrir menu'));
      await tester.pumpAndSettle();
    }
    final subscription = find.text('Assinatura');
    expect(subscription, findsOneWidget);
    await tester.ensureVisible(subscription);
    await tester.tap(subscription);
    await tester.pumpAndSettle();
    expect(find.text('Sua assinatura Rocha+'), findsOneWidget);
    expect(find.text('R\$ 4,50 por mês'), findsOneWidget);
    expect(find.text('R\$ 49,50 por ano'), findsOneWidget);
    expect(find.textContaining('Não pague novamente'), findsOneWidget);
    expect(find.textContaining('A contratação ainda não está disponível'), findsOneWidget);
    expect(find.textContaining('7 dias por conta'), findsOneWidget);
    expect(find.text('Verificar acesso'), findsNothing);
  }

  testWidgets('mobile drawer opens read-only subscription page',
      (tester) async => openSubscription(tester, const Size(430, 950)));

  testWidgets('wide/TV sidebar opens read-only subscription page',
      (tester) async => openSubscription(tester, const Size(1200, 950)));
}
