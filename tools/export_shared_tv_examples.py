#!/usr/bin/env python3
"""Export isolated, identical ROCHA+ test channel references for Roku and Android TV.

Does not alter existing app catalogs, official APKs, Roku packages or production approval.
"""
import argparse
import json
from pathlib import Path
from prepare_tv_channel_fixtures import prepare


def export(source, output, limit):
    data = json.loads(Path(source).read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("catalog source must be an array")
    channels = prepare(data, limit=limit, https_only=True)
    common = [{
        "id": x["id"], "name": x["name"], "url": x["url"],
        "group": x["group"], "status": "experimental_not_physically_verified",
        "approved": False, "blocked": False, "quarantined": True,
    } for x in channels]
    output = Path(output)
    (output / "roku").mkdir(parents=True, exist_ok=True)
    (output / "android-tv").mkdir(parents=True, exist_ok=True)
    payload = json.dumps(common, indent=2, ensure_ascii=False) + "\n"
    (output / "roku" / "catalog-test.json").write_text(payload, encoding="utf-8")
    (output / "android-tv" / "catalog-test.json").write_text(payload, encoding="utf-8")
    (output / "results.json").write_text(json.dumps({
        "platforms": ["roku", "android-tv"], "duration_seconds": 180,
        "production_ready": False,
        "channels": [{"id": c["id"], "roku": "not_tested", "android_tv": "not_tested"} for c in common],
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return len(common)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="branding/lab_candidates.json")
    parser.add_argument("--out", default="build/tv-shared-test")
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args()
    if not 1 <= args.limit <= 100:
        parser.error("--limit must be 1..100")
    count = export(args.source, args.out, args.limit)
    print(f"{count} isolated Roku/Android TV examples exported; no channels approved or installed.")
