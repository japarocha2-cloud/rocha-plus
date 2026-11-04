#!/usr/bin/env python3
"""Reject silent loss of catalog IDs/decisions between two JSON snapshots.

Usage: python3 tools/roku_catalog_guard.py previous.json proposed.json
Expected shape: a JSON list or {"channels": [ ... ]}.
Each channel requires id; optional operator_decision and other metadata.
This does not authorize or play any stream.
"""
import json
import sys


def load(path):
    with open(path, encoding="utf-8") as stream:
        data = json.load(stream)
    rows = data["channels"] if isinstance(data, dict) else data
    if not isinstance(rows, list):
        raise ValueError(f"{path}: expected list of channels")
    result = {}
    for row in rows:
        if not isinstance(row, dict) or not row.get("id"):
            raise ValueError(f"{path}: channel missing stable id")
        key = str(row["id"])
        if key in result:
            raise ValueError(f"{path}: duplicate channel id {key}")
        result[key] = row
    return result


def main():
    if len(sys.argv) != 3:
        print("Usage: roku_catalog_guard.py previous.json proposed.json")
        return 2
    before, after = load(sys.argv[1]), load(sys.argv[2])
    removed = sorted(set(before) - set(after))
    changed = []
    for key in sorted(set(before) & set(after)):
        old = before[key].get("operator_decision")
        new = after[key].get("operator_decision")
        if old != new:
            changed.append((key, old, new))
    print(f"Previous: {len(before)} | Proposed: {len(after)} | New: {len(set(after)-set(before))}")
    for key in removed:
        print(f"BLOCK removed channel: {key}")
    for key, old, new in changed:
        print(f"BLOCK changed operator decision: {key}: {old!r} -> {new!r}")
    if removed or changed:
        print("FAIL: preserve missing channels and prior decisions; reconcile changes manually.")
        return 1
    print("PASS: no channel ID or operator decision was silently lost.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(2)
