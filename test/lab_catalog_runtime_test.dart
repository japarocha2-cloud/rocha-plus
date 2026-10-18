import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/app.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

const lab = bool.fromEnvironment('ROCHA_LAB_TEST');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });

  test('all 20 distinct experimental URLs load only in laboratory builds', () async {
    final entries = jsonDecode(await rootBundle.loadString(
      'catalog/rl_positives_experimental.json')) as List;
    final urls = entries.map((e) => e['url'] as String).toSet();
    expect(entries, hasLength(20));
    expect(urls, hasLength(20));
    expect(entries.every((e) => e['distribution_permission'] == 'unverified'), isTrue);
    final channels = await ChannelRepository(
      catalogLoader: () async => '[]', quarantineLoader: () async => '[]',
    ).loadBrazilPublicDirectory();
    final loaded = channels.map((c) => c.url).toSet();
    expect(loaded.intersection(urls), lab ? urls : isEmpty);
    expect(channels.length, loaded.length);
  });

  for (final size in [const Size(320, 568), const Size(360, 800),
      const Size(412, 915)]) {
    testWidgets('local lab entry, carousel, kids list and return at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Preload actual assets using real async I/O, then exercise the same
      // asynchronous preferences/catalogue transition that runs on Android.
      await tester.runAsync(() => rootBundle.loadString('catalog/approved.json'));
      await tester.pumpWidget(const RochaPlusApp());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('O login ainda não foi ativado'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final scroll = find.descendant(of: find.byKey(const ValueKey('home-scroll')),
        matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('category-Infantil')),
        150, scrollable: scroll);
      await tester.tap(find.byKey(const ValueKey('category-Infantil')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(LiveTvScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('channel-grid')), findsOneWidget);
      expect(find.text('Não foi possível carregar os canais.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }, skip: !lab);
  }
}
