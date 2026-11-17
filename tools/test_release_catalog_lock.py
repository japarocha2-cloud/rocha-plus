import copy
import io
import json
import unittest
import zipfile
from pathlib import Path

from release_catalog_lock import describe, load_manifest, verify_apk, verify_selection, _compare

ROOT = Path(__file__).resolve().parents[1]


def _bytes(data):
    return json.dumps(data, ensure_ascii=False, indent=1).encode('utf-8')


class ReleaseCatalogLockTest(unittest.TestCase):
    def setUp(self):
        self.manifest = load_manifest(ROOT)
        self.raw = (ROOT / self.manifest['asset']).read_bytes()
        self.data = json.loads(self.raw)

    def test_repository_catalog_matches_frozen_lab_cliente_manifest(self):
        verify_selection(ROOT)
        self.assertEqual(self.manifest['count'], 540)
        self.assertEqual(self.manifest['sha256'],
                         '4e629180b39ca1bd8eace257b935094ea8fcfa317d6be16a5fbe6ce55bfc8ea4')
        names = [p['name'] for p in self.manifest['protected']]
        self.assertEqual(names[0], 'CazeTV (1080p)')
        self.assertIn('Rede Globo (1080p)', names)
        self.assertIn('MasterChef', names)

    def _rejects(self, mutate, message):
        data = copy.deepcopy(self.data)
        mutate(data)
        with self.assertRaisesRegex(ValueError, message):
            _compare(describe(_bytes(data)), self.manifest)

    def test_rejects_added_channel_even_with_new_id(self):
        extra = dict(self.data['channels'][-1], id='ffffffffffffffff', name='Canal Novo',
                     url='https://x.invalid/a.m3u8')
        self._rejects(lambda d: d['channels'].append(extra), 'manifesto')

    def test_rejects_same_count_with_swapped_channel(self):
        def swap(d):
            d['channels'][-1] = dict(d['channels'][-1], id='eeeeeeeeeeeeeeee')
        self._rejects(swap, 'manifesto')

    def test_rejects_duplicate_ids_and_duplicate_channels(self):
        self._rejects(lambda d: d['channels'].append(d['channels'][0]), 'duplicad')

    def test_rejects_reordering_that_moves_cazetv(self):
        def move(d):
            rows = d['channels']
            caze = next(r for r in rows if r['id'] == self.manifest['firstSportsId'])
            rows.remove(caze)
            rows.append(caze)
        self._rejects(move, 'manifesto')

    def test_rejects_changed_globo_link(self):
        globo = next(p for p in self.manifest['protected'] if p['name'] == 'Rede Globo (1080p)')
        def edit(d):
            next(r for r in d['channels'] if r['id'] == globo['id'])['url'] = 'https://other.invalid/'
        self._rejects(edit, 'manifesto')

    def _apk(self, asset_bytes, libapp):
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, 'w') as z:
            if asset_bytes is not None:
                z.writestr('assets/flutter_assets/' + self.manifest['asset'], asset_bytes)
            z.writestr('lib/arm64-v8a/libapp.so', libapp)
        buf.seek(0)
        return buf

    def test_apk_with_frozen_asset_and_compiled_pin_passes(self):
        pin = (self.manifest['asset'] + '\0' + self.manifest['sha256']).encode()
        self.assertTrue(verify_apk(self._apk(self.raw, b'xx' + pin + b'yy'), self.manifest))

    def test_apk_built_with_open_catalog_is_blocked(self):
        # Build #744: asset bundled, but the app never pinned it (iptv-org import).
        with self.assertRaisesRegex(ValueError, 'catálogo aberto'):
            verify_apk(self._apk(self.raw, b'https://iptv-org.github.io/iptv/countries/br.m3u'), self.manifest)

    def test_apk_without_frozen_asset_is_blocked(self):
        with self.assertRaisesRegex(ValueError, 'sem o catálogo'):
            verify_apk(self._apk(None, b''), self.manifest)


if __name__ == '__main__':
    unittest.main()
