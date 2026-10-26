import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/playback_failure.dart';

void main() {
  testWidgets('a live source can finish initializing after the old eight second limit', (tester) async {
    final ready = Completer<void>();
    var completed = false;
    Object? failure;
    unawaited(initializeLivePlayback(() => ready.future).then<void>(
      (_) { completed = true; },
      onError: (Object error) { failure = error; },
    ));
    await tester.pump(const Duration(seconds: 9));
    expect(completed, isFalse);
    expect(failure, isNull);
    ready.complete();
    await tester.pump();
    expect(completed, isTrue);
    expect(failure, isNull);
  });

  testWidgets('a hung initializer still times out and late completion cannot succeed', (tester) async {
    final ready = Completer<void>();
    var completed = false;
    Object? failure;
    unawaited(initializeLivePlayback(() => ready.future).then<void>(
      (_) { completed = true; },
      onError: (Object error) { failure = error; },
    ));
    await tester.pump(const Duration(seconds: 31));
    expect(failure, isA<TimeoutException>());
    expect(completed, isFalse);
    ready.complete();
    await tester.pump();
    expect(completed, isFalse);
  });

  test('classifies native HTTP errors without exposing source URLs or tokens', () {
    const secret = 'private-source-token';
    for (final status in [401, 403]) {
      final failure = PlaybackFailure.from(
        'InvalidResponseCodeException: Response code: $status, '
        'https://example.test/live?token=$secret',
      );
      expect(failure, PlaybackFailure.accessDenied);
      expect(failure.message, isNot(contains(secret)));
      expect(failure.message, isNot(contains('example.test')));
    }
    expect(PlaybackFailure.from('HTTP error 404'), PlaybackFailure.notFound);
    expect(PlaybackFailure.from('Response code: 503'), PlaybackFailure.server);
    expect(PlaybackFailure.from(TimeoutException('late')), PlaybackFailure.timeout);
    expect(PlaybackFailure.from('DecoderInitializationException'), PlaybackFailure.decoder);
    expect(PlaybackFailure.from('SocketException'), PlaybackFailure.network);
    expect(PlaybackFailure.from('https://example.test/?token=403'), PlaybackFailure.unknown);
    expect(PlaybackFailure.from('unclassified $secret').message, isNot(contains(secret)));
  });
}
