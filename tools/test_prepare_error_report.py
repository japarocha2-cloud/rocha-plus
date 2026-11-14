"""The prepare failure line must never leak secrets.

A literal ValueError from prepare_homologation.py or lab_credentials.py may be
shown as "Motivo: ..."; everything else stays generic.
"""
import ast
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from lab_credentials import LabBundleFormatError, lab_environment
from prepare_homologation import BRANCH, PROJECT, SAFE_VALUE_ERROR_MESSAGES, blocked_message

TOOLS = Path(__file__).resolve().parent
PREPARE = TOOLS / 'prepare_homologation.py'
CREDENTIALS = TOOLS / 'lab_credentials.py'
GENERIC = ('Homologacao bloqueada: confira projeto .lab, OAuth Android/SHA-1, '
           'chave LAB e scaffold. ')
INDIVIDUAL = 'individual-SENTINEL-1234'
BUNDLED = 'bundle-SENTINEL-5678'


class BlockedMessageTest(unittest.TestCase):
    def bundle(self, password):
        return {'project': PROJECT, 'package': 'com.rochaplus.app.lab',
                'secrets': {'ROCHA_LAB_KEYSTORE_BASE64': 'QUJDRA==',
                            'ROCHA_LAB_KEYSTORE_PASSWORD': password,
                            'ROCHA_LAB_KEY_ALIAS': 'lab-key',
                            'ROCHA_LAB_GOOGLE_SERVICES_JSON': '{"project_info": {}}'}}

    def mismatch_error(self):
        env = {'ROCHA_LAB_BUNDLE_JSON': json.dumps(self.bundle(BUNDLED)),
               'LAB_KEYSTORE_PASSWORD': INDIVIDUAL}
        with self.assertRaises(ValueError) as caught:
            lab_environment(env)
        return caught.exception

    def test_mismatched_bundle_shows_fixed_reason_without_values(self):
        error = self.mismatch_error()
        self.assertIs(type(error), ValueError)
        message = blocked_message(error)
        self.assertIn('Tipo de falha: ValueError.', message)
        self.assertTrue(message.endswith(
            'Motivo: Secrets individuais e bundle LAB inconsistentes.'))
        self.assertNotIn('SENTINEL', message)

    def test_dynamic_and_unexpected_errors_stay_generic(self):
        cases = [
            (json.JSONDecodeError('Expecting value', '{"token": "SENTINEL-JSON"}', 0),
             'JSONDecodeError'),
            (KeyError('SENTINEL-KEY'), 'KeyError'),
            (RuntimeError('SENTINEL-RUNTIME'), 'RuntimeError'),
            (ValueError('mensagem dinamica SENTINEL-DYNAMIC'), 'ValueError'),
        ]
        for error, name in cases:
            with self.subTest(name=name):
                message = blocked_message(error)
                self.assertEqual(message, GENERIC + f'Tipo de falha: {name}.')
                self.assertNotIn('Motivo:', message)
                self.assertNotIn('SENTINEL', message)

    def test_value_error_subclass_stays_generic(self):
        error = LabBundleFormatError('Secrets individuais e bundle LAB inconsistentes')
        message = blocked_message(error)
        self.assertNotIn('Motivo:', message)
        self.assertEqual(message, GENERIC + 'Tipo de falha: LabBundleFormatError.')

    def test_every_allowed_literal_is_reported(self):
        for text in sorted(SAFE_VALUE_ERROR_MESSAGES):
            with self.subTest(text=text):
                self.assertTrue(blocked_message(ValueError(text)).endswith(f'Motivo: {text}.'))

    def test_allow_list_matches_literal_value_errors(self):
        expected = set()
        for path in (PREPARE, CREDENTIALS):
            expected |= self.literal_value_errors(path)
        self.assertEqual(SAFE_VALUE_ERROR_MESSAGES, frozenset(expected))

    def literal_value_errors(self, path):
        values = set()
        for node in ast.walk(ast.parse(path.read_text(encoding='utf-8'))):
            if not isinstance(node, ast.Raise) or not isinstance(node.exc, ast.Call):
                continue
            name = getattr(node.exc.func, 'id', getattr(node.exc.func, 'attr', None))
            argument = node.exc.args[0] if node.exc.args else None
            if (name == 'ValueError' and isinstance(argument, ast.Constant)
                    and isinstance(argument.value, str)):
                values.add(argument.value)
        return values

    def test_cli_reports_mismatch_without_leaking_values(self):
        env = dict(os.environ)
        env.update({'ROCHA_HOMOLOGATION_TARGET': 'lab',
                    'GITHUB_REF': BRANCH,
                    'GITHUB_EVENT_NAME': 'workflow_dispatch',
                    'ROCHA_LAB_BUNDLE_JSON': json.dumps(self.bundle(BUNDLED)),
                    'LAB_KEYSTORE_PASSWORD': INDIVIDUAL})
        with tempfile.TemporaryDirectory() as private:
            result = subprocess.run([sys.executable, str(PREPARE), 'prepare', '--private', private],
                                    env=env, cwd=private, capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 1)
        self.assertIn('Tipo de falha: ValueError.', output)
        self.assertIn('Motivo: Secrets individuais e bundle LAB inconsistentes', output)
        self.assertNotIn('SENTINEL', output)


if __name__ == '__main__':
    unittest.main()
