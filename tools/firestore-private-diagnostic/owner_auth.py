#!/usr/bin/env python3
"""Mint and preflight an audience-bound Google ID token without persisting it."""

from __future__ import annotations

import base64
import json
import subprocess
import time
from pathlib import Path
from typing import Any


class OwnerAuthError(RuntimeError):
    pass


def _decode_segment(segment: str) -> dict[str, Any]:
    padding = "=" * (-len(segment) % 4)
    try:
        value = base64.urlsafe_b64decode(segment + padding)
        decoded = json.loads(value)
    except (ValueError, json.JSONDecodeError) as exc:
        raise OwnerAuthError("identity token is not a well-formed JWT") from exc
    if not isinstance(decoded, dict):
        raise OwnerAuthError("identity token JWT segment is not an object")
    return decoded


def unverified_claims(token: str) -> dict[str, Any]:
    """Decode claims only for fail-closed routing checks, never for trust."""
    parts = token.split(".")
    if len(parts) != 3:
        raise OwnerAuthError("identity token is not a three-part JWT")
    return _decode_segment(parts[1])


def require_routing_claims(token: str, audience: str, *, now: int | None = None) -> dict[str, Any]:
    claims = unverified_claims(token)
    current = int(time.time()) if now is None else now
    if claims.get("aud") != audience:
        raise OwnerAuthError("identity token audience does not exactly match the configured audience")
    if claims.get("iss") not in {"https://accounts.google.com", "accounts.google.com"}:
        raise OwnerAuthError("identity token issuer is not Google")
    if not isinstance(claims.get("sub"), str) or not claims["sub"]:
        raise OwnerAuthError("identity token subject is missing")
    if not isinstance(claims.get("exp"), (int, float)) or claims["exp"] <= current:
        raise OwnerAuthError("identity token is expired")
    return claims


def mint_identity_token(caller_service_account: str, audience: str) -> str:
    command = [
        "gcloud", "auth", "print-identity-token",
        f"--impersonate-service-account={caller_service_account}",
        f"--audiences={audience}",
        "--include-email",
        "--quiet",
    ]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        raise OwnerAuthError("gcloud could not mint the short-lived identity token") from exc
    token = result.stdout.strip()
    require_routing_claims(token, audience)
    return token


def verify_cryptographically(token: str, audience: str, allowed_email: str) -> dict[str, Any]:
    verifier = Path(__file__).with_name("verify-owner-token.cjs")
    command = [
        "node", str(verifier), "--stdin",
        "--audience", audience,
        "--allowed-email", allowed_email,
    ]
    try:
        result = subprocess.run(
            command, input=token, check=True, capture_output=True, text=True
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise OwnerAuthError("cryptographic identity-token verification failed") from exc
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise OwnerAuthError("identity-token verifier returned invalid output") from exc
