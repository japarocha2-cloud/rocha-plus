import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'm3u_parser.dart';

class ChannelRepository {
  static final http.Client _client = http.Client();
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');
  static final Uri sportsPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/categories/sports.m3u');

  static List<Channel>? _memoryCache;

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) return _memoryCache!;

    final results = await Future.wait([
      _loadPlaylist(developmentPlaylist),
      _loadPlaylist(sportsPlaylist),
    ]);

    final brazil = results[0];
    final sports = results[1]
        .map((channel) => Channel(
              name: channel.name,
              url: channel.url,
              logo: channel.logo,
              group: 'Esportes',
            ))
        .toList(growable: false);

    final merged = <String, Channel>{};
    for (final channel in [...brazil, ...sports]) {
      merged[channel.url] = channel;
    }

    // A varredura roda em lotes para não disparar centenas de conexões
    // simultâneas. Canais sem resposta HTTP válida não entram no catálogo.
    final online = await _keepReachable(merged.values.toList(growable: false));
    final ordered = _orderSportsFirst(online);
    if (ordered.isNotEmpty) {
      _memoryCache = List.unmodifiable(ordered);
    }

    // Se houver uma falha geral de rede, preserva o último catálogo saudável.
    if (_memoryCache != null) return _memoryCache!;
    throw Exception('Não foi possível carregar canais disponíveis.');
  }

  Future<List<Channel>> _loadPlaylist(Uri playlist) async {
    final res = await _client.get(playlist).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Não foi possível carregar o catálogo.');
    }
    return M3uParser.parse(utf8.decode(res.bodyBytes));
  }

  Future<List<Channel>> _keepReachable(List<Channel> channels) async {
    const batchSize = 12;
    final online = <Channel>[];

    for (var start = 0; start < channels.length; start += batchSize) {
      final end = (start + batchSize < channels.length)
          ? start + batchSize
          : channels.length;
      final batch = channels.sublist(start, end);
      final checks = await Future.wait(batch.map(_isReachable));
      for (var i = 0; i < batch.length; i++) {
        if (checks[i]) online.add(batch[i]);
      }
    }
    return online;
  }

  List<Channel> _orderSportsFirst(List<Channel> channels) {
    final indexed = channels.asMap().entries.toList(growable: false);
    indexed.sort((a, b) {
      final aScore = _sportsPriority(a.value);
      final bScore = _sportsPriority(b.value);
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  int _sportsPriority(Channel channel) {
    if (channel.group != 'Esportes') return 0;

    final name = channel.name.toLowerCase();

    // Futebol vem antes dos demais esportes. Termos das competições
    // recebem peso extra quando aparecem no nome/metadado do canal.
    final footballTerms = [
      'futebol', 'football', 'soccer', 'brasileir', 'champions',
      'libertadores', 'sul-americana', 'copa', 'serie a', 'série a',
      'premier league', 'la liga', 'bundesliga'
    ];
    final womenTerms = [
      'feminino', 'feminina', 'women', 'womens', "women's", 'femenino'
    ];

    final isFootball = footballTerms.any(name.contains);
    final isWomen = womenTerms.any(name.contains);

    var score = 100; // outros esportes
    if (isFootball) score = isWomen ? 800 : 900;
    if (name.contains('brasileir')) score += 90;
    if (name.contains('champions')) score += 85;
    if (name.contains('libertadores')) score += 60;
    if (name.contains('sul-americana')) score += 50;

    return score;
  }


  Uri? _firstMediaUri(String playlist, Uri base) {
    for (final raw in const LineSplitter().convert(playlist)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final resolved = base.resolve(line);
      if (resolved.scheme == 'https') return resolved;
    }
    return null;
  }

  Future<bool> _validateMediaPlaylist(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 400) return false;
      final sample = utf8.decode(response.bodyBytes, allowMalformed: true).trimLeft();
      if (!sample.startsWith('#EXTM3U')) return false;

      // Alguns masters possuem mais de um nível antes da playlist de mídia.
      if (sample.contains('#EXT-X-STREAM-INF')) {
        final child = _firstMediaUri(sample, uri);
        if (child == null || child == uri) return false;
        return await _validateMediaPlaylist(child);
      }

      if (!sample.contains('#EXTINF')) return false;
      final segment = _firstMediaUri(sample, uri);
      return segment != null && await _probeMedia(segment);
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeMedia(Uri uri) async {
    try {
      final request = http.Request('GET', uri)
        ..headers['Range'] = 'bytes=0-2047'
        ..headers['User-Agent'] = 'RochaPlus/0.1';
      final response = await _client.send(request).timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 400) {
        await response.stream.drain<void>();
        return false;
      }
      final bytes = await response.stream.take(2048).expand((chunk) => chunk).toList();
      return bytes.isNotEmpty;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isReachable(Channel channel) async {
    final uri = Uri.tryParse(channel.url);
    if (uri == null || uri.scheme != 'https') {
      return false;
    }

    try {
      // GET com Range funciona melhor que HEAD em servidores HLS/CDN
      // que recusam HEAD mesmo quando o stream está ativo.
      final request = http.Request('GET', uri)
        ..headers['Range'] = 'bytes=0-1023'
        ..headers['User-Agent'] = 'RochaPlus/0.1';
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 400) {
        await response.stream.drain<void>();
        return false;
      }

      // HTTP 200 sozinho não prova que um canal toca. Para HLS, validamos
      // se a resposta realmente parece uma playlist e se ela anuncia mídia.
      final bytes = await response.stream.take(4096).expand((chunk) => chunk).toList();
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final sample = utf8.decode(bytes, allowMalformed: true).trimLeft();
      final looksLikeHls = contentType.contains('mpegurl') ||
          channel.url.toLowerCase().contains('.m3u8') ||
          sample.startsWith('#EXTM3U');
      if (!looksLikeHls) return bytes.isNotEmpty;

      if (!sample.startsWith('#EXTM3U')) return false;

      // Master HLS: valida também uma variante real, não apenas o índice.
      if (sample.contains('#EXT-X-STREAM-INF')) {
        final child = _firstMediaUri(sample, uri);
        if (child == null) return false;
        return _validateMediaPlaylist(child);
      }

      // Media playlist: exige pelo menos um segmento e verifica que esse
      // segmento realmente responde antes de liberar o canal no catálogo.
      if (sample.contains('#EXTINF')) {
        final segment = _firstMediaUri(sample, uri);
        if (segment == null) return false;
        return await _probeMedia(segment);
      }
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
