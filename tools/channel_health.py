#!/usr/bin/env python3
"""Rocha+ channel health audit. Read-only, standard library, no automatic removals."""
import argparse
import concurrent.futures
import csv
import datetime as dt
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT = [
    "https://iptv-org.github.io/iptv/countries/br.m3u",
    "https://iptv-org.github.io/iptv/categories/sports.m3u",
]
AGENT = "RochaPlusHealthAudit/1.0"
def fetch(url, timeout, cap=2000000):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    started = time.monotonic()
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = response.read(cap + 1)
        return response.status, response.headers.get("Content-Type", ""), data[:cap], round((time.monotonic()-started)*1000)

def lines(text):
    return [s.strip() for s in text.splitlines() if s.strip()]

def parse_m3u(text, source):
    entries, info = [], ""
    for line in lines(text):
        if line.startswith("#EXTINF"):
            info = line
        elif not line.startswith("#"):
            name = info.rsplit(",", 1)[-1].strip() if info else line
            entries.append({"name": name, "url": urllib.parse.urljoin(source, line), "source": source})
            info = ""
    return entries

def check(entry, timeout):
    start = time.monotonic()
    result = dict(entry, status="inconclusivo", detail="", latency_ms=0)
    try:
        url = entry["url"]
        for depth in range(3):
            code, typ, body, latency = fetch(url, timeout)
            result["latency_ms"] += latency
            if code not in (200, 206):
                result.update(status="falhou", detail="HTTP " + str(code))
                break
            data = body.decode("utf-8", errors="replace").lstrip("\ufeff")
            if "#EXTM3U" in data[:200] or "#EXT-X-" in data[:500]:
                candidates = [x for x in lines(data) if not x.startswith("#")]
                if not candidates:
                    result.update(status="inconclusivo", detail="Playlist sem URI de mídia")
                    break
                url = urllib.parse.urljoin(url, candidates[0])
                if depth == 2:
                    result.update(status="inconclusivo", detail="Playlist encadeada; limite de profundidade")
            else:
                if body[:1] == b"<" and ("html" in typ.lower() or b"<html" in body[:100].lower()):
                    result.update(status="falhou", detail="Resposta HTML em vez de mídia")
                elif body:
                    result.update(status="funcionando", detail="Mídia/segmento acessível (reprodução não comprovada)")
                else:
                    result.update(status="inconclusivo", detail="Resposta vazia")
                break
    except urllib.error.HTTPError as exc:
        result.update(status="falhou" if exc.code in (401, 403, 404, 410) else "inconclusivo", detail="HTTP " + str(exc.code))
    except Exception as exc:
        result.update(status="inconclusivo", detail=type(exc).__name__ + ": " + str(exc)[:160])
    result["elapsed_ms"] = round((time.monotonic()-start)*1000)
    if result["status"] == "funcionando" and result["elapsed_ms"] > timeout * 850:
        result.update(status="instavel", detail="Resposta lenta; segmento acessível")
    return result

def main():
    parser = argparse.ArgumentParser(description="Auditoria read-only do catálogo Rocha+")
    parser.add_argument("--playlist", action="append", help="URL M3U; repetível. Padrão: Brasil e esportes")
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--timeout", type=float, default=8)
    parser.add_argument("--max-channels", type=int, default=0, help="0 testa todos")
    parser.add_argument("--output", default="reports/channel_health")
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 32 or args.timeout <= 0:
        parser.error("workers deve ser 1..32 e timeout > 0")
    all_entries, source_errors = [], []
    for source in args.playlist or DEFAULT:
        try:
            code, _, data, _ = fetch(source, args.timeout)
            decoded = data.decode("utf-8-sig", errors="replace")
            if code not in (200, 206) or "#EXTM3U" not in decoded[:500]:
                raise ValueError(f"Resposta inválida: HTTP {code}, primeiros caracteres: {decoded[:90]!r}")
            all_entries.extend(parse_m3u(decoded, source))
        except Exception as exc:
            source_errors.append({"source": source, "error": str(exc)})
    seen, unique, duplicates = set(), [], []
    for channel in all_entries:
        key = channel["url"]
        if key in seen:
            duplicates.append(channel)
        else:
            seen.add(key)
            unique.append(channel)
    targets = unique[:args.max_channels] if args.max_channels > 0 else unique
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda c: check(c, args.timeout), targets))
    summary = {status: sum(row["status"] == status for row in results)
               for status in ("funcionando", "instavel", "falhou", "inconclusivo")}
    report = {"generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
              "scanned": len(results), "duplicates": len(duplicates),
              "source_errors": source_errors, "summary": summary,
              "results": results, "duplicate_entries": duplicates}
    base = Path(args.output)
    base.parent.mkdir(parents=True, exist_ok=True)
    base.with_suffix(".json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    with base.with_suffix(".csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=["name", "url", "source", "status", "detail", "latency_ms", "elapsed_ms"])
        writer.writeheader()
        writer.writerows(results)
    print(json.dumps({"scanned": len(results), "duplicates": len(duplicates),
                      "source_errors": source_errors, "summary": summary,
                      "json": str(base.with_suffix(".json")), "csv": str(base.with_suffix(".csv"))}, ensure_ascii=False, indent=2))
    if not targets:
        raise SystemExit("Nenhum canal carregado. Verifique a conexão e URLs das fontes.")

if __name__ == "__main__":
    main()
