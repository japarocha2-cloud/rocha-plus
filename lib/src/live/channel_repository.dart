import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'channel_identity.dart';
import 'channel_blocks.dart';
import 'channel_scanner.dart';
import 'package:flutter/services.dart';

class ChannelRepository {
  static final http.Client _defaultClient = http.Client();
  final http.Client _client;
  Future<List<Channel>>? _pendingLoad;
  ChannelRepository({http.Client? client,
    Future<String> Function()? catalogLoader,
    Future<String> Function()? quarantineLoader})
      : _client = client ?? _defaultClient,
        _catalogLoader = catalogLoader ?? (() => rootBundle.loadString('catalog/approved.json')),
        _quarantineLoader = quarantineLoader ?? (() => rootBundle.loadString('catalog/quarantine.json'));
  final Future<String> Function() _catalogLoader;
  final Future<String> Function() _quarantineLoader;
  List<Channel>? _reviewedCache;
  final Set<String> _excludedNames = {};
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
    _reviewedCache = null;
  }

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
    return _excludedNames.contains(normalized) || _userBlockedNames.contains(normalized) ||
        _blockedChannelNames.any((name) => channelIdentity(name) == normalized);
  }

  // Playback errors do not change the reviewed catalogue.
  Future<void> reportPlaybackFailure(String url) async {}
  void reportPlaybackSuccess(String url) {}
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
    return _orderSportsFirst(filtered);
  }

  static void resetSessionHealthForTests() {
    ChannelBlocks.resetForTests();
    _userBlockedNames = {};
  }

  List<Channel> _visibleReviewedChannels(Iterable<Channel> channels) =>
      channels
          .where((channel) => !_isPermanentlyBlocked(channel))
          .toList(growable: false);

  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) {
    return _pendingLoad ??= _loadDirectory(forceRefresh: forceRefresh)
        .whenComplete(() => _pendingLoad = null);
  }

  Future<List<Channel>> _loadDirectory({required bool forceRefresh}) async {
    _userBlockedNames = await _blocks.load();
    if (!forceRefresh && _reviewedCache != null) {
      return _visibleReviewedChannels(_reviewedCache!);
    }
    // Only the packaged, previously selected sources may enter the catalogue.
    // Missing/invalid assets never trigger a public-playlist fallback.
    final sources = await Future.wait([_catalogLoader(), _quarantineLoader()]);
    final approved = jsonDecode(sources[0]);
    final excluded = jsonDecode(sources[1]);
    if (approved is! List || excluded is! List) {
      throw const FormatException('Catálogo selecionado inválido.');
    }
    _excludedNames.clear();
    for (final item in excluded) {
      if (item is Map && item['name'] is String) {
        _excludedNames.add(channelIdentity(item['name'] as String));
      }
    }
    final channels = <Channel>[];
    final seen = <String>{};
    for (final item in approved) {
      if (item is! Map || item['approved'] != true || item['status'] != 'approved' ||
          item['blocked'] == true || item['quarantined'] == true ||
          item['name'] is! String || item['url'] is! String) {
        continue;
      }
      final name = (item['name'] as String).trim();
      final url = item['url'] as String;
      final uri = Uri.tryParse(url);
      final evidence = item['evidence'];
      if (name.isEmpty || uri == null || uri.scheme != 'https' ||
          uri.host.isEmpty || uri.userInfo.isNotEmpty ||
          evidence is! Map || evidence['decoded_seconds'] is! num ||
          (evidence['decoded_seconds'] as num) < 29 ||
          evidence['video_codec'] is! String || (evidence['video_codec'] as String).isEmpty ||
          evidence['audio_codec'] is! String || (evidence['audio_codec'] as String).isEmpty ||
          !seen.add(url)) {
        continue;
      }
      final logo = item['logo'] is String ? item['logo'] as String : null;
      final logoUri = logo == null ? null : Uri.tryParse(logo);
      final channel = Channel(name: name, url: url,
          logo: logoUri != null && logoUri.scheme == 'https' &&
              logoUri.host.isNotEmpty && logoUri.userInfo.isEmpty ? logo : null,
          group: item['group'] is String ? item['group'] as String : 'TV aberta');
      if (!_isPermanentlyBlocked(channel)) channels.add(channel);
    }
    _reviewedCache = List.unmodifiable(channels);
    return _visibleReviewedChannels(_reviewedCache!);
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
