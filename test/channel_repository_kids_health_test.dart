import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);
  test('22 failed kids entries remain excluded after URL and session changes', () {
    const failed = [
      'Avatar: A lenda de Aang',
      'BabyFirst Brazil',
      'Comedy Central South Park',
      'Geekdot (720p)',
      'Gloob Web [Not 24/7]',
      'Nick Jr. Club (United States) BR (720p)',
      'Nickelodeon Classico (720p)',
      'Nickelodeon Teen (720p)',
      'Nickelodeon Toons (720p)',
      'O Reino Infantil',
      'Oggy e as Baratas Tontas',
      'Pluto TV Anime Acao',
      'Pluto TV Junior',
      'Pluto TV Kids',
      'Pluto TV Kids Club (United States)',
      'SBT Kids (1080p) [Geo-blocked]',
      'South Park: Colecao Cartman',
      'South Park: Colecao Kenny',
      'South Park: Colecao Kyle',
      'South Park: Colecao Stan',
      'Tokusato',
      'Turma da Monica (720p)',
    ];
    for (final name in failed) {
      for (final url in ['https://example.com/old.m3u8', 'https://example.com/new.m3u8']) {
        ChannelRepository.resetSessionHealthForTests();
        expect(ChannelRepository().isBlocked(Channel(name: name, url: url,
          group: 'Infantil')), isTrue, reason: name);
      }
    }
  });
  test('all eight kids entries with advancing video stay eligible', () {
    const retained = [
      'Bob Esponja Calca Quadrada (720p)',
      'Kuriakos Kids (1080p)',
      'Naruto Brazil',
      'Nickelodeon (Brazil) (480p)',
      'NickOnline HD (720p)',
      'NickOnline Bob Esponja (720p) [Not 24/7]',
      'One Piece BR',
      'Pluto TV Anime BR',
    ];
    for (final name in retained) {
      expect(ChannelRepository().isBlocked(Channel(name: name,
        url: 'https://example.com/retained.m3u8', group: 'Infantil')),
        isFalse, reason: name);
    }
  });
}
