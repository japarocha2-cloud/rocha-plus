import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);

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
}
