#!/usr/bin/env python3
"""Import only consolidated audiovisual passes into the debug feature lab."""
import argparse
import json
import re
import subprocess
from pathlib import Path


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--report', default='build/lab/final/results.json')
    p.add_argument('--run', default='manual')
    p.add_argument('--asset', action='store_true', help='Prepare LAB APK asset instead of installing to ADB')
    args = p.parse_args()
    result = json.loads(Path(args.report).read_text())
    approved = [r for r in result['channels'] if r['status'] == 'automatic_audiovisual_pass'
                and r.get('eligible') and not r.get('blocked')]
    if args.asset:
        Path('branding/lab_approved.json').write_text(json.dumps(approved, ensure_ascii=False, indent=2))
    else:
        directory = 'files/rocha-lab/' + re.sub(r'[^a-zA-Z0-9_-]', '_', args.run)
        subprocess.run(['adb', 'shell', 'run-as', 'com.rochaplus.app.lab', 'mkdir', '-p', directory], check=True)
        # stdin avoids shell interpolation of channel metadata and URLs.
        subprocess.run(['adb', 'shell', 'run-as', 'com.rochaplus.app.lab', 'sh', '-c',
                        f"'cat > {directory}/validated-catalog.json.tmp && mv {directory}/validated-catalog.json.tmp {directory}/validated-catalog.json'"],
                       input=json.dumps({'channels': approved}).encode(), check=True)
    print(json.dumps({'importedAudiovisualPasses': len(approved), 'productionApproved': False}))


if __name__ == '__main__':
    main()
