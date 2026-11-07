import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(1920, 1080)]) {
    testWidgets('subscription is reachable from Home at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: RochaTheme.dark,
        home: const HomeScreen(previewOnly: true),
      ));
      if (size.width < 900) {
        tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        await tester.pumpAndSettle();
      }
      final menu = find.byKey(const ValueKey('official-sidebar'));
      await tester.scrollUntilVisible(find.text('Assinatura'), 200,
          scrollable: find.descendant(
              of: menu, matching: find.byType(Scrollable)).first);
      await tester.ensureVisible(find.text('Assinatura'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assinatura'));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.text('Assinatura ainda não verificada'), findsOneWidget);
      expect(find.text('Verificar acesso'), findsNothing);
      expect(find.text('Acesso confirmado pelo servidor'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  }

  testWidgets('plans do not offer payment or imply an active trial', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: RochaTheme.dark,
      home: const SubscriptionScreen(accountUid: 'test-account'),
    ));
    await tester.scrollUntilVisible(find.text('R\$ 49,50 por ano'), 200);
    expect(find.text('R\$ 4,50 por mês'), findsOneWidget);
    expect(find.text('R\$ 49,50 por ano'), findsOneWidget);
    expect(find.textContaining('bloqueio ainda está em homologação'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
