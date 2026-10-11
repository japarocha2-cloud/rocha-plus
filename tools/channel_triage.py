#!/usr/bin/env python3
"""Rocha+ audit triage: analyze scanner CSV without removing/changing channels."""
import argparse
import csv
import json
from collections import Counter
from pathlib import Path

def classify(row):
    state = row["status"].strip().lower()
    detail = row.get("detail", "").strip()
    if state in ("funcionando", "instavel"):
        return "prioridade_player" if state == "funcionando" else "retestar_lentidao"
    if detail.startswith(("HTTP 401", "HTTP 403")):
        return "acesso_restrito"
    if detail.startswith(("HTTP 404", "HTTP 410")):
        return "link_nao_encontrado"
    if detail.startswith("HTTP "):
        return "retestar_http"
    if state == "inconclusivo":
        return "retestar_inconclusivo"
    return "investigar_falha"

def analyze(rows):
    enriched = []
    for row in rows:
        item = dict(row)
        item["triagem"] = classify(row)
        enriched.append(item)
    counts = Counter(item["triagem"] for item in enriched)
    return enriched, dict(sorted(counts.items()))

def main():
    ap = argparse.ArgumentParser(description="Triagem do relatório Rocha+; somente leitura")
    ap.add_argument("--input", default="reports/channel_health.csv")
    ap.add_argument("--output", default="reports/channel_triage")
    args = ap.parse_args()
    with open(args.input, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows or not {"name", "url", "status", "detail"}.issubset(rows[0]):
        ap.error("CSV vazio ou sem colunas name,url,status,detail")
    enriched, summary = analyze(rows)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.with_suffix(".csv").open("w", encoding="utf-8-sig", newline="") as f:
        fields = list(dict.fromkeys([*rows[0].keys(), "triagem"]))
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(enriched)
    output.with_suffix(".json").write_text(
        json.dumps({"total": len(rows), "triagem": summary}, ensure_ascii=False, indent=2),
        encoding="utf-8")
    print(json.dumps({"total": len(rows), "triagem": summary, "csv": str(output.with_suffix(".csv"))},
                     ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
