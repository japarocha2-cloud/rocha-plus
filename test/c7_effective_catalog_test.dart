import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/c7_catalog_policy.dart';

void main() {
  test('effective LAB directory, cache and refresh apply the same physical policy', () async {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    final repo = ChannelRepository(client: MockClient((request) async => http.Response(
      request.url == ChannelRepository.sportsPlaylist ? '#EXTM3U\n' :
      '#EXTM3U\n#EXTINF:-1 group-title="Esportes",ESPN\nhttps://example.test/espn\n'
      '#EXTINF:-1 group-title="General",Record\nhttps://example.test/record\n'
      '#EXTINF:-1 group-title="News",Record News\nhttps://example.test/news\n'
      '#EXTINF:-1 group-title="Documentary",HISTORY Brasil\nhttps://example.test/history\n', 200)));
    for (final refresh in [false, false, true]) {
      final result = await repo.loadBrazilPublicDirectory(forceRefresh: refresh);
      expect(result.where((c) => c.group == 'Esportes').first.name, 'CazéTV');
      expect(result.any((c) => c.name == 'Record'), isFalse);
      expect(result.any((c) => c.name == 'Record News'), isTrue);
      expect(result.any((c) => c.url == 'https://example.test/history'), isTrue);
    }
  }, skip: !C7CatalogPolicy.enabled);
}
