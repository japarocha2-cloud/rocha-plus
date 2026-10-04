import 'package:shared_preferences/shared_preferences.dart';
import 'channel.dart';

class FavoritesRepository {
  static const _key = 'favorite_channel_urls';

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
