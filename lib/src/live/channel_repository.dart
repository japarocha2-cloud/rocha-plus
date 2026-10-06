import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'channel.dart';
import 'm3u_parser.dart';

class ChannelRepository {
  static const _catalogCacheKey = 'rocha_plus_channel_catalog_v1';
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');

  static List<Channel>? _memoryCache;

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) return _memoryCache!;

    final prefs = await SharedPreferences.getInstance();
    final cachedSource = prefs.getString(_catalogCacheKey);

    try {
      final res = await http
          .get(developmentPlaylist)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('Não foi possível carregar o catálogo.');
      }

      final source = utf8.decode(res.bodyBytes);
      final parsed = M3uParser.parse(source);
      final cleaned = _cleanAndPrioritize(parsed);
      if (cleaned.isEmpty) {
        throw Exception('O catálogo recebido não contém canais válidos.');
      }

      await prefs.setString(_catalogCacheKey, source);
      _memoryCache = List.unmodifiable(cleaned);
      return _memoryCache!;
    } catch (_) {
      if (cachedSource != null && cachedSource.isNotEmpty) {
        final cached = _cleanAndPrioritize(M3uParser.parse(cachedSource));
        if (cached.isNotEmpty) {
          _memoryCache = List.unmodifiable(cached);
          return _memoryCache!;
        }
      }
      rethrow;
    }
  }

  List<Channel> _cleanAndPrioritize(List<Channel> input) {
    final seenUrls = <String>{};
    final bestByName = <String, Channel>{};

    for (final channel in input) {
      final name = channel.name.trim();
      final url = channel.url.trim();
      if (name.isEmpty || url.isEmpty) {
        continue;
      }

      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
        continue;
      }

      final lowerName = name.toLowerCase();
      if (lowerName.contains('[geo-blocked]') ||
          lowerName.contains('[not 24/7]') ||
          lowerName == 'sbt cuiaba') {
        continue;
      }
      if (!seenUrls.add(url)) {
        continue;
      }

      final normalizedName = name
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .trim();

      final current = bestByName[normalizedName];
      if (current == null ||
          _playbackPreference(channel) < _playbackPreference(current)) {
        bestByName[normalizedName] = channel;
      }
    }

    final cleaned = bestByName.values.toList(growable: false);
    cleaned.sort((a, b) {
      final priority = _channelPriority(a.name).compareTo(_channelPriority(b.name));
      if (priority != 0) {
        return priority;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return cleaned;
  }

  int _playbackPreference(Channel channel) {
    final name = channel.name.toLowerCase();
    final path = Uri.tryParse(channel.url)?.path.toLowerCase() ?? '';

    var score = 10;
    if (path.endsWith('.m3u8')) score -= 4;

    // On phones and Cast, a stable HD feed usually beats a fixed ultra-high
    // bitrate feed. Keep 1080p/4K when it is the only available source.
    if (name.contains('720p') || RegExp(r'(^|\W)hd($|\W)').hasMatch(name)) {
      score -= 3;
    }
    if (name.contains('1080p') || name.contains('fhd')) score -= 1;
    if (name.contains('2160p') || name.contains('4k') || name.contains('uhd')) {
      score += 3;
    }
    if (name.contains('480p') || name.contains('360p') || name.contains('sd')) {
      score += 2;
    }
    return score;
  }

  int _channelPriority(String rawName) {
    final name = rawName.toLowerCase();
    // Rocha+ requested order: SBT first, then Globo, Record and Band.
    if (RegExp(r'(^|\s)sbt(\s|$)').hasMatch(name)) {
      return 0;
    }
    if (name.contains('globo')) {
      return 1;
    }
    if (name.contains('record')) {
      return 2;
    }
    if (RegExp(r'(^|\s)band(\s|$)').hasMatch(name) ||
        name.contains('bandnews')) {
      return 3;
    }

    // Other nationally known/public directory brands ahead of regional feeds.
    if (name.contains('tv brasil') ||
        name.contains('cultura') ||
        name.contains('canal gov') ||
        name.contains('senado') ||
        name.contains('câmara') ||
        name.contains('camara')) {
      return 4;
    }
    return 10;
  }
}
