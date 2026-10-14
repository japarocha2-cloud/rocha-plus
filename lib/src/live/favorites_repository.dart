import 'package:shared_preferences/shared_preferences.dart';
import 'channel.dart';

class FavoritesRepository {
  final String? accountId;
  FavoritesRepository({this.accountId});
  String? get _key => accountId == null || accountId!.isEmpty
      ? null : 'favorite_channel_urls.account.${Uri.encodeComponent(accountId!)}';

  Future<Set<String>> load() async {
    final key = _key;
    if (key == null) return <String>{};
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key)?.toSet() ?? <String>{};
  }

  Future<void> save(Set<String> urls) async {
    final key = _key;
    if (key == null) throw StateError('Entre na sua conta para salvar favoritos.');
    final prefs = await SharedPreferences.getInstance();
    final values = urls.toList()..sort();
    if (!await prefs.setStringList(key, values)) {
      throw StateError('Não foi possível salvar os favoritos.');
    }
  }

  bool contains(Set<String> favorites, Channel channel) =>
      favorites.contains(channel.url);
}
