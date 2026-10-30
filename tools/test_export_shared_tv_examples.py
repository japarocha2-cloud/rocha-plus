import json
import tempfile
import unittest
from pathlib import Path
from export_shared_tv_examples import export


class SharedTvExamplesTests(unittest.TestCase):
    def test_same_catalog_both_platforms_and_independent_results(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            source = base / "source.json"
            source.write_text(json.dumps([
                {"name": "Canal A", "url": "https://example.org/a.m3u8", "group": "Cultura"},
                {"name": "Canal B", "url": "http://example.org/b.m3u8", "group": "Esportes"},
            ]), encoding="utf-8")
            self.assertEqual(export(source, base / "out", 12), 1)
            roku = (base / "out/roku/catalog-test.json").read_bytes()
            android = (base / "out/android-tv/catalog-test.json").read_bytes()
            self.assertEqual(roku, android)
            item = json.loads(roku)[0]
            self.assertFalse(item["approved"])
            self.assertTrue(item["quarantined"])
            results = json.loads((base / "out/results.json").read_text(encoding="utf-8"))
            self.assertEqual(results["channels"][0]["roku"], "not_tested")
            self.assertEqual(results["channels"][0]["android_tv"], "not_tested")


if __name__ == "__main__":
    unittest.main()
