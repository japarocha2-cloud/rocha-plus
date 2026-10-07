import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);
  tearDown(ChannelRepository.restoreDefaultClientForTests);

  test('player failure quarantines a stream for the current session', () {
    final repository = ChannelRepository();
    const url = 'https://example.com/live.m3u8';

    expect(repository.isQuarantined(url), isFalse);
    repository.reportPlaybackFailure(url);
    expect(repository.isQuarantined(url), isTrue);
  });

  test('successful playback clears a previous quarantine', () {
    final repository = ChannelRepository();
    const url = 'https://example.com/live.m3u8';

    repository.reportPlaybackFailure(url);
    repository.reportPlaybackSuccess(url);
    expect(repository.isQuarantined(url), isFalse);
  });

  test('sports catalog excludes non-sports and quarantined streams', () {
    final repository = ChannelRepository();
    const sport = Channel(name: 'Futebol Brasil', url: 'https://example.com/sport.m3u8', group: 'Esportes');
    const news = Channel(name: 'Jornal', url: 'https://example.com/news.m3u8', group: 'News');

    expect(repository.sportsOnly([sport, news]), [sport]);
    repository.reportPlaybackFailure(sport.url);
    expect(repository.sportsOnly([sport, news]), isEmpty);
  });

  test('physical-test blocklist survives remote URL changes', () {
    final repository = ChannelRepository();
    const blockedA = Channel(
      name: '1001 Noites',
      url: 'https://example.com/old-feed.m3u8',
      group: 'General',
    );
    const blockedB = Channel(
      name: '  1001 NOITES  ',
      url: 'https://example.com/new-feed.m3u8',
      group: 'Geral',
    );
    const allowed = Channel(
      name: 'N Sports',
      url: 'https://example.com/nsports.m3u8',
      group: 'Esportes',
    );

    expect(repository.isPermanentlyBlockedForTests(blockedA), isTrue);
    expect(repository.isPermanentlyBlockedForTests(blockedB), isTrue);
    expect(repository.isPermanentlyBlockedForTests(allowed), isFalse);
  });

  test('male football ranks before female football and other sports', () {
    final repository = ChannelRepository();
    const male = Channel(name: 'Brasileirão Futebol', url: 'https://example.com/a.m3u8', group: 'Esportes');
    const female = Channel(name: 'Futebol Feminino', url: 'https://example.com/b.m3u8', group: 'Esportes');
    const tennis = Channel(name: 'Tênis', url: 'https://example.com/c.m3u8', group: 'Esportes');

    expect(repository.sportsPriorityForTests(male), greaterThan(repository.sportsPriorityForTests(female)));
    expect(repository.sportsPriorityForTests(female), greaterThan(repository.sportsPriorityForTests(tennis)));
    expect(repository.sportsOnly([tennis, female, male]), [male, female, tennis]);
  });

  test('one dead catalog does not erase a healthy catalog', () async {
    ChannelRepository.setClientForTests(MockClient((request) async {
      if (request.url == ChannelRepository.developmentPlaylist) {
        return http.Response('''#EXTM3U\n#EXTINF:-1 group-title="News",Canal Teste\nhttps://example.com/live.m3u8''', 200);
      }
      return http.Response('offline', 503);
    }));

    final channels = await ChannelRepository().loadBrazilPublicDirectory(forceRefresh: true);
    expect(channels.any((channel) => channel.name == 'Canal Teste'), isTrue);
  });
  test('HLS validator accepts media playlist and rejects dead stream', () async {
    ChannelRepository.setClientForTests(MockClient((request) async {
      if (request.url.host == 'ok.example.com') {
        return http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts', 200);
      }
      return http.Response('offline', 503);
    }));

    final repository = ChannelRepository();
    expect(await repository.validateStreamForTests('https://ok.example.com/live.m3u8'), isTrue);
    expect(await repository.validateStreamForTests('https://dead.example.com/live.m3u8'), isFalse);
  });

  test('HLS validator follows an HTTPS master playlist child', () async {
    ChannelRepository.setClientForTests(MockClient((request) async {
      if (request.url.path.endsWith('master.m3u8')) {
        return http.Response('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nchild.m3u8', 200);
      }
      return http.Response('#EXTM3U\n#EXTINF:6,\nsegment.ts', 200);
    }));

    expect(
      await ChannelRepository().validateStreamForTests('https://ok.example.com/master.m3u8'),
      isTrue,
    );
  });
}
