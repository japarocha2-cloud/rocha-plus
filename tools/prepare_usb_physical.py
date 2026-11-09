"""Create an isolated USB QA debug variant without touching the existing LAB."""
import os
from pathlib import Path
import xml.etree.ElementTree as ET

BRANCH = "refs/heads/fix/subscription-access-20261026"
PACKAGE = "com.rochaplus.app.usbqa"
ANDROID = "{http://schemas.android.com/apk/res/android}"


def prepare(root, env):
    if env.get("GITHUB_REF") != BRANCH:
        raise ValueError("USB QA is restricted to the correction branch")
    root = Path(root)
    gradle = root / "android/app/build.gradle.kts"
    source = gradle.read_text(encoding="utf-8")
    original = 'applicationIdSuffix = ".lab"'
    if source.count(original) != 1:
        raise ValueError("Expected exactly one isolated LAB debug suffix")
    if source.count('applicationId = "com.rochaplus.app"') != 1:
        raise ValueError("Unexpected Android application ID")
    source = source.replace(original, 'applicationIdSuffix = ".usbqa"')
    manifest = root / "android/app/src/debug/AndroidManifest.xml"
    tree = ET.parse(manifest)
    app = tree.getroot().find("application")
    if app is None:
        raise ValueError("Debug application is missing")
    app.set(ANDROID + "label", "Rocha+ USB QA")
    gradle.write_text(source, encoding="utf-8")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    prepare(Path(__file__).resolve().parents[1], os.environ)
