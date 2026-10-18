from pathlib import Path
import unittest
from android_version_code import resolve_version_code, MAX_VERSION_CODE, VERSION_CODE_BASE

class AndroidVersionCodeTests(unittest.TestCase):
    def test_first_corrected_candidate_updates_legacy_2465(self):
        self.assertGreater(resolve_version_code('503'), 2465)

    def test_following_runs_are_strictly_increasing(self):
        self.assertEqual(resolve_version_code('504'), resolve_version_code('503') + 1)

    def test_invalid_values_are_rejected(self):
        for value in ('', '0', '-1', '1.5', 'abc', ' 503', '５０３', None):
            with self.subTest(value=value), self.assertRaises(ValueError):
                resolve_version_code(value)

    def test_android_limit(self):
        self.assertEqual(resolve_version_code(str(MAX_VERSION_CODE - VERSION_CODE_BASE)), MAX_VERSION_CODE)
        with self.assertRaises(ValueError):
            resolve_version_code(str(MAX_VERSION_CODE - VERSION_CODE_BASE + 1))

    def test_all_release_outputs_use_same_resolved_code(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/build.yml').read_text()
        self.assertEqual(workflow.count('--build-number="$ROCHA_ANDROID_VERSION_CODE"'), 3)
        self.assertNotIn('--build-number=${{ github.run_number }}', workflow)
        self.assertIn('run: python3 tools/android_version_code.py', workflow)

if __name__ == '__main__':
    unittest.main()
