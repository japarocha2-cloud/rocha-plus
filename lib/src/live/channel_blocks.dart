import 'package:shared_preferences/shared_preferences.dart';
import 'channel_identity.dart';

class ChannelBlocks {
  static const _key = 'rocha_blocked_channel_names_v1';
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }
  Future<void> block(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final names = (prefs.getStringList(_key) ?? []).toSet();
    names.add(channelIdentity(name));
    if (!await prefs.setStringList(_key, names.toList()..sort())) {
      throw StateError('Não foi possível salvar o bloqueio.');
    }
  }
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key)) {
      throw StateError('Não foi possível restaurar os canais.');
    }
  }
}
