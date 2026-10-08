import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });

  ChannelRepository repository() => ChannelRepository(client: MockClient((request) async =>
    http.Response('#EXTM3U\n#EXTINF:-1 group-title="General",Canal Teste\nhttps://example.com/tv\n',
      200, headers: {'content-type': 'text/plain; charset=utf-8'})));

  for (final size in [const Size(320, 568), const Size(430, 932),
      const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('featured layout stays usable at $size without replacing official assets',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: RochaTheme.dark, home: HomeScreen(repository: repository())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-featured-carousel')), findsOneWidget);
      expect(find.byKey(const ValueKey('official-hero')), findsOneWidget);
      expect(find.byKey(const ValueKey('tv-galaxy-background')),
        size.width >= 900 ? findsOneWidget : findsNothing);
      expect(find.text('Explore o Rocha+'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Rotates without input every six seconds, including the last-to-first loop.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Espaço infantil'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Esportes ao vivo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('official-hero')), findsOneWidget);

      // Manual arrows continue working at every position and restart the interval.
      await tester.tap(find.byTooltip('Destaque anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Esportes ao vivo'), findsOneWidget);
      await tester.tap(find.byTooltip('Próximo destaque'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('official-hero')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
