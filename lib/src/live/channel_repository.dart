import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'channel_identity.dart';
import 'channel_blocks.dart';
import 'channel_scanner.dart';
import 'm3u_parser.dart';

class ChannelRepository {
  static final http.Client _defaultClient = http.Client();
  final http.Client _client;
  Future<List<Channel>>? _pendingLoad;
  ChannelRepository({http.Client? client}) : _client = client ?? _defaultClient;
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');
  static final Uri sportsPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/categories/sports.m3u');

  static Set<String> _userBlockedNames = {};
  final ChannelBlocks _blocks = ChannelBlocks();

  Future<void> blockChannel(Channel channel) async {
    await _blocks.block(channel.name);
    _userBlockedNames = await _blocks.load();
  }

  Future<void> restoreUserBlockedChannels() async {
    await _blocks.clear();
    _userBlockedNames = {};
    _memoryCache = null;
  }

  static final Map<Uri, List<Channel>> _sourceCache = {};
  static List<Channel>? _memoryCache;
  static List<Channel>? _lastKnownGoodCache;
  static final Set<String> _sessionFailedUrls = <String>{};

  // Bloqueio persistente por nome. Use esta camada para canais reprovados
  // em teste físico: eles não voltam quando o diretório remoto é atualizado.
  static const Set<String> _blockedChannelNames = <String>{
    '1001 noites',
    '30a golf kingdom (720p)',
    'pluto tv esportes',
    'canal do inter (720p) [not 24/7]',
    'band sports (1080p)',
    'times brasil (720p)',
    'tv thathi (720p) [not 24/7]',
    'tv sul de minas (720p)',
    'tv meio (720p)',
    'tv difusora leste (1080p)',
    'tv encontro das aguas',
  };

  bool _isPermanentlyBlocked(Channel channel) {
    final normalized = channelIdentity(channel.name);
    return _userBlockedNames.contains(normalized) ||
        _blockedChannelNames.any((name) => channelIdentity(name) == normalized);
  }

  void reportPlaybackFailure(String url) {
    _sessionFailedUrls.add(url);
  }

  void reportPlaybackSuccess(String url) => _sessionFailedUrls.remove(url);

  bool isQuarantined(String url) => _sessionFailedUrls.contains(url);

  Future<Map<String, ChannelReachability>> scanChannels(List<Channel> channels) =>
      ChannelScanner(_client).scan(channels);

  bool isBlocked(Channel channel) => _isPermanentlyBlocked(channel);

  bool isPermanentlyBlockedForTests(Channel channel) =>
      _isPermanentlyBlocked(channel);

  List<Channel> sportsOnly(Iterable<Channel> channels) {
    final filtered = channels
        .where((channel) => channel.group == 'Esportes')
        .where((channel) => !_isPermanentlyBlocked(channel))
        .where((channel) => !_sessionFailedUrls.contains(channel.url))
        .toList(growable: false);
    return _orderSportsFirst(filtered);
  }

  static void resetSessionHealthForTests() {
    _userBlockedNames = {};
    _sourceCache.clear();
    _sessionFailedUrls.clear();
    _memoryCache = null;
    _lastKnownGoodCache = null;
  }

  List<Channel> _withoutSessionFailures(Iterable<Channel> channels) =>
      channels
          .where((channel) => !_sessionFailedUrls.contains(channel.url))
          .where((channel) => !_isPermanentlyBlocked(channel))
          .toList(growable: false);

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) {
    return _pendingLoad ??= _loadDirectory(forceRefresh: forceRefresh)
        .whenComplete(() => _pendingLoad = null);
  }

  Future<List<Channel>> _loadDirectory({required bool forceRefresh}) async {
    _userBlockedNames = await _blocks.load();
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
      final previous = merged[channel.url];
      merged[channel.url] = previous == null ? channel : Channel(
        name: previous.name,
        url: previous.url,
        logo: previous.logo ?? channel.logo,
        group: channel.group == 'Esportes' ? 'Esportes' : previous.group,
      );
    }

    // A tela precisa abrir rápido. O catálogo é exibido assim que as fontes
    // são carregadas; a validação profunda não bloqueia mais centenas de
    // canais antes de a interface aparecer. Falhas reais do player entram
    // em quarentena durante a sessão por reportPlaybackFailure().
    final ordered = _orderSportsFirst(
      merged.values.where((channel) => !_isPermanentlyBlocked(channel)).toList(),
    );
    if (ordered.isNotEmpty) {
      _memoryCache = List.unmodifiable(ordered);
      _lastKnownGoodCache = _memoryCache;
      return _withoutSessionFailures(_memoryCache!);
    }

    if (fallback != null && fallback.isNotEmpty) {
      return _withoutSessionFailures(fallback);
    }
    if (_memoryCache != null) return _withoutSessionFailures(_memoryCache!);
    throw Exception('Não foi possível carregar canais disponíveis.');
  }

  Future<List<Channel>> _loadPlaylistSafely(Uri playlist) async {
    try {
      final channels = await _loadPlaylist(playlist);
      if (channels.isEmpty) return _sourceCache[playlist] ?? const <Channel>[];
      _sourceCache[playlist] = List.unmodifiable(channels);
      return channels;
    } catch (_) {
      return _sourceCache[playlist] ?? const <Channel>[];
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

    final name = channelIdentity(channel.name);

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

    final isFootball = !RegExp(r'\b(american football|futebol americano|nfl|rugby)\b').hasMatch(name) &&
        footballTerms.any((term) => RegExp('\\b${RegExp.escape(term)}').hasMatch(name));
    final isWomen = womenTerms.any(name.contains);

    var score = 100; // outros esportes
    if (isFootball) score = isWomen ? 800 : 900;
    var competitionBonus = 0;
    if (name.contains('brasileir')) competitionBonus += 90;
    if (name.contains('champions')) competitionBonus += 85;
    if (name.contains('libertadores')) competitionBonus += 60;
    if (name.contains('sul-americana')) competitionBonus += 50;

    return score + (isFootball ? (competitionBonus > 99 ? 99 : competitionBonus) : 0);
  }

}
