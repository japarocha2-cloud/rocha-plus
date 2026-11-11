#!/usr/bin/env python3
"""Export TV catalogue candidates from the SAME public M3U sources as the Rocha+ APK.

This does not assert that streams play or that redistribution is licensed.
Approved entries must be explicitly provided through --approved-urls.
No modification of APK, freeze, or existing TV lists.
"""
import argparse, json, re, urllib.request
from pathlib import Path
from urllib.parse import urlparse

SOURCES = [
    "https://iptv-org.github.io/iptv/countries/br.m3u",
    "https://iptv-org.github.io/iptv/categories/sports.m3u",
]
BLOCKED = {
    "1001 noites", "30a golf kingdom", "pluto tv esportes",
    "canal do inter", "band sports", "times brasil", "tv thathi",
    "tv sul de minas", "tv meio", "tv difusora leste",
    "tv encontro das aguas",
}
TV_NATIONAL = ("sbt", "globo", "rede globo", "tv morena", "record", "band",
               "redetv", "rede tv", "tv brasil", "tv cultura")

def identity(s):
    import unicodedata
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"\s*\(\d+p\)|\s*\[not 24/7\]", "", s)
    return " ".join(s.split())

def valid_https(url):
    p = urlparse(url)
    return p.scheme == "https" and bool(p.hostname) and not p.username

def parse(text):
    data, pending = [], None
    for line in text.splitlines():
        line = line.strip().lstrip("\ufeff")
        if line.startswith("#EXTINF:"):
            title = line.rsplit(",", 1)[-1].strip()
            logo = re.search(r'tvg-logo="([^"]*)"', line)
            group = re.search(r'group-title="([^"]*)"', line)
            pending = (title, logo.group(1) if logo else None,
                       group.group(1) if group else "TV aberta")
        elif pending and line and not line.startswith("#"):
            if valid_https(line) and identity(pending[0]) not in BLOCKED:
                data.append({"name":pending[0],"url":line,"logo":pending[1],
                             "group":pending[2]})
            pending = None
    return data

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--approved-urls", type=Path, help="One reviewed approved URL per line")
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    approved = set(args.approved_urls.read_text(encoding="utf-8").splitlines()) if args.approved_urls else set()
    collected = {}
    for src in SOURCES:
        try:
            req = urllib.request.Request(src, headers={"User-Agent":"RochaPlusCatalogExporter/1.0"})
            with urllib.request.urlopen(req, timeout=15) as f:
                for item in parse(f.read().decode("utf-8-sig")):
                    collected.setdefault(item["url"], item)
        except Exception as error:
            print(f"Source unavailable: {src}: {error}")
    result = []
    for item in collected.values():
        name = identity(item["name"])
        if any(name == k or name.startswith(k + " ") for k in BLOCKED):
            continue
        item["status"] = "approved" if item["url"] in approved else "unverified"
        item["category"] = "Nacionais" if any(name == x or name.startswith(x + " ") for x in TV_NATIONAL) else item["group"]
        result.append(item)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"{len(result)} unique candidates; {sum(x['status']=='approved' for x in result)} approved")

if __name__ == "__main__":
    main()
