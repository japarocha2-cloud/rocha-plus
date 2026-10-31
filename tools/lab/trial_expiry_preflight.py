"""Fail-closed configuration guard for a future Rocha+ trial-expiry LAB build.

This is a preflight only. It does not alter Flutter/Android configuration,
connect to a service, sign an APK, or establish runtime network isolation.
"""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit

FORBIDDEN_PACKAGES = {"com.rochaplus.app", "com.rochaplus.app.candidate"}
EMULATOR_HOSTS = {"127.0.0.1", "localhost", "10.0.2.2", "10.0.3.2"}
REQUIRED_KEYS = {
    "package", "labOnly", "trialGateEnabled", "paymentsEnabled",
    "firebaseProject", "entitlementUrl", "emulatorOnly",
}


def validate(config):
    if not isinstance(config, dict) or set(config) != REQUIRED_KEYS:
        raise ValueError("Unexpected or missing LAB configuration keys")
    package = config["package"]
    if (not isinstance(package, str)
            or not package.startswith("com.rochaplus.app.lab.")
            or package in FORBIDDEN_PACKAGES
            or len(package.split(".")) < 5):
        raise ValueError("LAB package must be distinct from official and candidate")
    for key, expected in (
        ("labOnly", True),
        ("trialGateEnabled", True),
        ("paymentsEnabled", False),
        ("emulatorOnly", True),
    ):
        if config[key] is not expected:
            raise ValueError(f"Unsafe LAB setting: {key}")
    if config["firebaseProject"] != "demo-rocha-sandbox":
        raise ValueError("LAB must use demo-only Firebase project")
    url = config["entitlementUrl"]
    if not isinstance(url, str):
        raise ValueError("Invalid emulator URL")
    parsed = urlsplit(url)
    if (parsed.scheme != "http" or parsed.hostname not in EMULATOR_HOSTS
            or parsed.username is not None or parsed.password is not None
            or parsed.fragment or parsed.query or not parsed.path.startswith("/")
            or parsed.port is None or not 1 <= parsed.port <= 65535):
        raise ValueError("LAB endpoint must be local emulator HTTP with explicit port")
    if parsed.path != "/demo-rocha-sandbox/southamerica-east1/entitlement":
        raise ValueError("LAB endpoint must use demo project entitlement route")
    return {"labPreflight": "passed", "package": package, "emulatorOnly": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(validate(json.loads(args.config.read_text(encoding="utf-8")))))
    except (ValueError, OSError, TypeError, json.JSONDecodeError) as error:
        parser.exit(1, f"LAB preflight blocked: {type(error).__name__}\n")


if __name__ == "__main__":
    main()
