import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';

// Simulated clocks only: no real Firebase, entitlement or payment is touched.
final serverStart = DateTime.utc(2026, 11, 16, 5, 32, 31, 377);
final trialEnd = serverStart.add(const Duration(days: 7));
const day = Duration(days: 1);

SubscriptionAccessResult result({required DateTime serverNow, required DateTime deviceNow,
    String reason = 'trial', bool allowed = true, DateTime? end}) =>
    SubscriptionAccessResult.fromPayload({
      'uid': 'A', 'allowed': allowed, 'reason': reason,
      'expiresAtMs': (end ?? trialEnd).millisecondsSinceEpoch,
      'serverTimeMs': serverNow.millisecondsSinceEpoch,
    }, 'A', clock: () => deviceNow)!;

void main() {
  group('remaining time label', () {
    test('formats days, hours and minutes in Portuguese', () {
      expect(remainingLabel(const Duration(days: 7)), '7 dias, 00 horas e 00 minutos restantes');
      expect(remainingLabel(const Duration(days: 1, hours: 1, minutes: 1)),
          '1 dia, 01 hora e 01 minuto restantes');
      expect(remainingLabel(const Duration(days: 2, hours: 3, minutes: 4, seconds: 59)),
          '2 dias, 03 horas e 04 minutos restantes');
      expect(remainingLabel(const Duration(seconds: 30)), 'Menos de 1 minuto restante');
      expect(remainingLabel(Duration.zero), 'Teste gratuito encerrado');
      expect(remainingLabel(const Duration(minutes: -5)), 'Teste gratuito encerrado');
    });
  });

  group('server-confirmed expiry', () {
    test('first access is exactly 7 x 24 hours', () {
      final r = result(serverNow: serverStart, deviceNow: serverStart);
      expect(r.remaining(serverStart), const Duration(days: 7));
    });

    test('wrong device clock (ahead or behind) does not change time left', () {
      final serverNow = serverStart.add(const Duration(days: 4, hours: 20, minutes: 56));
      for (final skew in [const Duration(hours: 5), const Duration(hours: -26), const Duration(days: 30)]) {
        final device = serverNow.add(skew);
        final r = result(serverNow: serverNow, deviceNow: device);
        expect(r.remaining(device), trialEnd.difference(serverNow), reason: 'skew $skew');
      }
    });

    test('time zone of the device does not change the countdown', () {
      final r = result(serverNow: serverStart, deviceNow: serverStart);
      final asLocal = serverStart.add(day).toLocal();
      expect(r.remaining(asLocal), r.remaining(serverStart.add(day)));
    });

    test('reopen / new login / reconnect keep exactly the same expiry', () {
      final first = result(serverNow: serverStart, deviceNow: serverStart);
      final later = result(serverNow: serverStart.add(const Duration(days: 3)),
          deviceNow: serverStart.add(const Duration(days: 3, hours: 2)));
      expect(later.expiresAt, first.expiresAt);
      expect(later.expiresAt, trialEnd);
    });

    test('never invents an expiry: missing, non-numeric or absurd values are ignored', () {
      for (final bad in [null, 'amanhã', 12, -1, DateTime.utc(2200).millisecondsSinceEpoch]) {
        final r = SubscriptionAccessResult.fromPayload({
          'uid': 'A', 'allowed': true, 'reason': 'trial', 'expiresAtMs': bad}, 'A')!;
        expect(r.expiresAt, isNull, reason: '$bad');
        expect(r.remaining(DateTime.now()), isNull);
      }
      final denied = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': false, 'reason': 'trial',
        'expiresAtMs': trialEnd.millisecondsSinceEpoch}, 'A')!;
      expect(denied.expiresAt, isNull, reason: 'inconsistent reason is dropped');
    });
  });

  group('Assinaturas screen', () {
    testWidgets('trial shows a live countdown corrected by the server clock', (tester) async {
      final serverNow = trialEnd.subtract(const Duration(days: 2, hours: 3, minutes: 4));
      var device = serverNow.add(const Duration(hours: 5)); // device clock 5h ahead
      final initialDevice = device;
      await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
        accountUid: 'A',
        clock: () => device,
        verifyAccess: (_) async => result(serverNow: serverNow, deviceNow: initialDevice),
      )));
      await tester.pumpAndSettle();
      expect(find.text('2 dias, 03 horas e 04 minutos restantes'), findsOneWidget);
      expect(find.textContaining('Vence em'), findsOneWidget);
      device = device.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('2 dias, 02 horas e 54 minutos restantes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('at zero shows "Teste gratuito encerrado" and asks the server again', (tester) async {
      final serverNow = trialEnd.subtract(const Duration(minutes: 1));
      var device = serverNow;
      var calls = 0;
      await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
        accountUid: 'A',
        clock: () => device,
        verifyAccess: (_) async {
          calls++;
          return calls == 1
              ? result(serverNow: serverNow, deviceNow: serverNow)
              : result(serverNow: trialEnd, deviceNow: trialEnd, reason: 'expired', allowed: false);
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('1 dia, 00 hora e 01 minuto restantes'), findsNothing);
      expect(find.text('Menos de 1 minuto restante'), findsNothing);
      expect(find.text('0 dias, 00 horas e 01 minuto restantes'), findsOneWidget);
      device = trialEnd.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Acesso expirado segundo o servidor'), findsOneWidget);
      expect(find.byKey(const ValueKey('trial-countdown')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('paid access shows its expiry date and no trial countdown', (tester) async {
      final paidEnd = serverStart.add(const Duration(days: 30));
      await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
        accountUid: 'A',
        clock: () => serverStart,
        verifyAccess: (_) async => result(serverNow: serverStart, deviceNow: serverStart,
            reason: 'paid', end: paidEnd),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trial-countdown')), findsNothing);
      expect(find.textContaining('restantes'), findsNothing);
      expect(find.byKey(const ValueKey('paid-until')), findsOneWidget);
      expect(find.textContaining('Validade informada pelo servidor (UTC): 16/12/2026 05:32'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('server without expiry (old contract) shows no invented countdown', (tester) async {
      await tester.pumpWidget(MaterialApp(home: SubscriptionScreen(
        accountUid: 'A',
        verifyAccess: (_) async => SubscriptionAccessResult.fromPayload(
            {'uid': 'A', 'allowed': true, 'reason': 'trial'}, 'A'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Teste gratuito confirmado pelo servidor'), findsOneWidget);
      expect(find.byKey(const ValueKey('trial-countdown')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
