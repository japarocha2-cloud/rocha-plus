import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  Map<String, Object> entry(String name, String url) =>
      {'name': name, 'url': url, 'approved': true, 'status': 'approved'};
  test('only reviewed entries load and no remote playlist is requested', () async {
    final repo = ChannelRepository(
      client: MockClient((_) async => throw StateError('Remote catalogue forbidden')),
      catalogLoader: () async => jsonEncode([
        entry('SBT', 'https://example.com/sbt.m3u8'),
        {'name': 'Candidate', 'url': 'https://example.com/unverified.m3u8'},
        {...entry('Blocked', 'https://example.com/blocked.m3u8'), 'blocked': true},
        entry('RecordTV', 'https://example.com/record.m3u8'),
      ]));
    final channels = await repo.loadBrazilPublicDirectory();
    expect(channels.map((c) => c.name), ['SBT']);
    expect(await repo.loadBrazilPublicDirectory(forceRefresh: true), hasLength(1));
  });
  test('failure removes a cached approved stream until playback succeeds', () async {
    var calls = 0;
    final repo = ChannelRepository(catalogLoader: () async {
      calls++;
      return jsonEncode([entry('SBT', 'https://example.com/live.m3u8')]);
    });
    await repo.loadBrazilPublicDirectory();
    repo.reportPlaybackFailure('https://example.com/live.m3u8');
    expect(await repo.loadBrazilPublicDirectory(), isEmpty);
    repo.reportPlaybackSuccess('https://example.com/live.m3u8');
    expect(await repo.loadBrazilPublicDirectory(), hasLength(1));
    expect(calls, 1);
  });
  test('empty reviewed catalogue stays empty without a candidate fallback', () async {
    final repo = ChannelRepository(catalogLoader: () async => '[]');
    expect(await repo.loadBrazilPublicDirectory(), isEmpty);
  });
  test('catalogue order is preserved and concurrent loads share one read', () async {
    var calls = 0;
    final repo = ChannelRepository(catalogLoader: () async {
      calls++;
      return jsonEncode([entry('SBT', 'https://example.com/a.m3u8'),
        entry('Regional', 'https://example.com/b.m3u8')]);
    });
    final results = await Future.wait([repo.loadBrazilPublicDirectory(), repo.loadBrazilPublicDirectory()]);
    expect(calls, 1);
    expect(results.first.map((c) => c.name), ['SBT', 'Regional']);
  });
  test('invalid approved asset fails closed', () async {
    final repo = ChannelRepository(catalogLoader: () async => '{}');
    await expectLater(repo.loadBrazilPublicDirectory(), throwsFormatException);
  });
}
