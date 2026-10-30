#!/usr/bin/env python3
"""Read-only ROCHA+ TV catalog gate for Android TV and Roku preparation."""
import argparse
import json
from pathlib import Path


def load_records(path):
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"{path}: expected JSON array")
    return data


def audit(approved, candidates):
    errors = []
    approved_urls = set()
    for i, item in enumerate(approved):
        if not isinstance(item, dict):
            errors.append(f"approved[{i}]: not an object")
            continue
        url = item.get("url")
        if not isinstance(url, str) or not url.strip():
            errors.append(f"approved[{i}]: missing URL")
            continue
        if item.get("blocked") is True:
            errors.append(f"approved[{i}]: blocked entry")
        if item.get("productionApproved") is False:
            errors.append(f"approved[{i}]: explicitly not production-approved")
        approved_urls.add(url.strip())
    candidate_urls = {item.get("url") for item in candidates if isinstance(item, dict) and isinstance(item.get("url"), str)}
    return {
        "approved_records": len(approved),
        "candidate_records": len(candidates),
        "approved_unique_urls": len(approved_urls),
        "candidate_overlap": len(approved_urls & candidate_urls),
        "ready_for_verified_only_export": bool(approved_urls) and not errors,
        "errors": errors,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--approved", type=Path, default=Path("branding/lab_approved.json"))
    parser.add_argument("--candidates", type=Path, default=Path("branding/lab_candidates.json"))
    args = parser.parse_args()
    try:
        report = audit(load_records(args.approved), load_records(args.candidates))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        return 2
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if not report["ready_for_verified_only_export"]:
        print("BLOCKED: no verified-only TV export; existing official catalogs remain unchanged.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
