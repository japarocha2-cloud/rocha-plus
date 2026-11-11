import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'channel.dart';
import 'channel_identity.dart';
import 'favorite_entry.dart';
import 'firestore_favorites_store.dart';

class FavoritesRepository extends ChangeNotifier {
  static const _key = 'favorite_channel_urls';
  final FavoritesStore? store;
  final bool Function()? isCurrentAccount;
  FavoritesRepository({this.store, this.isCurrentAccount});
  factory FavoritesRepository.forAccount(String uid) => FavoritesRepository(
    store: FirestoreFavoritesStore(uid),
    isCurrentAccount: () => FirebaseAuth.instance.currentUser?.uid == uid,
  );
  StreamSubscription<FavoritesSnapshot>? _subscription;
  Completer<void>? _first;
  final Map<String, FavoriteEntry> _remote = {};
  final Map<String, FavoriteEntry?> _pending = {};
  final Map<String, int> _versions = {};
  Set<String> _local = {};
  Set<String> legacyUrls = {};
  bool _disposed = false;
  bool ready = false;
  bool fromCache = false;
  bool serverPending = false;
  String? error;
  bool get cloud => store != null;
  bool get syncing => serverPending || _pending.isNotEmpty;
  bool get confirmed => cloud && ready && !fromCache && !syncing && error == null;
  String get status => error != null
    ? 'Não foi possível sincronizar seus favoritos. Tente novamente.'
    : syncing ? 'Salvando favoritos na sua conta…'
    : fromCache ? 'Favoritos neste aparelho. Aguardando conexão para sincronizar.'
    : confirmed ? 'Favoritos salvos na sua conta'
    : cloud ? 'Carregando favoritos da sua conta…' : 'Favoritos deste aparelho';
  static String idFor(Channel channel) =>
    sha256.convert(utf8.encode(channelIdentity(channel.name))).toString();
  Map<String, FavoriteEntry> get _entries {
    final result = {..._remote};
    for (final item in _pending.entries) {
      if (item.value == null) { result.remove(item.key); }
      else { result[item.key] = item.value!; }
    }
    return result;
  }
  Set<String> get values => cloud ? _entries.keys.toSet() : {..._local};
  bool contains(Set<String> favorites, Channel channel) =>
    favorites.contains(cloud ? idFor(channel) : channel.url);
  void _notify() { if (!_disposed) notifyListeners(); }
  Future<Set<String>> load() async {
    if (_disposed) return {};
    if (!cloud) {
      final prefs = await SharedPreferences.getInstance();
      _local = prefs.getStringList(_key)?.toSet() ?? {};
      ready = true; return values;
    }
    if (isCurrentAccount?.call() == false) throw StateError('Session changed');
    if (_first == null) {
      _first = Completer<void>();
      final prefs = await SharedPreferences.getInstance();
      legacyUrls = prefs.getStringList(_key)?.toSet() ?? {};
      if (_disposed) return {};
      _subscription = store!.watch().listen((snapshot) {
        if (_disposed) return;
        _remote..clear()..addEntries(snapshot.entries.map((e) => MapEntry(e.id, e)));
        fromCache = snapshot.fromCache; serverPending = snapshot.pending;
        ready = true; error = null;
        if (!_first!.isCompleted) _first!.complete();
        _notify();
      }, onError: (Object _) {
        if (_disposed) return;
        error = 'sync'; ready = true;
        if (!_first!.isCompleted) _first!.complete();
        _notify();
      });
    }
    await _first!.future;
    return values;
  }
  // Legacy/local-only API retained for fixtures and layout previews.
  Future<void> save(Set<String> urls) async {
    if (cloud) throw StateError('Use per-channel mutations for cloud favorites');
    final prefs = await SharedPreferences.getInstance();
    final list = urls.toList()..sort();
    if (!await prefs.setStringList(_key, list)) throw StateError('Save failed');
    _local = {...urls}; _notify();
  }
  Future<void> toggle(Channel channel) async {
    if (_disposed || isCurrentAccount?.call() == false) throw StateError('Session changed');
    if (!cloud) {
      final next = {..._local};
      next.contains(channel.url) ? next.remove(channel.url) : next.add(channel.url);
      return save(next);
    }
    if (!ready) throw StateError('Favorites not loaded');
    final id = idFor(channel);
    final desired = _entries.containsKey(id) ? null : FavoriteEntry(
      id: id, channel: channel, addedAt: DateTime.now().millisecondsSinceEpoch);
    _write(id, desired);
  }
  void _write(String id, FavoriteEntry? desired) {
    final version = (_versions[id] ?? 0) + 1;
    _versions[id] = version; _pending[id] = desired; error = null; _notify();
    final operation = Future<void>.sync(() =>
      desired == null ? store!.remove(id) : store!.put(desired));
    unawaited(operation.then((_) {
      if (_disposed || _versions[id] != version) return;
      if (desired == null) { _remote.remove(id); } else { _remote.putIfAbsent(id, () => desired); }
      _pending.remove(id); _notify();
    }).catchError((Object _) {
      if (_disposed || _versions[id] != version) return;
      _pending.remove(id); error = 'save'; _notify();
    }));
  }
  Future<void> retry() async {
    if (_disposed || !cloud || isCurrentAccount?.call() == false) return;
    await _subscription?.cancel();
    _subscription = null; _first = null; ready = false; error = null; _notify();
    await load();
  }
  List<Channel> savedChannels(List<Channel> catalog) {
    if (!cloud) return catalog.where((c) => _local.contains(c.url)).toList();
    final current = {for (final channel in catalog) idFor(channel): channel};
    final saved = _entries.values.toList()..sort((a, b) {
      final order = a.addedAt.compareTo(b.addedAt);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return saved.map((entry) => current[entry.id] ?? entry.channel).toList();
  }
  Future<void> importLegacy(List<Channel> catalog) async {
    if (_disposed || !cloud || !ready || isCurrentAccount?.call() == false) {
      throw StateError('Favorites unavailable for this session');
    }
    for (final channel in catalog.where((c) => legacyUrls.contains(c.url))) {
      final id = idFor(channel);
      if (_entries.containsKey(id)) continue;
      final entry = FavoriteEntry(id: id, channel: channel,
        addedAt: DateTime.now().millisecondsSinceEpoch);
      // Migration is explicit and waits for server confirmation. Existing
      // cloud favorites remain intact; legacy data is never silently reassigned.
      await store!.put(entry);
      if (_disposed || isCurrentAccount?.call() == false) return;
      _remote[id] = entry;
    }
    legacyUrls = {}; _notify(); // Legacy storage retained for unmatched channels.
  }
  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    if (_first != null && !_first!.isCompleted) _first!.complete();
    super.dispose();
  }
}
