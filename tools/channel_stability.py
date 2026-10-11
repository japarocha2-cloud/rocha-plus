#!/usr/bin/env python3
"""Rocha+ V4 read-only bounded streaming stability check with FFmpeg."""
import argparse
import concurrent.futures
import csv
import json
import re
import shutil
import subprocess
import time
from collections import Counter
from pathlib import Path

def run_check(row, seconds=30, timeout=50):
    command = ["ffmpeg", "-hide_banner", "-nostdin", "-nostats", "-loglevel", "warning",
               "-rw_timeout", "10000000", "-i", row["url"], "-t", str(seconds),
               "-map", "0:v:0?", "-map", "0:a:0?", "-f", "null", "-"]
    started = time.monotonic()
    try:
        result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                text=True, errors="replace", timeout=timeout)
        elapsed = round(time.monotonic()-started, 1)
        detail = (result.stderr or "")[-800:]
        if result.returncode == 0 and elapsed >= seconds * 0.7:
            status = "completou_teste"
        elif result.returncode == 0:
            status = "terminou_antes_do_prazo"
        else:
            status = "erro_decodificacao_ou_rede"
        return {**row, "v4_status": status, "v4_elapsed_seconds": elapsed,
                "v4_exit_code": result.returncode, "v4_detail": detail.replace("\n", " | ")}
    except subprocess.TimeoutExpired:
        return {**row, "v4_status": "tempo_esgotado", "v4_elapsed_seconds": round(time.monotonic()-started, 1),
                "v4_exit_code": "", "v4_detail": "Processo finalizado após timeout"}
    except Exception as error:
        return {**row, "v4_status": "erro_execucao", "v4_elapsed_seconds": round(time.monotonic()-started, 1),
                "v4_exit_code": "", "v4_detail": str(error)[:300]}

def main():
    ap = argparse.ArgumentParser(description="Rocha+ V4, amostragem de estabilidade; sem gravação")
    ap.add_argument("--input", default="reports/channel_probe.csv")
    ap.add_argument("--output", default="reports/channel_stability")
    ap.add_argument("--seconds", type=int, default=30)
    ap.add_argument("--timeout", type=int, default=50)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--max-channels", type=int, default=10, help="0 = todos os candidatos")
    args = ap.parse_args()
    if not shutil.which("ffmpeg"):
        ap.error("FFmpeg não encontrado. Configure PATH apontando para a pasta com ffmpeg.exe")
    if not 1 <= args.workers <= 6 or not 5 <= args.seconds <= 120 or args.timeout <= args.seconds:
        ap.error("Use workers 1..6, seconds 5..120 e timeout maior que seconds")
    with open(args.input, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    if not rows or not {"url", "probe_status"}.issubset(rows[0]):
        ap.error("CSV V3 vazio ou inválido")
    candidates = [r for r in rows if r["probe_status"] == "video_e_audio"]
    if args.max_channels > 0:
        candidates = candidates[:args.max_channels]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda r: run_check(r, args.seconds, args.timeout), candidates))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = list(dict.fromkeys([*rows[0].keys(), "v4_status", "v4_elapsed_seconds", "v4_exit_code", "v4_detail"]))
    with output.with_suffix(".csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(results)
    summary = {"checked": len(results), "seconds_target": args.seconds,
               "results": dict(Counter(r["v4_status"] for r in results)),
               "warning": "Conclusão do FFmpeg não prova Cast, reprodução contínua sem congelamentos ou ausência de perda de frames."}
    output.with_suffix(".json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print("CSV:", output.with_suffix(".csv"))

if __name__ == "__main__":
    main()
