import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('mobile layout shows four categories below advertising carousel at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: RochaTheme.dark,
        home: const HomeScreen(previewOnly: true)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-featured-carousel')), findsOneWidget);
      expect(find.byKey(const ValueKey('sponsor-slot-2')), findsOneWidget);
      // On short screens the section sits below the visible viewport; scroll to it.

      final scroll = find.descendant(
        of: find.byKey(const ValueKey('home-scroll')),
        matching: find.byType(Scrollable)).first;
      for (final category in ['TV ao Vivo', 'Esportes', 'Infantil', 'Notícias']) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('category-$category')), 150,
          scrollable: scroll);
        expect(find.byKey(ValueKey('category-$category')), findsOneWidget);
        final cover = tester.widget<Image>(find.descendant(
          of: find.byKey(ValueKey('category-$category')),
          matching: find.byType(Image)).first);
        expect((cover.image as AssetImage).assetName,
          startsWith('branding/categories/mobile/'));

      }
      final first = tester.getTopLeft(find.byKey(const ValueKey('category-TV ao Vivo')));
      final last = tester.getTopLeft(find.byKey(const ValueKey('category-Notícias')));
      expect((first.dy - last.dy).abs(), lessThan(2));
      expect(first.dx, lessThan(last.dx));
      expect(tester.takeException(), isNull);
    });
  }
}
