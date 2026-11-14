import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/c7_selected_catalog.dart';
import 'package:rocha_plus/src/live/c7_catalog_policy.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/official_catalog_pin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Bundled official selection loads all 479 base rows and three distinct additions (Telecine Action addition repeats its base card)', () async {
    final rows = await C7SelectedCatalog().load();
    final source = jsonDecode(File('catalog/official/frozen/2026-11-08/ROCHA_CATALOGO_OFICIAL_CONGELADO_2026-11-08.json').readAsStringSync()) as Map<String,dynamic>;
    expect(rows, hasLength(482));
    for (final value in source['canais'] as List) {
      final original = value as Map<String,dynamic>;
      expect(rows.any((r) => r.name == original['nome'] && r.url == original['url_atual'] && r.group == original['categoria']), isTrue);
    }
    expect(rows.where((c) => c.group == 'Esportes').first.name, 'CazéTV');
    final ratimbum = rows.singleWhere((c) => c.name == 'TV Rá-Tim-Bum HD');
    expect(ratimbum.alternateUrls, hasLength(3));
    expect(ratimbum.url, ratimbum.alternateUrls[1]);
    expect(rows.where((c) => c.name.startsWith('Telecine Action')).map((c) => c.name), ['Telecine Action (1080p)']);
  });
  test('Official C7 ignores stale removal cache and refresh never calls network', () async {
    SharedPreferences.setMockInitialValues({'rocha_blocked_channel_names_v1': ['TV Universal (480p)', 'CazéTV', 'Record TV MT']});
    var calls = 0;
    final repo = ChannelRepository(client: MockClient((_) async {calls++; throw StateError('external catalog request');}));
    for (final refresh in [false,true]) {
      final rows = await repo.loadBrazilPublicDirectory(forceRefresh: refresh);
      expect(rows, hasLength(482));
      expect(rows.any((r) => r.name == 'TV Universal (480p)'), isTrue);
      expect(rows.any((r) => r.name == 'Record TV MT'), isTrue);
    }
    expect(calls, 0);
    expect((await SharedPreferences.getInstance()).getStringList('rocha_blocked_channel_names_v1'), hasLength(3));
  }, skip: !C7CatalogPolicy.enabled);
  test('Runtime source tampering cannot trigger a public fallback', () async {
    final raw = File('branding/c7/selection.json').readAsStringSync();
    await expectLater(C7SelectedCatalog(read: () async => '$raw ', expectedSha256: officialCatalogSha256).load(), throwsA(isA<C7CatalogUnavailable>()));
  });
}
