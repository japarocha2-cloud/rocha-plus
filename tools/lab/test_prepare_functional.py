import copy
import json
import unittest
from unittest.mock import Mock
from prepare_functional import configuration, verify_catalog, SHA1


def source():
    return {'project_info': {'project_id': 'rocha-plus-homologacao', 'project_number': '123'},
        'client': [{'client_info': {'mobilesdk_app_id': '1:123:android:fixture',
            'android_client_info': {'package_name': 'com.rochaplus.app.lab'}},
            'api_key': [{'current_key': 'fixture-public-config'}], 'oauth_client': [
                {'client_type': 1, 'android_info': {'package_name': 'com.rochaplus.app.lab', 'certificate_hash': SHA1}},
                {'client_type': 3, 'client_id': 'fixture.apps.googleusercontent.com'}]}]}


class PreflightTests(unittest.TestCase):
    def test_valid_config_requires_real_auth_and_readonly_gate(self):
        result = configuration(source())
        self.assertEqual(result['ROCHA_FUNCTIONAL_LAB'], 'true')
        self.assertEqual(result['ROCHA_APPLE_ENABLED'], 'false')
        self.assertTrue(result['ROCHA_LAB_ENTITLEMENT_URL'].endswith('/entitlementReadOnly'))

    def test_wrong_project_package_and_historical_only_cert_deny(self):
        for change in ('project', 'package', 'cert', 'web', 'sender'):
            value = copy.deepcopy(source())
            if change == 'project': value['project_info']['project_id'] = 'rocha-plus'
            if change == 'package': value['client'][0]['client_info']['android_client_info']['package_name'] = 'com.rochaplus.app'
            if change == 'cert': value['client'][0]['oauth_client'][0]['android_info']['certificate_hash'] = 'e1ad9a7e3b7388721756f5b7dc6195f8135cd4bd'
            if change == 'web': value['client'][0]['oauth_client'].pop()
            if change == 'sender': value['project_info']['project_number'] = '999'
            with self.subTest(change=change), self.assertRaises(ValueError): configuration(value)

    def test_catalog_empty_or_pending_stops_build(self):
        path = Mock()
        for rows in ([], {}, [{'eligible': True, 'status': 'pending'}]):
            path.read_bytes.return_value = json.dumps(rows).encode()
            with self.assertRaises(ValueError): verify_catalog(path)

    def test_diagnostic_mode_requires_empty_snapshot_and_disables_catalog(self):
        path = Mock()
        path.read_bytes.return_value = b'[]'
        self.assertEqual(
            verify_catalog(path, diagnostic_mode=True),
            'diagnostic-catalog-disabled')
        path.read_bytes.return_value = json.dumps(
            [{'status': 'candidate'}]).encode()
        with self.assertRaises(ValueError):
            verify_catalog(path, diagnostic_mode=True)


if __name__ == '__main__': unittest.main()
