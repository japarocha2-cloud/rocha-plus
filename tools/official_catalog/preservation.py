"""Verify original Roku LAB files/artwork and unrelated Android data are intact."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]

def verify():
    doc=json.loads((ROOT/'catalog/official/roku-baseline-files.json').read_bytes())
    allowed={'platforms/roku-lab-visual/'+p for p in doc['authorizedChanges']}
    for name,pin in doc['files'].items():
        if name not in allowed:
            assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==pin, name+' baseline changed'
    subprocess.run(['git','diff','--exit-code','92451ea','--','branding/lab_candidates.json','branding/lab_approved.json','backend','functions','firestore.rules','lib/src/auth','lib/src/screens/subscription_screen.dart','lib/src/screens/lab_subscription_screen.dart'],cwd=ROOT,check=True)
    print(f'{len(doc["files"])-len(allowed)} Roku LAB baseline files preserved; unrelated Android sources unchanged')

if __name__=='__main__':verify()
