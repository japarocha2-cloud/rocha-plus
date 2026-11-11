import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_search.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

void main() {
  test('search finds regional names across accents, case and spacing', () {
    const cuiaba = Channel(name: 'SBT Cuiaba', url: 'https://example.com/cuiaba');
    const rondon = Channel(name: 'SBT Rondonopolis', url: 'https://example.com/rondon');
    const mutum = Channel(name: 'SBT Nova Mutum', url: 'https://example.com/mutum');
    expect(channelMatchesSearch(cuiaba, '  CUIABÁ  '), isTrue);
    expect(channelMatchesSearch(cuiaba, 'Cuiaba\u0301'), isTrue);
    expect(channelMatchesSearch(rondon, 'Rondonópolis'), isTrue);
    expect(channelMatchesSearch(mutum, 'sbt   nova mutum'), isTrue);
    expect(channelMatchesSearch(mutum, 'Cuiabá'), isFalse);
  });
  test('search preserves resolution and category searches', () {
    const channel = Channel(name: 'Rede Globo (1080p)',
        url: 'https://example.com/globo', group: 'TV aberta');
    const news = Channel(name: 'Canal News',
        url: 'https://example.com/news', group: 'Notícias');
    expect(channelMatchesSearch(channel, '1080p'), isTrue);
    expect(channelMatchesSearch(channel, 'tv aberta'), isTrue);
    expect(channelMatchesSearch(news, 'noticias'), isTrue);
    expect(channelMatchesSearch(channel, '  '), isTrue);
  });
  testWidgets('regional accented search reaches the live TV grid', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = ChannelRepository(client: MockClient((request) async =>
        http.Response(request.url == ChannelRepository.sportsPlaylist ? '#EXTM3U' :
          '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="RedeTVParana.br@SD",RedeTV! Parana\nhttps://example.com/parana\n'
          '#EXTINF:-1 tvg-id="SBTInterior.br@SD",SBT Interior\nhttps://example.com/interior\n'
          '#EXTINF:-1 tvg-id="TVPantanalMS.br@SD",TV Pantanal MS\nhttps://example.com/pantanal\n',
          200, headers: {'content-type': 'text/plain; charset=utf-8'})));
    await tester.pumpWidget(MaterialApp(home:
        LiveTvScreen(initialGroup: 'TV aberta', repository: repo)));
    await tester.pumpAndSettle();
    for (final entry in {
      'Paraná': 'RedeTV! Parana',
      'INTERIOR': 'SBT Interior',
      'PANTANAL  MS': 'TV Pantanal MS',
    }.entries) {
      await tester.enterText(find.byType(TextField), entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('1 canais'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('3 canais'), findsOneWidget);
  });
}
