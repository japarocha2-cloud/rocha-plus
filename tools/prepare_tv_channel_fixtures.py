#!/usr/bin/env python3
"""Prepare reproducible, isolated Roku/Android TV channel test fixtures.

This is NOT an approval/export-to-production pipeline. Never alters source catalogs.
"""
import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlsplit


def slug(value):
    value = re.sub(r"[^a-z0-9]+", "-", value.casefold()).strip("-")
    return value[:64] or "canal"


def prepare(records, limit=12, https_only=True):
    chosen, seen = [], set()
    for record in records:
        if not isinstance(record, dict) or record.get("blocked") is True:
            continue
        url = record.get("url")
        name = record.get("name")
        if not isinstance(name, str) or not name.strip() or not isinstance(url, str):
            continue
        parsed = urlsplit(url)
        if parsed.scheme not in (("https",) if https_only else ("https", "http")) or not parsed.netloc:
            continue
        if url in seen:
            continue
        seen.add(url)
        chosen.append({
            "id": f"{len(chosen)+1:03d}-{slug(name)}",
            "name": name,
            "url": url,
            "group": record.get("group") or "Sem categoria",
            "source_status": record.get("status", "unknown"),
            "production_approved": record.get("productionApproved") is True,
            "android_tv": {"player": "LibVLC/ExoPlayer", "result": "not_tested", "duration_seconds": 180},
            "roku_tv": {"player": "Roku Video", "result": "not_tested", "duration_seconds": 180},
        })
        if len(chosen) >= limit:
            break
    return chosen


def m3u(item):
    name = item["name"].replace("\r", " ").replace("\n", " ").replace(",", " ")
    group = str(item["group"]).replace('"', "'").replace("\n", " ")
    return f'#EXTM3U\n#EXTINF:-1 group-title="{group}",{name}\n{item["url"]}\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("branding/lab_candidates.json"))
    parser.add_argument("--out", type=Path, default=Path("build/tv-channel-fixtures"))
    parser.add_argument("--limit", type=int, default=12)
    parser.add_argument("--include-http", action="store_true", help="PC/LAB only; Roku compatibility not guaranteed")
    args = parser.parse_args()
    if not 1 <= args.limit <= 100:
        parser.error("--limit must be between 1 and 100")
    records = json.loads(args.source.read_text(encoding="utf-8"))
    if not isinstance(records, list):
        parser.error("source must be a JSON array")
    fixtures = prepare(records, args.limit, not args.include_http)
    args.out.mkdir(parents=True, exist_ok=True)
    for item in fixtures:
        (args.out / (item["id"] + ".m3u")).write_text(m3u(item), encoding="utf-8")
    (args.out / "manifest.json").write_text(json.dumps({
        "kind": "experimental-tv-fixtures",
        "approved_for_production": False,
        "notes": "Each result is independent. Never overwrite production catalog from this manifest.",
        "channels": fixtures,
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Created {len(fixtures)} isolated test playlists in {args.out}; no stream was tested.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
