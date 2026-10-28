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

  test('failed playback leaves cached channels visible and retryable without reload', () async {
    var calls = 0;
    final repo = ChannelRepository(client: MockClient((request) async {
      calls++;
      return http.Response('#EXTM3U\n#EXTINF:-1,Canal\nhttps://example.com/live\n', 200);
    }));
    await repo.loadBrazilPublicDirectory();
    repo.reportPlaybackFailure('https://example.com/live');
    expect(await repo.loadBrazilPublicDirectory(), hasLength(1));
    repo.reportPlaybackSuccess('https://example.com/live');
    expect(await repo.loadBrazilPublicDirectory(), hasLength(1));
    expect(calls, 2);
  });

  test('same URL with different names preserves both source identities', () async {
    final repo = ChannelRepository(client: MockClient((request) async =>
        http.Response('#EXTM3U\n#EXTINF:-1,${request.url == ChannelRepository.sportsPlaylist ? 'Foreign name' : 'Nome brasileiro'}\n'
            'https://example.com/live\n', 200)));
    final channels = await repo.loadBrazilPublicDirectory();
    expect(channels, hasLength(2));
    expect(channels.map((c) => c.name), containsAll(['Nome brasileiro', 'Foreign name']));
    expect(channels.firstWhere((c) => c.name == 'Foreign name').group, 'Esportes');
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
  test('same identity deduplicates exact URL but preserves fallback and regional feeds', () async {
    final repo = ChannelRepository(client: MockClient((request) async =>
      http.Response('#EXTM3U\n'
          '#EXTINF:-1,Canal (720p)\nhttps://example.com/live\n'
          '#EXTINF:-1,Canal (1080p)\nhttps://example.com/live\n'
          '#EXTINF:-1,Canal\nhttps://example.com/fallback?quality=original\n'
          '#EXTINF:-1,Canal Interior\nhttps://example.com/live\n', 200)));
    final channels = await repo.loadBrazilPublicDirectory();
    expect(channels, hasLength(3));
    expect(channels.where((c) => c.url == 'https://example.com/live'), hasLength(2));
    expect(channels.map((c) => c.url), contains('https://example.com/fallback?quality=original'));
  });

  test('hiding every channel returns empty and restore uses cache while offline', () async {
    var offline = false;
    var calls = 0;
    final repo = ChannelRepository(client: MockClient((request) async {
      calls++;
      return offline ? http.Response('', 503) : http.Response(
          '#EXTM3U\n#EXTINF:-1,Canal\nhttps://example.com/live\n', 200);
    }));
    final original = await repo.loadBrazilPublicDirectory();
    await repo.blockChannel(original.single);
    expect(await repo.loadBrazilPublicDirectory(), isEmpty);
    offline = true;
    expect(await repo.loadBrazilPublicDirectory(forceRefresh: true), isEmpty);
    final callsBeforeRestore = calls;
    await repo.restoreUserBlockedChannels();
    final restored = await repo.loadBrazilPublicDirectory();
    expect(restored.single.url, original.single.url);
    expect(calls, callsBeforeRestore);
  });

  test('an empty refreshed source retains only its own last known streams', () async {
    var refresh = false;
    final repo = ChannelRepository(client: MockClient((request) async {
      if (request.url == ChannelRepository.sportsPlaylist) {
        return http.Response(refresh ? '#EXTM3U\n' :
            '#EXTM3U\n#EXTINF:-1,Esporte\nhttps://example.com/sport\n', 200);
      }
      return http.Response('#EXTM3U\n#EXTINF:-1,TV\n'
          'https://example.com/${refresh ? 'new' : 'old'}\n', 200);
    }));
    await repo.loadBrazilPublicDirectory();
    refresh = true;
    final refreshed = await repo.loadBrazilPublicDirectory(forceRefresh: true);
    expect(refreshed.map((c) => c.url), containsAll([
      'https://example.com/new', 'https://example.com/sport']));
    expect(refreshed.map((c) => c.url), isNot(contains('https://example.com/old')));
  });
}
