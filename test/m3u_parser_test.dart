import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/m3u_parser.dart';

void main() {
  test('commas in quoted browser metadata never contaminate channel names', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-name="Canal Infantil" user-agent="Mozilla/5.0 (Linux, Android) Chrome/149.0 Safari/537.36" group-title="Kids",Canal Infantil, Ao Vivo
https://example.com/kids.m3u8
#EXTINF:-1 group-title="News" tvg-name="Notícias",Canal Notícias
https://example.com/news.m3u8
''';
    final channels = M3uParser.parse(playlist);
    expect(channels.map((c) => c.name), ['Canal Infantil, Ao Vivo', 'Canal Notícias']);
    expect(channels.map((c) => c.group), ['Infantil', 'Notícias']);
  });

  test('parses a basic M3U channel', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/logo.png" group-title="TV Aberta",Canal Teste
https://example.com/live.m3u8
''';
    final channels = M3uParser.parse(playlist);
    expect(channels, hasLength(1));
    expect(channels.first.name, 'Canal Teste');
    expect(channels.first.group, 'TV aberta');
    expect(channels.first.logo, 'https://example.com/logo.png');
    expect(channels.first.url, 'https://example.com/live.m3u8');
  });

  test('ignores invalid stream urls and keeps parsing', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 group-title="Teste",Inválido
arquivo-local.m3u8
#EXTINF:-1 group-title="Teste",Válido
https://example.com/ok.m3u8
''';
    final channels = M3uParser.parse(playlist);
    expect(channels, hasLength(1));
    expect(channels.first.name, 'Válido');
  });

  test('uses fallback group when group-title is missing', () {
    const playlist = '''#EXTM3U
#EXTINF:-1,Canal sem grupo
https://example.com/live.m3u8
''';
    final channels = M3uParser.parse(playlist);
    expect(channels.single.group, 'Outros');
  });

  test('accepts https streams and rejects insecure http', () {
    const playlist = '''#EXTM3U
#EXTINF:-1,HTTP
http://example.com/a.m3u8
#EXTINF:-1,HTTPS
https://example.com/b.m3u8
''';
    final channels = M3uParser.parse(playlist);
    expect(channels, hasLength(1));
    expect(channels.single.name, 'HTTPS');
    expect(channels.single.url, 'https://example.com/b.m3u8');
  });
  test('sanitizes Undefined and technical compound groups', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 group-title="Animation;Kids",Undefined Canal Criança
https://example.com/kids.m3u8
''';
    final channels = M3uParser.parse(playlist);
    expect(channels.single.name, 'Canal Criança');
    expect(channels.single.group, 'Infantil');
  });

  test('compound groups use meaningful children and news tags', () {
    final channels = M3uParser.parse('#EXTM3U\n'
        '#EXTINF:-1 group-title="General;Kids",Kids\nhttps://example.com/kids\n'
        '#EXTINF:-1 group-title="General;News",News\nhttps://example.com/news\n'
        '#EXTINF:-1 group-title="Adult;Animation",Mixed\nhttps://example.com/mixed\n');
    expect(channels.map((c) => c.group), ['Infantil', 'Notícias', 'Geral']);
  });
  test('rejects empty hosts and credentials and strips insecure logos', () {
    final channels = M3uParser.parse('#EXTM3U\n'
        '#EXTINF:-1,Bad\nhttps:\n'
        '#EXTINF:-1,Credential\nhttps://user:pass@example.com/live\n'
        '#EXTINF:-1 tvg-logo="http://example.com/logo.png",Good\nhttps://example.com/live\n');
    expect(channels, hasLength(1));
    expect(channels.single.logo, isNull);
  });

  test('recognizes open TV even when upstream uses General or Undefined', () {
    final channels = M3uParser.parse('#EXTM3U\n'
        '#EXTINF:-1 tvg-id="RedeGlobo.br@SD" group-title="Undefined",Rede Globo (1080p)\nhttps://example.com/globo\n'
        '#EXTINF:-1 tvg-id="SBTNacional.br@SD" group-title="Undefined",SBT Nacional (1080p)\nhttps://example.com/sbt\n'
        '#EXTINF:-1 group-title="General",TV Morena (720p)\nhttps://example.com/morena\n'
        '#EXTINF:-1 group-title="General",Record MS\nhttps://example.com/record\n'
        '#EXTINF:-1 group-title="General",Band MS\nhttps://example.com/band\n'
        '#EXTINF:-1 group-title="General",SBT MS\nhttps://example.com/sbtms\n');
    expect(channels, hasLength(6));
    expect(channels.every((c) => c.group == 'TV aberta'), isTrue);
  });

  test('open TV identities do not steal specialist or unrelated channels', () {
    final channels = M3uParser.parse('#EXTM3U\n'
        '#EXTINF:-1 tvg-id="SBTKids.br@SD" group-title="Kids",SBT Kids\nhttps://example.com/kids\n'
        '#EXTINF:-1 tvg-id="RecordNews.br@SD" group-title="News",Record News\nhttps://example.com/news\n'
        '#EXTINF:-1 tvg-id="BandSports.br@SD" group-title="Sports",Band Sports\nhttps://example.com/sports\n'
        '#EXTINF:-1 group-title="General",Canal Generalista Desconhecido\nhttps://example.com/general\n');
    expect(channels.map((c) => c.group), ['Infantil', 'Notícias', 'Esportes', 'Geral']);
  });
}
