/// Official CazéTV video identifier for YouTube's embedded player.
class CazeTvSource {
  const CazeTvSource._();

  // YouTube requires the installed app ID as the WebView HTTP Referer.
  // Keep this aligned with Android's applicationId (com.rochaplus.app).
  static const appHttpReferer = 'https://com.rochaplus.app/';

  static const configuredVideoId =
      String.fromEnvironment('CAZETV_YOUTUBE_VIDEO_ID');

  static bool isValidVideoId(String value) {
    if (value.length != 11) return false;
    for (final unit in value.codeUnits) {
      final digit = unit >= 48 && unit <= 57;
      final upper = unit >= 65 && unit <= 90;
      final lower = unit >= 97 && unit <= 122;
      if (!(digit || upper || lower || unit == 45 || unit == 95)) return false;
    }
    return true;
  }

  static String? get officialVideoId =>
      isValidVideoId(configuredVideoId) ? configuredVideoId : null;

  static Uri? get embedUri {
    final id = officialVideoId;
    if (id == null) return null;
    return Uri.https('www.youtube.com', '/embed/$id', const {
      'playsinline': '1',
      'controls': '1',
      'rel': '0',
    });
  }
}
