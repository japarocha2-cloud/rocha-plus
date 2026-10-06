import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';

void main() {
  testWidgets('Sports is a real Home navigation target', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.scrollUntilVisible(find.text('Esportes'), 250);

    expect(find.text('Esportes'), findsOneWidget);
    await tester.tap(find.text('Esportes'));
    await tester.pump();

    expect(find.text('Esportes entra na próxima etapa.'), findsNothing);
  });
  testWidgets('unfinished destinations are not exposed as finished buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Filmes'), findsNothing);
    expect(find.text('Séries'), findsNothing);
    expect(find.text('Documentários'), findsNothing);
    expect(find.text('Regionais'), findsNothing);
    expect(find.text('Infantil'), findsNothing);
  });

}
