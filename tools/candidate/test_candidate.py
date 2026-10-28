import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import prepare_candidate as candidate

SHA = {'SHA1': 'ab' * 20, 'SHA256': 'cd' * 32}


def source():
    return {'project_info': {'project_id': candidate.PROJECT, 'project_number': '123'},
        'client': [{'client_info': {'mobilesdk_app_id': '1:123:android:fixture',
            'android_client_info': {'package_name': candidate.PACKAGE}},
            'api_key': [{'current_key': 'fixture-not-a-credential'}],
            'oauth_client': [{'client_type': 3, 'client_id': 'fixture.apps.googleusercontent.com'},
                {'client_type': 1, 'android_info': {'package_name': candidate.PACKAGE,
                    'certificate_hash': SHA['SHA1']}}]}]}


class CandidateTest(unittest.TestCase):
    def env(self):
        return {'GITHUB_REF': candidate.IDENTITY['branch'], 'GITHUB_EVENT_NAME': 'workflow_dispatch'}

    def scaffold(self, root):
        gradle = root / 'android/app/build.gradle.kts'
        gradle.parent.mkdir(parents=True)
        gradle.write_text('''android {
    defaultConfig { applicationId = "com.rochaplus.app" }
    buildTypes {
        getByName("release") { signingConfig = signingConfigs.getByName("debug") }
        getByName("debug") { applicationIdSuffix = ".lab" }
    }
}
''')
        return gradle

    def test_rejects_official_lab_usbqa_wrong_project_and_oauth_signer(self):
        for kind in ['official', 'lab', 'usbqa', 'project', 'sha', 'web', 'app']:
            data = source()
            if kind in ['official', 'lab', 'usbqa']:
                data['client'][0]['client_info']['android_client_info']['package_name'] = {
                    'official': 'com.rochaplus.app', 'lab': 'com.rochaplus.app.lab',
                    'usbqa': 'com.rochaplus.app.usbqa'}[kind]
            elif kind == 'project':
                data['project_info']['project_id'] = 'rocha-plus-homologacao'
            elif kind == 'sha':
                data['client'][0]['oauth_client'][1]['android_info']['certificate_hash'] = '00' * 20
            elif kind == 'web':
                data['client'][0]['oauth_client'].pop(0)
            else:
                data['client'][0]['client_info']['mobilesdk_app_id'] = '1:999:android:bad'
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                candidate.firebase_configuration(data, SHA)

    def test_no_private_material_inside_repository_or_key_replacement(self):
        with self.assertRaises(ValueError):
            candidate.private_path(candidate.REPO / 'private')
        with tempfile.TemporaryDirectory() as directory:
            private = Path(directory)
            (private / 'candidate.p12').write_bytes(b'fixture')
            with patch.object(candidate.subprocess, 'run') as run, self.assertRaises(ValueError):
                candidate.init_signing(private)
            run.assert_not_called()

    def test_rejected_branch_event_endpoint_and_scaffold_never_mutate_files(self):
        cases = [{'GITHUB_REF': 'refs/heads/main'}, {'GITHUB_EVENT_NAME': 'push'},
            {'ROCHA_CANDIDATE_SUBSCRIPTIONS': 'true', 'ROCHA_CANDIDATE_ENTITLEMENT_URL':
                'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/entitlement'},
            {'ROCHA_CANDIDATE_SUBSCRIPTIONS': 'false', 'ROCHA_CANDIDATE_ENTITLEMENT_URL': candidate.ENDPOINT},
            {'ROCHA_CANDIDATE_SUBSCRIPTIONS': 'yes'}, {'bad_scaffold': True}]
        for change in cases:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / 'source'
                gradle = self.scaffold(root)
                if change.get('bad_scaffold'):
                    gradle.write_text(gradle.read_text().replace('com.rochaplus.app', 'com.rochaplus.app.lab'))
                before = gradle.read_text()
                private = Path(directory) / 'private'
                with patch.object(candidate, 'inspect_signing', return_value=SHA), self.assertRaises(ValueError):
                    candidate.prepare(root, private, source(), self.env() | change)
                self.assertEqual(gradle.read_text(), before)
                self.assertFalse(private.exists())

    def test_candidate_configuration_keeps_private_inputs_outside_scaffold(self):
        for enabled in [False, True]:
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / 'source'
                gradle = self.scaffold(root)
                private = Path(directory) / 'private'
                private.mkdir(mode=0o700)
                env = self.env() | ({'ROCHA_CANDIDATE_SUBSCRIPTIONS': 'true',
                    'ROCHA_CANDIDATE_ENTITLEMENT_URL': candidate.ENDPOINT} if enabled else {})
                with patch.object(candidate, 'inspect_signing', return_value=SHA):
                    config_path = candidate.prepare(root, private, source(), env)
                self.assertEqual(config_path.stat().st_mode & 0o777, 0o600)
                config = json.loads(config_path.read_text())
                self.assertEqual(config['ROCHA_FIREBASE_PROJECT_ID'], candidate.PROJECT)
                self.assertEqual(config['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], str(enabled).lower())
                text = gradle.read_text()
                self.assertIn('applicationId = "com.rochaplus.app.candidate"', text)
                self.assertIn('applicationIdSuffix = ".debug"', text)
                self.assertNotIn('applicationIdSuffix = ".lab"', text)
                self.assertLess(text.index('create("rochaCandidate")'), text.index('getByName("release")'))
                self.assertIn('signingConfig = signingConfigs.getByName("rochaCandidate")', text)
                self.assertNotIn('fixture-not-a-credential', text)
                self.assertFalse((root / 'google-services.json').exists())

    def test_verifier_checks_real_binary_identity_signer_version_abis_and_hash(self):
        for bad in [None, 'package', 'version', 'abi', 'signer', 'metadata']:
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as directory:
                private = Path(directory)
                apk = private / 'fixture.apk'
                apk.write_bytes(b'fixture-not-an-apk')  # Tools are mocked; no binary approval claim.
                expected = candidate.IDENTITY | {'fingerprints': SHA}
                if bad == 'metadata':
                    expected['package'] = 'com.rochaplus.app.lab'
                (private / 'expected.json').write_text(json.dumps(expected))
                package = 'com.rochaplus.app.lab' if bad == 'package' else candidate.PACKAGE
                version = '714' if bad == 'version' else '1'
                abi = 'x86_64' if bad == 'abi' else 'arm64-v8a'
                badging = f"package: name='{package}' versionCode='{version}' versionName='0.1.0-candidate.1'\nnative-code: '{abi}'\n"
                signed = 'Signer #1 certificate SHA-1 digest: ' + SHA['SHA1'] + '\n'
                signed += 'Signer #1 certificate SHA-256 digest: ' + ('00' * 32 if bad == 'signer' else SHA['SHA256']) + '\n'
                def run(args, **kwargs):
                    return subprocess.CompletedProcess(args, 0, stdout=badging if 'badging' in args else signed)
                with patch.object(candidate, 'inspect_signing', return_value=SHA), patch.object(candidate.subprocess, 'run', side_effect=run):
                    if bad:
                        with self.assertRaises(ValueError):
                            candidate.verify(apk, private, private)
                    else:
                        result = candidate.verify(apk, private, private)
                        self.assertEqual(result['package'], candidate.PACKAGE)
                        self.assertFalse(result['productionApproved'])
                        self.assertEqual(len(result['apkSha256']), 64)


if __name__ == '__main__':
    unittest.main()
