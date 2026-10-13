import json
import tempfile
import unittest
from pathlib import Path
from sync_platform_baseline import sync, selected, ROOT

class PlatformBaselineTests(unittest.TestCase):
    def test_platforms_have_exact_frozen_catalogue_and_no_candidate_fallback(self):
        self.assertEqual(sync(check=True), 190)
    def test_unreviewed_entry_is_rejected_instead_of_exported(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'catalog').mkdir()
            data = json.loads((ROOT / 'catalog/approved.json').read_text())
            data[0]['approved'] = False
            (root / 'catalog/approved.json').write_text(json.dumps(data))
            (root / 'catalog/quarantine.json').write_text('[]')
            with self.assertRaises(ValueError): selected(root)
    def test_http_entry_is_rejected_instead_of_exported(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'catalog').mkdir()
            data = json.loads((ROOT / 'catalog/approved.json').read_text())
            data[0]['url'] = 'http://example.com/unreviewed'
            (root / 'catalog/approved.json').write_text(json.dumps(data))
            (root / 'catalog/quarantine.json').write_text('[]')
            with self.assertRaises(ValueError): selected(root)
