import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);
  test('general device failures and demo source stay excluded after feed changes', () {
    const outcomes = <String, bool>{
      'Adesso TV (720p)': false,
      'Alpha Channel (720p)': true,
      'Araruna TV': false,
      'Auge TV (720p)': true,
      'Bem Melhor (720p)': true,
      'Canal FDR': true,
      'Canal Libras (720p)': true,
      'Canal Ricos (480p)': true,
      'Canal START (720p)': true,
      'Canal UOL (1080p)': false,
      'Catve2 (720p)': false,
      'Catve FM (720p) [Not 24/7]': false,
      'Catve Master TV (720p) [Not 24/7]': false,
      'Cinturao Verde': true,
      'COM Brasil (720p)': false,
      'ConecTV Brasil (720p)': false,
      'Conexao TV (720p)': true,
      'Cultura Fast (720p)': false,
      'Demais TV (720p)': true,
      'EUTV (720p)': false,
      'Fala Litoral (480p)': false,
      'Lider TV (Brazil) (720p)': true,
      'MBC Brasil TV': true,
      'MKK Web TV (720p) [Not 24/7]': true,
      'NTV (Brazil) (720p)': false,
      'O Dia TV': false,
      'RBATV (720p)': false,
      'RCTV Brasil': true,
      'RecordTV Belem (720p) [Geo-blocked]': true,
      'RecordTV Brasilia (720p) [Geo-blocked]': true,
      'RecordTV Goias (720p) [Geo-blocked]': true,
      'RecordTV Itapoan (720p) [Geo-blocked]': true,
      'RecordTV Rio (720p) [Geo-blocked]': true,
      'RecordTV Sao Paulo (720p) [Geo-blocked]': true,
      'Rede Brasil (1080p)': false,
      'Rede Metropole (720p)': true,
      'Rede SPTV (360p)': false,
      'Rede TV! Mais': false,
      'SOU TV': false,
      'TELE 6 (720p)': true,
      'TV 3 Curitiba': true,
      'TV Adorar (720p)': true,
      'TV Aldeia (720p)': false,
      'TV Alianca Catarinense (720p)': true,
      'TV Alternativa (410p)': false,
      'TV Arapuan (720p)': false,
      'TV Birigui (640p)': true,
      'TV Brasil Oeste (720p)': false,
      'TV BRICS Portuguese (1080p)': false,
      'TV Carioca (720p)': true,
      'TV Comunitaria (360p)': false,
      'TV Diario Macapa (1080p) [Not 24/7]': true,
      'TV Difusao (720p)': false,
      'TV Futuro (1080p)': false,
      'TV Gazin (720p)': true,
      'TV Grao Para (720p)': true,
      'TV Guarapari (720p)': false,
      'TV Litoral RN (720p)': false,
      'TV Mais Marica (1080p)': false,
      'TV Marajoara (720p)': false,
      'TV Metropole (720p) [Not 24/7]': false,
      'TV Passo Fundo (720p)': false,
      'TV Petropolis (720p)': false,
      'TV Sao Raimundo (268p)': false,
      'TVC-Rio': false,
      'TVCOM Maceio (480p)': false,
      'TVitape (720p)': true,
      'TVLatinaSat (720p)': false,
      'TVNBN (720p)': false,
    };
    for (final entry in outcomes.entries) {
      for (final url in ['https://example.com/old.m3u8', 'https://example.com/new.m3u8']) {
        ChannelRepository.resetSessionHealthForTests();
        expect(ChannelRepository().isBlocked(Channel(name: entry.key,
          url: url, group: 'Geral')), entry.value, reason: entry.key);
      }
    }
  });
}
