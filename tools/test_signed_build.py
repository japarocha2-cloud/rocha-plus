import base64
import json
import tempfile
import unittest
from pathlib import Path
from prepare_signed_build import prepare, subscription_config

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
                      'ROCHA_GOOGLE_SERVER_CLIENT_ID':'test',
                      'ROCHA_LAB_ONLY':'true', 'ROCHA_LAYOUT_PREVIEW':'true',
                      'ROCHA_EXPERIMENTAL_SUBSCRIPTIONS':'true',
                      'ROCHA_ENTITLEMENT_URL':'http://untrusted.example'}
            key, cfg = prepare(root, root / 'private', {
                'ROCHA_KEYSTORE_BASE64':base64.b64encode(b'fixture').decode(),
                'ROCHA_KEYSTORE_PASSWORD':'fixture-password', 'ROCHA_KEY_ALIAS':'fixture',
                'ROCHA_FIREBASE_CONFIG_JSON':json.dumps(config)})
            self.assertEqual(key.read_bytes(), b'fixture')
            self.assertEqual(json.loads(cfg.read_text()), config | subscription_config({}))
            self.assertNotIn('getByName("debug")', gradle.read_text())
            self.assertNotIn('fixture-password', gradle.read_text())

    def test_subscription_defaults_override_untrusted_json_modes(self):
        config = subscription_config({})
        self.assertEqual(config['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'false')
        self.assertEqual(config['ROCHA_ENTITLEMENT_URL'], '')
        self.assertEqual(config['ROCHA_LAB_ONLY'], 'false')
        self.assertEqual(config['ROCHA_LAYOUT_PREVIEW'], 'false')

    def test_subscription_endpoint_and_branch_are_required(self):
        env = {'ROCHA_SUBSCRIPTION_LAB': 'true',
               'GITHUB_REF': 'refs/heads/feat/dual-player-lab-20261020'}
        for endpoint in ('', 'http://rights.example/v1/entitlement',
                         'https://user:pass@rights.example/v1/entitlement',
                         'https://127.0.0.1/v1/entitlement',
                         'https://rights.local/v1/entitlement',
                         'https://rights.example:8080/v1/entitlement',
                         'https://rights.example/v1/entitlement?token=secret',
                         'https://rights.example/v1/entitlement#test'):
            with self.subTest(endpoint=endpoint), self.assertRaises(ValueError):
                subscription_config(env | {'ROCHA_ENTITLEMENT_URL': endpoint})
        env['ROCHA_ENTITLEMENT_URL'] = 'https://rights.example/v1/entitlement'
        self.assertEqual(subscription_config(env)['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'true')
        with self.assertRaises(ValueError):
            subscription_config(env | {'GITHUB_REF': 'refs/heads/main'})

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
        self.assertIn("'rocha-plus-beta-login-universal'", workflow)
        self.assertIn("'rocha-plus-subscription-lab-universal'", workflow)
        self.assertIn("'rocha-plus-beta-login-arm64'", workflow)
        self.assertIn("'rocha-plus-subscription-lab-arm64'", workflow)
        self.assertIn("'rocha-plus-beta-login-play-store-aab'", workflow)
        self.assertIn("'rocha-plus-subscription-lab-play-store-aab'", workflow)
        self.assertNotIn('name: rocha-plus-universal', workflow)
        self.assertNotIn('name: rocha-plus-play-store', workflow)
        self.assertIn('name: rocha-plus-layout-preview-no-channels', workflow)
        self.assertIn('--dart-define=ROCHA_LAYOUT_PREVIEW=true', workflow)

if __name__ == '__main__':
    unittest.main()
