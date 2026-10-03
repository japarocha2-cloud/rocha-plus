import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/m3u_parser.dart';

void main() {
  test('parses a basic M3U channel', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/logo.png" group-title="TV Aberta",Canal Teste
https://example.com/live.m3u8
''';

    final channels = M3uParser.parse(playlist);

    expect(channels, hasLength(1));
    expect(channels.first.name, 'Canal Teste');
    expect(channels.first.group, 'TV Aberta');
    expect(channels.first.logo, 'https://example.com/logo.png');
    expect(channels.first.url, 'https://example.com/live.m3u8');
  });
}
