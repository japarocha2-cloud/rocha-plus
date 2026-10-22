import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import 'cast_hls_proxy.dart';
import 'cast_readiness.dart';

Future<void> _receiverShutdown = Future<void>.value();

/// Requests receiver shutdown and closes the local relay independently.
/// A disconnected/offline receiver still requires physical verification.
Future<void> revokeCastPlayback({
  Future<void> Function()? closeRelay,
  Future<bool> Function()? isReady,
  Future<void> Function()? stopReceiver,
}) async {
  final relay = (closeRelay ?? CastHlsProxy.instance.close)()
      .timeout(const Duration(seconds: 3));
  // A new protected session must wait for older receiver stop requests too.
  final receiver = _receiverShutdown.then((_) async {
    if (await (isReady?.call() ?? CastReadiness.ready)
        .timeout(const Duration(seconds: 3))) {
      await (stopReceiver ?? GoogleCastSessionManager.instance.endSessionAndStopCasting)()
          .timeout(const Duration(seconds: 8));
    }
  });
  _receiverShutdown = receiver.catchError((Object _) {});
  await Future.wait<void>([
    relay,
    receiver,
  ]);
}
