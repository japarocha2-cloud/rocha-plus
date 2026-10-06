import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'm3u_parser.dart';

class ChannelRepository {
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');

  static List<Channel>? _memoryCache;

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) return _memoryCache!;

    final res = await http
        .get(developmentPlaylist)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Não foi possível carregar o catálogo.');
    }

    final parsed = M3uParser.parse(utf8.decode(res.bodyBytes));
    final cleaned = _cleanAndPrioritize(parsed);
    _memoryCache = List.unmodifiable(cleaned);
    return _memoryCache!;
  }

  List<Channel> _cleanAndPrioritize(List<Channel> input) {
    final seenUrls = <String>{};
    final seenNames = <String>{};
    final cleaned = <Channel>[];

    for (final channel in input) {
      final name = channel.name.trim();
      final url = channel.url.trim();
      if (name.isEmpty || url.isEmpty) continue;

      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        continue;
      }

      final normalizedName = name
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .trim();
      if (!seenUrls.add(url) || !seenNames.add(normalizedName)) continue;
      cleaned.add(channel);
    }

    cleaned.sort((a, b) {
      final priority = _channelPriority(a.name).compareTo(_channelPriority(b.name));
      if (priority != 0) return priority;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return cleaned;
  }

  int _channelPriority(String rawName) {
    final name = rawName.toLowerCase();
    // Rocha+ requested order: SBT first, then Globo, Record and Band.
    if (RegExp(r'(^|\s)sbt(\s|$)').hasMatch(name)) return 0;
    if (name.contains('globo')) return 1;
    if (name.contains('record')) return 2;
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
