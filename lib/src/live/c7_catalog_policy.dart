import 'channel.dart';
import 'channel_identity.dart';

/// Operator's C7-only physical decisions. Never edits source snapshots.
class C7CatalogPolicy {
  static const enabled = bool.fromEnvironment('ROCHA_FULL_UI_LAB');
  static String identity(String name) => channelIdentity(name)
      .replaceAll(RegExp(r'\s*\[geo-blocked\]'), '')
      .replaceFirst(RegExp(r'^recordtv\b'), 'record')
      .replaceFirst(RegExp(r'^record tv\b'), 'record')
      .replaceFirst(RegExp(r'^tv record\b'), 'record')
      .trim();

  static bool removeRecord(Channel channel) {
    final name = identity(channel.name);
    final original = channelIdentity(channel.name);
    final family = original.startsWith('recordtv ') ||
        original.startsWith('record tv ') || original.startsWith('tv record ') ||
        const {'record', 'record news', 'pluto tv record news',
          'record interior sp', 'record brasilia', 'record goias', 'record belem',
          'record rs', 'record rio', 'record itapoan', 'record sao paulo',
        }.contains(name);
    return family && !const {
      'record news', 'pluto tv record news', 'record interior sp',
    }.contains(name);
  }

  static bool isCaze(Channel c) => c.group == 'Esportes' &&
      channelIdentity(c.name).replaceAll(' ', '') == 'cazetv';

  static List<Channel> apply(Iterable<Channel> source) {
    final retained = source.where((c) => !removeRecord(c)).toList();
    // Move only CazéTV into the first existing sports slot. All other relative
    // ordering and every retained Channel instance/field stay unchanged.
    final caze = retained.where(isCaze).toList();
    if (caze.isEmpty) return retained;
    final rest = retained.where((c) => !isCaze(c)).toList();
    final firstSports = rest.indexWhere((c) => c.group == 'Esportes');
    rest.insertAll(firstSports < 0 ? rest.length : firstSports, caze);
    return rest;
  }
}
