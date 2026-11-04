import unittest
from prepare_checkout_build import validate

class CheckoutBuildTest(unittest.TestCase):
    def bundle(self):
        return dict(verified_by='operator', verified_at='2026-11-04',
            firebase_project_id='test-project', firebase_app_id='1:123:android:abc',
            firebase_sender_id='123', firebase_api_key='fixture', google_server_client_id='fixture',
            android_package='com.rochaplus.app.checkout', signing_sha256='ab'*32,
            checkout_url='https://southamerica-east1-test-project.cloudfunctions.net/checkout',
            entitlement_url='https://southamerica-east1-test-project.cloudfunctions.net/entitlement',
            backend_project_id='test-project', backend_token_audience='test-project',
            merchant_id='123', checkout_enabled=False, payment_mode='one_time',
            backend_kind='firebase_entitlements', identity_binding='firebase_uid')
    def test_matching_project_keeps_catalog_unblocked(self):
        result=validate(self.bundle())
        self.assertEqual(result['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'false')
        self.assertEqual(result['ROCHA_LAYOUT_PREVIEW'], 'false')
        self.assertEqual(result['ROCHA_LAB_ONLY'], 'false')
    def test_other_backend_or_audience_rejected(self):
        for key in ['backend_project_id','backend_token_audience','backend_kind','identity_binding']:
            b=self.bundle(); b[key]='other'
            with self.assertRaises(ValueError): validate(b)
    def test_enabled_or_recurring_rejected(self):
        for key,value in [('checkout_enabled', True),('payment_mode','recurring')]:
            b=self.bundle(); b[key]=value
            with self.assertRaises(ValueError): validate(b)
    def test_redirects_credentials_and_foreign_hosts_rejected(self):
        for url in ['http://example.com/checkout',
                    'https://user@southamerica-east1-test-project.cloudfunctions.net/checkout',
                    'https://southamerica-east1-test-project.cloudfunctions.net/checkout?next=evil']:
            b=self.bundle(); b['checkout_url']=url
            with self.assertRaises(ValueError): validate(b)
if __name__ == '__main__': unittest.main()
