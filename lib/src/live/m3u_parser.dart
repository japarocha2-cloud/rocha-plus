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
          channels.add(Channel(name: name, url: line, logo: logo, group: group));
        }
        name = null; logo = null; group = 'Outros';
      }
    }
    return channels;
  }

  static String? _attribute(String line, String key) =>
      RegExp('$key="([^"]*)"').firstMatch(line)?.group(1);
}
