import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/trial_expiry_lab_screen.dart';
import 'package:rocha_plus/src/auth/playback_permission.dart';

void main() {
  testWidgets('LAB fictitious trial grants, expires and restores locally',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrialExpiryLabScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ACESSO FICTÍCIO LIBERADO • LAB'), findsOneWidget);
    expect(find.text('Minha assinatura'), findsNothing);

    await tester.tap(find.text('Simular vencimento'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ACESSO FICTÍCIO LIBERADO • LAB'), findsNothing);
    expect(find.text('TRIAL FICTÍCIO VENCIDO • LAB: reprodução bloqueada.'), findsOneWidget);
    expect(find.text('Minha assinatura'), findsNothing);

    await tester.tap(find.text('Simular trial válido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ACESSO FICTÍCIO LIBERADO • LAB'), findsOneWidget);
    expect(find.text('Minha assinatura'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('LAB repeated expiry never opens real subscription actions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrialExpiryLabScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(find.text('Simular vencimento'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ACESSO FICTÍCIO LIBERADO • LAB'), findsNothing);
      expect(find.text('Minha assinatura'), findsNothing);
      expect(find.text('Sair da conta'), findsNothing);

      await tester.tap(find.text('Simular trial válido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ACESSO FICTÍCIO LIBERADO • LAB'), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('LAB expiry revokes a previously acquired playback permit',
      (tester) async {
    final permission = PlaybackPermission();
    await tester.pumpWidget(MaterialApp(
      home: TrialExpiryLabScreen(playbackPermission: permission),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final permit = permission.acquire();
    permit.ensureValid();

    await tester.tap(find.text('Simular vencimento'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(() => permit.ensureValid(), throwsStateError);
    expect(() => permission.acquire(), throwsStateError);
    expect(find.text('Minha assinatura'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

}
