"""Export the approved Build #510 catalogue without fetching public playlists."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import urlparse
ROOT = Path(__file__).resolve().parents[1]
TARGETS = ('platforms/roku', 'platforms/web-tv')

def selected(root):
    data = json.loads((root / 'catalog/approved.json').read_text())
    excluded = json.loads((root / 'catalog/quarantine.json').read_text())
    blocked = {entry['name'].casefold() for entry in excluded}
    urls, ids = set(), set()
    for entry in data:
        uri = urlparse(entry['url'])
        evidence = entry.get('evidence', {})
        if (entry.get('approved') is not True or entry.get('status') != 'approved'
            or entry.get('blocked') or entry.get('quarantined') or uri.scheme != 'https'
            or not uri.hostname or uri.username or uri.password or entry['name'].casefold() in blocked
            or evidence.get('decoded_seconds', 0) < 29 or not evidence.get('video_codec')
            or not evidence.get('audio_codec') or entry['url'] in urls or entry['id'] in ids):
            raise ValueError('Unreviewed or duplicate catalogue entry')
        urls.add(entry['url']); ids.add(entry['id'])
    return data

def sync(root=ROOT, check=False):
    data = selected(root)
    for target in TARGETS:
        folder = root / target
        for name in ('approved.json', 'quarantine.json'):
            source = (root / 'catalog' / name).read_bytes()
            destination = folder / 'catalog' / name
            if check:
                if not destination.exists() or destination.read_bytes() != source:
                    raise ValueError('Platform catalogue differs from the approved baseline: ' + target)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(source)
        if (folder / 'catalog/candidates.json').exists():
            raise ValueError('Experimental fallback must be removed: ' + target)
    source = root / 'platforms/shared/account.js'
    destination = root / 'platforms/web-tv/shared/account.js'
    if check:
        if not destination.exists() or destination.read_bytes() != source.read_bytes():
            raise ValueError('Shared account adapter differs')
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.read_bytes())
    return len(data)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    print(f'{sync(check=args.check)} reviewed channels; shared account adapter consistent')
