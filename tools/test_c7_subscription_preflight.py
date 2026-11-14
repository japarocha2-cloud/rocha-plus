import json
import unittest
from c7_subscription_preflight import inspect, PACKAGE, CERT_SHA1

class C7SubscriptionPreflightTest(unittest.TestCase):
    def test_old_lab_package_cannot_satisfy_c7_registration(self):
        data={'project_info':{'project_id':'rocha-plus-homologacao'},'client':[{'client_info':{'android_client_info':{'package_name':'com.rochaplus.app.lab'}}}]}
        result=inspect({'ROCHA_LAB_GOOGLE_SERVICES_JSON':json.dumps(data)})
        self.assertTrue(result['labProjectMatches'])
        self.assertFalse(result['c7PackageClientPresent'])
    def test_exact_package_certificate_and_project_are_independent(self):
        data={'project_info':{'project_id':'rocha-plus-homologacao'},'client':[{'client_info':{'android_client_info':{'package_name':PACKAGE}},'oauth_client':[{'client_type':1,'android_info':{'package_name':PACKAGE,'certificate_hash':CERT_SHA1}},{'client_type':3,'client_id':'test.apps.googleusercontent.com'}]}]}
        result=inspect({'ROCHA_LAB_GOOGLE_SERVICES_JSON':json.dumps(data)})
        self.assertTrue(result['c7PackageClientPresent'])
        self.assertTrue(result['c7CertificateRegistered'])
        self.assertTrue(result['webOAuthClientPresent'])
        data['project_info']['project_id']='rocha-plus'
        self.assertFalse(inspect({'ROCHA_LAB_GOOGLE_SERVICES_JSON':json.dumps(data)})['labProjectMatches'])
    def test_invalid_input_never_echoes_secret_value(self):
        result=inspect({'ROCHA_LAB_GOOGLE_SERVICES_JSON':'synthetic-private-value'})
        self.assertFalse(result['labBundleValid'])
        self.assertNotIn('synthetic-private-value',json.dumps(result))
