import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from validate_cazetv_source import official_author, validate

class CazeTvBuildTest(unittest.TestCase):
    def test_official_metadata_and_fixed_https_endpoint(self):
        def fetch(url):
            endpoint = urlsplit(url)
            self.assertEqual(endpoint.netloc, "www.youtube.com")
            self.assertEqual(endpoint.scheme, "https")
            self.assertEqual(endpoint.path, "/oembed")
            self.assertEqual(parse_qs(endpoint.query)["url"],
                             ["https://www.youtube.com/watch?v=abcdefghijk"])
            return {"type": "video", "provider_name": "YouTube",
                    "author_url": "https://www.youtube.com/@CazeTV"}
        evidence = validate("abcdefghijk", fetch)
        self.assertTrue(evidence["metadata_verified"])
        self.assertFalse(evidence["playback_verified"])

    def test_invalid_id_never_fetches(self):
        def fetch(_):
            self.fail("Must not fetch invalid ID")
        for value in ["", "../playlist", "https://youtu.be/abcdefghijk", "a" * 12]:
            with self.assertRaises(ValueError):
                validate(value, fetch)

    def test_wrong_author_malformed_data_and_network_failure_block(self):
        for payload in [{}, [], {"type": "video", "provider_name": "YouTube",
                                 "author_url": "https://www.youtube.com/@fake"}]:
            with self.assertRaises(ValueError):
                validate("abcdefghijk", lambda _: payload)
        def offline(_):
            raise OSError("offline")
        with self.assertRaises(OSError):
            validate("abcdefghijk", offline)

    def test_author_url_is_exact(self):
        self.assertTrue(official_author("https://www.youtube.com/@CazeTV"))
        for url in ["https://www.youtube.com.evil.test/@CazeTV",
                    "https://user@www.youtube.com/@CazeTV",
                    "https://www.youtube.com/@CazeTV?x=1",
                    "http://www.youtube.com/@CazeTV", None]:
            self.assertFalse(official_author(url))

    def test_signed_outputs_all_receive_same_video_id_and_preview_does_not(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    ".github/workflows/build.yml").read_text(encoding="utf-8")
        define = '--dart-define="CAZETV_YOUTUBE_VIDEO_ID=$CAZETV_YOUTUBE_VIDEO_ID"'
        self.assertEqual(workflow.count(define), 3)
        self.assertIn("python3 tools/validate_cazetv_source.py", workflow)
        preview = workflow.split("- name: Build visual-only layout preview APK")[1]
        preview = preview.split("- name: Upload visual-only")[0]
        self.assertNotIn("CAZETV_YOUTUBE_VIDEO_ID", preview)

if __name__ == "__main__":
    unittest.main()
