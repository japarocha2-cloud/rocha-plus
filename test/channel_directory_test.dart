import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

Map<String, Object?> approved(String name, String url) => {
  'name': name, 'url': url, 'approved': true, 'status': 'approved',
  'group': 'TV aberta',
  'evidence': {'decoded_seconds': 30, 'video_codec': 'h264', 'audio_codec': 'aac'},
};

ChannelRepository repository(List<Object?> entries, {List<Object?> excluded = const []}) =>
    ChannelRepository(catalogLoader: () async => jsonEncode(entries),
      quarantineLoader: () async => jsonEncode(excluded),
      client: MockClient((_) async => throw StateError('Public catalogue fallback forbidden')));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });

  test('refresh never imports channels outside the selected catalogue', () async {
    final repo = repository([approved('Canal', 'https://example.com/live')]);
    expect(await repo.loadBrazilPublicDirectory(), hasLength(1));
    expect(await repo.loadBrazilPublicDirectory(forceRefresh: true), hasLength(1));
  });

  test('quarantine and historical removals survive quality and URL changes', () async {
    final repo = repository([
      approved('Removido (1080p)', 'https://example.com/new'),
      approved('1001 Noites', 'https://example.com/new2'),
      approved('Canal', 'https://example.com/live'),
    ], excluded: [{'name': 'Removido (720p)', 'reason': 'timeout'}]);
    expect((await repo.loadBrazilPublicDirectory()).single.name, 'Canal');
    await repo.restoreUserBlockedChannels();
    expect((await repo.loadBrazilPublicDirectory(forceRefresh: true)).single.name, 'Canal');
  });

  test('unapproved, insecure, silent and untested sources are excluded', () async {
    final repo = repository([
      approved('OK', 'https://example.com/ok'),
      {...approved('No approval', 'https://example.com/no'), 'approved': false},
      approved('HTTP', 'http://example.com/http'),
      {...approved('No evidence', 'https://example.com/unknown'), 'evidence': null},
      {...approved('Silent', 'https://example.com/silent'),
        'evidence': {'decoded_seconds': 30, 'video_codec': 'h264', 'audio_codec': ''}},
    ]);
    expect((await repo.loadBrazilPublicDirectory()).single.name, 'OK');
  });

  test('playback errors and legacy failure cache cannot hide approved channels', () async {
    final entries = [approved('Canal', 'https://example.com/live')];
    SharedPreferences.setMockInitialValues({
      'rocha_rejected_channel_urls_v1': ['https://example.com/live'],
    });
    final first = repository(entries);
    await first.loadBrazilPublicDirectory();
    await first.reportPlaybackFailure('https://example.com/live');
    ChannelRepository.resetSessionHealthForTests();
    final second = repository(entries);
    expect((await second.loadBrazilPublicDirectory()).single.name, 'Canal');
    second.reportPlaybackSuccess('https://example.com/live');
    await second.restoreUserBlockedChannels();
    expect((await second.loadBrazilPublicDirectory(forceRefresh: true)).single.name, 'Canal');
  });

  test('concurrent loads share asset reads and preserve the original URL', () async {
    var reads = 0;
    final gate = Completer<void>();
    final repo = ChannelRepository(quarantineLoader: () async => '[]', catalogLoader: () async {
      reads++;
      await gate.future;
      return jsonEncode([approved('Canal', 'https://example.com/master.m3u8?quality=original')]);
    });
    final first = repo.loadBrazilPublicDirectory();
    final second = repo.loadBrazilPublicDirectory();
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(reads, 1);
    expect(results.first.single.url, 'https://example.com/master.m3u8?quality=original');
  });

  test('invalid assets fail closed without public playlist requests', () async {
    final repo = ChannelRepository(catalogLoader: () async => '{}', quarantineLoader: () async => '[]',
      client: MockClient((_) async => throw StateError('Unexpected network request')));
    await expectLater(repo.loadBrazilPublicDirectory(), throwsFormatException);
    expect(await repository([]).loadBrazilPublicDirectory(), isEmpty);
  });
}
