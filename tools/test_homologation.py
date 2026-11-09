import base64
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_homologation import BRANCH, PACKAGE, PROJECT, firebase_configuration, prepare, verify


class HomologationTest(unittest.TestCase):
    fingerprint = 'ab' * 20

    def source(self):
        return {'project_info': {'project_id': PROJECT, 'project_number': '123'},
                'client': [{'client_info': {'mobilesdk_app_id': '1:123:android:fixture',
                            'android_client_info': {'package_name': PACKAGE}},
                            'api_key': [{'current_key': 'test-key'}],
                            'oauth_client': [{'client_type': 3, 'client_id': 'fixture.apps.googleusercontent.com'},
                                             {'client_type': 1, 'android_info': {'package_name': PACKAGE,
                                                                               'certificate_hash': self.fingerprint}}]}]}

    def test_configuration_maps_only_experimental_project_and_package(self):
        config, fingerprints = firebase_configuration(self.source())
        self.assertEqual(config['ROCHA_FIREBASE_PROJECT_ID'], PROJECT)
        self.assertEqual(fingerprints, [self.fingerprint])

    def test_official_project_wrong_package_and_missing_android_oauth_are_rejected(self):
        for kind in ['project', 'package', 'sha', 'ambiguous_web', 'app']:
            source = self.source()
            if kind == 'project':
                source['project_info']['project_id'] = 'rocha-plus'
            elif kind == 'package':
                source['client'][0]['client_info']['android_client_info']['package_name'] = 'com.rochaplus.app'
            elif kind == 'sha':
                source['client'][0]['oauth_client'].pop()
            elif kind == 'ambiguous_web':
                source['client'][0]['oauth_client'].append({'client_type': 3, 'client_id': 'other.apps.googleusercontent.com'})
            else:
                source['client'][0]['client_info']['mobilesdk_app_id'] = '1:999:android:fixture'
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                firebase_configuration(source)

    def env(self):
        return {'GITHUB_REF': BRANCH, 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                'ROCHA_LAB_GOOGLE_SERVICES_JSON': json.dumps(self.source()),
                'LAB_KEYSTORE_BASE64': base64.b64encode(b'test-keystore').decode(),
                'LAB_KEYSTORE_PASSWORD': 'test-password', 'LAB_KEY_ALIAS': 'test-alias'}

    def scaffold(self, root):
        gradle = root / 'android/app/build.gradle.kts'
        gradle.parent.mkdir(parents=True)
        gradle.write_text('android {\n    buildTypes {\n        getByName("release") {}\n    }\n}')
        manifest = root / 'android/app/src/main/AndroidManifest.xml'
        manifest.parent.mkdir(parents=True)
        manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Rocha+" /></manifest>')
        return gradle

    def test_manual_experimental_only_and_no_private_files_on_rejection(self):
        for change in [{'GITHUB_REF': 'refs/heads/main'}, {'GITHUB_EVENT_NAME': 'pull_request'},
                       {'GITHUB_REF': 'refs/heads/fix/subscription-access-20261026',
                        'GITHUB_EVENT_NAME': 'push'},
                       {'LAB_KEYSTORE_PASSWORD': ''}]:
            with tempfile.TemporaryDirectory() as directory:
                private = Path(directory) / 'private'
                with self.assertRaises(ValueError):
                    prepare(directory, private, self.env() | change)
                self.assertFalse(private.exists())

    def test_manual_correction_branch_keeps_homologation_isolated(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle = self.scaffold(root)
            config_path, _ = prepare(root, root / 'private', self.env() | {
                'GITHUB_REF': 'refs/heads/fix/subscription-access-20261026'})
            config = json.loads(config_path.read_text())
            self.assertEqual(config['ROCHA_FIREBASE_PROJECT_ID'], PROJECT)
            self.assertEqual(config['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'false')
            self.assertEqual(config['ROCHA_ENTITLEMENT_URL'], '')
            self.assertIn('applicationIdSuffix = ".lab"', gradle.read_text())

    def test_correction_branch_can_prepare_explicit_subscription_experiment(self):
        endpoint = 'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/entitlement'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.scaffold(root)
            config_path, _ = prepare(root, root / 'private', self.env() | {
                'GITHUB_REF': 'refs/heads/fix/subscription-access-20261026',
                'ROCHA_SUBSCRIPTION_LAB': 'true', 'ROCHA_ENTITLEMENT_URL': endpoint})
            config = json.loads(config_path.read_text())
            self.assertEqual(config['ROCHA_FIREBASE_PROJECT_ID'], PROJECT)
            self.assertEqual(config['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'true')
            self.assertEqual(config['ROCHA_ENTITLEMENT_URL'], endpoint)
            self.assertEqual(config['ROCHA_LAB_ONLY'], 'false')
            expected = json.loads((root / 'private/expected.json').read_text())
            self.assertTrue(expected['subscriptionEnforcementConfigured'])
            self.assertTrue(expected['entitlementEndpointConfigured'])

    def test_enabled_homologation_cannot_send_tokens_to_another_endpoint(self):
        for endpoint in ['https://rights.example/v1/entitlement',
                         'https://southamerica-east1-rocha-plus.cloudfunctions.net/entitlement',
                         'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/entitlement?token=secret']:
            with self.subTest(endpoint=endpoint), tempfile.TemporaryDirectory() as directory:
                private = Path(directory) / 'private'
                with self.assertRaises(ValueError):
                    prepare(directory, private, self.env() | {
                        'ROCHA_SUBSCRIPTION_LAB': 'true', 'ROCHA_ENTITLEMENT_URL': endpoint})
                self.assertFalse(private.exists())

    def test_scaffold_isolated_and_json_cannot_enable_lab_player_or_payment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle = self.scaffold(root)
            source = self.source() | {'ROCHA_LAB_ONLY': 'true', 'ROCHA_EXPERIMENTAL_SUBSCRIPTIONS': 'true'}
            config_path, key = prepare(root, root / 'private', self.env() | {'ROCHA_LAB_GOOGLE_SERVICES_JSON': json.dumps(source)})
            config = json.loads(config_path.read_text())
            self.assertEqual(config['ROCHA_LAB_ONLY'], 'false')
            self.assertEqual(config['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'false')
            self.assertIn('applicationIdSuffix = ".lab"', gradle.read_text())
            self.assertNotIn('test-password', gradle.read_text())
            self.assertEqual(key.stat().st_mode & 0o777, 0o600)
            expected = json.loads((root / 'private/expected.json').read_text())
            self.assertFalse(expected['subscriptionEnforcementConfigured'])
            self.assertFalse(expected['entitlementEndpointConfigured'])

    def check_apk(self, package=PACKAGE, digests=None, crypto_error=False, metadata=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk, expected, output = (root / n for n in ['app.apk', 'expected.json', 'report.json'])
            apk.write_bytes(b'fixture-apk')
            expected.write_text(json.dumps({'project': PROJECT, 'package': PACKAGE,
                                           'certificateSha1': [self.fingerprint],
                                           **({'subscriptionEnforcementConfigured': False,
                                               'entitlementEndpointConfigured': False}
                                              if metadata is None else metadata)}))
            result = subprocess.CompletedProcess([], 0, f"package: name='{package}' versionCode='1'", '')
            with patch('prepare_homologation.subprocess.run', return_value=result), \
                 patch('prepare_homologation.report_certificate', return_value=digests or [self.fingerprint],
                       side_effect=RuntimeError('bad signature') if crypto_error else None):
                try:
                    report = verify(apk, root, expected, root / 'summary', output)
                    return report
                except (ValueError, RuntimeError):
                    self.assertFalse(output.exists())
                    raise

    def test_apk_wrong_package_or_certificate_cannot_generate_success_report(self):
        with self.assertRaises(ValueError):
            self.check_apk(package='com.rochaplus.app')
        with self.assertRaises(ValueError):
            self.check_apk(digests=['cd' * 20])
        with self.assertRaises(RuntimeError):
            self.check_apk(crypto_error=True)

    def test_matching_apk_certificate_is_configuration_evidence_only(self):
        report = self.check_apk()
        self.assertTrue(report['certificateMatchesConfiguration'])
        self.assertFalse(report['productionApproved'])
        self.assertFalse(report['cloudAccessValidated'])
        self.assertEqual(report['physicalLoginValidation'], 'pending')

    def test_access_configuration_never_implies_payment_or_trial_homologation(self):
        for enabled in (False, True):
            report = self.check_apk(metadata={
                'subscriptionEnforcementConfigured': enabled,
                'entitlementEndpointConfigured': enabled})
            self.assertEqual(report['subscriptionEnforcementConfigured'], enabled)
            self.assertEqual(report['entitlementEndpointConfigured'], enabled)
            self.assertEqual(report['paymentFlowValidation'], 'pending')
            self.assertEqual(report['trialExpiryValidation'], 'pending')
            self.assertFalse(report['productionApproved'])
            self.assertFalse(report['cloudAccessValidated'])

    def test_missing_or_inconsistent_access_metadata_blocks_success_report(self):
        for metadata in ({}, {'subscriptionEnforcementConfigured': 'false',
                              'entitlementEndpointConfigured': False},
                         {'subscriptionEnforcementConfigured': True,
                          'entitlementEndpointConfigured': False}):
            with self.subTest(metadata=metadata), self.assertRaises(ValueError):
                self.check_apk(metadata=metadata)
