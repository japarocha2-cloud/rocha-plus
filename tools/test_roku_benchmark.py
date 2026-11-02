import hashlib
import json
import unittest
from pathlib import Path
from urllib.parse import urlsplit

from import_roku_benchmark import CAT, EXPECTED_SHA256, SOURCE, convert


class RokuBenchmarkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (CAT / SOURCE).read_bytes()
        cls.previous = json.loads((CAT / 'approved.json').read_text())
        cls.active, cls.pending, cls.manifest = convert(cls.data, cls.previous)

    def test_inventory_preserved_without_promoting_negative_results(self):
        self.assertEqual(len(self.active), 395)
        self.assertEqual(len(self.pending), 393)
        self.assertEqual(self.manifest['positive_pending_rows'], 114)
        self.assertEqual(len({r['url'] for r in self.active + self.pending}), 788)
        self.assertEqual(sum(r['evidence']['detection'] == 'video_audio' for r in self.active + self.pending), 509)

    def test_only_https_hls_positive_candidates_reach_runtime(self):
        for row in self.active:
            self.assertEqual(urlsplit(row['url']).scheme, 'https')
            self.assertIn('.m3u8', row['url'].lower())
            self.assertEqual(row['evidence']['detection'], 'video_audio')
            self.assertFalse(row['approved'])
            self.assertFalse(row['evidence']['roku_playback_verified'])

    def test_existing_ids_and_metadata_preserved(self):
        old = {r['url']: r for r in self.previous}
        for row in self.active:
            if row['url'] in old:
                self.assertEqual(row['id'], old[row['url']]['id'])
                self.assertEqual(row['group'], old[row['url']]['group'])
                if old[row['url']].get('logo'):
                    self.assertEqual(row['logo'], old[row['url']]['logo'])
        self.assertEqual(len({r['id'] for r in self.active}), 395)

    def test_explicit_blocks_not_overridden_by_benchmark(self):
        previous = json.loads(json.dumps(self.previous))
        previous.append(dict(self.active[0], blocked=True))
        active, pending, _ = convert(self.data, previous)
        self.assertNotIn(self.active[0]['url'], {r['url'] for r in active})
        blocked = next(r for r in pending if r['url'] == self.active[0]['url'])
        self.assertIn('previous_explicit_block', blocked['review_reasons'])

    def test_modified_snapshot_rejected(self):
        with self.assertRaises(ValueError):
            convert(self.data + b'\n', self.previous)

    def test_reproducible_export(self):
        for name, value in [('benchmark-test.json', self.active), ('benchmark-pending.json', self.pending), ('benchmark-manifest.json', self.manifest)]:
            self.assertEqual(json.loads((CAT / name).read_text()), value)
        self.assertEqual(hashlib.sha256(self.data).hexdigest(), EXPECTED_SHA256)


if __name__ == '__main__':
    unittest.main()
