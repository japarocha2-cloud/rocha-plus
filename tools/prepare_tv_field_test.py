"""Configure a distinct package identity for the Android TV field-test APK."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"

def prepare(root):
    root = Path(root)
    gradle = root / "android/app/build.gradle.kts"
    text = gradle.read_text(encoding="utf-8")
    updated, count = re.subn(
        r'applicationId\s*=\s*"com\.rochaplus\.app"',
        'applicationId = "com.rochaplus.app.tvtest"',
        text,
    )
    if count != 1:
        raise ValueError("Expected main app ID exactly once")
    gradle.write_text(updated, encoding="utf-8")

    manifest = root / "android/app/src/main/AndroidManifest.xml"
    tree = ET.parse(manifest)
    app = tree.getroot().find("application")
    if app is None:
        raise ValueError("Android application missing")
    app.set(f"{{{ANDROID}}}label", "Rocha+ Teste TV")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

if __name__ == "__main__":
    prepare(Path(__file__).resolve().parents[1])
