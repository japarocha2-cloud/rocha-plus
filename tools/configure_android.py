import re
from pathlib import Path
import shutil
import os
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
    app.set(attr("networkSecurityConfig"), "@xml/rocha_network_security")
    # Android still denies arbitrary cleartext traffic. Only lab-reviewed hosts
    # are granted HTTP access; HTTPS remains supported normally.
    allowed_hosts = root / "tools/allowed_http_hosts.txt"
    hosts = [line.strip().lower() for line in allowed_hosts.read_text(encoding="utf-8").splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    if not hosts or any(not host or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789.-" for c in host)
                        for host in hosts):
        raise ValueError("Invalid or empty HTTP host allowlist")
    config = ET.Element("network-security-config")
    ET.SubElement(config, "base-config", {"cleartextTrafficPermitted": "false"})
    scoped = ET.SubElement(config, "domain-config", {"cleartextTrafficPermitted": "true"})
    for host in sorted(set(hosts)):
        ET.SubElement(scoped, "domain", {"includeSubdomains": "false"}).text = host
    xml_path = root / "android/app/src/main/res/xml/rocha_network_security.xml"
    xml_path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(config).write(xml_path, encoding="utf-8", xml_declaration=True)
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
        # Debug laboratory installs alongside production instead of replacing it.
        lab_suffix = 'applicationIdSuffix = ".lab"'
        if not re.search(r'applicationIdSuffix = "\.lab(?:cazetv|c7)?"', text):
            text += '\nandroid { buildTypes { getByName("debug") { ' + lab_suffix + ' } } }\n'
        branch = os.environ.get("GITHUB_HEAD_REF") or os.environ.get("GITHUB_REF_NAME", "")
        suffix = None
        if branch == "lab/cazetv-link-only-20261106":
            suffix = ".labcazetv"
        elif branch.startswith(("lab/candidata7-", "lab/p0-candidata7-")):
            suffix = ".labc7"
        if suffix:
            # Replace the debug suffix; never stack overrides on repeated setup.
            text = re.sub(r'applicationIdSuffix = "\.lab(?:cazetv|c7)?"',
                          'applicationIdSuffix = "' + suffix + '"', text)
        gradle.write_text(text, encoding="utf-8")
    debug_manifest = root / "android/app/src/debug/AndroidManifest.xml"
    debug_manifest.parent.mkdir(parents=True, exist_ok=True)
    debug_manifest.write_text(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
        'xmlns:tools="http://schemas.android.com/tools">'
        '<application android:label="Rocha+ LAB" tools:replace="android:label" /></manifest>',
        encoding="utf-8",
    )
    activity = root / "android/app/src/main/kotlin/com/example/rocha_plus/MainActivity.kt"
    activity.parent.mkdir(parents=True, exist_ok=True)
    activity.write_text((root / "tools/MainActivity.kt").read_text(encoding="utf-8"), encoding="utf-8")
    branch = os.environ.get("GITHUB_HEAD_REF") or os.environ.get("GITHUB_REF_NAME", "")
    if branch.startswith(("lab/candidata7-", "lab/p0-candidata7-")):
        res = root / "android/app/src/main/res"
        launch = res / "drawable/launch_background.xml"
        launch.parent.mkdir(parents=True, exist_ok=True)
        launch.write_text('<layer-list xmlns:android="http://schemas.android.com/apk/res/android">'
                          '<item android:drawable="@android:color/black" />'
                          '<item android:width="200dp" android:height="200dp" android:gravity="center">'
                          '<bitmap android:src="@drawable/rocha_plus_icon" android:gravity="fill" />'
                          '</item></layer-list>', encoding="utf-8")
        # Flutter's v21 drawable overrides the base resource on modern Android.
        v21 = res / "drawable-v21/launch_background.xml"
        v21.parent.mkdir(parents=True, exist_ok=True)
        v21.write_text(launch.read_text(), encoding="utf-8")
        for styles in [res / "values/styles.xml", res / "values-night/styles.xml"]:
            if styles.exists():
                style_tree = ET.parse(styles)
                launch_style = style_tree.getroot().find("style[@name='LaunchTheme']")
                if launch_style is not None:
                    for key, value in [("android:windowSplashScreenBackground", "#05040A"),
                                       ("android:windowSplashScreenAnimatedIcon", "@drawable/rocha_plus_icon")]:
                        item = launch_style.find("item[@name='" + key + "']")
                        if item is None:
                            item = ET.SubElement(launch_style, "item", {"name": key})
                        item.text = value
                    style_tree.write(styles, encoding="utf-8", xml_declaration=True)
    drawable = root / "android/app/src/main/res/drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "branding/rocha_plus_icon.webp",
                    drawable / "rocha_plus_icon.webp")

if __name__ == "__main__":
    configure(Path(__file__).resolve().parents[1])
