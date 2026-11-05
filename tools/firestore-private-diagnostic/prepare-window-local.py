#!/usr/bin/env python3
"""Write a non-secret, fail-closed invocation configuration."""

import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit


def exact_https_url(value: str, label: str) -> str:
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        raise argparse.ArgumentTypeError(f"{label} must be an absolute HTTPS URL")
    if parsed.query or parsed.fragment:
        raise argparse.ArgumentTypeError(f"{label} must not contain a query or fragment")
    return value.rstrip("/")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--audience", required=True)
    parser.add_argument("--caller-service-account", required=True)
    parser.add_argument("--allowed-email", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    url = exact_https_url(args.url, "url")
    audience = exact_https_url(args.audience, "audience")
    if url != audience:
        parser.error("url and audience must be identical for this diagnostic contract")
    if not args.caller_service_account.endswith(".iam.gserviceaccount.com"):
        parser.error("caller-service-account must be a service account email")
    if args.allowed_email != args.caller_service_account:
        parser.error("allowed-email must match caller-service-account")
    config = {
        "url": url,
        "audience": audience,
        "caller_service_account": args.caller_service_account,
        "allowed_email": args.allowed_email,
        "method": "POST",
    }
    args.output.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote non-secret invocation config: {args.output}")


if __name__ == "__main__":
    main()
