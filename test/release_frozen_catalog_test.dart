import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';

import 'package:rocha_plus/src/live/c7_catalog_policy.dart';
import 'package:rocha_plus/src/live/c7_selected_catalog.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

// Runs with the exact defines tools/prepare_signed_build.py gives every signed
// official build (see build.yml). Proves the app-level repository loads the
// owner-frozen LAB Cliente catalog from the bundled asset, with zero network
// access: no iptv-org br/sports import, no remote or last-known-good cache.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest = jsonDecode(File('catalog/official/release-manifest.json').readAsStringSync());
  const signedDefines = bool.fromEnvironment('ROCHA_CLOSED_CATALOG');

  test('signed build defines pin the frozen LAB Cliente catalog', () {
    if (!signedDefines) return markTestSkipped('run with signed-build defines');
    expect(C7CatalogPolicy.enabled, isTrue);
    expect(C7SelectedCatalog.selectionAsset, manifest['asset']);
    expect(C7SelectedCatalog.compiledSha256, manifest['sha256']);
  });

  test('repository loads exactly the frozen 540 with CazéTV first and no network', () async {
    if (!signedDefines) return markTestSkipped('run with signed-build defines');
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response('#EXTM3U\n#EXTINF:-1 group-title="Sports",Intruso\nhttps://x.invalid/a.m3u8\n', 200);
    });
    ChannelRepository.resetSessionHealthForTests();
    final channels = await ChannelRepository(client: client).loadBrazilPublicDirectory(forceRefresh: true);
    expect(requests, isEmpty, reason: 'official build must never import public playlists');
    expect(channels, hasLength(manifest['count']));
    expect(channels.map((c) => c.name), isNot(contains('Intruso')));
    final sports = channels.where((c) => c.group == 'Esportes').toList();
    expect(C7CatalogPolicy.isCaze(sports.first), isTrue);
    for (final item in manifest['protected'] as List) {
      final channel = channels.singleWhere((c) => c.name == item['name']);
      expect(sha256.convert(utf8.encode(channel.url)).toString(), item['urlSha256']);
      expect(channel.group, item['group']);
    }
  });

  testWidgets('commercial Home shows the LAB Cliente sections (not the 5-card legacy grid)', (tester) async {
    if (!signedDefines) return markTestSkipped('run with signed-build defines');
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: _Empty())));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
        of: find.byKey(const ValueKey('home-scroll')), matching: find.byType(Scrollable)).first;
    for (final category in ['Filmes', 'Documentários', 'Religiosos', 'Futebol']) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('category-$category')), 250, scrollable: scrollable);
      expect(find.byKey(ValueKey('category-$category')), findsOneWidget);
    }
  });
}

class _Empty extends ChannelRepository {
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({bool forceRefresh = false}) async => [];
}
