#!/usr/bin/env python3
"""Build the LAB presentation overlay from documented decisions.

Never edits the frozen catalog or branding/c7/selection.json. Inputs:
  catalog/lab/presentation_decisions.json  (category / hidden / URL decisions, each with a source)
Outputs:
  branding/lab/presentation_overlay.json   (read by the app when ROCHA_LAB_PRESENTATION=true)
  tools/lab/allowed_http_hosts.lab.txt     (HTTP hosts of visible LAB rows only)
"""
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
SELECTION = ROOT / "branding/c7/selection.json"
DECISIONS = ROOT / "catalog/lab/presentation_decisions.json"
OVERLAY = ROOT / "branding/lab/presentation_overlay.json"
HOSTS = ROOT / "tools/lab/allowed_http_hosts.lab.txt"
ORDER = ["TV ao Vivo", "Esportes", "Infantil", "Notícias", "Documentários", "Culinária",
         "Educação", "Comédia", "Filmes/Séries", "PET", "Outros", "Não testados"]
HOST_RE = re.compile(r"^[a-z0-9.-]+$")


def identity(name):
    text = unicodedata.normalize("NFKD", name.lower())
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"\((?:\d{3,4}p|hd|sd|fhd|4k)\)|\b(?:hd|sd|fhd|4k)\b", " ", text)
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def build(selection_raw, decisions):
    sha = hashlib.sha256(selection_raw).hexdigest()
    selection = json.loads(selection_raw)
    if decisions.get("schema") != "rocha.lab.presentation-decisions.v1":
        raise ValueError("decisions schema")
    if decisions.get("baseSelectionSha256") != sha:
        raise ValueError("decisions were made for another selection.json")
    if decisions.get("order") != ORDER:
        raise ValueError("order differs from the agreed order")
    rows = {r["id"]: r for r in selection["channels"]}
    cats, hidden, urls = decisions["categories"], decisions.get("hidden", {}), decisions.get("urlOverrides", {})
    if set(cats) != set(rows):
        raise ValueError("every selection row needs exactly one category")
    for key, value in cats.items():
        if value.get("category") not in ORDER or not str(value.get("basis", "")).strip():
            raise ValueError(f"invalid category decision {key}")
    for group in (hidden, urls):
        for key, value in group.items():
            if key not in rows or not str(value.get("source", "")).strip():
                raise ValueError(f"decision without row/source {key}")
    for key, value in urls.items():
        parts = urlsplit(value["url"])
        if parts.scheme not in ("http", "https") or not parts.hostname or parts.username or " " in value["url"]:
            raise ValueError(f"invalid URL override {key}")
    out_rows, seen_identity, seen_url, http_hosts, warnings = {}, {}, {}, set(), []
    for key, row in rows.items():
        if key in hidden:
            out_rows[key] = {"category": cats[key]["category"], "hidden": True}
            continue
        url = urls.get(key, {}).get("url", row["url"])
        # The app already drops the duplicate addition (same identity and URL).
        dropped_by_app = row.get("sourceLayer") == "addition" and any(
            identity(rows[k]["name"]) == identity(row["name"]) and u == url
            for k, u in seen_url.items())
        if dropped_by_app:
            continue
        ident = identity(row["name"])
        if url in seen_url.values():
            raise ValueError(f"duplicate visible URL {row['name']}")
        if ident in seen_identity:
            # Same channel name, different stream: kept, but listed for an owner decision.
            warnings.append(f"{seen_identity[ident]} / {row['name']}")
        seen_identity.setdefault(ident, row["name"])
        seen_url[key] = url
        entry = {"category": cats[key]["category"]}
        if key in urls:
            entry["url"], entry["urlSource"] = url, urls[key]["source"]
        out_rows[key] = entry
        parts = urlsplit(url)
        if parts.scheme == "http":
            host = parts.hostname.lower()
            if not HOST_RE.match(host):
                raise ValueError(f"unsupported host {host}")
            http_hosts.add(host)
    overlay = {"schema": "rocha.lab.presentation.v1", "baseSelectionSha256": sha,
               "order": ORDER, "rows": dict(sorted(out_rows.items())),
               "ownerReview": {"sameNameDifferentUrl": warnings}}
    return overlay, sorted(http_hosts)


def apply_network(root, hosts_file=None):
    """Add LAB hosts as per-host cleartext exceptions; the base stays cleartext=false."""
    import xml.etree.ElementTree as ET
    xml_path = Path(root) / "android/app/src/main/res/xml/rocha_network_security.xml"
    tree = ET.parse(xml_path)
    base = tree.getroot().find("base-config")
    if base is None or base.get("cleartextTrafficPermitted") != "false":
        raise ValueError("base network policy must keep cleartext disabled")
    scoped = tree.getroot().find("domain-config")
    if scoped is None or scoped.get("cleartextTrafficPermitted") != "true":
        raise ValueError("unexpected network security scaffold")
    present = {d.text for d in scoped.findall("domain")}
    hosts = [h.strip() for h in Path(hosts_file or HOSTS).read_text(encoding="utf-8").splitlines()
             if h.strip() and not h.startswith("#")]
    for host in hosts:
        if not HOST_RE.match(host):
            raise ValueError(f"unsupported host {host}")
        if host not in present:
            ET.SubElement(scoped, "domain", {"includeSubdomains": "false"}).text = host
    tree.write(xml_path, encoding="utf-8", xml_declaration=True)
    return len(set(hosts) - present)


def main(check=False):
    overlay, hosts = build(SELECTION.read_bytes(), json.loads(DECISIONS.read_text(encoding="utf-8")))
    text = json.dumps(overlay, ensure_ascii=False, indent=1) + "\n"
    host_text = ("# Generated by tools/lab/presentation_overlay.py: HTTP hosts of visible LAB rows.\n"
                 + "\n".join(hosts) + "\n")
    if check:
        if OVERLAY.read_text(encoding="utf-8") != text or HOSTS.read_text(encoding="utf-8") != host_text:
            raise SystemExit("overlay out of date: run tools/lab/presentation_overlay.py")
        return
    OVERLAY.write_text(text, encoding="utf-8")
    HOSTS.write_text(host_text, encoding="utf-8")
    visible = sum(1 for r in overlay["rows"].values() if not r.get("hidden"))
    print(f"overlay: {len(overlay['rows'])} rows, {visible} visible; {len(hosts)} HTTP hosts")


if __name__ == "__main__":
    if "--apply-network" in sys.argv:
        i = sys.argv.index('--apply-network')
        extra = sys.argv[i + 2] if len(sys.argv) > i + 2 else None
        print(f"LAB HTTP hosts added: {apply_network(sys.argv[i + 1], extra)}")
    else:
        main(check="--check" in sys.argv)
