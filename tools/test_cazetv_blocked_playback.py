import unittest
from validate_cazetv_source import validate

class BlockedPlaybackTest(unittest.TestCase):
    def test_device_rejected_source_cannot_pass_metadata_validation(self):
        calls = []
        def official_metadata(url):
            calls.append(url)
            return {"type": "video", "provider_name": "YouTube",
                    "author_url": "https://www.youtube.com/@CazeTV"}
        with self.assertRaisesRegex(ValueError, "Owner blocks embedding"):
            validate("vbAYMEX6MVw", fetch=official_metadata)
        self.assertEqual(calls, [])

if __name__ == "__main__":
    unittest.main()
