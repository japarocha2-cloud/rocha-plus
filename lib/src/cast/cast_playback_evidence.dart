class CastPlaybackEvidence {
  static bool matches(String requested, String? contentId, Uri? contentUrl) =>
      contentId == requested || contentUrl?.toString() == requested;

  static bool confirms({
    required String requested,
    String? contentId,
    Uri? contentUrl,
    required bool playing,
  }) => playing && matches(requested, contentId, contentUrl);
}

/// A transient PLAYING status alone is not enough for initial confirmation.
class CastPlaybackProgress {
  Duration? _first;
  bool observe({required String requested, String? contentId, Uri? contentUrl,
      required bool playing, required Duration position}) {
    if (!CastPlaybackEvidence.confirms(requested: requested, contentId: contentId,
        contentUrl: contentUrl, playing: playing)) {
      return false;
    }
    _first ??= position;
    return position - _first! >= const Duration(milliseconds: 500);
  }
}
