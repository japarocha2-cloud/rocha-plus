from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID)

def attr(name):
    return f"{{{ANDROID}}}{name}"

def configure(root):
    root = Path(root)
    manifest = root / "android/app/src/main/AndroidManifest.xml"
    tree = ET.parse(manifest)
    node = tree.getroot()
    permissions = {
        "android.permission.INTERNET",
        "android.permission.ACCESS_NETWORK_STATE",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    }
    present = {entry.get(attr("name")) for entry in node.findall("uses-permission")}
    for name in sorted(permissions - present):
        ET.SubElement(node, "uses-permission", {attr("name"): name})
    for name in ("android.software.leanback", "android.hardware.touchscreen"):
        feature = next((entry for entry in node.findall("uses-feature")
                        if entry.get(attr("name")) == name), None)
        if feature is None:
            feature = ET.SubElement(node, "uses-feature", {attr("name"): name})
        feature.set(attr("required"), "false")
    app = node.find("application")
    if app is None:
        raise ValueError("Android application missing")
    app.set(attr("label"), "Rocha+")
    app.set(attr("icon"), "@drawable/rocha_plus_icon")
    app.set(attr("roundIcon"), "@drawable/rocha_plus_icon")
    app.set(attr("usesCleartextTraffic"), "false")
    provider = "com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
    metadata = next((entry for entry in app.findall("meta-data")
                     if entry.get(attr("name")) == provider), None)
    if metadata is None:
        metadata = ET.SubElement(app, "meta-data", {attr("name"): provider})
    metadata.set(attr("value"), "com.felnanuke.google_cast.GoogleCastOptionsProvider")
    service_name = "com.google.android.gms.cast.framework.media.MediaNotificationService"
    service = next((entry for entry in app.findall("service")
                    if entry.get(attr("name")) == service_name), None)
    if service is None:
        service = ET.SubElement(app, "service", {attr("name"): service_name})
    service.set(attr("exported"), "false")
    service.set(attr("foregroundServiceType"), "mediaPlayback")
    for intent in app.findall("activity/intent-filter"):
        names = {entry.get(attr("name")) for entry in intent.findall("category")}
        if "android.intent.category.LAUNCHER" in names:
            if "android.intent.category.LEANBACK_LAUNCHER" not in names:
                ET.SubElement(intent, "category", {
                    attr("name"): "android.intent.category.LEANBACK_LAUNCHER"})
    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    gradle = root / "android/app/build.gradle.kts"
    if gradle.exists():
        text = gradle.read_text(encoding="utf-8")
        text = text.replace('com.example.rocha_plus', 'com.rochaplus.app')
        dependency = 'implementation("com.google.android.gms:play-services-cast-framework:21.5.0")'
        if dependency not in text:
            text += "\n dependencies { " + dependency + " }\n"
        gradle.write_text(text, encoding="utf-8")
    activity = root / "android/app/src/main/kotlin/com/example/rocha_plus/MainActivity.kt"
    activity.parent.mkdir(parents=True, exist_ok=True)
    activity.write_text((root / "tools/MainActivity.kt").read_text(encoding="utf-8"), encoding="utf-8")
    drawable = root / "android/app/src/main/res/drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "branding/rocha_plus_icon.webp",
                    drawable / "rocha_plus_icon.webp")

if __name__ == "__main__":
    configure(Path(__file__).resolve().parents[1])
