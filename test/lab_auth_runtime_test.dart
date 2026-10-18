import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/app.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';
import 'auth_test.dart' show FakeAuth;

const authenticatedLab = bool.fromEnvironment('ROCHA_LAB_TEST') &&
    bool.fromEnvironment('ROCHA_LAB_REQUIRE_LOGIN', defaultValue: true);

void main() {
  late FakeAuth repository;
  late AuthController controller;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    repository = FakeAuth();
    controller = AuthController(repository);
  });
  tearDown(() async {
    controller.dispose();
    await repository.changes.close();
  });
  Future<void> showApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() => ChannelRepository().loadBrazilPublicDirectory());
    await tester.pumpWidget(RochaPlusApp(authController: controller));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    // Check route/session transitions without waiting for unrelated asset I/O
    // under the widget test's fake clock (Home rendering is tested separately).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  Future<void> settleHome(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    // Check route/session transitions without waiting for unrelated asset I/O
    // under the widget test's fake clock (Home rendering is tested separately).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  testWidgets('lab requires a confirmed session; popup completion alone grants no access', (tester) async {
    await showApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Visualizar layout de teste'), findsNothing);
    await tester.tap(find.text('Entrar com Google'));
    // Check route/session transitions without waiting for unrelated asset I/O
    // under the widget test's fake clock (Home rendering is tested separately).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.attempts, 1);
    expect(find.byType(HomeScreen), findsNothing);
    repository.changes.add(const AuthAccount(uid: 'verified-lab-user'));
    await settleHome(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).accountId, 'verified-lab-user');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !authenticatedLab);
  testWidgets('lab initialization failure stays on login without local bypass', (tester) async {
    repository.initializationFailure = const LoginFailure('Configuração ausente');
    await showApp(tester);
    expect(find.text('Configuração ausente'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(controller.ready, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !authenticatedLab);
  testWidgets('expired lab session clears player routes and switching account changes Home UID', (tester) async {
    repository.initial = const AuthAccount(uid: 'A');
    await showApp(tester);
    await settleHome(tester);
    final home = find.byType(HomeScreen);
    expect(home, findsOneWidget);
    unawaited(Navigator.of(tester.element(home)).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Private player route')))));
    // Check route/session transitions without waiting for unrelated asset I/O
    // under the widget test's fake clock (Home rendering is tested separately).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    repository.changes.add(null);
    // Check route/session transitions without waiting for unrelated asset I/O
    // under the widget test's fake clock (Home rendering is tested separately).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Private player route'), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    repository.changes.add(const AuthAccount(uid: 'B'));
    await settleHome(tester);
    expect(tester.widget<HomeScreen>(find.byType(HomeScreen)).accountId, 'B');
    await tester.widget<HomeScreen>(find.byType(HomeScreen)).onSignOut!();
    // Check route/session transitions without waiting for unrelated asset I/O
    // under the widget test's fake clock (Home rendering is tested separately).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !authenticatedLab);
}
