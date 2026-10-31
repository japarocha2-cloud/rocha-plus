import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/trial_expiry_lab_screen.dart';

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
    expect(find.text('Acesso não liberado. Confira sua assinatura ou aguarde a confirmação do pagamento.'), findsOneWidget);
    expect(find.text('Minha assinatura'), findsNothing);

    await tester.tap(find.text('Simular trial válido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ACESSO FICTÍCIO LIBERADO • LAB'), findsOneWidget);
    expect(find.text('Minha assinatura'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
