import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  test('24 physical outcomes persist after session and source changes', () {
    const failed = <String>['Pluto TV Turbo', 'Laboral TV (360p)', 'Detetives Medicos', 'Pluto TV Aliens', 'Pluto TV Animais', 'Pluto TV Investigacao', 'Pluto TV Negocio Fechado', 'Pluto TV Policial', 'MacGyver (United States)', 'Pluto TV Desenhos Classicos', 'Comedy Central Pluto TV BR', 'FailArmy Brazil', 'Pluto TV Series Comedia', 'Pluto TV KFOOD', 'Tastemade Brasil (720p)'];
    const playing = <String>['Smithsonian Channel Pluto TV', 'AWTV (1080p) [Geo-blocked]', 'Comedy Central Brasil (480p)', 'Fora Tedio TV (720p)', 'Bem Mais TV (1080p)', 'TV Life America (720p)', 'TV UFOP (1080p)', 'TVE RS (1080p)', 'Unisul TV (720p)'];
    for (final names in [failed, playing]) {
      for (final name in names) {
        for (final url in ['https://example.com/old.m3u8', 'https://example.com/new.m3u8']) {
          ChannelRepository.resetSessionHealthForTests();
          expect(ChannelRepository().isBlocked(Channel(name: name, url: url, group: 'Geral')),
            names == failed, reason: name);
        }
      }
    }
  });
}
