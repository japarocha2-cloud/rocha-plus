import tempfile
import unittest
from pathlib import Path
from xml.dom import minidom
from isolate_test_android import isolate


class IsolatedAndroidTest(unittest.TestCase):
    def test_flutter_v2_and_launcher_survive_isolation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            gradle = root / "android/app/build.gradle.kts"
            gradle.parent.mkdir(parents=True)
            gradle.write_text('namespace = "com.rochaplus.app"\n'
                              'applicationId = "com.rochaplus.app"')
            manifest = root / "android/app/src/main/AndroidManifest.xml"
            manifest.parent.mkdir(parents=True)
            manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
              <application android:label="Rocha+">
                <activity android:name=".MainActivity" android:exported="true"/>
                <meta-data android:name="flutterEmbedding" android:value="2"/>
              </application></manifest>''')
            isolate(root)
            isolate(root)
            doc = minidom.parseString(manifest.read_text())
            # Use prefixed attributes exactly as Flutter's embedding detector does.
            metadata = doc.getElementsByTagName("meta-data")[0]
            self.assertEqual(metadata.getAttribute("android:name"), "flutterEmbedding")
            self.assertEqual(metadata.getAttribute("android:value"), "2")
            self.assertEqual(doc.getElementsByTagName("activity")[0].getAttribute(
                "android:name"), "com.rochaplus.app.MainActivity")
            self.assertIn('applicationId = "com.rochaplus.soultvtest"', gradle.read_text())
            self.assertIn('namespace = "com.rochaplus.app"', gradle.read_text())


if __name__ == "__main__":
    unittest.main()
