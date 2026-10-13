import unittest
from validate_billing_config import validate, valid_endpoint
class BillingConfigTests(unittest.TestCase):
    def test_missing_service_prevents_commercial_apk(self):
        with self.assertRaises(ValueError): validate({})
    def test_credentials_http_and_placeholders_are_rejected(self):
        for url in ['http://example.org/api','https://user:secret@example.org/api','https://example.com/api','https://localhost/api']:
            self.assertFalse(valid_endpoint(url))
    def test_https_services_are_accepted_without_embedding_credentials(self):
        validate({'ROCHA_BILLING_API_URL':'https://project.cloudfunctions.net/mercadoBilling',
                  'ROCHA_ROKU_PAIRING_ENDPOINT':'https://project.cloudfunctions.net/rokuPairing'})
