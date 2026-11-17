import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocha_plus/src/live/c7_selected_catalog.dart';
import 'package:rocha_plus/src/live/lab_presentation_overlay.dart';

void main() {
  final raw = File('branding/c7/selection.json').readAsStringSync();
  final sha = sha256.convert(utf8.encode(raw)).toString();
  final overlayRaw = File('branding/lab/presentation_overlay.json').readAsStringSync();

  C7SelectedCatalog catalog({String? overlay}) => C7SelectedCatalog(
        read: () async => raw, expectedSha256: sha,
        readOverlay: overlay == null ? null : () async => overlay);

  test('without the LAB layer the pinned catalog is unchanged (482 cards)', () async {
    final channels = await catalog().load();
    expect(channels, hasLength(482));
    expect(channels.any((c) => c.group == 'Não testados'), isFalse);
  });

  test('LAB layer: agreed categories, no duplicate Rá-Tim-Bum, approved Retrô URL', () async {
    final channels = await catalog(overlay: overlayRaw).load();
    expect(channels, hasLength(481));
    expect(channels.map((c) => c.group).toSet().difference(LabPresentationOverlay.agreedOrder.toSet()), isEmpty);
    expect(channels.where((c) => c.group == 'Não testados'), hasLength(71));
    final esportes = channels.where((c) => c.group == 'Esportes').toList();
    expect(esportes.first.name, 'CazéTV');
    final ratimbum = channels.where((c) => RegExp(r'r[aá][ -]?tim[ -]?bum', caseSensitive: false).hasMatch(c.name));
    expect(ratimbum.map((c) => c.name), ['TV Rá-Tim-Bum HD']);
    expect(ratimbum.single.url, 'http://170.83.49.66:8083/TVRATIMBUMHD/index.m3u8');
    final retro = channels.singleWhere((c) => c.name == 'Retro Cartoon (720p)');
    expect(retro.url, 'https://stmv1.video.brstream.com.br/retrotv/retrotv/playlist.m3u8');
    expect(channels.map((c) => c.url).toSet(), hasLength(channels.length));
  });

  test('priority channels keep their documented links', () async {
    final byName = {for (final c in await catalog(overlay: overlayRaw).load()) c.name: c};
    expect(byName['CazéTV']!.url, 'http://138.204.86.4:8080/CAZE_TV/playlist.m3u8');
    expect(byName['History (Brazil) (720p)']!.url, 'http://170.83.16.50/HISTORY/index.m3u8');
    expect(byName['TV Globo Sao Paulo (720p)']!.url, 'http://79.127.238.228:14173/');
    expect(byName.keys, containsAll(['Record News (720p)', 'Pluto TV Record News (720p)',
        'RecordTV Interior SP', 'Record TV MT', 'Globoplay Novelas (1080p)',
        'History 2 Latin America Brazil (720p)']));
  });

  test('a layer made for another selection, or a malformed one, is ignored', () async {
    final other = overlayRaw.replaceFirst(sha, '0' * 64);
    expect(await catalog(overlay: other).load(), hasLength(482));
    expect(await catalog(overlay: '{not json').load(), hasLength(482));
    final badCategory = overlayRaw.replaceFirst('"category": "Esportes"', '"category": "Novelas"');
    expect(await catalog(overlay: badCategory).load(), hasLength(482));
  });

  test('layer keeps Globoplay Novelas organized and hides no Record (conflict left to owner)', () async {
    final channels = await catalog(overlay: overlayRaw).load();
    expect(channels.singleWhere((c) => c.name == 'Globoplay Novelas (1080p)').group, 'Outros');
    final records = channels.where((c) => c.name.toLowerCase().contains('record')).map((c) => c.name).toSet();
    final base = (await catalog().load()).where((c) => c.name.toLowerCase().contains('record')).map((c) => c.name).toSet();
    expect(records, base);
  });
}
