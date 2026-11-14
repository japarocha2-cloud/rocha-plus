import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/c7_catalog_policy.dart';
import 'package:rocha_plus/src/live/c7_selected_catalog.dart';

void main() {
  test('C7 initial load, refresh, restore and corrupt selection never import public playlists', () async {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
    var calls = 0;
    var broken = false;
    final raw = File('test/fixtures/c7_selection_fixture.json').readAsStringSync();
    final hash = File('test/fixtures/c7_selection_fixture.sha256').readAsStringSync().trim();
    final repo = ChannelRepository(
      client: MockClient((request) async {calls++; throw StateError('C7 must never request ${request.url.host}');}),
      c7Selection: C7SelectedCatalog(read: () async => broken ? '$raw ' : raw, expectedSha256: hash),
    );
    for (final refresh in [false, false, true]) {
      final result = await repo.loadBrazilPublicDirectory(forceRefresh: refresh);
      expect(result, hasLength(4));
      expect(result.where((c) => c.group=='Esportes').first.name,'CazéTV');
      expect(result.map((c) => c.group).toSet(),{'Notícias','Esportes','Documentários'});
      expect(result.any((c) => c.name=='HISTORY'),isTrue);
      expect(calls,0);
    }
    await repo.restoreUserBlockedChannels();
    expect(await repo.loadBrazilPublicDirectory(forceRefresh:true),hasLength(4));
    broken=true;
    await expectLater(repo.loadBrazilPublicDirectory(forceRefresh:true),throwsA(isA<C7CatalogUnavailable>()));
    expect(calls,0);
  },skip:!C7CatalogPolicy.enabled);
  test('C7 with no recovered source refuses expansion instead of installing pending rows', () async {
    SharedPreferences.setMockInitialValues({});
    var calls=0;
    final repo=ChannelRepository(client:MockClient((_) async {calls++;throw StateError('external fallback');}),c7Selection:C7SelectedCatalog(expectedSha256:''));
    await expectLater(repo.loadBrazilPublicDirectory(),throwsA(isA<C7CatalogUnavailable>()));
    expect(calls,0);
  },skip:!C7CatalogPolicy.enabled);
}
