import 'channel.dart';

class M3uParser {
  static List<Channel> parse(String source) {
    final lines = source.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    String? name;
    String? logo;
    String group = 'Outros';

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        name = line.contains(',') ? line.substring(line.indexOf(',') + 1).trim() : 'Canal';
        logo = _attribute(line, 'tvg-logo');
        group = _attribute(line, 'group-title') ?? 'Outros';
      } else if (line.isNotEmpty && !line.startsWith('#') && name != null) {
        final uri = Uri.tryParse(line);
        if (uri != null && uri.scheme == 'https') {
          channels.add(Channel(
            name: _cleanName(name),
            url: line,
            logo: logo,
            group: _cleanGroup(group),
          ));
        }
        name = null; logo = null; group = 'Outros';
      }
    }
    return channels;
  }

  static String _cleanName(String value) {
    final cleaned = value.replaceAll(RegExp(r'\bundefined\b', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? 'Canal' : cleaned;
  }

  static String _cleanGroup(String value) {
    final parts = value
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'Outros';

    final normalized = parts.first.toLowerCase();
    if (normalized.contains('sport')) return 'Esportes';
    if (normalized.contains('news')) return 'Notícias';
    if (normalized.contains('animation') ||
        normalized.contains('kids') ||
        normalized.contains('children')) {
      return 'Infantil';
    }
    if (normalized.contains('general')) return 'Geral';
    return parts.first;
  }

  static String? _attribute(String line, String key) =>
      RegExp('$key="([^"]*)"').firstMatch(line)?.group(1);
}
