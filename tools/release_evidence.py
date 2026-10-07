from pathlib import Path
import hashlib
import json
import os
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
android = "{http://schemas.android.com/apk/res/android}"
manifests = [
    path for path in (root / "build/app/intermediates").rglob("AndroidManifest.xml")
    if "release" in str(path).lower()
    and ("merged_manifests" in path.parts or "merged_manifest" in path.parts)
]
if not manifests:
    raise SystemExit("Merged release manifest was not found.")
merged = ET.parse(manifests[0]).getroot()
app = merged.find("application")
assert app is not None
assert app.get(android + "usesCleartextTraffic") == "false"
assert app.get(android + "debuggable", "false") != "true"
permissions = sorted(node.get(android + "name") for node in merged.findall("uses-permission"))
assert "android.permission.INTERNET" in permissions

outputs = {}
for relative in (
    "build/app/outputs/flutter-apk/app-release.apk",
    "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk",
    "build/app/outputs/bundle/release/app-release.aab",
):
    path = root / relative
    assert path.is_file(), f"Missing candidate: {relative}"
    outputs[path.name] = {
        "size_bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
brand = root / "branding/rocha_plus_icon.webp"
assert hashlib.sha1(b"blob " + str(brand.stat().st_size).encode() + b"\0" + brand.read_bytes()).hexdigest() == "587481a95f41f7811884dbd3e15ea987d0ae463e"
report = {
    "commit": os.environ["GITHUB_SHA"],
    "build_number": os.environ["GITHUB_RUN_NUMBER"],
    "permissions": permissions,
    "cleartext_allowed": False,
    "debuggable": False,
    "signing": "development candidate; production signing not configured",
    "physical_validation": "pending",
    "branding_blob": "587481a95f41f7811884dbd3e15ea987d0ae463e",
    "outputs": outputs,
}
folder = root / "build/qa"
folder.mkdir(parents=True, exist_ok=True)
(folder / "release-evidence.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
