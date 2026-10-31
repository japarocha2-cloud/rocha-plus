import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import MagicMock, patch
import prepare_candidate as candidate

WRONG = {'SHA1': 'ab' * 20, 'SHA256': 'cd' * 32}
class ApprovedSignerRegression(unittest.TestCase):
    def test_prepare_rejects_unapproved_signer_before_reading_scaffold(self):
        with patch.object(candidate, 'private_path', return_value=MagicMock()), patch.object(candidate, 'inspect_signing', return_value=WRONG), patch.object(candidate, 'firebase_configuration') as firebase:
            with self.assertRaisesRegex(ValueError, 'approved'):
                candidate.prepare('.', 'fictional-private', {}, {'GITHUB_REF': candidate.IDENTITY['branch'], 'GITHUB_EVENT_NAME': 'workflow_dispatch'})
            firebase.assert_not_called()

    def test_verify_rejects_self_consistent_but_unapproved_certificate(self):
        private = MagicMock()
        (private / 'expected.json').read_text.return_value = json.dumps(candidate.IDENTITY | {'fingerprints': WRONG})
        badging = "package: name='com.rochaplus.app.candidate' versionCode='1' versionName='0.1.0-candidate.1'\nnative-code: 'arm64-v8a'\n"
        signed = 'Signer #1 certificate SHA-1 digest: ' + WRONG['SHA1'] + '\nSigner #1 certificate SHA-256 digest: ' + WRONG['SHA256'] + '\n'
        def run(args, **kwargs):
            return subprocess.CompletedProcess(args, 0, stdout=badging if 'badging' in args else signed)
        with patch.object(candidate, 'private_path', return_value=private), patch.object(candidate, 'inspect_signing', return_value=WRONG), patch.object(candidate.subprocess, 'run', side_effect=run), patch.object(Path, 'read_bytes', return_value=b'fictional-apk'):
            with self.assertRaisesRegex(ValueError, 'approved'):
                candidate.verify('fictional.apk', 'fictional-tools', 'fictional-private')
if __name__ == '__main__':
    unittest.main()
