import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';

void main() {
  for (final reason in ['trial', 'paid', 'expired']) {
    testWidgets('subscription identifies server reason ' + reason + ' without invented validity', (tester) async {
      final result = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': reason != 'expired', 'reason': reason,
      }, 'A')!;
      await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
        accountUid: 'A', verifyAccess: (_) async => result)));
      await tester.tap(find.text('Verificar acesso'));
      await tester.pumpAndSettle();
      expect(find.text(result.label), findsOneWidget);
      expect(find.textContaining('Validade informada'), findsNothing);
    });
  }

  testWidgets('server validity is optional display metadata', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'A', verifyAccess: (_) async => SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': true, 'reason': 'paid',
        'expiresAt': '2026-11-01T12:00:00Z',
      }, 'A'))));
    await tester.tap(find.text('Verificar acesso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Validade informada pelo servidor'), findsOneWidget);
  });

  testWidgets('late account A result cannot appear on account B', (tester) async {
    final pending = Completer<SubscriptionAccessResult?>();
    Future<SubscriptionAccessResult?> verify(String uid) => pending.future;
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'A', verifyAccess: verify)));
    await tester.tap(find.text('Verificar acesso'));
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'B', verifyAccess: verify)));
    pending.complete(const SubscriptionAccessResult(uid: 'A', allowed: true, reason: 'paid'));
    await tester.pumpAndSettle();
    expect(find.text('Assinatura ainda não verificada'), findsOneWidget);
    expect(find.textContaining('Acesso pago'), findsNothing);
  });

  testWidgets('failed refresh clears prior paid status instead of caching a grant', (tester) async {
    var offline = false;
    Future<SubscriptionAccessResult?> verify(String uid) async =>
        offline ? null : SubscriptionAccessResult(uid: uid, allowed: true, reason: 'paid');
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'A', verifyAccess: verify)));
    await tester.tap(find.text('Verificar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso pago confirmado pelo servidor'), findsOneWidget);
    offline = true;
    await tester.tap(find.text('Verificar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível confirmar o acesso'), findsOneWidget);
    expect(find.text('Acesso pago confirmado pelo servidor'), findsNothing);
  });

  testWidgets('resume and reopening require a fresh server check', (tester) async {
    Future<SubscriptionAccessResult?> verify(String uid) async =>
        SubscriptionAccessResult(uid: uid, allowed: true, reason: 'trial');
    Widget screen() => MaterialApp(home: SubscriptionScreen(
        accountUid: 'A', verifyAccess: verify));
    await tester.pumpWidget(screen());
    await tester.tap(find.text('Verificar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Teste gratuito confirmado pelo servidor'), findsOneWidget);
    await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Assinatura ainda não verificada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    expect(find.text('Assinatura ainda não verificada'), findsOneWidget);
  });
}
