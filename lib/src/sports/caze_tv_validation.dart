import 'dart:convert';
import 'package:http/http.dart' as http;
import 'caze_tv_source.dart';

/// Checks publisher metadata on YouTube itself; never downloads media.
/// Metadata is not proof of playback or of current regional embed permission.
class CazeTvValidation {
  const CazeTvValidation._();

  static bool isOfficialAuthor(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' ||
        uri.host != 'www.youtube.com' ||
        uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return false;
    }
    return uri.path.toLowerCase() == '/@cazetv' ||
        uri.path == '/channel/UCZiYbVptd3PVPf4f6eR6UaQ';
  }

  static Future<bool> verify(String id, {http.Client? client}) async {
    if (!CazeTvSource.isValidVideoId(id)) return false;
    final transport = client ?? http.Client();
    try {
      final uri = Uri.https('www.youtube.com', '/oembed', {
        'url': Uri.https('www.youtube.com', '/watch', {'v': id}).toString(),
        'format': 'json',
      });
      final response = await transport.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> &&
          data['type'] == 'video' &&
          data['provider_name'] == 'YouTube' &&
          data['author_url'] is String &&
          isOfficialAuthor(data['author_url'] as String);
    } catch (_) {
      return false;
    } finally {
      if (client == null) transport.close();
    }
  }
}
