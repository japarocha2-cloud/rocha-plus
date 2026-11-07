"""Regression tests for Windows report import. No streaming requests."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("import_pc_report.py")

class PCReportTests(unittest.TestCase):
    def test_import_keeps_false_positive_out_of_approved_catalogue(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            rows=[
                {"name":"Band", "group":"TV ao Vivo","url":"https://example.org/a.m3u8",
                 "status":"Confirmado PC","phases":{
                    "ffmpeg":{"success":True,"duration":0.3,"error":"HTTP connection failure"},
                    "vlc":{"success":True,"duration":0.3,"error":"cannot connect"},
                    "confirm":{"success":True,"duration":0.3,"error":"main input error"}}},
                {"name":"TV Realidade","group":"Entretenimento","url":"https://example.org/b.m3u8",
                 "status":"Confirmado PC","phases":{
                    "ffmpeg":{"success":True,"duration":60,"error":""},
                    "vlc":{"success":True,"duration":60,"error":""},
                    "confirm":{"success":True,"duration":180,"error":""}}},
                {"name":"Reality Brasil","group":"Entretenimento","url":"https://example.org/c.m3u8",
                 "status":"Revisar PC","phases":{}}
            ]
            source=root/"report.json"
            source.write_text(json.dumps(rows),encoding="utf-8")
            dest=root/"out"
            subprocess.run([sys.executable,str(SCRIPT),str(source),"--output",str(dest)],check=True)
            index=json.loads((dest/"index.json").read_text(encoding="utf-8"))
            self.assertEqual(index["total"],3)
            self.assertTrue(index["reviewOnly"])
            self.assertEqual(sum(v["productionApproved"] for v in index["categories"].values()),0)
            files=list(dest.glob("*.json"))
            all_rows=[r for f in files if f.name!="index.json" for r in json.loads(f.read_text(encoding="utf-8"))["channels"]]
            self.assertEqual(len(all_rows),3)
            band=next(x for x in all_rows if x["name"]=="Band")
            self.assertEqual(band["reviewReason"],"playback_errors_in_logs")
            self.assertFalse(band["productionApproved"])
            reality=next(x for x in all_rows if x["name"]=="Reality Brasil")
            self.assertEqual(reality["category"],"Reality")
            self.assertTrue(all(not x["androidApproved"] for x in all_rows))

if __name__ == "__main__":
    unittest.main()
