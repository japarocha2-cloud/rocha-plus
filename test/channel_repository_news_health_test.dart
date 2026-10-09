import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);
  test('news failures remain blocked and all 14 playing entries stay eligible', () {
    const outcomes = <String, bool>{
      'Aratu On': false,
      'BandNews (1080p)': true,
      'BM&C News (720p)': true,
      'BR8 TV': true,
      'Canal 38 (720p)': false,
      'Canal Metropolitano de Noticias': false,
      'J3NEWS TV': false,
      'Plena TV (720p)': false,
      'Pluto TV Record News (720p)': true,
      'SBT News (720p)': false,
      'STZ TV (1080p)': false,
      'TCM 10 HD (1080p)': false,
      'TV A Folha (720p)': false,
      'TV Brusque (720p)': true,
      'TV Paraense (720p)': true,
      'TV Sim Cachoeiro (720p)': false,
      'TV Sim Sao Mateus (720p)': false,
      'TV Zoom (720p)': false,
      'TVideoNews (720p) [Not 24/7]': false,
      'VEJA+ TV (1080p)': false,
    };
    for (final entry in outcomes.entries) {
      for (final url in ['https://example.com/old.m3u8', 'https://example.com/new.m3u8']) {
        ChannelRepository.resetSessionHealthForTests();
        expect(ChannelRepository().isBlocked(Channel(name: entry.key,
          url: url, group: 'Notícias')), entry.value, reason: entry.key);
      }
    }
  });
}
