import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocha_plus/src/live/c7_selected_catalog.dart';
import 'package:rocha_plus/src/live/catalog_presentation.dart';
import 'package:rocha_plus/src/live/channel.dart';

void main() {
  test('Home shows exactly CazéTV, SBT Nacional and Rede Globo, in order, from the LAB selection', () async {
    final raw = File('branding/lab/c7_validated_selection.json').readAsStringSync();
    final channels = await C7SelectedCatalog(read: () async => raw,
        expectedSha256: sha256.convert(utf8.encode(raw)).toString()).load();
    final highlights = homeHighlights(channels);
    expect(highlights.map((c) => c.name),
        ['CazeTV (1080p)', 'SBT Nacional (1080p)', 'Rede Globo (1080p)']);
    expect(highlights.any((c) => c.name.startsWith('SBT Interior')), isFalse);
    expect(highlights[0].url, 'http://138.204.86.4:8080/CAZE_TV/playlist.m3u8');
    expect(highlights[2].url, 'http://79.127.238.228:14173/');
    // 539 audited + MasterChef restored after two clean 180 s retests (17/11/2026).
    expect(channels, hasLength(540), reason: 'selection unchanged except MasterChef');
  });

  test('regional variants never enter, and a missing channel is simply skipped', () {
    const list = [
      Channel(name: 'SBT Interior (720p)', url: 'https://a/1', group: 'TV aberta'),
      Channel(name: 'TV Globo Brasilia (1080p)', url: 'https://a/2', group: 'Outros'),
      Channel(name: 'Rede Globo (1080p)', url: 'https://a/3', group: 'TV aberta'),
      Channel(name: 'Rede Globo (720p)', url: 'https://a/4', group: 'TV aberta'),
    ];
    expect(homeHighlights(list).map((c) => c.url), ['https://a/3']);
  });
}
