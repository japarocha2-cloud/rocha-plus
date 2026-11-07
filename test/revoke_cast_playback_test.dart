import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/cast/revoke_cast_playback.dart';

void main() {
  test('new session cleanup waits for older pending receiver shutdown', () async {
    final firstStop = Completer<void>();
    final started = Completer<void>();
    var secondStops = 0;
    final first = revokeCastPlayback(
      closeRelay: () async {}, isReady: () async => true,
      stopReceiver: () async { started.complete(); await firstStop.future; },
    );
    await started.future;
    final second = revokeCastPlayback(
      closeRelay: () async {}, isReady: () async => true,
      stopReceiver: () async { secondStops++; },
    );
    await Future<void>.delayed(Duration.zero);
    expect(secondStops, 0);
    firstStop.complete();
    await Future.wait([first, second]);
    expect(secondStops, 1);
  });

  test('receiver stop is still requested if closing relay fails', () async {
    var stops = 0;
    await expectLater(revokeCastPlayback(
      closeRelay: () async => throw StateError('relay failed'),
      isReady: () async => true,
      stopReceiver: () async { stops++; },
    ), throwsStateError);
    expect(stops, 1);
  });

  test('relay is closed even if receiver cannot confirm shutdown', () async {
    var closes = 0;
    await expectLater(revokeCastPlayback(
      closeRelay: () async { closes++; },
      isReady: () async => true,
      stopReceiver: () async => throw StateError('receiver offline'),
    ), throwsStateError);
    expect(closes, 1);
  });

  test('a device without initialized Cast still closes its relay', () async {
    var closes = 0;
    var stops = 0;
    await revokeCastPlayback(
      closeRelay: () async { closes++; },
      isReady: () async => false,
      stopReceiver: () async { stops++; },
    );
    expect(closes, 1);
    expect(stops, 0);
  });
}
