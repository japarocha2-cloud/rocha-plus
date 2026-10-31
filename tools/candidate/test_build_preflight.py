"""Unit tests for the fail-closed candidate build preflight."""
import unittest
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

    def test_subscription_enforcement_rejected(self):
        with self.assertRaises(ValueError):
            build_preflight.check(self.valid() | {"ROCHA_CANDIDATE_SUBSCRIPTIONS": "true"})

if __name__ == "__main__":
    unittest.main()
