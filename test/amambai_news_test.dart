import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/news/amambai_news_repository.dart';
import 'package:rocha_plus/src/news/news_carousel_card.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

const fixture = '''<div class="td-big-grid-flex-post"><h3 class="entry-title"><a href="https://www.amambainoticias.com.br/2026/10/01/advert/">Fixed commercial tile</a></h3></div>
<div class="td_module_wrap"><span data-img-url="https://www.amambainoticias.com.br/wp-content/uploads/2026/10/report.jpg"></span>
<h3 class="entry-title"><a href="https://www.amambainoticias.com.br/2026/10/18/report/?utm_source=tracking">Notícia atual &amp; informação local</a></h3>
<time datetime="2026-10-18T05:00:00-04:00"></time><div class="td-excerpt">Uma chamada curta com informação suficiente para visitar o jornal e ler os detalhes da reportagem completa.</div></div>
<div class="td_module_wrap"><h3 class="entry-title"><a href="https://www.amambainoticias.com.br/2026/10/17/older/">Older news</a></h3><time datetime="2026-10-17T05:00:00-04:00"></time><div class="td-excerpt">Old</div></div>''';
final now = DateTime.utc(2026, 10, 18, 12);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('selects one latest editorial preview, decodes text and strips tracking', () {
    final headline = AmambaiNewsRepository.parseHomepage(fixture, now)!;
    expect(headline.title, 'Notícia atual & informação local');
    expect(headline.article.toString(), 'https://www.amambainoticias.com.br/2026/10/18/report/');
    expect(headline.image?.path, endsWith('report.jpg'));
    expect('${headline.title} ${headline.summary}'.split(' ').length, lessThanOrEqualTo(25));
    expect(AmambaiNewsRepository.parseHomepage('<html>changed layout</html>', now), isNull);
  });
  test('rejects foreign, executable, insecure and malformed URLs', () {
    for (final url in ['javascript:alert(1)', 'http://www.amambainoticias.com.br/2026/10/18/a/',
      'https://www.amambainoticias.com.br.attacker.test/2026/10/18/a/',
      'https://user@www.amambainoticias.com.br/2026/10/18/a/',
      'https://www.amambainoticias.com.br:8443/2026/10/18/a/']) {
      expect(AmambaiNewsRepository.trustedUri(url), isNull);
    }
    expect(AmambaiNewsRepository.trustedUri('https://www.amambainoticias.com.br/wp-content/uploads/a.svg', image: true), isNull);
  });
  test('coalesces loads, refreshes after TTL and restores last good preview offline', () async {
    var clock = now;
    var calls = 0;
    var online = true;
    final client = MockClient((request) async {
      calls++;
      expect(request.url, AmambaiNewsRepository.homepage);
      expect(request.followRedirects, isFalse);
      return http.Response(online ? fixture : '', online ? 200 : 503, headers: {'content-type': 'text/html; charset=utf-8'});
    });
    final repo = AmambaiNewsRepository(client: client, now: () => clock);
    final first = repo.load();
    expect(identical(first, repo.load()), isTrue);
    expect((await first)?.title, contains('Notícia atual'));
    await repo.load();
    expect(calls, 1);
    clock = clock.add(const Duration(minutes: 16));
    online = false;
    expect(await repo.load(), isNotNull);
    expect(calls, 2);
    final restored = AmambaiNewsRepository(client: client, now: () => clock);
    expect((await restored.load())?.article.path, endsWith('/report/'));
    clock = clock.add(const Duration(days: 8));
    expect(await restored.load(), isNull);
  });
  for (final width in [280.0, 360.0, 696.0]) {
    testWidgets('news card fits $width with enlarged text and opens the exact article', (tester) async {
      Uri? opened;
      final repo = AmambaiNewsRepository(now: () => now,
        client: MockClient((_) async => http.Response(fixture, 200, headers: {'content-type': 'text/html; charset=utf-8'})));
      // Resolve the HTTP/cache fixture before testing geometry and click routing.
      // pumpAndSettle alone does not wait for an external stream with no frames.
      expect(await tester.runAsync(() => repo.load()), isNotNull);
      await tester.pumpWidget(MaterialApp(theme: RochaTheme.dark,
        home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(body: Center(child: SizedBox(width: width, height: width * 9 / 16,
            child: NewsCarouselCard(repository: repo, opener: (uri) async { opened = uri; return true; },
              imageProvider: (_) => MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQwAAAABJRU5ErkJggg==')))))))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notícia atual'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('amambai-news-card')));
      await tester.pump();
      expect(opened?.path, '/2026/10/18/report/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('offline card remains clickable and failed launch reports a recoverable error', (tester) async {
    final repo = AmambaiNewsRepository(now: () => now,
      client: MockClient((_) async => http.Response('', 503)));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 180,
      child: NewsCarouselCard(repository: repo, opener: (uri) async {
        expect(uri, AmambaiNewsRepository.homepage);
        return false;
      })))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amambai-news-card')));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o jornal. Tente novamente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('mobile carousel starts with news and keeps Bau next', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: RochaTheme.dark,
      home: const HomeScreen(previewOnly: true)));
    await tester.pump();
    final pager = tester.widget<PageView>(find.byKey(const ValueKey('home-featured-carousel')));
    expect(pager.controller!.initialPage % 3, 0);
    expect(find.byKey(const ValueKey('amambai-news-card')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('home-featured-carousel')), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bau-test-banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !const bool.fromEnvironment('ROCHA_NEWS_CAROUSEL'));
}
