import 'c7_selected_catalog.dart';
import 'c7_catalog_policy.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'channel_identity.dart';
import 'channel_blocks.dart';
import 'channel_scanner.dart';
import 'm3u_parser.dart';
import 'playback_failure.dart';

class ChannelRepository {
  static final http.Client _defaultClient = http.Client();
  final http.Client _client;
  Future<List<Channel>>? _pendingLoad;
  final C7SelectedCatalog _c7Selection;
  ChannelRepository({http.Client? client, C7SelectedCatalog? c7Selection})
      : _client = client ?? _defaultClient,
        _c7Selection = c7Selection ?? C7SelectedCatalog();
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');
  static final Uri sportsPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/categories/sports.m3u');

  // One shared stream correction for existing cards in remote and LAB catalogs.
  // Never adds channels or changes their identity, artwork or category.
  static Channel applyPhysicalTestStream(Channel channel) {
    final identity = channelIdentity(channel.name);
    const streams = <String, String>{
      'cazetv': 'http://138.204.86.4:8080/CAZE_TV/playlist.m3u8',
      'globo': 'http://79.127.238.228:14173/',
      'history (brazil)': 'http://170.83.16.50/HISTORY/index.m3u8',
      'tv ra-tim-bum': 'http://170.83.49.66:8083/TVRATIMBUMHD/index.m3u8',
      'ra-tim-bum': 'http://170.83.49.66:8083/TVRATIMBUMHD/index.m3u8',
    };
    final url = streams[identity];
    if (url == null || url == channel.url) return channel;
    return Channel(
      name: channel.name,
      url: url,
      logo: channel.logo,
      group: channel.group,
      genres: channel.genres,
      preferredEngine: channel.preferredEngine,
    );
  }

  static Set<String> _userBlockedNames = {};
  final ChannelBlocks _blocks = ChannelBlocks();

  Future<void> blockChannel(Channel channel) async {
    await _blocks.block(channel.name);
    _userBlockedNames = await _blocks.load();
  }

  Future<void> restoreUserBlockedChannels() async {
    await _blocks.clear();
    _userBlockedNames = {};
  }

  static final Map<Uri, List<Channel>> _sourceCache = {};
  static List<Channel>? _memoryCache;
  static List<Channel>? _lastKnownGoodCache;
  static final Map<String, PlaybackFailure> _playbackFailures = {};

  // Only an explicit local user choice hides a channel. Historical names
  // without URL/device/date evidence must not block alternative feeds.
  bool _isPermanentlyBlocked(Channel channel) =>
      _userBlockedNames.contains(channelIdentity(channel.name));

  void reportPlaybackFailure(String url, {
    PlaybackFailure failure = PlaybackFailure.unknown,
  }) {
    _playbackFailures[url] = failure;
  }

  void reportPlaybackSuccess(String url) => _playbackFailures.remove(url);

  PlaybackFailure? lastPlaybackFailure(String url) => _playbackFailures[url];

  // A transient player error is diagnostic evidence, not a channel exclusion.
  // Keep this compatibility query for callers; explicit/user blocks are still
  // enforced separately by isBlocked and the catalogue approval rules.
  bool isQuarantined(String url) => false;

  Future<Map<String, ChannelReachability>> scanChannels(List<Channel> channels) =>
      ChannelScanner(_client).scan(channels);

  bool isBlocked(Channel channel) => _isPermanentlyBlocked(channel);

  bool isPermanentlyBlockedForTests(Channel channel) =>
      _isPermanentlyBlocked(channel);

  List<Channel> sportsOnly(Iterable<Channel> channels) {
    final filtered = channels
        .where((channel) => channel.group == 'Esportes')
        .where((channel) => !_isPermanentlyBlocked(channel))
        .toList(growable: false);
    return C7CatalogPolicy.enabled ? filtered : _orderSportsFirst(filtered);
  }

  static void resetSessionHealthForTests() {
    _userBlockedNames = {};
    _sourceCache.clear();
    _playbackFailures.clear();
    _memoryCache = null;
    _lastKnownGoodCache = null;
  }

  List<Channel> _withoutSessionFailures(Iterable<Channel> channels) =>
      channels
          .where((channel) => !_isPermanentlyBlocked(channel))
          .toList(growable: false);

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) {
    if (C7CatalogPolicy.enabled) {
      // Before all remote/last-known-good caches: C7 never imports br/sports.
      return _loadC7Selection();
    }
    return _pendingLoad ??= _loadDirectory(forceRefresh: forceRefresh)
        .whenComplete(() => _pendingLoad = null);
  }

  Future<List<Channel>> _loadC7Selection() async {
    final selected = await _c7Selection.load();
    // Owner-frozen records are never filtered by legacy pending/removal caches.
    // Historical device decisions remain stored for evidence, without exclusion.
    return selected;
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
              genres: channel.genres,
              preferredEngine: channel.preferredEngine,
            ))
        .toList(growable: false);

    // Deduplicate only exact stream/name identities. Identically addressed
    // regional or editorial variants must not silently inherit each other's
    // title or category. Different URLs stay as fallback streams until a
    // playback audit can prove which variants are genuinely duplicates.
    final merged = <(String, String), Channel>{};
    for (final channel in [...brazil, ...sports]) {
      final identity = channelIdentity(channel.name);
      final key = (channel.url.trim(), identity);
      final previous = merged[key];
      merged[key] = previous == null ? channel : Channel(
        name: previous.name,
        url: previous.url,
        logo: previous.logo ?? channel.logo,
        group: previous.group == 'Esportes' || channel.group == 'Esportes'
            ? 'Esportes'
            : previous.group,
        genres: previous.genres.isNotEmpty ? previous.genres : channel.genres,
        preferredEngine: previous.preferredEngine ?? channel.preferredEngine,
      );
    }

    // A tela precisa abrir rápido. O catálogo é exibido assim que as fontes
    // são carregadas; a validação profunda não bloqueia mais centenas de
    // canais antes de a interface aparecer. Falhas do player são registradas
    // para diagnóstico, sem esconder um canal após um erro transitório.
    // Cache source data before local hiding so restore also works offline.
    // When multiple source URLs describe the same corrected card, show it
    // once. Source records are retained; other channels and regional variants
    // remain untouched. Never deduplicate by stream URL alone.
    final correctedCards = <(String, String), Channel>{};
    for (final original in merged.values) {
      final channel = applyPhysicalTestStream(original);
      final key = (channelIdentity(channel.name), channel.url.trim());
      correctedCards.putIfAbsent(key, () => channel);
    }
    final ordered = _orderSportsFirst(correctedCards.values.toList());
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
