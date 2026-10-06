import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'm3u_parser.dart';

class ChannelRepository {
  static http.Client _client = http.Client();
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');
  static final Uri sportsPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/categories/sports.m3u');

  static List<Channel>? _memoryCache;
  static List<Channel>? _lastKnownGoodCache;
  static final Set<String> _sessionFailedUrls = <String>{};

  void reportPlaybackFailure(String url) {
    _sessionFailedUrls.add(url);
    final cached = _memoryCache;
    if (cached != null) {
      _memoryCache = List.unmodifiable(
        cached.where((channel) => !_sessionFailedUrls.contains(channel.url)),
      );
    }
  }

  void reportPlaybackSuccess(String url) => _sessionFailedUrls.remove(url);

  bool isQuarantined(String url) => _sessionFailedUrls.contains(url);

  List<Channel> sportsOnly(Iterable<Channel> channels) {
    final filtered = channels
        .where((channel) => channel.group == 'Esportes')
        .where((channel) => !_sessionFailedUrls.contains(channel.url))
        .toList(growable: false);
    return _orderSportsFirst(filtered);
  }

  static void resetSessionHealthForTests() {
    _sessionFailedUrls.clear();
    _memoryCache = null;
    _lastKnownGoodCache = null;
  }

  static void setClientForTests(http.Client client) {
    _client = client;
    resetSessionHealthForTests();
  }

  List<Channel> _withoutSessionFailures(Iterable<Channel> channels) =>
      channels.where((channel) => !_sessionFailedUrls.contains(channel.url)).toList(growable: false);

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) {
      return _withoutSessionFailures(_memoryCache!);
    }

    final fallback = _lastKnownGoodCache;

    final results = await Future.wait([
      _loadPlaylistSafely(developmentPlaylist),
      _loadPlaylistSafely(sportsPlaylist),
    ]).timeout(const Duration(seconds: 16), onTimeout: () => const [<Channel>[], <Channel>[]]);

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

    // A tela precisa abrir rápido. O catálogo é exibido assim que as fontes
    // são carregadas; a validação profunda não bloqueia mais centenas de
    // canais antes de a interface aparecer. Falhas reais do player entram
    // em quarentena durante a sessão por reportPlaybackFailure().
    final ordered = _orderSportsFirst(
      _withoutSessionFailures(merged.values),
    );
    if (ordered.isNotEmpty) {
      _memoryCache = List.unmodifiable(ordered);
      _lastKnownGoodCache = _memoryCache;
      return _memoryCache!;
    }

    if (fallback != null && fallback.isNotEmpty) {
      return _withoutSessionFailures(fallback);
    }
    if (_memoryCache != null) return _withoutSessionFailures(_memoryCache!);
    throw Exception('Não foi possível carregar canais disponíveis.');
  }

  Future<List<Channel>> _loadPlaylistSafely(Uri playlist) async {
    try {
      return await _loadPlaylist(playlist);
    } catch (_) {
      return const <Channel>[];
    }
  }

  Future<List<Channel>> _loadPlaylist(Uri playlist) async {
    final res = await _client.get(playlist).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Não foi possível carregar o catálogo.');
    }
    return M3uParser.parse(utf8.decode(res.bodyBytes));
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

  int sportsPriorityForTests(Channel channel) => _sportsPriority(channel);

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

}
