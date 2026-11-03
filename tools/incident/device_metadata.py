"""Read-only Android package evidence. Does not read app storage, tokens or accounts."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def package_valid(value):
    return bool(re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", value or ""))


def parse_metadata(package, dump, source, activity):
    if not package_valid(package):
        raise ValueError("Invalid package")
    # Parse only allowlisted metadata. Never return dumpsys text or account details.
    code = re.search(r"\bversionCode=(\d+)", dump)
    name = re.search(r"\bversionName=([^\s]+)", dump)
    installer = re.search(r"(?:installerPackageName|Installer package name)\s*[=:]\s*([\w.]+)", source + "\n" + dump)
    foreground = [line for line in activity.splitlines() if "mResumedActivity" in line or "topResumedActivity" in line]
    return {
        "readOnly": True, "packageName": package,
        "versionName": name.group(1)[:80] if name else None,
        "versionCode": int(code.group(1)) if code else None,
        "installerPackage": installer.group(1) if installer and installer.group(1) != "null" else None,
        "installationProvenanceVerified": False,
        "foregroundPackageMatches": any(package + "/" in line for line in foreground),
        "firebaseUidVerified": False, "firebaseProjectVerified": False,
        "backendVerified": False, "customerSessionVerified": False,
    }


def collect(package, serial=None, hash_apk=False):
    if not package_valid(package):
        raise ValueError("Invalid package")
    prefix = ["adb"] + (["-s", serial] if serial else [])

    def run(args, required=True):
        proc = subprocess.run(prefix + args, capture_output=True, text=True, timeout=45, check=False)
        if required and proc.returncode:
            raise RuntimeError("Device read not confirmed; raw output withheld")
        return proc.stdout if proc.returncode == 0 else ""

    dump = run(["shell", "dumpsys", "package", package])
    if not re.search(r"\bversionCode=\d+", dump):
        raise RuntimeError("Installed package not confirmed")
    source = run(["shell", "cmd", "package", "get-install-source", package], required=False)
    activity = run(["shell", "dumpsys", "activity", "activities"], required=False)
    report = parse_metadata(package, dump, source, activity)
    report["apkHashes"] = []
    if hash_apk:
        paths = run(["shell", "pm", "path", package]).splitlines()
        with tempfile.TemporaryDirectory(prefix="rocha-incident-apk-") as folder:
            for index, line in enumerate(paths):
                if not line.startswith("package:"):
                    raise RuntimeError("Unexpected APK path response")
                remote = line.removeprefix("package:").strip()
                if not re.fullmatch(r"/[A-Za-z0-9_./=+~:-]+\.apk", remote):
                    raise RuntimeError("Unexpected APK path")
                target = Path(folder) / (str(index) + ".apk")
                run(["pull", remote, str(target)])
                target.chmod(0o600)
                report["apkHashes"].append({"component": "base" if remote.endswith("/base.apk") else "split",
                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--serial", help="Only for device selection; never included in the report")
    parser.add_argument("--hash-apk", action="store_true", help="Copy installed APKs temporarily for hashes; never upload them")
    args = parser.parse_args()
    try:
        print(json.dumps(collect(args.package, args.serial, args.hash_apk), indent=2))
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError):
        raise SystemExit("Device evidence not confirmed. No app storage was read and no device setting was changed.")
