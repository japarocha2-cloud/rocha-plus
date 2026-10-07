import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);
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
