import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
from configure_android import configure, attr

class AndroidConfigurationTest(unittest.TestCase):
    def test_manifest_is_idempotent_and_keeps_cast_and_tv_without_cleartext(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            manifest = root / "android/app/src/main/AndroidManifest.xml"
            manifest.parent.mkdir(parents=True)
            manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
              <application android:label="rocha_plus">
                <activity android:name=".MainActivity" android:exported="true">
                  <intent-filter><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
                </activity>
              </application></manifest>''', encoding="utf-8")
            brand = root / "branding/rocha_plus_icon.webp"
            brand.parent.mkdir()
            brand.write_bytes(b"fixture-brand")
            configure(root)
            configure(root)
            node = ET.parse(manifest).getroot()
            app = node.find("application")
            self.assertEqual(app.get(attr("usesCleartextTraffic")), "false")
            self.assertEqual(app.get(attr("label")), "Rocha+")
            self.assertEqual(len(node.findall("uses-permission")), 4)
            self.assertEqual(len(app.findall("service")), 1)
            self.assertEqual(app.find("service").get(attr("exported")), "false")
            self.assertEqual(len(app.findall("meta-data")), 1)
            categories = app.findall("activity/intent-filter/category")
            self.assertEqual(len(categories), 2)
            for feature in node.findall("uses-feature"):
                self.assertEqual(feature.get(attr("required")), "false")
            self.assertEqual((root / "android/app/src/main/res/drawable/rocha_plus_icon.webp").read_bytes(),
                             brand.read_bytes())

if __name__ == "__main__":
    unittest.main()
