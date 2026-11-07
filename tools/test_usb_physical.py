import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
from prepare_usb_physical import prepare, BRANCH, ANDROID


class UsbPhysicalPreparationTest(unittest.TestCase):
    def scaffold(self, root):
        gradle = root / "android/app/build.gradle.kts"
        gradle.parent.mkdir(parents=True)
        gradle.write_text('android { defaultConfig { applicationId = "com.rochaplus.app" } }\n'
                          'android { buildTypes { getByName("debug") { applicationIdSuffix = ".lab" } } }\n')
        manifest = root / "android/app/src/debug/AndroidManifest.xml"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                            '<application android:label="Rocha+ LAB" /></manifest>')
        return gradle, manifest

    def test_separate_debug_package_and_label_preserve_base_id(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle, manifest = self.scaffold(root)
            prepare(root, {"GITHUB_REF": BRANCH})
            self.assertIn('applicationIdSuffix = ".usbqa"', gradle.read_text())
            self.assertIn('applicationId = "com.rochaplus.app"', gradle.read_text())
            self.assertEqual(ET.parse(manifest).getroot().find("application").get(
                ANDROID + "label"), "Rocha+ USB QA")

    def test_other_branch_cannot_write_any_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle, manifest = self.scaffold(root)
            original = (gradle.read_bytes(), manifest.read_bytes())
            with self.assertRaises(ValueError):
                prepare(root, {"GITHUB_REF": "refs/heads/main"})
            self.assertEqual((gradle.read_bytes(), manifest.read_bytes()), original)

    def test_missing_or_ambiguous_debug_suffix_is_rejected(self):
        for suffix in ["", 'applicationIdSuffix = ".lab"\napplicationIdSuffix = ".lab"']:
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                gradle, manifest = self.scaffold(root)
                gradle.write_text('applicationId = "com.rochaplus.app"\n' + suffix)
                original = (gradle.read_bytes(), manifest.read_bytes())
                with self.assertRaises(ValueError):
                    prepare(root, {"GITHUB_REF": BRANCH})
                self.assertEqual((gradle.read_bytes(), manifest.read_bytes()), original)

    def test_unexpected_application_id_is_rejected_before_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle, manifest = self.scaffold(root)
            gradle.write_text(gradle.read_text().replace("com.rochaplus.app", "com.other.app"))
            original = (gradle.read_bytes(), manifest.read_bytes())
            with self.assertRaises(ValueError):
                prepare(root, {"GITHUB_REF": BRANCH})
            self.assertEqual((gradle.read_bytes(), manifest.read_bytes()), original)

    def test_missing_debug_application_does_not_modify_gradle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gradle, manifest = self.scaffold(root)
            manifest.write_text("<manifest />")
            original = gradle.read_bytes()
            with self.assertRaises(ValueError):
                prepare(root, {"GITHUB_REF": BRANCH})
            self.assertEqual(gradle.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
