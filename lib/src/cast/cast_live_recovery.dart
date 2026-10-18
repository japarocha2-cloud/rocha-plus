import 'dart:async';

/// Bounded recovery of the same approved live source, with one optional relay.
class CastLiveRecovery {
  Uri current;
  final Future<void> Function(Uri) reload;
  final Future<Uri> Function()? relay;
  final bool Function() canRecover;
  final Future<void> Function() giveUp;
  int attempts = 0;
  bool _disposed = false;
  bool _gaveUp = false;
  Future<bool>? _pending;
  CastLiveRecovery({required this.current, required this.reload,
    required this.canRecover, required this.giveUp, this.relay});

  bool get busy => _pending != null;
  Future<bool> recover() => _pending ??= _recover().whenComplete(() => _pending = null);
  Future<bool> _recover() async {
    while (!_disposed && canRecover() && attempts < 2) {
      attempts++;
      try {
        // First retry starts at live edge. Second may change only transport.
        if (attempts == 2 && relay != null) current = await relay!();
        if (_disposed || !canRecover()) return false;
        await reload(current);
        if (_disposed || !canRecover()) return false;
        return true;
      } catch (_) { /* Try the next bounded transport or finish locally. */ }
    }
    if (!_disposed && canRecover() && !_gaveUp) {
      _gaveUp = true;
      await giveUp();
    }
    return false;
  }
  void dispose() { _disposed = true; }
}

/// Buffering/PLAYING without advancing media is different from deliberate pause.
class CastStallWatchdog {
  Duration? _position;
  Duration? _lastProgress;
  final Duration limit;
  CastStallWatchdog({this.limit = const Duration(seconds: 15)});
  void reset() { _position = null; _lastProgress = null; }
  bool observe({required Duration position, required Duration now, required bool paused}) {
    if (_lastProgress == null || paused || (_position != null && position > _position!)) {
      _lastProgress = now;
    }
    _position = position;
    return !paused && now - _lastProgress! >= limit;
  }
}
