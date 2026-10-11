import unittest
from tools.channel_stability import media_seconds

class FFmpegProgressTests(unittest.TestCase):
    def test_microseconds_legacy(self):
        self.assertEqual(media_seconds("out_time_ms=30000000\nprogress=end\n"), 30)
    def test_microseconds_modern(self):
        self.assertEqual(media_seconds("out_time_us=30000000\nprogress=end\n"), 30)
    def test_timestamp_fallback(self):
        self.assertEqual(media_seconds("out_time=00:00:30.500000\nprogress=end\n"), 30.5)
    def test_max_progress(self):
        self.assertEqual(media_seconds("out_time_us=2000000\nout_time_us=30000000\n"), 30)
    def test_missing_progress(self):
        self.assertEqual(media_seconds("progress=end\n"), 0)
if __name__ == "__main__":
    unittest.main()
