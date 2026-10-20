import unittest
import json
import tempfile
from pathlib import Path
from aggregate import aggregate, export_categories


class AggregateTest(unittest.TestCase):
    def test_missing_shards_stay_pending_and_inconclusive_is_not_unavailable(self):
        candidate = lambda url: {'url': url, 'name': url, 'eligible': True,
          'origins': ['br'], 'group': 'Infantil'}
        inventory = {'candidates': [candidate('a'), candidate('b'), candidate('c')],
          'sources': {'br': {}}, 'complete': True, 'sourceFailures': {}, 'summary': {}}
        report = [{'channelUrl': 'a', 'testedAt': '2026-10-20T00:00:00Z', 'automaticAudiovisualPass': False},
                  {'channelUrl': 'b', 'testedAt': '2026-10-20T00:00:00Z', 'automaticAudiovisualPass': True}]
        result = aggregate(inventory, [report])
        self.assertEqual([r['status'] for r in result['channels']], ['failed_or_inconclusive', 'automatic_audiovisual_pass', 'pending'])
        self.assertEqual(result['summary']['tested'], 2)
        self.assertEqual(result['summary']['productionApproved'], 0)
        self.assertEqual(result['summary']['approvedByCategory'], {'Infantil': 1})

    def test_category_exports_exclude_pending_failed_blocked_and_remove_stale_files(self):
        def row(name, status='automatic_audiovisual_pass', blocked=False):
            return {'name': name, 'url': 'https://example.test/' + name, 'group': 'Infantil',
                    'eligible': True, 'blocked': blocked, 'status': status,
                    'result': {'preferred': 'exo', 'testedAt': '2026-10-20T00:00:00Z'}}
        result = {'channels': [row('Zebra'), row('Árvore'), row('Pendente', 'pending'),
                               row('Falhou', 'failed_or_inconclusive'), row('Bloqueado', blocked=True)]}
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            index = export_categories(result, out)
            self.assertEqual([r['category'] for r in index[:4]], ['TV ao Vivo', 'Esportes', 'Infantil', 'Notícias'])
            entry = index[2]
            self.assertEqual(entry['validatedChannels'], 2)
            exported = json.loads((out / entry['files']['json']).read_text())
            self.assertEqual([r['name'] for r in exported], ['Árvore', 'Zebra'])
            playlist = (out / entry['files']['m3u']).read_text()
            self.assertLess(playlist.index('Árvore'), playlist.index('Zebra'))
            self.assertNotIn('Pendente', playlist)
            self.assertNotIn('Bloqueado', playlist)
            empty = export_categories({'channels': []}, out)
            self.assertTrue(all(e['validatedChannels'] == 0 and not e['files'] for e in empty))
            self.assertEqual(list((out / 'categories').iterdir()), [])


if __name__ == '__main__':
    unittest.main()
