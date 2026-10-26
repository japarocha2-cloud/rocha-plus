import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from report_apk_certificate import certificate_fingerprints, report


class CertificateReportTest(unittest.TestCase):
    digest = 'ab' * 20

    def test_numbered_and_sdk_range_certificates_are_supported(self):
        for label in ['Signer #1', 'Signer (minSdkVersion=28, maxSdkVersion=32)',
                      'Signer (minSdkVersion=33 (dev release=true), maxSdkVersion=37)']:
            with self.subTest(label=label):
                self.assertEqual(certificate_fingerprints(
                    f'{label} certificate SHA-1 digest: {self.digest}\n'), [self.digest])

    def test_public_key_stamp_and_malformed_digests_cannot_pass(self):
        for line in [f'Signer #1 public key SHA-1 digest: {self.digest}',
                     f'Source Stamp Signer certificate SHA-1 digest: {self.digest}',
                     'Signer #1 certificate SHA-1 digest: abc', '']:
            with self.subTest(line=line), self.assertRaises(ValueError):
                certificate_fingerprints(line)

    def test_invalid_apk_never_writes_success_even_with_digest_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk, signer, summary = (root / n for n in ['app.apk', 'apksigner', 'summary'])
            apk.touch()
            signer.touch(mode=0o700)
            result = subprocess.CompletedProcess([], 1,
                f'Signer #1 certificate SHA-1 digest: {self.digest}\n', 'DOES NOT VERIFY\n')
            with patch('report_apk_certificate.subprocess.run', return_value=result):
                with self.assertRaises(subprocess.CalledProcessError):
                    report(apk, signer, summary)
            self.assertFalse(summary.exists())

    def test_verified_apk_records_certificate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk, signer, summary = (root / n for n in ['app.apk', 'apksigner', 'summary'])
            apk.touch()
            signer.touch(mode=0o700)
            result = subprocess.CompletedProcess([], 0,
                f'Signer (minSdkVersion=28, maxSdkVersion=37) certificate SHA-1 digest: {self.digest}\n', '')
            with patch('report_apk_certificate.subprocess.run', return_value=result):
                report(apk, signer, summary)
            self.assertIn(self.digest, summary.read_text())
