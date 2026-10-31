"""Static wiring checks for the offline LAB trial-expiry demo.

These checks do not replace Flutter widget tests or runtime network auditing.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TrialExpiryFlutterWiringTests(unittest.TestCase):
    def test_lab_entry_is_opt_in(self):
        source = (ROOT / "lib/src/screens/lab_entry_screen.dart").read_text()
        self.assertIn("ROCHA_LAB_TRIAL_EXPIRY_DEMO", source)
        self.assertIn("const TrialExpiryLabScreen()", source)
        self.assertIn("const _LabCatalogueLoader()", source)

    def test_demo_uses_injected_verifier_and_no_real_subscription_actions(self):
        source = (ROOT / "lib/src/screens/trial_expiry_lab_screen.dart").read_text()
        self.assertIn("verifyAccess: _verify", source)
        self.assertIn("showSubscriptionActions: false", source)
        self.assertIn("stopRemotePlayback: () async {}", source)
        self.assertNotIn("SubscriptionAccess.isAllowed", source)
        self.assertNotIn("FirebaseAuth.instance", source)
        self.assertNotIn("http.get(", source)

    def test_gate_keeps_existing_default_for_non_lab_users(self):
        source = (ROOT / "lib/src/auth/subscription_gate.dart").read_text()
        self.assertIn("this.showSubscriptionActions = true", source)
        self.assertIn("if (widget.showSubscriptionActions)", source)

    def test_main_routes_lab_without_normal_app(self):
        source = (ROOT / "lib/main.dart").read_text()
        self.assertIn("runApp(labOnly ? const RochaLabApp() : const RochaPlusApp())", source)


if __name__ == "__main__":
    unittest.main()
