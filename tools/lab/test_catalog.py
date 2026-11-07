import unittest
from catalog import build, normalize, parse, football


def playlist(name, url, channel_id='x', group=''):
    return f'#EXTM3U\n#EXTINF:-1 tvg-id="{channel_id}" group-title="{group}",{name}\n{url}\n'


class InventoryTest(unittest.TestCase):
    def test_signed_queries_are_not_reordered_and_defaults_deduplicate(self):
        self.assertEqual(normalize('HTTPS://Example.COM:443/live?a=2&b=1#frag'), 'https://example.com/live?a=2&b=1')
        self.assertNotEqual(normalize('https://a/live?a=2&b=1'), normalize('https://a/live?b=1&a=2'))

    def test_metadata_filter_alternates_and_blocks(self):
        sources = {'countries/br.m3u': playlist('BR', 'https://a/live'),
                   'categories/news.m3u': playlist('BR', 'https://a:443/live') + playlist('Alternate', 'https://b/live'),
                   'languages/por.m3u': playlist('Blocked', 'https://c/live', 'blocked'),
                   'categories/sports.m3u': playlist('NFL football', 'https://d/live', 'nfl') + playlist('FIFA', 'https://e/live', 'fifa')}
        result = build(sources, [{'id': 'x', 'country': 'BR'}], {'blocked'})
        rows = {r['url']: r for r in result['candidates']}
        self.assertEqual(result['summary']['duplicateOccurrences'], 1)
        self.assertEqual(rows['https://a/live']['alternateUrls'], ['https://b/live'])
        self.assertTrue(rows['https://b/live']['eligible'])
        self.assertFalse(rows['https://c/live']['eligible'])
        self.assertFalse(rows['https://d/live']['eligible'])
        self.assertTrue(rows['https://e/live']['eligible'])
        self.assertTrue(all(not r['productionApproved'] for r in rows.values()))

    def test_quoted_comma_and_football_false_positives(self):
        row = list(parse('#EXTM3U\n#EXTINF:-1 group-title="News, Current",Name, local\nhttps://a/live\n'))[0]
        self.assertEqual(row['name'], 'Name, local')
        self.assertFalse(football('NFL American football'))
        self.assertFalse(football('Copa do vinho'))
        self.assertFalse(football('Sports TV'))
        self.assertTrue(football('UEFA Champions'))


if __name__ == '__main__':
    unittest.main()
