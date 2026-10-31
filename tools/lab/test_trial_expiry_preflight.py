"""Regression tests for the LAB-only preflight; no network or SDK needed."""
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

MODULE = Path(__file__).with_name("trial_expiry_preflight.py")
spec = importlib.util.spec_from_file_location("trial_expiry_preflight", MODULE)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


def valid():
    return {
        "package": "com.rochaplus.app.lab.expiry",
        "labOnly": True,
        "trialGateEnabled": True,
        "paymentsEnabled": False,
        "firebaseProject": "demo-rocha-sandbox",
        "entitlementUrl": "http://127.0.0.1:5001/demo-rocha-sandbox/southamerica-east1/entitlement",
        "emulatorOnly": True,
    }


class TrialExpiryPreflightTests(unittest.TestCase):
    def test_local_demo_only_passes(self):
        self.assertEqual(preflight.validate(valid())["labPreflight"], "passed")

    def test_candidate_and_official_packages_blocked(self):
        for package in ("com.rochaplus.app", "com.rochaplus.app.candidate"):
            with self.subTest(package=package), self.assertRaises(ValueError):
                preflight.validate(valid() | {"package": package})

    def test_real_firebase_or_external_urls_blocked(self):
        for url in (
            "https://southamerica-east1-rocha-plus-candidate.cloudfunctions.net/entitlement",
            "http://evil.example:5001/demo-rocha-sandbox/southamerica-east1/entitlement",
            "http://localhost:5001/rocha-plus-candidate/southamerica-east1/entitlement",
            "http://localhost:5001/demo-rocha-sandbox/southamerica-east1/entitlement?x=1",
            "http://localhost:5001@evil.example/demo-rocha-sandbox/southamerica-east1/entitlement",
            "http://localhost:notaport/demo-rocha-sandbox/southamerica-east1/entitlement",
            "http://localhost:99999/demo-rocha-sandbox/southamerica-east1/entitlement",
            "http://localhost:5001/demo-rocha-sandbox/southamerica-east1/entitlement#fragment",
        ):
            with self.subTest(url=url), self.assertRaises(ValueError):
                preflight.validate(valid() | {"entitlementUrl": url})

    def test_production_project_and_unsafe_flags_blocked(self):
        changes = (
            {"firebaseProject": "rocha-plus-candidate"},
            {"paymentsEnabled": True},
            {"labOnly": False},
            {"trialGateEnabled": False},
            {"emulatorOnly": False},
        )
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                preflight.validate(valid() | change)

    def test_cli_accepts_only_safe_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "lab.json"
            path.write_text(json.dumps(valid()), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(MODULE), str(path)],
                capture_output=True, text=True, timeout=15,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["labPreflight"], "passed")

    def test_cli_fails_closed_on_unsafe_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "lab.json"
            path.write_text(json.dumps(valid() | {"paymentsEnabled": True}), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(MODULE), str(path)],
                capture_output=True, text=True, timeout=15,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("rocha-plus-candidate", result.stderr)

    def test_unknown_keys_blocked(self):
        with self.assertRaises(ValueError):
            preflight.validate(valid() | {"extra": "ignored"})


if __name__ == "__main__":
    unittest.main()
