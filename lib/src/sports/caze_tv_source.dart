/// CazéTV playback configuration.
///
/// A build may inject the official embeddable YouTube video id. Keeping this
/// outside the UI lets Rocha+ update the source without coupling it to Player
/// or Cast. It intentionally stores only a YouTube video id, never a media URL.
class CazeTvSource {
  const CazeTvSource._();

  static const configuredVideoId =
      String.fromEnvironment('CAZETV_YOUTUBE_VIDEO_ID');

  static bool isValidVideoId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{11}\$').hasMatch(value);

  static String? get officialVideoId =>
      isValidVideoId(configuredVideoId) ? configuredVideoId : null;

  static Uri? get embedUri {
    final id = officialVideoId;
    if (id == null) return null;
    return Uri.https('www.youtube.com', '/embed/\$id', const {
      'playsinline': '1',
      'controls': '1',
      'rel': '0',
    });
  }
}
