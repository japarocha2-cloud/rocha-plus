"""Keep the experimental APK separate without breaking Flutter's manifest reader."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"
TEST_ID = "com.rochaplus.soultvtest"


def isolate(root):
    root = Path(root)
    gradle = root / "android/app/build.gradle.kts"
    text, count = re.subn(r'(applicationId\s*=\s*")[^"]+(")',
                         rf'\g<1>{TEST_ID}\g<2>', gradle.read_text(), count=1)
    if count != 1:
        raise ValueError("applicationId not found")
    manifest = root / "android/app/src/main/AndroidManifest.xml"
    tree = ET.parse(manifest)
    app = tree.getroot().find("application")
    activity = tree.getroot().find("./application/activity")
    if app is None or activity is None:
        raise ValueError("Launcher activity not found")
    app.set(f"{{{ANDROID}}}label", "Rocha+ Canais Teste")
    activity.set(f"{{{ANDROID}}}name", "com.rochaplus.app.MainActivity")
    # Flutter looks up android:name literally when detecting embedding v2.
    # ElementTree otherwise serializes this namespace as ns0 in a new process.
    ET.register_namespace("android", ANDROID)
    gradle.write_text(text)
    tree.write(manifest, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    isolate(Path(__file__).resolve().parents[1])
