import unittest
from validate_billing_config import validate

class UnifiedBillingConfigurationTests(unittest.TestCase):
    def test_unified_release_rejects_spark_trial(self):
        with self.assertRaisesRegex(ValueError, "Spark trial cannot be mixed"):
            validate({
                "ROCHA_UNIFIED_RELEASE": "true",
                "ROCHA_SPARK_TRIAL": "true",
                "ROCHA_SPARK_FIREBASE_PROJECT_ID": "rocha-plus",
            })

    def test_unified_release_requires_server_urls(self):
        with self.assertRaises(ValueError):
            validate({"ROCHA_UNIFIED_RELEASE": "true", "ROCHA_SPARK_TRIAL": "false"})

    def test_unified_release_accepts_valid_server_urls(self):
        validate({
            "ROCHA_UNIFIED_RELEASE": "true",
            "ROCHA_SPARK_TRIAL": "false",
            "ROCHA_BILLING_API_URL": "https://billing.example.org/api",
            "ROCHA_ROKU_PAIRING_ENDPOINT": "https://billing.example.org/pair",
        })

    def test_existing_spark_laboratory_still_supported(self):
        validate({"ROCHA_SPARK_TRIAL": "true", "ROCHA_SPARK_FIREBASE_PROJECT_ID": "rocha-plus"})

if __name__ == "__main__":
    unittest.main()
