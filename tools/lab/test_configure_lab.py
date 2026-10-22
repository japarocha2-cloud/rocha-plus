import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from configure import configure_lab


class LabConfigurationTest(unittest.TestCase):
    def test_flutter_namespace_survives_and_debug_transport_is_isolated(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            manifest = root / 'android/app/src/main/AndroidManifest.xml'
            manifest.parent.mkdir(parents=True)
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name=".MainActivity"/><meta-data android:name="flutterEmbedding" android:value="2"/></application></manifest>')
            main = root / 'android/app/src/main/kotlin/com/example/rocha_plus/MainActivity.kt'
            main.parent.mkdir(parents=True)
            main.write_text('package com.rochaplus.app\nclass MainActivity : FlutterActivity() {}')
            asset = root / 'branding/lab_candidates.json'
            asset.parent.mkdir()
            asset.write_text(json.dumps([{'url': 'http://example.com/live'}]))
            configure_lab(root)
            configure_lab(root)
            text = manifest.read_text()
            self.assertIn('android:name="flutterEmbedding"', text)
            self.assertIn('android:value="2"', text)
            self.assertNotIn('ns0:', text)
            self.assertEqual(main.read_text().count('open class MainActivity'), 1)
            self.assertNotIn('open open', main.read_text())
            debug = root / 'android/app/src/debug/res/xml/rocha_network_security.xml'
            config = ET.parse(debug).getroot()
            self.assertEqual({x.text for x in config.findall('domain-config/domain')}, {'10.0.2.2', 'example.com'})
            self.assertFalse((root / 'android/app/src/main/res/xml/rocha_network_security.xml').exists())


if __name__ == '__main__':
    unittest.main()
