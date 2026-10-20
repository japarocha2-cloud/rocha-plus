"""Add the debug-only export bridge after the normal Android scaffold."""
from pathlib import Path
import xml.etree.ElementTree as ET
import re
ET.register_namespace("android", "http://schemas.android.com/apk/res/android")

def configure_lab(root):
    root = Path(root)
    a = '{http://schemas.android.com/apk/res/android}'
    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    tree = ET.parse(manifest)
    activity = tree.getroot().find('application/activity')
    activity.set(a + 'name', 'com.rochaplus.app.LabActivity')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
    kotlin = root / 'android/app/src/debug/kotlin/com/rochaplus/app/LabActivity.kt'
    kotlin.parent.mkdir(parents=True, exist_ok=True)
    kotlin.write_text('''package com.rochaplus.app

    import android.os.Bundle
    import android.view.WindowManager
    import io.flutter.embedding.engine.FlutterEngine
    import io.flutter.plugin.common.MethodChannel
    import java.io.File

    class LabActivity : MainActivity() {
        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        override fun configureFlutterEngine(engine: FlutterEngine) {
            super.configureFlutterEngine(engine)
            android.util.Log.i("RochaLab", "bridge registered package=$packageName auto=" + intent.getBooleanExtra("lab_auto", false) + " fixture=" + intent.getBooleanExtra("lab_fixture", false))
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.rochaplus.app/lab")
                .setMethodCallHandler { call, result ->
                android.util.Log.i("RochaLab", "method=${call.method}")
                    if (!packageName.endsWith(".lab")) {
                        result.error("LAB_ONLY", "Debug laboratory required", null)
                    } else if (call.method == "directory") {
                        val run = intent.getStringExtra("lab_run") ?: "manual"
                        val safeRun = run.replace(Regex("[^a-zA-Z0-9_-]"), "_")
                        val dir = File(filesDir, "rocha-lab/$safeRun")
                        dir.mkdirs()
                        result.success(dir.absolutePath)
                    } else if (call.method == "configuration") {
                        result.success(mapOf(
                            "auto" to intent.getBooleanExtra("lab_auto", false),
                            "fixture" to intent.getBooleanExtra("lab_fixture", false),
                            "features" to intent.getBooleanExtra("lab_features", false),
                            "offset" to intent.getIntExtra("lab_offset", 0),
                            "limit" to intent.getIntExtra("lab_limit", 0)))
                    } else result.notImplemented()
                }
        }
    }
    ''')
    # A debug-specific security config includes candidate HTTP origins only in LAB.
    import json
    from urllib.parse import urlsplit
    rows = json.loads((root / 'branding/lab_candidates.json').read_text())
    hosts = sorted({'10.0.2.2'} | {urlsplit(r['url']).hostname for r in rows if r['url'].startswith('http://')})
    security = ET.Element('network-security-config')
    ET.SubElement(security, 'base-config', {'cleartextTrafficPermitted': 'false'})
    if hosts:
        scoped = ET.SubElement(security, 'domain-config', {'cleartextTrafficPermitted': 'true'})
        for host in hosts:
            ET.SubElement(scoped, 'domain', {'includeSubdomains': 'false'}).text = host
    out = root / 'android/app/src/debug/res/xml/rocha_network_security.xml'
    out.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(security).write(out, encoding='utf-8', xml_declaration=True)

    main = root / 'android/app/src/main/kotlin/com/example/rocha_plus/MainActivity.kt'
    main.write_text(re.sub(r'(?m)^class MainActivity\s*:', 'open class MainActivity :', main.read_text()))

if __name__ == '__main__':
    configure_lab(Path(__file__).resolve().parents[2])
