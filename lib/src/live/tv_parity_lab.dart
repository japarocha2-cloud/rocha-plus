import 'dart:convert';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'channel.dart';

/// Opt-in LAB reader; never changes the normal channel repository.
class TvParityLab {
  static const asset = 'docs/tv/roku-android-parity-12.json';

  static Future<List<Channel>> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    final parsed = jsonDecode(raw);
    if (parsed is! Map<String, dynamic> ||
        parsed['production_approved'] != false ||
        parsed['channels'] is! List) {
      throw const FormatException('Invalid experimental TV catalogue');
    }
    final channels = <Channel>[];
    final urls = <String>{};
    for (final entry in parsed['channels'] as List) {
      if (entry is! Map<String, dynamic> ||
          entry['production_approved'] != false ||
          entry['roku_result'] != 'not_tested' ||
          entry['android_tv_result'] != 'not_tested') {
        throw const FormatException('Unsafe LAB channel');
      }
      final url = entry['url'];
      final name = entry['name'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
          uri.userInfo.isNotEmpty || !urls.add(url) ||
          name is! String || name.trim().isEmpty) {
        throw const FormatException('Invalid LAB stream');
      }
      channels.add(Channel(
        name: name,
        url: url,
        group: entry['group'] is String ? entry['group'] as String : 'Outros',
        logo: entry['logo'] is String && (entry['logo'] as String).startsWith('https://')
            ? entry['logo'] as String : null,
      ));
    }
    if (channels.length != 12) {
      throw const FormatException('LAB must contain 12 channels');
    }
    return List.unmodifiable(channels);
  }
}
