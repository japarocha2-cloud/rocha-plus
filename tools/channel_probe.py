#!/usr/bin/env python3
"""Read-only FFprobe checks for Rocha+ channel triage CSV."""
import argparse
import concurrent.futures
import csv
import json
import shutil
import subprocess
from collections import Counter
from pathlib import Path

def probe(item, timeout):
    url = item["url"]
    cmd = ["ffprobe", "-v", "error", "-show_entries",
           "stream=codec_type,codec_name,width,height",
           "-of", "json", "-rw_timeout", str(int(timeout*1000000)), url]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True,
                             timeout=timeout+3, check=False)
        parsed = json.loads(out.stdout or "{}")
        streams = parsed.get("streams", [])
        audio = [s for s in streams if s.get("codec_type") == "audio"]
        video = [s for s in streams if s.get("codec_type") == "video"]
        status = "video_e_audio" if audio and video else ("somente_video" if video else
                 ("somente_audio" if audio else "sem_midia_detectada"))
        return {**item, "probe_status": status, "video_codec": video[0].get("codec_name","") if video else "",
                "audio_codec": audio[0].get("codec_name","") if audio else "",
                "resolution": str(video[0].get("width",""))+"x"+str(video[0].get("height","")) if video else "",
                "probe_error": (out.stderr or "")[:220] if out.returncode else ""}
    except subprocess.TimeoutExpired:
        return {**item, "probe_status": "tempo_esgotado", "video_codec": "",
                "audio_codec": "", "resolution": "", "probe_error": "Timeout"}
    except Exception as exc:
        return {**item, "probe_status": "erro", "video_codec": "", "audio_codec": "",
                "resolution": "", "probe_error": str(exc)[:220]}

def main():
    ap = argparse.ArgumentParser(description="Rocha+ FFprobe read-only stream audit")
    ap.add_argument("--input", default="reports/channel_triage.csv")
    ap.add_argument("--output", default="reports/channel_probe")
    ap.add_argument("--all", action="store_true", help="Test all entries, not just priority_player")
    ap.add_argument("--max-channels", type=int, default=0)
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--timeout", type=float, default=15)
    args = ap.parse_args()
    if not shutil.which("ffprobe"):
        ap.error("FFprobe não encontrado. Instale FFmpeg e adicione a pasta bin ao PATH.")
    if not 1 <= args.workers <= 12 or args.timeout <= 0:
        ap.error("workers deve ser 1..12 e timeout > 0")
    with open(args.input, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    if not rows or "url" not in rows[0] or "triagem" not in rows[0]:
        ap.error("CSV de triagem inválido")
    selected = rows if args.all else [r for r in rows if r["triagem"] == "prioridade_player"]
    if args.max_channels > 0:
        selected = selected[:args.max_channels]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        output = list(pool.map(lambda r: probe(r, args.timeout), selected))
    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    fields = list(dict.fromkeys([*rows[0].keys(), "probe_status", "video_codec", "audio_codec", "resolution", "probe_error"]))
    with target.with_suffix(".csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(output)
    report = {"total":len(output),"summary": dict(Counter(r["probe_status"] for r in output)),
              "note": "Detecção pontual de codecs; reprodução contínua/Cast não comprovados."}
    target.with_suffix(".json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print("CSV:", target.with_suffix(".csv"))

if __name__ == "__main__":
    main()
