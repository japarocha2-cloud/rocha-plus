#!/usr/bin/env python3
"""Invoke the private diagnostic with a verified, audience-bound ID token."""

import argparse
import json
import ssl
import urllib.error
import urllib.request
from pathlib import Path

from owner_auth import mint_identity_token, verify_cryptographically


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "redirect refused", headers, fp)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=30.0)
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    if config.get("url") != config.get("audience"):
        parser.error("configured URL and audience must be identical")
    token = mint_identity_token(config["caller_service_account"], config["audience"])
    verification = verify_cryptographically(token, config["audience"], config["allowed_email"])
    if verification.get("valid") is not True:
        raise RuntimeError("identity token did not pass verification")
    request = urllib.request.Request(
        config["url"],
        method="POST",
        data=b"{}",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "rocha-plus-private-diagnostic/1.0",
        },
    )
    opener = urllib.request.build_opener(NoRedirect, urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    try:
        with opener.open(request, timeout=args.timeout) as response:
            body = response.read(1024 * 1024)
            print(json.dumps({"status": response.status, "body": json.loads(body)}))
    except urllib.error.HTTPError as exc:
        # Never print request headers or the token. The bounded response is safe only as text.
        body = exc.read(16 * 1024).decode("utf-8", "replace")
        print(json.dumps({"status": exc.code, "body": body}))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
