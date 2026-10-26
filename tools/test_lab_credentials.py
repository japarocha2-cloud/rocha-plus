import base64
import io
import json
import tempfile
import unittest
from pathlib import Path

from lab_credentials import lab_environment, export_signing_environment


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
