"""Preflight for candidate-only signed build; no secret material is read."""
import json
import os
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
    if len(SIGNER.get("SHA1", "")) != 40 or len(SIGNER.get("SHA256", "")) != 64:
        raise ValueError("Candidate public signing fingerprint missing")
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
