"""Verify safe Dart defines generation without contacting external services."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).parent
sys.path.insert(0, str(ROOT))
spec = importlib.util.spec_from_file_location("generate_lab_defines", ROOT / "generate_lab_defines.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
from test_trial_expiry_preflight import valid


class LabDefinesTests(unittest.TestCase):
    def test_safe_defines(self):
        result = module.generate(valid())
        self.assertEqual(result["ROCHA_LAB_ONLY"], "true")
        self.assertEqual(result["ROCHA_EXPERIMENTAL_SUBSCRIPTIONS"], "false")
        self.assertEqual(result["ROCHA_ENTITLEMENT_URL"], "")
        self.assertEqual(result["ROCHA_FIREBASE_PROJECT_ID"], "demo-rocha-sandbox")
        self.assertEqual(result["ROCHA_PAYMENTS_ENABLED"], "false")
        self.assertEqual(result["ROCHA_LAB_TRIAL_EXPIRY_DEMO"], "true")
        self.assertEqual(result["ROCHA_LAB_EMULATOR_ONLY"], "true")

    def test_no_external_backend(self):
        for change in (
            {"firebaseProject": "rocha-plus-candidate"},
            {"entitlementUrl": "https://example.com/entitlement"},
            {"paymentsEnabled": True},
        ):
            with self.subTest(change=change), self.assertRaises(ValueError):
                module.generate(valid() | change)


if __name__ == "__main__":
    unittest.main()
