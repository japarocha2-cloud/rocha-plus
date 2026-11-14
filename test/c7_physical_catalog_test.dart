import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/c7_catalog_policy.dart';

void main() {
  test('C7 preserves approved Record variants and unrelated names', () {
    const rows = [
      Channel(name: 'Record (720p)', url: 'remove'),
      Channel(name: 'RecordTV Goias (720p) [Geo-blocked]', url: 'remove2'),
      Channel(name: 'Record News (720p)', url: 'news'),
      Channel(name: 'Pluto TV Record News (720p)', url: 'pluto'),
      Channel(name: 'RecordTV Interior SP', url: 'interior'),
      Channel(name: 'Recordação', url: 'other'),
      Channel(name: 'Record Store Radio', url: 'unrelated'),
      Channel(name: 'HISTORY Brasil', url: 'history', logo: 'logo'),
    ];
    final result = C7CatalogPolicy.apply(rows);
    expect(result, rows.skip(2).toList());
    for (final c in result) { expect(identical(c, rows.firstWhere((r) => r.url == c.url)), isTrue); }
    expect(rows, hasLength(8));
  });
  test('CazéTV first sports slot is stable and preserves URL, artwork and others', () {
    const rows = [
      Channel(name: 'Notícias', url: 'news', group: 'Notícias'),
      Channel(name: 'Sport B', url: 'b', group: 'Esportes'),
      Channel(name: 'Sport A', url: 'a', group: 'Esportes'),
      Channel(name: 'CazéTV', url: 'working', group: 'Esportes', logo: 'approved'),
      Channel(name: 'HISTORY', url: 'history', group: 'Documentários'),
    ];
    final result = C7CatalogPolicy.apply(rows);
    expect(result.map((c) => c.url), ['news','working','b','a','history']);
    expect(identical(result[1], rows[3]), isTrue);
    expect(C7CatalogPolicy.apply(result), result);
  });
}
