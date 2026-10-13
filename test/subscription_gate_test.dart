import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/billing/subscription_gate.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/subscription_screen.dart';
import 'billing_test.dart' show FakeBillingRepository;
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('expired account cannot enter Home and failed refresh keeps it blocked', (tester) async {
    final repository = FakeBillingRepository()..active = false;
    await tester.pumpWidget(MaterialApp(home: SubscriptionGate(uid: 'A',
      repository: repository, onSignOut: () async {})));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    repository.fail = true;
    await tester.tap(find.text('Já paguei / verificar acesso'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsNothing);
  });
  testWidgets('expiration disposes the entire nested channel/player route stack', (tester) async {
    final repository = FakeBillingRepository();
    await tester.pumpWidget(MaterialApp(home: SubscriptionGate(uid: 'A',
      repository: repository, onSignOut: () async {})));
    await tester.pump(const Duration(milliseconds: 500));
    final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Player privado'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Player privado'), findsOneWidget);
    repository.active = false;
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Player privado'), findsNothing);
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
