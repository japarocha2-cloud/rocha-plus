import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/c7_selected_catalog.dart';

void main() {
  final raw = File('test/fixtures/c7_selection_fixture.json').readAsStringSync();
  final hash = File('test/fixtures/c7_selection_fixture.sha256').readAsStringSync().trim();
  test('Python export and Dart SHA match; categories/URLs/order are preserved', () async {
    final rows = await C7SelectedCatalog(read: () async => raw, expectedSha256: hash).load();
    expect(rows.map((c) => c.name), ['News','CazéTV','ESPN','HISTORY']);
    expect(rows.map((c) => c.group), ['Notícias','Esportes','Esportes','Documentários']);
    expect(rows[1].url, 'http://138.204.86.4:8080/CAZE_TV/playlist.m3u8');
    expect(rows.last.url, 'http://170.83.16.50/HISTORY/index.m3u8');
    expect(rows[1].logo, 'https://example.test/logo');
  });
  test('missing pin and tampered bytes fail without reading candidates', () async {
    var reads = 0;
    await expectLater(C7SelectedCatalog(read: () async {reads++; return raw;}, expectedSha256: '').load(), throwsA(isA<C7CatalogUnavailable>()));
    expect(reads,0);
    await expectLater(C7SelectedCatalog(read: () async => '$raw ', expectedSha256: hash).load(), throwsA(isA<C7CatalogUnavailable>()));
  });
  test('removed ID/name, duplicate IDs and English runtime categories are rejected', () async {
    for (final variant in ['removed-id','removed-identity','duplicate','english']) {
      final data = jsonDecode(raw) as Map<String,dynamic>;
      final rows = data['channels'] as List;
      if (variant == 'removed-id') rows[0]['id'] = 'removed';
      if (variant == 'removed-identity') {rows[0]['id']='different'; rows[0]['name']='Removed'; rows[0]['url']='https://example.test/new-url';}
      if (variant == 'duplicate') rows[0]['id'] = rows[1]['id'];
      if (variant == 'english') rows[0]['group'] = 'Sports';
      final altered = jsonEncode(data);
      await expectLater(C7SelectedCatalog(read: () async => altered, expectedSha256: sha256.convert(utf8.encode(altered)).toString()).load(), throwsA(isA<C7CatalogUnavailable>()),reason:variant);
    }
  });
}
