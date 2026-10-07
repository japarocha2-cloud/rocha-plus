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
