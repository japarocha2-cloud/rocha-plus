import base64
import json
import tempfile
import unittest
from pathlib import Path
from prepare_signed_build import prepare

class SignedBuildTest(unittest.TestCase):
    def test_missing_secrets_fail_before_writing(self):
        with tempfile.TemporaryDirectory() as folder:
            private = Path(folder) / 'private'
            with self.assertRaises(ValueError):
                prepare(folder, private, {})
            self.assertFalse(private.exists())

    def test_restores_inputs_and_replaces_debug_signing_without_embedding_password(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            gradle = root / 'android/app/build.gradle.kts'
            gradle.parent.mkdir(parents=True)
            gradle.write_text('android {\n    buildTypes {\nrelease { signingConfig = signingConfigs.getByName("debug") }\n}\n}')
            config = {'ROCHA_FIREBASE_PROJECT_ID':'rocha-plus',
                      'ROCHA_FIREBASE_APP_ID':'1:977269532083:android:7f7b15eff64a6a443f97c6',
                      'ROCHA_FIREBASE_API_KEY':'test', 'ROCHA_FIREBASE_SENDER_ID':'test',
                      'ROCHA_GOOGLE_SERVER_CLIENT_ID':'test'}
            key, cfg = prepare(root, root / 'private', {
                'ROCHA_KEYSTORE_BASE64':base64.b64encode(b'fixture').decode(),
                'ROCHA_KEYSTORE_PASSWORD':'fixture-password', 'ROCHA_KEY_ALIAS':'fixture',
                'ROCHA_FIREBASE_CONFIG_JSON':json.dumps(config)})
            self.assertEqual(key.read_bytes(), b'fixture')
            self.assertEqual(json.loads(cfg.read_text()), config)
            self.assertNotIn('getByName("debug")', gradle.read_text())
            self.assertNotIn('fixture-password', gradle.read_text())

    def test_automatic_builds_cannot_publish_locked_apk_as_full_beta(self):
        workflow = (Path(__file__).resolve().parents[1] /
                    '.github/workflows/build.yml').read_text(encoding='utf-8')
        signed = "github.event_name == 'workflow_dispatch' && inputs.signed_login"
        for step in ('Build universal APK', 'Build optimized APKs',
                     'Build Play Store bundle', 'Verify release evidence',
                     'Upload release evidence', 'Upload universal APK',
                     'Upload ARM64 APK', 'Upload Play Store AAB'):
            heading = f'- name: {step}'
            self.assertIn(heading, workflow)
            self.assertIn(f'if: {signed}', workflow[workflow.index(heading):][:170])
        self.assertIn('name: rocha-plus-beta-login-universal', workflow)
        self.assertIn('name: rocha-plus-beta-login-arm64', workflow)
        self.assertIn('name: rocha-plus-beta-login-play-store-aab', workflow)
        self.assertNotIn('name: rocha-plus-universal', workflow)
        self.assertNotIn('name: rocha-plus-play-store', workflow)
        self.assertIn('name: rocha-plus-layout-preview-no-channels', workflow)
        self.assertIn('--dart-define=ROCHA_LAYOUT_PREVIEW=true', workflow)

if __name__ == '__main__':
    unittest.main()
