import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/validated_lab_repository.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

Map<String, dynamic> sample(String engine) => {
  'engine': engine,
  'elapsedSeconds': 180,
  'startupMilliseconds': 1000,
  'bufferingMilliseconds': 0,
  'stalls': 0,
  'progressSeconds': 178,
  'videoTrackDetected': true,
  'audioTrackDetected': true,
  'error': null,
};
Map<String, dynamic> candidate(String url) => {
  'name': 'Canal Validado',
  'url': url,
  'group': 'Filmes',
  'genres': ['Comédia'],
  'status': 'automatic_audiovisual_pass',
  'eligible': true,
  'blocked': false,
  'result': {
    'channelName': 'Canal Validado',
    'channelUrl': url,
    'group': 'Filmes',
    'testedAt': '2026-10-20T00:00:00Z',
    'exo': sample('exoPlayer'),
    'vlc': sample('libVlc'),
    'confirmation': sample('libVlc'),
    'preferred': 'libVlc',
    'measuredEvidence': {
      'confirmation': {
        'changingPixelsObserved': true,
        'audioOutputObserved': true,
      },
    },
  },
};
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  test('stored user block survives a fresh validated repository', () async {
    SharedPreferences.setMockInitialValues({
      'rocha_blocked_channel_names_v1': ['canal validado'],
    });
    final repo = ValidatedLabRepository(
      read: () async => jsonEncode([candidate('https://example.test/pass')]),
    );
    expect(await repo.loadBrazilPublicDirectory(), isEmpty);
  });
  test(
    'empty approved snapshot never loads the live candidate directory',
    () async {
      final repo = ValidatedLabRepository(read: () async => '[]');
      expect(await repo.loadBrazilPublicDirectory(), isEmpty);
    },
  );
  test('rejects pending, blocked, missing PCM and incomplete confirmation', () async {
    final pass = candidate('https://example.test/pass');
    final pending = candidate('https://example.test/pending')
      ..['status'] = 'pending';
    final blocked = candidate('https://example.test/blocked')
      ..['blocked'] = true;
    final silent = candidate('https://example.test/silent');
    silent['result']['measuredEvidence']['confirmation']['audioOutputObserved'] =
        false;
    final short = candidate('https://example.test/short');
    short['result']['confirmation']['elapsedSeconds'] = 60;
    final repo = ValidatedLabRepository(
      read: () async => jsonEncode([pending, blocked, silent, short, pass]),
    );
    final channels = await repo.loadBrazilPublicDirectory();
    expect(channels, hasLength(1));
    expect(channels.single.url, pass['url']);
    expect(channels.single.preferredEngine, 'libVlc');
    expect(channels.single.genres, ['Comédia']);
  });
}
