"""Regression checks for candidate Firebase identity; no secrets or network."""
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).with_name("prepare_candidate.py")
spec = importlib.util.spec_from_file_location("candidate_prepare_for_test", SCRIPT)
candidate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate)

SHA1 = "e2f0e4efa910b18b93fce60e9944f7ddf48ee02b"
FP = {"SHA1": SHA1, "SHA256": "1103e22ab107a77ad3e6ef8b0d327e44240b91b9a4c0bbbad2d258185e0c696b"}

def fixture(project="rocha-plus-candidate", package="com.rochaplus.app.candidate",
            sha=SHA1, web=True):
    oauth = [{"client_type": 1, "client_id": "android.apps.googleusercontent.com",
              "android_info": {"package_name": package, "certificate_hash": sha}}]
    if web:
        oauth.append({"client_type": 3, "client_id": "633579358750-test.apps.googleusercontent.com"})
    return {
        "project_info": {"project_id": project, "project_number": "633579358750"},
        "client": [{
            "client_info": {"android_client_info": {"package_name": package},
                            "mobilesdk_app_id": "1:633579358750:android:c27207eca8dc4ab2a13c0f"},
            "oauth_client": oauth,
            "api_key": [{"current_key": "test-placeholder-not-a-secret"}],
        }],
    }

class CandidateIdentityGuards(unittest.TestCase):
    def test_valid_candidate_identity(self):
        actual = candidate.firebase_configuration(fixture(), FP)
        self.assertEqual(actual["ROCHA_FIREBASE_PROJECT_ID"], "rocha-plus-candidate")

    def test_official_project_rejected(self):
        with self.assertRaises(ValueError):
            candidate.firebase_configuration(fixture(project="rocha-plus"), FP)

    def test_official_package_rejected(self):
        with self.assertRaises(ValueError):
            candidate.firebase_configuration(fixture(package="com.rochaplus.app"), FP)

    def test_wrong_certificate_rejected(self):
        with self.assertRaises(ValueError):
            candidate.firebase_configuration(fixture(sha="0" * 40), FP)

    def test_missing_web_oauth_rejected(self):
        with self.assertRaises(ValueError):
            candidate.firebase_configuration(fixture(web=False), FP)

    def test_wrong_branch_and_event_rejected_before_key_access(self):
        with self.assertRaisesRegex(ValueError, "manual isolated branch"):
            candidate.prepare(Path("/tmp/candidate-scaffold"), Path("/tmp/candidate-private"),
                              fixture(), {"GITHUB_REF": "refs/heads/main",
                                          "GITHUB_EVENT_NAME": "push"})

if __name__ == "__main__":
    unittest.main()
