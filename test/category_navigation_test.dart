import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  for (final category in ['Infantil', 'Notícias']) {
    testWidgets('$category filters compound tags without leaking other channels', (tester) async {
      final repo = ChannelRepository(client: MockClient((request) async =>
        http.Response(request.url == ChannelRepository.sportsPlaylist ? '#EXTM3U' :
            '#EXTM3U\n'
            '#EXTINF:-1 group-title="General;Kids",Canal Criança\nhttps://example.com/kids\n'
            '#EXTINF:-1 group-title="General;News",Jornal Agora\nhttps://example.com/news\n', 200, headers: {'content-type': 'text/plain; charset=utf-8'})));
      await tester.pumpWidget(MaterialApp(home:
          LiveTvScreen(initialGroup: category, repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text(category), findsWidgets);
      expect(find.text('Canal Criança'), category == 'Infantil' ? findsOneWidget : findsNothing);
      expect(find.text('Jornal Agora'), category == 'Notícias' ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty requested category stays empty instead of showing unrelated channels', (tester) async {
    final repo = ChannelRepository(client: MockClient((request) async =>
      http.Response(request.url == ChannelRepository.sportsPlaylist ? '#EXTM3U' :
          '#EXTM3U\n#EXTINF:-1 group-title="News",Jornal\nhttps://example.com/news\n', 200, headers: {'content-type': 'text/plain; charset=utf-8'})));
    await tester.pumpWidget(MaterialApp(home:
        LiveTvScreen(initialGroup: 'Infantil', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum canal encontrado.'), findsOneWidget);
    expect(find.text('Jornal'), findsNothing);
  });

  testWidgets('TV aberta displays upstream General and Undefined networks only', (tester) async {
    final repo = ChannelRepository(client: MockClient((request) async =>
      http.Response(request.url == ChannelRepository.sportsPlaylist ? '#EXTM3U' :
          '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="SBTNacional.br@SD" group-title="Undefined",SBT Nacional\nhttps://example.com/sbt\n'
          '#EXTINF:-1 group-title="General",TV Morena\nhttps://example.com/morena\n'
          '#EXTINF:-1 group-title="Kids",Canal Criança\nhttps://example.com/kids\n'
          '#EXTINF:-1 group-title="News",Jornal\nhttps://example.com/news\n',
          200, headers: {'content-type': 'text/plain; charset=utf-8'})));
    await tester.pumpWidget(MaterialApp(home:
        LiveTvScreen(initialGroup: 'TV aberta', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('SBT Nacional'), findsOneWidget);
    expect(find.text('TV Morena'), findsOneWidget);
    expect(find.text('TV aberta'), findsWidgets);
    expect(find.text('2 canais'), findsOneWidget);
    expect(find.text('Canal Criança'), findsNothing);
    expect(find.text('Jornal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
