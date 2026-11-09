import 'dart:async';

/// Observes terminal connection states independently of the control route.
/// False, a stream error, or stream completion invalidate this observation once.
class CastConnectionObserver {
  CastConnectionObserver(
    Stream<bool> connected, {
    required void Function() onDisconnected,
    bool Function()? isDisconnected,
  }) : _onDisconnected = onDisconnected {
    final subscription = connected.listen(
      (value) {
        if (!value) _disconnect();
      },
      onError: (Object error, StackTrace stack) => _disconnect(),
      onDone: _disconnect,
    );
    if (_active) {
      _subscription = subscription;
      // A terminal event may have happened just before the subscription attached.
      try {
        if (isDisconnected?.call() == true) _disconnect();
      } catch (_) {
        _disconnect();
      }
    } else {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
  }

  final void Function() _onDisconnected;
  StreamSubscription<bool>? _subscription;
  bool _active = true;

  void _disconnect() {
    if (!_active) return;
    dispose();
    _onDisconnected();
  }

  void dispose() {
    _active = false;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
  }
}
