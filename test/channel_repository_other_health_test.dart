import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  test('physical failures stay blocked after session reset and source changes', () {
    const failed = <String>['Pluto TV Turbo', 'Laboral TV (360p)', 'Detetives Medicos', 'Pluto TV Aliens', 'Pluto TV Animais'];
    for (final name in failed) {
      for (final url in ['https://example.com/old.m3u8', 'https://example.com/new.m3u8']) {
        ChannelRepository.resetSessionHealthForTests();
        expect(ChannelRepository().isBlocked(Channel(name: name, url: url, group: 'Documentary')),
          isTrue, reason: name);
      }
    }
    ChannelRepository.resetSessionHealthForTests();
    expect(ChannelRepository().isBlocked(Channel(name: 'Pluto TV Investigacao',
      url: 'https://example.com/pending.m3u8', group: 'Documentary')), isFalse,
      reason: 'Interruption before result must not block an untested channel');
  });
}
