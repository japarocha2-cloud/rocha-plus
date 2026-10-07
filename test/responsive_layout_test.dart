import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932),
      const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('Home and login fit phone/TV viewport $size with enlarged text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app(Widget child) => MaterialApp(
        theme: RochaTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)),
          child: child,
        ),
      );
      await tester.pumpWidget(app(const HomeScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('category-Infantil')), 200,
        scrollable: find.descendant(of: find.byKey(const ValueKey('home-scroll')),
          matching: find.byType(Scrollable)).first);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Explorar canais gratuitos'), 150);
      expect(find.text('Explorar canais gratuitos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
