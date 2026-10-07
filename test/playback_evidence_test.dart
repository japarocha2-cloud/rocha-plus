import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/playback_evidence.dart';

void main() {
  test('play command and buffering are not evidence of advancing video', () {
    final evidence = PlaybackEvidence()..reset(Duration.zero);
    expect(evidence.observe(position: Duration.zero, isPlaying: true,
        isBuffering: false, hasError: false), isFalse);
    expect(evidence.observe(position: const Duration(seconds: 1), isPlaying: true,
        isBuffering: true, hasError: false), isFalse);
    expect(evidence.confirmed, isFalse);
    expect(evidence.observe(position: const Duration(seconds: 2), isPlaying: true,
        isBuffering: false, hasError: false), isTrue);
    expect(evidence.observe(position: const Duration(seconds: 3), isPlaying: true,
        isBuffering: false, hasError: false), isFalse);
  });
  test('errors and retries clear evidence, paused positions do not confirm', () {
    final evidence = PlaybackEvidence()..reset(const Duration(seconds: 5));
    expect(evidence.observe(position: const Duration(seconds: 6), isPlaying: false,
        isBuffering: false, hasError: false), isFalse);
    expect(evidence.observe(position: const Duration(seconds: 6), isPlaying: true,
        isBuffering: false, hasError: false), isTrue);
    evidence.observe(position: const Duration(seconds: 6), isPlaying: false,
        isBuffering: false, hasError: true);
    expect(evidence.confirmed, isFalse);
    evidence.reset(const Duration(seconds: 10));
    expect(evidence.observe(position: const Duration(seconds: 9), isPlaying: true,
        isBuffering: false, hasError: false), isFalse);
  });
}
