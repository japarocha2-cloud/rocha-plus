import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';

void main() {
  for (final reason in ['trial', 'paid', 'expired']) {
    testWidgets('automatically displays verified $reason without invented validity', (tester) async {
      final result = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': reason != 'expired', 'reason': reason,
      }, 'A')!;
      await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
        accountUid: 'A', verifyAccess: (_) async => result)));
      await tester.pumpAndSettle();
      if (reason == 'trial') {
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
      } else {
        expect(find.byType(AlertDialog), findsNothing);
      }
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
    await tester.pumpAndSettle();
    expect(find.textContaining('Validade informada pelo servidor'), findsOneWidget);
  });

  testWidgets('late account A result cannot appear on account B', (tester) async {
    final pending = Completer<SubscriptionAccessResult?>();
    final b = Completer<SubscriptionAccessResult?>();
    Future<SubscriptionAccessResult?> verify(String uid) =>
        uid == 'A' ? pending.future : b.future;
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'A', verifyAccess: verify)));
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'B', verifyAccess: verify)));
    pending.complete(const SubscriptionAccessResult(uid: 'A', allowed: true, reason: 'paid'));
    await tester.pump();
    b.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível confirmar o acesso'), findsOneWidget);
    expect(find.textContaining('Acesso pago'), findsNothing);
  });

  testWidgets('failed refresh clears prior paid status', (tester) async {
    var offline = false;
    Future<SubscriptionAccessResult?> verify(String uid) async =>
        offline ? null : SubscriptionAccessResult(uid: uid, allowed: true, reason: 'paid');
    await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
      accountUid: 'A', verifyAccess: verify)));
    await tester.pumpAndSettle();
    expect(find.text('Acesso pago confirmado pelo servidor'), findsOneWidget);
    offline = true;
    await tester.tap(find.text('Verificar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível confirmar o acesso'), findsOneWidget);
    expect(find.text('Acesso pago confirmado pelo servidor'), findsNothing);
  });

  testWidgets('resume and reopening query the server again', (tester) async {
    var calls = 0;
    Future<SubscriptionAccessResult?> verify(String uid) async {
      calls++;
      return SubscriptionAccessResult(uid: uid, allowed: true, reason: 'paid');
    }
    Widget screen() => MaterialApp(home: SubscriptionScreen(accountUid: 'A', verifyAccess: verify));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(calls, 3);
  });
}
