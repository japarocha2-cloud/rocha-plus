import base64
import io
import json
import tempfile
import unittest
from pathlib import Path

from lab_credentials import lab_environment, export_signing_environment, LabBundleFormatError


class LabCredentialsTest(unittest.TestCase):
    def bundle(self):
        return {'project': 'rocha-plus-homologacao', 'package': 'com.rochaplus.app.lab',
                'secrets': {'ROCHA_LAB_KEYSTORE_BASE64': base64.b64encode(b'fixture').decode(),
                            'ROCHA_LAB_KEYSTORE_PASSWORD': 'fixture-password',
                            'ROCHA_LAB_KEY_ALIAS': 'fixture-alias',
                            'ROCHA_LAB_GOOGLE_SERVICES_JSON': '{}'}}

    def test_single_bundle_maps_to_existing_lab_fields_only(self):
        env = lab_environment({'ROCHA_LAB_BUNDLE_JSON': json.dumps(self.bundle())})
        self.assertEqual(env['LAB_KEY_ALIAS'], 'fixture-alias')
        self.assertNotIn('ROCHA_KEYSTORE_PASSWORD', env)

    def test_copy_formatting_never_changes_credential_values(self):
        raw = json.dumps(self.bundle())
        for value in ['\ufeff' + raw, '\n```json\n' + raw + '\n```\n', json.dumps(raw)]:
            with self.subTest(format=value[:8]):
                env = lab_environment({'ROCHA_LAB_BUNDLE_JSON': value})
                self.assertEqual(env['LAB_KEYSTORE_PASSWORD'], 'fixture-password')
                self.assertEqual(env['LAB_KEYSTORE_BASE64'], self.bundle()['secrets']['ROCHA_LAB_KEYSTORE_BASE64'])

    def test_link_truncated_json_and_non_objects_fail_without_echoing_private_text(self):
        for raw in ['https://example.invalid/fixture-private-path', '{"secret":"fixture-private-value', '[]']:
            with self.subTest(kind=raw[:1]), self.assertRaises(LabBundleFormatError) as caught:
                lab_environment({'ROCHA_LAB_BUNDLE_JSON': raw})
            self.assertNotIn('fixture-private', str(caught.exception))

    def test_ascii_transport_preserves_values_and_rejects_production_or_corruption(self):
        raw = json.dumps(self.bundle())
        encoded = base64.b64encode(raw.encode()).decode()
        wrapped = 'ROCHA_LAB_V1:\n' + '\n'.join(encoded[i:i+60] for i in range(0, len(encoded), 60))
        self.assertEqual(lab_environment({'ROCHA_LAB_BUNDLE_JSON': wrapped})['LAB_KEYSTORE_PASSWORD'], 'fixture-password')
        with self.assertRaises(LabBundleFormatError):
            lab_environment({'ROCHA_LAB_BUNDLE_JSON': 'ROCHA_LAB_V1:invalid!base64'})
        bad = self.bundle() | {'project': 'rocha-plus'}
        with self.assertRaises(ValueError):
            lab_environment({'ROCHA_LAB_BUNDLE_JSON': 'ROCHA_LAB_V1:' + base64.b64encode(json.dumps(bad).encode()).decode()})

    def test_official_project_and_unknown_secrets_are_rejected(self):
        for kind in ('project', 'secret'):
            bundle = self.bundle()
            if kind == 'project':
                bundle['project'] = 'rocha-plus'
            else:
                bundle['secrets']['GITHUB_TOKEN'] = 'fixture'
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                lab_environment({'ROCHA_LAB_BUNDLE_JSON': json.dumps(bundle)})

    def test_conflicting_secrets_and_environment_injection_are_rejected(self):
        for override in [{'LAB_KEY_ALIAS': 'other'}, {'LAB_KEYSTORE_PASSWORD': 'value\nINJECTED=true'}]:
            with self.subTest(override=override), self.assertRaises(ValueError):
                lab_environment({'ROCHA_LAB_BUNDLE_JSON': json.dumps(self.bundle())} | override)
        with self.assertRaises(ValueError):
            lab_environment({'LAB_KEYSTORE_PASSWORD': 'value\nINJECTED=true'})

    def test_export_masks_fields_and_exports_only_build_signing_values(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'env'
            output = io.StringIO()
            export_signing_environment({'ROCHA_LAB_BUNDLE_JSON': json.dumps(self.bundle())}, path, stream=output)
            self.assertEqual(path.read_text().splitlines(),
                             ['LAB_KEYSTORE_PASSWORD=fixture-password', 'LAB_KEY_ALIAS=fixture-alias'])
            self.assertIn('::add-mask::fixture-password', output.getvalue())
            self.assertNotIn('GOOGLE_SERVICES', path.read_text())
