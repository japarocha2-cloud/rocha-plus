#!/usr/bin/env python3
"""Import Windows PC observations into review-only category files.

Never promotes PC results to the Android production or validated catalogue.
Usage: python3 tools/lab/import_pc_report.py path/to/rocha_lab_pc_resultados.json
"""
import argparse
import collections
import json
import re
import unicodedata
from pathlib import Path

ORDER = ["TV ao Vivo", "Esportes", "Infantil", "Notícias", "Filmes",
         "Séries", "Documentários", "Música", "Educação", "Cultura",
         "Entretenimento", "Reality", "Religiosos", "Futebol", "Outros"]
PRIORITY = ("globo", "sbt", "record", "band", "rede tv", "tv brasil",
            "cartoon", "discovery", "nickelodeon", "pluto")

def category(row):
    name = row.get("name", "").lower()
    group = row.get("group", "")
    if re.search(r"reality|big brother|bbb|a fazenda", name):
        return "Reality"
    if re.search(r"novela|série|series", name) and group == "Outros":
        return "Séries"
    if re.search(r"tv cultura|arte 1", name) and group == "Outros":
        return "Cultura"
    if re.search(r"canção nova|cancao nova|rede vida|aparecida", name) and group == "Outros":
        return "Religiosos"
    return group if group in ORDER else "Outros"

def sort_key(row):
    name = row.get("name", "")
    norm = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    rank = next((i for i, token in enumerate(PRIORITY) if token in norm), len(PRIORITY))
    return rank, norm, row.get("url", "")

def review_reason(row):
    phases = row.get("phases") or {}
    if row.get("status") != "Confirmado PC":
        return "not_confirmed"
    if not all(isinstance(phases.get(k), dict) and phases[k].get("success") for k in ("ffmpeg", "vlc", "confirm")):
        return "missing_successful_phase"
    errors = "\n".join(str(phases[k].get("error", "")) for k in ("ffmpeg", "vlc", "confirm"))
    if re.search(r"HTTP connection failure|cannot connect|não é capaz de abrir|main input error|tempo limite", errors, re.I):
        return "playback_errors_in_logs"
    duration = phases["confirm"].get("duration")
    if not isinstance(duration, (float, int)) or duration < 150:
        return "confirmation_shorter_than_150_seconds"
    # PC process completion is not proof of video frames, decoded audio, or rights.
    return "needs_audiovisual_and_permission_review"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report", type=Path)
    ap.add_argument("--output", type=Path, default=Path("build/lab/pc-review"))
    args = ap.parse_args()
    records = json.loads(args.report.read_text(encoding="utf-8"))
    if not isinstance(records, list):
        raise ValueError("PC report must contain a list")
    groups = {name: [] for name in ORDER}
    for row in records:
        if not isinstance(row, dict):
            raise ValueError("Invalid channel record")
        group = category(row)
        groups[group].append({
            "name": row.get("name", ""),
            "url": row.get("url", ""),
            "category": group,
            "pcStatus": row.get("status", ""),
            "reviewReason": review_reason(row),
            "productionApproved": False,
            "androidApproved": False,
        })
    args.output.mkdir(parents=True, exist_ok=True)
    summary = {}
    for i, (group, rows) in enumerate(groups.items()):
        rows.sort(key=sort_key)
        filename = f"{i+1:02d}-{unicodedata.normalize('NFKD', group).encode('ascii','ignore').decode().lower().replace(' ', '-')}.json"
        (args.output / filename).write_text(json.dumps({"category": group, "channels": rows}, ensure_ascii=False, indent=2), encoding="utf-8")
        summary[group] = {"candidates": len(rows), "androidApproved": 0, "productionApproved": 0}
    (args.output / "index.json").write_text(json.dumps({
        "source": str(args.report), "total": len(records), "reviewOnly": True,
        "categories": summary}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"total": len(records), "productionApproved": 0, "categories": summary}, ensure_ascii=False))

if __name__ == "__main__":
    main()
