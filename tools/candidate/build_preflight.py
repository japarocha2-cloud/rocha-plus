"""Preflight for candidate-only signed build; no secret material is read."""
import json
import os
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
IDENTITY = json.loads((ROOT / "tools/candidate/identity.json").read_text())
SIGNER = json.loads((ROOT / "tools/candidate/signer-public.json").read_text())

def check(env):
    if env.get("GITHUB_EVENT_NAME") != "workflow_dispatch":
        raise ValueError("Candidate build requires explicit manual dispatch")
    if env.get("GITHUB_REF") != IDENTITY["branch"]:
        raise ValueError("Candidate build must use its isolated homologation branch")
    if IDENTITY["package"] != "com.rochaplus.app.candidate" or IDENTITY["firebaseProject"] != "rocha-plus-candidate":
        raise ValueError("Candidate identity changed")
    if IDENTITY.get("productionApproved") is not False:
        raise ValueError("Candidate must never be production-approved by preflight")
    for kind, expected in (("SHA1", "e2f0e4efa910b18b93fce60e9944f7ddf48ee02b"),
                           ("SHA256", "1103e22ab107a77ad3e6ef8b0d327e44240b91b9a4c0bbbad2d258185e0c696b")):
        actual = SIGNER.get(kind)
        if not isinstance(actual, str) or not re.fullmatch(r"[a-f0-9]+", actual) or actual != expected:
            raise ValueError("Candidate public signing certificate mismatch")
    if env.get("ROCHA_CANDIDATE_SUBSCRIPTIONS", "false") != "false":
        raise ValueError("Candidate subscription enforcement requires separate approval")
    return True

if __name__ == "__main__":
    try:
        check(os.environ)
        print("Candidate build preflight passed (identity only; no APK, credentials or signing checked).")
    except ValueError as exc:
        print(f"Candidate preflight blocked: {exc}", file=sys.stderr)
        sys.exit(1)
