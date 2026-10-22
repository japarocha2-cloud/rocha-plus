import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'channel.dart';

class FavoritesRepository {
  /// Capture identity synchronously. Async reads/writes never consult a mutable
  /// login session, and the unowned legacy global list is never imported.
  FavoritesRepository({String? accountUid})
    : _key = accountUid == null || accountUid.isEmpty
          ? 'favorite_channel_urls_v2:guest'
          : 'favorite_channel_urls_v2:uid:${base64Url.encode(utf8.encode(accountUid))}';

  final String _key;

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? <String>{};
  }

  Future<void> save(Set<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    final values = urls.toList()..sort();
    await prefs.setStringList(_key, values);
  }

  bool contains(Set<String> favorites, Channel channel) =>
      favorites.contains(channel.url);
}
