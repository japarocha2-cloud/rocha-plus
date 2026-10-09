import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/app.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';

class FakeAuth extends AuthRepository {
  final changes = StreamController<AuthAccount?>.broadcast();
  AuthAccount? initial;
  LoginFailure? initializationFailure;
  LoginFailure? signInFailure;
  bool logoutFails = false;
  LoginFailure? deletionFailure;
  int deletions = 0;
  int attempts = 0;
  Completer<void>? gate;
  @override
  Future<void> initialize() async {
    if (initializationFailure != null) throw initializationFailure!;
  }
  @override
  Stream<AuthAccount?> get accountChanges async* {
    yield initial;
    yield* changes.stream;
  }
  @override
  bool supports(LoginProvider provider) => true;
  @override
  Future<void> signIn(LoginProvider provider) async {
    attempts++;
    if (gate != null) await gate!.future;
    if (signInFailure != null) throw signInFailure!;
  }
  @override
  Future<void> deleteAccount() async {
    deletions++;
    if (gate != null) await gate!.future;
    if (deletionFailure != null) throw deletionFailure!;
    changes.add(null);
  }
  @override
  Future<void> signOut() async {
    if (logoutFails) throw StateError('network');
    changes.add(null);
  }
}

Future<void> initialize(AuthController controller) async {
  await controller.initialize();
  await Future<void>.value();
}

void main() {
  late FakeAuth repository;
  late AuthController controller;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeAuth();
    controller = AuthController(repository);
  });
  tearDown(() async {
    controller.dispose();
    await repository.changes.close();
  });

  test('missing configuration fails closed', () async {
    repository.initializationFailure = const LoginFailure('Login indisponível');
    await controller.initialize();
    expect(controller.account, isNull);
    expect(controller.ready, isFalse);
    expect(controller.initializing, isFalse);
    expect(controller.supports(LoginProvider.google), isFalse);
    expect(controller.error, 'Login indisponível');
  });
  test('restores only the account reported by the authentication backend', () async {
    repository.initial = const AuthAccount(uid: 'verified');
    await initialize(controller);
    expect(controller.account?.uid, 'verified');
    expect(controller.initializing, isFalse);
  });
  test('popup completion does not grant access without confirmed session', () async {
    await initialize(controller);
    await controller.signIn(LoginProvider.google);
    expect(controller.account, isNull);
    repository.changes.add(const AuthAccount(uid: 'verified'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.account?.uid, 'verified');
  });
  test('cancelled authentication keeps signed-out state without error', () async {
    await initialize(controller);
    repository.signInFailure = const LoginFailure('', cancelled: true);
    await controller.signIn(LoginProvider.apple);
    expect(controller.account, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
  });
  test('errors do not grant access and concurrent clicks share one attempt', () async {
    await initialize(controller);
    repository.gate = Completer<void>();
    repository.signInFailure = const LoginFailure('Sem conexão');
    final first = controller.signIn(LoginProvider.google);
    await controller.signIn(LoginProvider.google);
    expect(repository.attempts, 1);
    repository.gate!.complete();
    await first;
    expect(controller.account, isNull);
    expect(controller.error, 'Sem conexão');
    expect(controller.busy, isFalse);
  });
  test('failed logout preserves session; successful logout clears it', () async {
    repository.initial = const AuthAccount(uid: 'verified');
    await initialize(controller);
    repository.logoutFails = true;
    await controller.signOut();
    expect(controller.account?.uid, 'verified');
    expect(controller.error, isNotNull);
    repository.logoutFails = false;
    await controller.signOut();
    expect(controller.account, isNull);
  });
  test('deletion failure preserves account and explains recent login', () async {
    repository.initial = const AuthAccount(uid: 'verified');
    await initialize(controller);
    repository.deletionFailure = const LoginFailure('Entre novamente');
    expect(await controller.deleteAccount(), isFalse);
    expect(controller.account?.uid, 'verified');
    expect(controller.error, 'Entre novamente');
    expect(controller.busy, isFalse);
  });
  test('confirmed deletion clears account and prevents duplicate requests', () async {
    repository.initial = const AuthAccount(uid: 'verified');
    await initialize(controller);
    repository.gate = Completer<void>();
    final deletion = controller.deleteAccount();
    expect(await controller.deleteAccount(), isFalse);
    expect(repository.deletions, 1);
    repository.gate!.complete();
    expect(await deletion, isTrue);
    expect(controller.account, isNull);
    expect(controller.busy, isFalse);
  });
  test('signed-out users cannot request deletion', () async {
    await initialize(controller);
    expect(await controller.deleteAccount(), isFalse);
    expect(repository.deletions, 0);
  });
  testWidgets('login has no guest bypass and errors stay on login', (tester) async {
    await initialize(controller);
    repository.signInFailure = const LoginFailure('Sem conexão');
    await tester.pumpWidget(MaterialApp(home: LoginScreen(controller: controller)));
    expect(find.text('Explorar canais gratuitos'), findsNothing);
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
  testWidgets('session expiration removes nested private routes', (tester) async {
    repository.initial = const AuthAccount(uid: 'verified');
    await initialize(controller);
    await tester.pumpWidget(RochaPlusApp(authController: controller));
    await tester.pump();
    if (find.text('Pular').evaluate().isNotEmpty) {
      await tester.tap(find.text('Pular'));
    }
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) =>
      const Scaffold(body: Text('Conteúdo privado')))));
    await tester.pumpAndSettle();
    expect(find.text('Conteúdo privado'), findsOneWidget);
    repository.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Conteúdo privado'), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
