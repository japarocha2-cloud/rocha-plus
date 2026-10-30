import unittest
from prepare_tv_channel_fixtures import prepare, m3u


class TestTvFixtures(unittest.TestCase):
    def test_https_filter(self):
        data = [{"name": "A", "url": "http://example.org/a.m3u8"}, {"name": "B", "url": "https://example.org/b.m3u8"}]
        self.assertEqual([x["name"] for x in prepare(data)], ["B"])

    def test_no_implicit_approval(self):
        data = [{"name": "A", "url": "https://example.org/a.m3u8", "productionApproved": False}]
        item = prepare(data)[0]
        self.assertFalse(item["production_approved"])
        self.assertEqual(item["android_tv"]["result"], "not_tested")
        self.assertEqual(item["roku_tv"]["result"], "not_tested")

    def test_dedupe_and_block(self):
        data = [{"name": "A", "url": "https://example.org/a.m3u8", "blocked": True},
                {"name": "B", "url": "https://example.org/b.m3u8"},
                {"name": "B alt", "url": "https://example.org/b.m3u8"}]
        self.assertEqual(len(prepare(data)), 1)

    def test_m3u(self):
        item = prepare([{"name": "Canal Exemplo", "url": "https://example.org/live.m3u8", "group": "Cultura"}])[0]
        self.assertIn("#EXTM3U", m3u(item))
        self.assertIn("https://example.org/live.m3u8", m3u(item))


if __name__ == "__main__":
    unittest.main()
