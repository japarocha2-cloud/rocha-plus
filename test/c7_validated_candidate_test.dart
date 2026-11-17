import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocha_plus/src/live/c7_catalog_policy.dart';
import 'package:rocha_plus/src/live/c7_selected_catalog.dart';

// The LAB candidate (C7 900 -> approved by real decode) loads through the app's
// own pinned C7 loader. The official selection.json is untouched.
void main() {
  final raw = File('branding/lab/c7_validated_selection.json').readAsStringSync();
  final sha = sha256.convert(utf8.encode(raw)).toString();

  test('validated candidate loads with its pinned SHA, CazéTV first in Esportes', () async {
    final channels = await C7SelectedCatalog(read: () async => raw, expectedSha256: sha).load();
    expect(channels, hasLength(jsonDecode(raw)['channels'].length));
    final sports = channels.where((c) => c.group == 'Esportes').toList();
    expect(C7CatalogPolicy.isCaze(sports.first), isTrue);
    expect(channels.map((c) => c.url).toSet(), hasLength(channels.length));
    final names = channels.map((c) => c.name).toSet();
    expect(names, containsAll(['Rede Globo (1080p)', 'History (Brazil) (720p)', 'TV Ra Tim Bum (720p)',
        'Globoplay Novelas (1080p)', 'DD Sports HD (1080p)', 'SBC TV (1080p)', 'TV Globo Brasilia (1080p)']));
    // Unstable / duplicate / non-functional entries are kept out of the LAB selection (reported separately).
    expect(names, isNot(contains('Pluto TV Record News (720p)')));
    expect(names, isNot(contains('DD Sports (1080p)')));
    expect(names, isNot(contains('TV Globo Sao Paulo (720p)')));
    // Restored after two clean 180 s retests (17/11/2026), shown under Culinária.
    final masterChef = channels.singleWhere((c) => c.name == 'MasterChef');
    expect(masterChef.group, 'Culinária');
    expect(masterChef.url, 'https://jmp2.uk/plu-6077045b6031bd00078de127.m3u8');
    final globo = channels.singleWhere((c) => c.name == 'Rede Globo (1080p)');
    expect(globo.url, 'http://79.127.238.228:14173/');
  });

  test('candidate is rejected if altered (no silent fallback)', () async {
    final tampered = raw.replaceFirst('CazeTV', 'CazeTV ');
    expect(() => C7SelectedCatalog(read: () async => tampered, expectedSha256: sha).load(),
        throwsA(isA<C7CatalogUnavailable>()));
  });

  test('official selection.json still loads unchanged with the official pin', () async {
    final official = await C7SelectedCatalog(read: () async => File('branding/c7/selection.json').readAsStringSync()).load();
    expect(official, hasLength(482));
  });
}
