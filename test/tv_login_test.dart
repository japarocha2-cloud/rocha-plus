import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';
import 'auth_test.dart' as fixtures;

void main() {
  late fixtures.FakeAuth repository;
  late AuthController controller;
  setUp(() {
    repository = fixtures.FakeAuth();
    controller = AuthController(repository);
  });
  tearDown(() async {
    controller.dispose();
    await repository.changes.close();
  });

  for (final size in [const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('TV login accepts remote OK at $size and awaits verified session',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await fixtures.initialize(controller);
      await tester.pumpWidget(MaterialApp(theme: RochaTheme.dark,
        home: MediaQuery(data: MediaQueryData(size: size,
          textScaler: TextScaler.linear(1.3)), child: LoginScreen(controller: controller))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tv-login-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('tv-login-background')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(repository.attempts, 1);
      expect(controller.account, isNull);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byKey(const ValueKey('layout-preview-button')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repository.attempts, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV offers initialization retry without granting guest access', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    repository.initializationFailure = const LoginFailure('Sem conexão');
    await fixtures.initialize(controller);
    await tester.pumpWidget(MaterialApp(theme: RochaTheme.dark,
      home: LoginScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-login-button')), findsOneWidget);
    repository.initializationFailure = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(controller.ready, isTrue);
    expect(controller.error, isNull);
    expect(controller.account, isNull);
    expect(find.byKey(const ValueKey('retry-login-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
