"""Generate safe, LAB-only Dart defines after strict preflight validation.

No network calls, Flutter invocation, Firebase credentials, signing, or APK build.
This does not guarantee runtime isolation: that requires separate Flutter audit.
"""
import argparse
import json
from pathlib import Path

from trial_expiry_preflight import validate


def generate(config):
    validate(config)
    return {
        "ROCHA_LAB_ONLY": "true",
        "ROCHA_LAYOUT_PREVIEW": "false",
        "ROCHA_EXPERIMENTAL_SUBSCRIPTIONS": "true",
        "ROCHA_ENTITLEMENT_URL": config["entitlementUrl"],
        "ROCHA_FIREBASE_PROJECT_ID": "demo-rocha-sandbox",
        "ROCHA_LAB_EMULATOR_ONLY": "true",
        "ROCHA_PAYMENTS_ENABLED": "false",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.config.resolve() == args.output.resolve():
        parser.error("Input and output must differ")
    try:
        config = json.loads(args.config.read_text(encoding="utf-8"))
        defines = generate(config)
        if args.output.is_symlink():
            raise ValueError("Output symlink forbidden")
        # No partial output on validation failure.
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(defines, stream, indent=2, sort_keys=True)
            stream.write("\n")
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as error:
        parser.exit(1, f"LAB defines blocked: {type(error).__name__}\n")


if __name__ == "__main__":
    main()
