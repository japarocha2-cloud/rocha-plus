import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';

// Design only. verifyAccess is simulated; no checkout is opened.
Future<void> pumpScreen(WidgetTester tester, {String? uid = 'A', Size size = const Size(412, 915)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final now = DateTime.now().toUtc();
  await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
    accountUid: uid,
    verifyAccess: (u) async => SubscriptionAccessResult.fromPayload({
      'uid': u, 'allowed': true, 'reason': 'trial',
      'expiresAtMs': now.add(const Duration(days: 6)).millisecondsSinceEpoch,
      'serverTimeMs': now.millisecondsSinceEpoch}, u),
  )));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all design sections are present, with real prices and server state', (tester) async {
    await pumpScreen(tester);
    for (final text in ['Estado da conta', 'Teste gratuito confirmado pelo servidor', 'Verificar acesso',
        'Plano Fundador Mensal', 'R\$ 7,90 por mês', 'Plano Fundador Anual', 'R\$ 86,90 por ano',
        'Recompensa pela fidelidade', 'Atualização futura — quando chegarem filmes e séries',
        'Assinantes fundadores', 'Novos assinantes após a expansão',
        'PREVISÃO FUTURA — INDISPONÍVEL PARA CONTRATAÇÃO', 'Resumo dos planos']) {
      await tester.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.textContaining('restantes'), findsOneWidget);
    expect(find.textContaining('R\$ 15,50'), findsWidgets);
    expect(find.textContaining('R\$ 170,50'), findsWidgets);
  });

  testWidgets('only the two existing Mercado Pago buttons; future cards have no button or link', (tester) async {
    await pumpScreen(tester);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('subscription-summary')), 300, scrollable: scroll);
    expect(find.widgetWithText(FilledButton, 'Assinar com Mercado Pago', skipOffstage: false), findsNWidgets(2));
    for (final key in ['future-founders', 'future-new-subscribers']) {
      final card = find.byKey(ValueKey(key));
      expect(find.descendant(of: card, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton || w is InkWell || w is GestureDetector)), findsNothing, reason: key);
    }
    expect(find.textContaining('vitalíc'), findsNothing, reason: 'no lifetime-price promise');
  });

  testWidgets('purchase buttons stay disabled without an account (callbacks unchanged)', (tester) async {
    await pumpScreen(tester, uid: null);
    final buttons = tester.widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Assinar com Mercado Pago', skipOffstage: false));
    expect(buttons, hasLength(2));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('with an account both purchase buttons are enabled (not pressed: no checkout)', (tester) async {
    await pumpScreen(tester);
    final buttons = tester.widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Assinar com Mercado Pago', skipOffstage: false));
    expect(buttons.every((b) => b.onPressed != null), isTrue);
  });

  for (final size in [const Size(320, 568), const Size(412, 915), const Size(1280, 720)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpScreen(tester, size: size);
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('subscription-summary')), 300, scrollable: scroll);
      expect(tester.takeException(), isNull);
    });
  }
}
