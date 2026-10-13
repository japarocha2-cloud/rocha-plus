import 'package:shared_preferences/shared_preferences.dart';
import 'channel_identity.dart';

class ChannelBlocks {
  static const _key = 'rocha_blocked_channel_names_v1';
  static const _urlKey = 'rocha_rejected_channel_urls_v1';
  static Future<void> _writes = Future<void>.value();

  static void resetForTests() {
    _writes = Future<void>.value();
  }

  Future<Set<String>> load() => _load(_key);
  Future<Set<String>> loadUrls() => _load(_urlKey);
  Future<Set<String>> _load(String key) async {
    await _writes.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? []).toSet();
  }
  Future<void> _serialize(Future<void> Function() operation) {
    final next = _writes.catchError((Object _) {}).then((_) => operation());
    _writes = next;
    return next;
  }
  Future<void> block(String name) => _store(_key, channelIdentity(name));
  Future<void> blockUrl(String url) => _store(_urlKey, url);
  Future<void> _store(String key, String value) => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    final values = (prefs.getStringList(key) ?? []).toSet()..add(value);
    if (!await prefs.setStringList(key, values.toList()..sort())) {
      throw StateError('Não foi possível salvar o bloqueio.');
    }
  });
  // Explicit restore only affects user-hidden names, not rejected streams.
  Future<void> clear() => _serialize(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key)) {
      throw StateError('Não foi possível restaurar os canais.');
    }
  });
}
