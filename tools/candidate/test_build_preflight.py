"""Unit tests for the fail-closed candidate build preflight."""
import unittest
from unittest.mock import patch
import build_preflight

class BuildPreflightTests(unittest.TestCase):
    def valid(self):
        return {"GITHUB_EVENT_NAME": "workflow_dispatch",
                "GITHUB_REF": "refs/heads/homolog/technical-candidate-20261028"}

    def test_manual_candidate_branch_allowed(self):
        self.assertTrue(build_preflight.check(self.valid()))

    def test_push_rejected(self):
        with self.assertRaises(ValueError):
            build_preflight.check(self.valid() | {"GITHUB_EVENT_NAME": "push"})

    def test_official_branch_rejected(self):
        with self.assertRaises(ValueError):
            build_preflight.check(self.valid() | {"GITHUB_REF": "refs/heads/main"})

    def test_wrong_sha1_rejected_even_with_correct_length(self):
        with patch.dict(build_preflight.SIGNER, {"SHA1": "0" * 40}):
            with self.assertRaisesRegex(ValueError, "certificate mismatch"):
                build_preflight.check(self.valid())

    def test_wrong_sha256_rejected_even_with_correct_length(self):
        with patch.dict(build_preflight.SIGNER, {"SHA256": "0" * 64}):
            with self.assertRaisesRegex(ValueError, "certificate mismatch"):
                build_preflight.check(self.valid())

    def test_official_firebase_project_rejected(self):
        with patch.dict(build_preflight.IDENTITY, {"firebaseProject": "rocha-plus"}):
            with self.assertRaisesRegex(ValueError, "identity changed"):
                build_preflight.check(self.valid())

    def test_official_package_rejected(self):
        with patch.dict(build_preflight.IDENTITY, {"package": "com.rochaplus.app"}):
            with self.assertRaisesRegex(ValueError, "identity changed"):
                build_preflight.check(self.valid())

    def test_production_approval_rejected(self):
        with patch.dict(build_preflight.IDENTITY, {"productionApproved": True}):
            with self.assertRaisesRegex(ValueError, "production-approved"):
                build_preflight.check(self.valid())

    def test_missing_public_fingerprint_rejected(self):
        with patch.dict(build_preflight.SIGNER, {"SHA1": ""}):
            with self.assertRaisesRegex(ValueError, "certificate mismatch"):
                build_preflight.check(self.valid())

    def test_subscription_enforcement_rejected(self):
        with self.assertRaises(ValueError):
            build_preflight.check(self.valid() | {"ROCHA_CANDIDATE_SUBSCRIPTIONS": "true"})

if __name__ == "__main__":
    unittest.main()
