import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/lab/functional_lab_app.dart';
import 'package:rocha_plus/src/lab/lab_entitlement.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';

class _DiagnosticAuth extends AuthRepository {
  final changes = StreamController<AuthAccount?>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Stream<AuthAccount?> get accountChanges async* {
    yield null;
    yield* changes.stream;
  }

  @override
  bool supports(LoginProvider provider) => provider == LoginProvider.google;

  @override
  Future<void> signIn(LoginProvider provider) async {
    changes.add(const AuthAccount(uid: 'diagnostic-fixture'));
  }

  @override
  Future<void> signOut() async {
    changes.add(null);
  }
}

void main() {
  testWidgets(
      'diagnostic mode uses authentication and entitlement, then keeps streams unreachable',
      (tester) async {
    final repository = _DiagnosticAuth();
    final controller = AuthController(repository);
    var entitlementCalls = 0;
    await tester.pumpWidget(FunctionalLabApp(
      authController: controller,
      diagnosticMode: true,
      verify: (uid) async {
        entitlementCalls++;
        expect(uid, 'diagnostic-fixture');
        return const LabAccess(true, Duration(seconds: 30));
      },
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('ROCHA+ - LAB DE DIAGNÓSTICO'), findsOneWidget);
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(entitlementCalls, 1);
    expect(find.text('Rocha+ LAB Diagnostic'), findsOneWidget);
    expect(find.byType(LiveTvScreen), findsNothing);
    expect(find.byKey(const ValueKey('diagnostic-catalog-warning')),
        findsOneWidget);

    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('Definitive catalog pending'), findsOneWidget);
    expect(find.text('Channel playback is unavailable in this build'),
        findsOneWidget);

    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(LiveTvScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await repository.changes.close();
  });

  testWidgets('diagnostic mode remains closed when entitlement is denied',
      (tester) async {
    final repository = _DiagnosticAuth();
    final controller = AuthController(repository);
    await tester.pumpWidget(FunctionalLabApp(
      authController: controller,
      diagnosticMode: true,
      verify: (_) async => LabAccess.denied,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Não foi possível confirmar acesso autorizado. Nenhum acesso foi concedido.'),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('diagnostic-catalog-warning')), findsNothing);
    expect(find.byType(LiveTvScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await repository.changes.close();
  });
}
