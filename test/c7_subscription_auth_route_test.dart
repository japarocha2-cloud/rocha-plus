import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/auth/subscription_access.dart';
import 'package:rocha_plus/src/screens/lab_subscription_screen.dart';
import 'auth_test.dart' show FakeAuth;

void main() {
  testWidgets('LAB consultation uses authenticated UID and clears status on logout', (tester) async {
    final repository = FakeAuth();
    final auth = AuthController(repository);
    await auth.initialize();
    await tester.pumpWidget(MaterialApp(home: LabSubscriptionScreen(
      authController: auth,
      verifyAccess: (uid) async {
        expect(uid, 'verified-subject');
        return SubscriptionAccessResult(uid: uid, allowed: true, reason: 'paid',
          expiresAt: DateTime.utc(2027, 10, 21));
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Verificar acesso'), findsNothing);
    await tester.tap(find.text('Entrar para consultar assinatura'));
    await tester.pumpAndSettle();
    expect(find.text('Verificar acesso'), findsNothing, reason: 'popup completion is not identity proof');
    repository.changes.add(const AuthAccount(uid: 'verified-subject'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Verificar acesso'));
    await tester.tap(find.text('Verificar acesso'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso pago confirmado pelo servidor'), findsOneWidget);
    await tester.ensureVisible(find.text('Trocar conta'));
    await tester.tap(find.text('Trocar conta'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso pago confirmado pelo servidor'), findsNothing);
    expect(find.text('Verificar acesso'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    await repository.changes.close();
  });
}
