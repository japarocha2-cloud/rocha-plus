import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("device_metadata", Path(__file__).with_name("device_metadata.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DeviceEvidenceTest(unittest.TestCase):
    def test_allowlist_excludes_other_package_and_private_values(self):
        result = module.parse_metadata("com.rochaplus.app", "versionCode=4107 minSdk=23\nversionName=0.1.0\nsecret=FIXTURE_PRIVATE", "installerPackageName=com.android.packageinstaller", "mResumedActivity: ActivityRecord{fixture com.rochaplus.app/.MainActivity}")
        self.assertEqual(result["versionCode"], 4107)
        self.assertEqual(result["installerPackage"], "com.android.packageinstaller")
        self.assertTrue(result["foregroundPackageMatches"])
        self.assertNotIn("FIXTURE_PRIVATE", str(result))
        self.assertFalse(result["customerSessionVerified"])

    def test_missing_metadata_stays_unknown_not_guessed(self):
        result = module.parse_metadata("com.rochaplus.app.lab", "", "", "mResumedActivity: other.app/.Activity")
        self.assertIsNone(result["versionCode"])
        self.assertIsNone(result["installerPackage"])
        self.assertFalse(result["foregroundPackageMatches"])

    def test_invalid_package_cannot_become_shell_input(self):
        for package in ["com.app;id", "com.app$(id)", "com.app\nother", "", "com.app/foo"]:
            with self.assertRaises(ValueError):
                module.parse_metadata(package, "", "", "")


if __name__ == "__main__":
    unittest.main()
