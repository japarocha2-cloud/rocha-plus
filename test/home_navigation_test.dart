import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';

void main() {
  testWidgets('Home exposes Sports and News as real navigation targets',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Esportes'), findsOneWidget);
    expect(find.text('Notícias'), findsOneWidget);

    await tester.tap(find.text('Esportes'));
    await tester.pump();

    expect(find.text('Esportes'), findsWidgets);
    expect(find.text('Esportes entra na próxima etapa.'), findsNothing);
  });
}
