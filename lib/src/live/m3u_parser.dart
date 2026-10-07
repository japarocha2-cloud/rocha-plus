import 'channel.dart';
import 'open_tv_channels.dart';

class M3uParser {
  static List<Channel> parse(String source) {
    final lines = source.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    String? name;
    String? logo;
    String? tvgId;
    String group = 'Outros';

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        name = line.contains(',') ? line.substring(line.indexOf(',') + 1).trim() : 'Canal';
        logo = _attribute(line, 'tvg-logo');
        tvgId = _attribute(line, 'tvg-id');
        group = _attribute(line, 'group-title') ?? 'Outros';
      } else if (line.isNotEmpty && !line.startsWith('#') && name != null) {
        final uri = Uri.tryParse(line);
        if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty) {
          channels.add(Channel(
            name: _cleanName(name),
            url: line,
            logo: _safeLogo(logo),
            group: _cleanGroup(group, name: name, tvgId: tvgId),
          ));
        }
        name = null; logo = null; tvgId = null; group = 'Outros';
      }
    }
    return channels;
  }

  static String _cleanName(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'\\bundefined\\b', caseSensitive: false), '')
        .trim();

    // Some upstream playlists leak HTTP/User-Agent or EXTINF attributes into
    // the display title. Keep the human channel name instead of exposing
    // browser metadata such as Chrome/Safari and group-title on Cast/Home.
    final leakedAttribute = RegExp(
      r'\\s+(?:tvg-[\\w-]+|group-title|user-agent|http-referrer|referrer)="',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (leakedAttribute != null) {
      cleaned = cleaned.substring(0, leakedAttribute.start).trim();
    }

    final browserPrefix = RegExp(
      r'^.*?\\b(?:Mozilla/\\d|Chrome/\\d|Safari/\\d|AppleWebKit/\\d)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (browserPrefix != null) {
      final quotedEnd = cleaned.lastIndexOf('"');
      if (quotedEnd >= 0 && quotedEnd + 1 < cleaned.length) {
        cleaned = cleaned.substring(quotedEnd + 1).trim();
      }
    }

    cleaned = cleaned.replaceFirst(RegExp(r'^[,;\\s]+'), '').trim();
    return cleaned.isEmpty ? 'Canal' : cleaned;
  }

  static String _cleanGroup(String value, {required String name, String? tvgId}) {
    final parts = value
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return OpenTvChannels.matches(name: name, tvgId: tvgId) ? 'TV aberta' : 'Outros';
    }

    final normalized = parts.map((part) => part.toLowerCase()).toList();
    bool has(String token) => normalized.any((part) => part.contains(token));
    if (has('adult')) return 'Geral';
    if (has('kids') || has('children') || has('infantil') || has('animation')) {
      return 'Infantil';
    }
    if (has('sport') || has('esporte')) return 'Esportes';
    if (has('news') || has('notícias') || has('noticias')) return 'Notícias';
    if (has('tv aberta') || OpenTvChannels.matches(name: name, tvgId: tvgId)) {
      return 'TV aberta';
    }
    if (has('general') || has('geral')) return 'Geral';
    return parts.first;
  }

  static String? _safeLogo(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' &&
        uri.host.isNotEmpty && uri.userInfo.isEmpty ? value : null;
  }

  static String? _attribute(String line, String key) =>
      RegExp('$key="([^"]*)"').firstMatch(line)?.group(1);
}
