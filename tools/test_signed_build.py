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

if __name__ == '__main__':
    unittest.main()
