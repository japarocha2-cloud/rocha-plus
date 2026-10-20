import 'player_lab_results.dart';

/// Collects timed observations, including HLS stalls when playhead does not
/// advance. Clock time comes from the caller and must be monotonic.
class LabObserver {
  final LabEngine engine;
  int? _lastTimestamp;
  Duration? _lastPosition;
  bool _wasStalled = false;
  int _stationaryMs = 0;
  int? _firstProgress;
  int _bufferingMs = 0;
  int _stalls = 0;
  int _progressMs = 0;
  bool _videoTrack = false;
  bool _audioTrack = false;
  String? _error;

  LabObserver(this.engine);

  void observe({
    required int milliseconds,
    required Duration position,
    required bool playing,
    required bool buffering,
    required bool videoTrack,
    required bool audioTrack,
    String? error,
  }) {
    final delta = _lastTimestamp == null
        ? 0
        : (milliseconds - _lastTimestamp!).clamp(0, 3600000).toInt();
    final advanced = _lastPosition != null && position > _lastPosition!;
    if (advanced) {
      final positionDelta = (position - _lastPosition!).inMilliseconds;
      _progressMs += positionDelta.clamp(0, delta).toInt();
      _firstProgress ??= milliseconds;
    }
    _stationaryMs = playing && !buffering && !advanced
        ? _stationaryMs + delta
        : 0;
    // One-second API updates are not necessarily a playback freeze.
    final stalled = _stationaryMs >= 3000;
    if (stalled && !_wasStalled) _stalls++;
    _wasStalled = stalled;
    if (buffering) _bufferingMs += delta;
    _videoTrack |= videoTrack;
    _audioTrack |= audioTrack;
    if (error != null && error.isNotEmpty) _error = error;
    _lastTimestamp = milliseconds;
    _lastPosition = position;
  }

  LabSample finish(int elapsedMilliseconds) => LabSample(
    engine: engine,
    elapsedSeconds: elapsedMilliseconds ~/ 1000,
    startupMilliseconds: _firstProgress ?? elapsedMilliseconds,
    bufferingMilliseconds: _bufferingMs,
    stalls: _stalls,
    progressSeconds: _progressMs ~/ 1000,
    videoTrackDetected: _videoTrack,
    audioTrackDetected: _audioTrack,
    error: _error,
  );
}
