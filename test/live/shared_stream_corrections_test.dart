import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  group('Correções compartilhadas de transmissão', () {
    test('corrige somente o cartão CazéTV existente', () {
      const original = Channel(
        name: 'CazeTV (1080p)',
        url: 'https://example.test/old.m3u8',
        logo: 'https://example.test/caze.png',
        group: 'Esportes',
        genres: ['Futebol'],
        preferredEngine: 'vlc',
      );
      final updated = ChannelRepository.applyPhysicalTestStream(original);
      expect(updated.url, 'http://138.204.86.4:8080/CAZE_TV/playlist.m3u8');
      expect(updated.name, original.name);
      expect(updated.logo, original.logo);
      expect(updated.group, original.group);
      expect(updated.genres, original.genres);
      expect(updated.preferredEngine, original.preferredEngine);
    });

    test('corrige somente Globo com nome exato', () {
      const globo = Channel(name: 'Globo', url: 'https://example.test/old');
      expect(ChannelRepository.applyPhysicalTestStream(globo).url,
          'http://79.127.238.228:14173/');
      const regional = Channel(
          name: 'TV Globo Sao Paulo (720p)', url: 'https://example.test/regional');
      expect(ChannelRepository.applyPhysicalTestStream(regional).url, regional.url);
    });

    test('corrige HISTORY sem alterar HISTORY 2', () {
      const history = Channel(
          name: 'History (Brazil) (720p)', url: 'https://example.test/old');
      const history2 = Channel(
          name: 'History 2 Latin America Brazil (720p)',
          url: 'https://example.test/history2');
      expect(ChannelRepository.applyPhysicalTestStream(history).url,
          'http://170.83.16.50/HISTORY/index.m3u8');
      expect(ChannelRepository.applyPhysicalTestStream(history2).url, history2.url);
    });

    test('mantém outros canais e evita modificações desnecessárias', () {
      const other = Channel(name: 'SBT', url: 'https://example.test/sbt.m3u8');
      expect(identical(ChannelRepository.applyPhysicalTestStream(other), other), isTrue);
    });
  });
}
