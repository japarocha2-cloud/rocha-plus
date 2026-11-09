import tempfile
import unittest
from configure_stable_signing import configure

class StableCandidateSigningTest(unittest.TestCase):
    def test_candidate7_never_silently_switches_update_certificate(self):
        with tempfile.TemporaryDirectory() as root:
            for ref in ['lab/candidata7-teste-fisico-20261107', 'lab/p0-candidata7-20261108', 'lab/catalogo-unico-oficial-20261108']:
                with self.subTest(ref=ref), self.assertRaisesRegex(ValueError, 'random update certificate'):
                    configure({'GITHUB_HEAD_REF': ref}, root)

    def test_legacy_missing_key_behavior_is_preserved(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertFalse(configure({}, root))
