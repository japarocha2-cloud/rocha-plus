#!/usr/bin/env python3
"""Compare a Rocha+ historical semicolon CSV against current local M3U files.

No network, video playback, redistribution approval, or automatic removals.
"""
import argparse
import csv
import re
import unicodedata
from collections import Counter
from pathlib import Path

def normalize(value):
    plain = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().lower()
    return " ".join(re.sub(r"\s*\(\d+p\)|\s*\[not 24/7\]", "", plain).split())

def parse_m3u(path):
    name = ""
    for raw in Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("#EXTINF:"):
            name = line.rsplit(",", 1)[-1].strip()
        elif line and not line.startswith("#"):
            yield {"nome_atual": name or "Sem nome", "url": line, "origem_atual": Path(path).name}
            name = ""

def compare(benchmark_path, playlist_paths):
    with open(benchmark_path, encoding="utf-8-sig", newline="") as stream:
        historical = list(csv.DictReader(stream, delimiter=";"))
    by_url = {r["url"].strip(): r for r in historical}
    by_name = {}
    for row in historical:
        by_name.setdefault(normalize(row["nome"]), []).append(row)
    rows = []
    for path in playlist_paths:
        for channel in parse_m3u(path):
            exact = by_url.get(channel["url"])
            matches = by_name.get(normalize(channel["nome_atual"]), [])
            label = "URL_EXATA" if exact else "NOME_SIMILAR_REVISAR" if matches else "SEM_HISTORICO"
            historical_row = exact or (matches[0] if len(matches) == 1 else None)
            rows.append({**channel, "correspondencia": label,
                         "historico_resultado": historical_row["deteccao"] if historical_row else "",
                         "historico_erro": historical_row["erro"] if historical_row else "",
                         "historico_url": historical_row["url"] if historical_row else "",
                         "decisao": "REVISAR_SEM_EXCLUSAO", "autorizacao": "NAO_VERIFICADA"})
    return rows

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--benchmark", required=True)
    parser.add_argument("--m3u", action="append", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    rows = compare(args.benchmark, args.m3u)
    fields = ["nome_atual", "url", "origem_atual", "correspondencia",
              "historico_resultado", "historico_erro", "historico_url", "decisao", "autorizacao"]
    with open(args.out, "w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter=";")
        writer.writeheader()
        writer.writerows(rows)
    print("Canais atuais:", len(rows), "| Correspondencia:",
          dict(Counter(r["correspondencia"] for r in rows)))
    print("Nenhuma URL removida; historico nao comprova reproducao atual.")

if __name__ == "__main__":
    main()
