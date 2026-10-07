class PlaybackEvidence {
  Duration _baseline = Duration.zero;
  bool confirmed = false;
  void reset(Duration position) {
    _baseline = position;
    confirmed = false;
  }
  bool observe({
    required Duration position,
    required bool isPlaying,
    required bool isBuffering,
    required bool hasError,
  }) {
    if (hasError) { confirmed = false; return false; }
    if (!confirmed && isPlaying && !isBuffering && position > _baseline) {
      confirmed = true;
      return true;
    }
    return false;
  }
}
