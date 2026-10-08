import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  test('partial refresh retains only the failed source from its own cache', () async {
    var refresh = false;
    final repo = ChannelRepository(client: MockClient((request) async {
      if (request.url == ChannelRepository.sportsPlaylist) {
        return refresh ? http.Response('', 503) : http.Response(
            '#EXTM3U\n#EXTINF:-1,Football\nhttps://example.com/sport\n', 200);
      }
      return http.Response('#EXTM3U\n#EXTINF:-1,TV\n'
          'https://example.com/${refresh ? 'new' : 'old'}\n', 200);
    }));
    await repo.loadBrazilPublicDirectory();
    refresh = true;
    final channels = await repo.loadBrazilPublicDirectory(forceRefresh: true);
    expect(channels.map((c) => c.url), containsAll([
      'https://example.com/sport', 'https://example.com/new']));
    expect(channels.map((c) => c.url), isNot(contains('https://example.com/old')));
  });

  test('successful playback restores a quarantined cached channel without reload', () async {
    var calls = 0;
    final repo = ChannelRepository(client: MockClient((request) async {
      calls++;
      return http.Response('#EXTM3U\n#EXTINF:-1,Canal\nhttps://example.com/live\n', 200);
    }));
    await repo.loadBrazilPublicDirectory();
    repo.reportPlaybackFailure('https://example.com/live');
    expect(await repo.loadBrazilPublicDirectory(), isEmpty);
    repo.reportPlaybackSuccess('https://example.com/live');
    expect(await repo.loadBrazilPublicDirectory(), hasLength(1));
    expect(calls, 2);
  });

  test('duplicate source URL retains Brazilian title and promotes sports group', () async {
    final repo = ChannelRepository(client: MockClient((request) async =>
        http.Response('#EXTM3U\n#EXTINF:-1,${request.url == ChannelRepository.sportsPlaylist ? 'Foreign name' : 'Nome brasileiro'}\n'
            'https://example.com/live\n', 200)));
    final channels = await repo.loadBrazilPublicDirectory();
    expect(channels.single.name, 'Nome brasileiro');
    expect(channels.single.group, 'Esportes');
  });

  test('concurrent catalog loads share requests and preserve source quality URL', () async {
    var calls = 0;
    final gate = Completer<void>();
    final repo = ChannelRepository(client: MockClient((request) async {
      calls++;
      await gate.future;
      return http.Response('#EXTM3U\n#EXTINF:-1 group-title="General",Canal\n'
          'https://example.com/master.m3u8?quality=original\n', 200);
    }));
    final first = repo.loadBrazilPublicDirectory();
    final second = repo.loadBrazilPublicDirectory();
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(calls, 2);
    expect(results.first.single.url,
        'https://example.com/master.m3u8?quality=original');
    await repo.loadBrazilPublicDirectory();
    expect(calls, 2);
  });
  test('one failed directory does not discard the other source', () async {
    final repo = ChannelRepository(client: MockClient((request) async {
      if (request.url == ChannelRepository.sportsPlaylist) {
        return http.Response('', 503);
      }
      return http.Response('#EXTM3U\n#EXTINF:-1,Canal\n'
          'https://example.com/master.m3u8\n', 200);
    }));
    expect(await repo.loadBrazilPublicDirectory(), hasLength(1));
  });
  test('failed refresh retains last known catalog', () async {
    var offline = false;
    final repo = ChannelRepository(client: MockClient((request) async =>
        offline ? http.Response('', 503) : http.Response(
        '#EXTM3U\n#EXTINF:-1,Canal\nhttps://example.com/master.m3u8\n', 200)));
    final first = await repo.loadBrazilPublicDirectory();
    offline = true;
    final fallback = await repo.loadBrazilPublicDirectory(forceRefresh: true);
    expect(fallback.single.url, first.single.url);
  });
}
