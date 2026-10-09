import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/caze_tv_screen.dart';
import 'package:rocha_plus/src/sports/caze_tv_source.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  Future<void> showScreen(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: RochaTheme.dark,
      home: const CazeTvScreen(),
    ));
    await tester.pump();
  }

  testWidgets('approved CazéTV hero, official player and gold CTA on phone',
      (tester) async {
    await showScreen(tester, const Size(390, 844));
    expect(find.byKey(const ValueKey('cazetv-approved-hero')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('cazetv-player-panel')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('cazetv-watch-official')),
      findsOneWidget);
    expect(find.text('CazéTV'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cazetv-watch-official')));
    if (CazeTvSource.officialVideoId == null) {
      expect(button.onPressed, isNull);
      expect(find.text('Transmissão não configurada'), findsOneWidget);
      expect(find.text('Nenhuma transmissão oficial configurada'),
        findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV-width layout includes non-interactive planned categories',
      (tester) async {
    await showScreen(tester, const Size(1280, 720));
    expect(find.byKey(const ValueKey('cazetv-content-categories')),
      findsOneWidget);
    expect(find.text('Conteúdo da CazéTV'), findsOneWidget);
    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Melhores momentos'), findsOneWidget);
    expect(find.text('Programas'), findsOneWidget);
    expect(find.text('Cortes'), findsOneWidget);
    expect(find.byKey(const ValueKey('cazetv-retry')), findsOneWidget);
    if (CazeTvSource.officialVideoId == null) {
      final retry = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('cazetv-retry')));
      expect(retry.onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
  });
}
