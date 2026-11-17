import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET

import presentation_overlay as po

ROOT = Path(__file__).resolve().parents[2]


def selection(rows):
    return json.dumps({"channels": rows}).encode()


def decisions(raw, cats, **extra):
    return {"schema": "rocha.lab.presentation-decisions.v1",
            "baseSelectionSha256": hashlib.sha256(raw).hexdigest(), "order": po.ORDER,
            "categories": cats, **extra}


ROWS = [
    {"id": "a", "name": "CazéTV", "url": "http://138.204.86.4:8080/CAZE_TV/playlist.m3u8", "sourceLayer": "addition"},
    {"id": "b", "name": "TV Ra Tim Bum (720p)", "url": "http://45.177.114.115/x.m3u8"},
    {"id": "c", "name": "Retro", "url": "https://h/chunk.m3u8"},
]
CATS = {"a": {"category": "Esportes", "basis": "existing"}, "b": {"category": "Outros", "basis": "existing"},
        "c": {"category": "Infantil", "basis": "existing"}}


class OverlayTest(unittest.TestCase):
    def test_real_repository_overlay_is_current_and_preserves_frozen_files(self):
        frozen = ROOT / "catalog/official/frozen/2026-11-08/ROCHA_CATALOGO_OFICIAL_CONGELADO_2026-11-08.json"
        sums = json.loads((ROOT / "catalog/official/frozen/SHA256SUMS.json").read_text())
        digest = hashlib.sha256(frozen.read_bytes()).hexdigest()
        self.assertIn(digest, json.dumps(sums))
        self.assertEqual(len(json.loads(frozen.read_text())["canais"]), 479)
        po.main(check=True)  # generated overlay equals the documented decisions
        overlay = json.loads(po.OVERLAY.read_text())
        self.assertEqual(overlay["order"], po.ORDER)
        visible = [r for r in overlay["rows"].values() if not r.get("hidden")]
        self.assertEqual(len(visible), 481)
        self.assertIn("138.204.86.4", po.HOSTS.read_text())

    def test_hide_override_and_hosts(self):
        raw = selection(ROWS)
        overlay, hosts = po.build(raw, decisions(raw, CATS,
            hidden={"b": {"reason": "dup", "source": "doc"}},
            urlOverrides={"c": {"url": "https://h/playlist.m3u8", "source": "doc"}}))
        self.assertTrue(overlay["rows"]["b"]["hidden"])
        self.assertEqual(overlay["rows"]["c"]["url"], "https://h/playlist.m3u8")
        self.assertEqual(hosts, ["138.204.86.4"])  # hidden row host is not allowed

    def test_rejects_unsourced_or_incomplete_decisions(self):
        raw = selection(ROWS)
        bad = [
            decisions(raw, {k: v for k, v in CATS.items() if k != "c"}),
            decisions(raw, {**CATS, "a": {"category": "Novela", "basis": "x"}}),
            decisions(raw, CATS, hidden={"b": {"reason": "dup"}}),
            decisions(raw, CATS, urlOverrides={"c": {"url": "ftp://h/x", "source": "doc"}}),
            {**decisions(raw, CATS), "baseSelectionSha256": "0" * 64},
            {**decisions(raw, CATS), "order": list(reversed(po.ORDER))},
        ]
        for case in bad:
            with self.assertRaises(ValueError):
                po.build(raw, case)

    def test_duplicate_url_is_refused(self):
        rows = copy.deepcopy(ROWS)
        rows[1]["url"] = rows[2]["url"]
        raw = selection(rows)
        with self.assertRaises(ValueError):
            po.build(raw, decisions(raw, CATS))

    def test_network_keeps_base_cleartext_disabled(self):
        with tempfile.TemporaryDirectory() as d:
            x = Path(d) / "android/app/src/main/res/xml/rocha_network_security.xml"
            x.parent.mkdir(parents=True)
            x.write_text('<network-security-config><base-config cleartextTrafficPermitted="false" />'
                         '<domain-config cleartextTrafficPermitted="true"><domain includeSubdomains="false">1.1.1.1</domain>'
                         '</domain-config></network-security-config>')
            po.apply_network(d)
            po.apply_network(d)
            root = ET.parse(x).getroot()
            self.assertEqual(root.find("base-config").get("cleartextTrafficPermitted"), "false")
            domains = [e.text for e in root.find("domain-config")]
            self.assertIn("138.204.86.4", domains)
            self.assertEqual(len(domains), len(set(domains)))


if __name__ == "__main__":
    unittest.main()
