"""Build a reproducible Roku test catalogue without promoting playback evidence."""
import argparse
import csv
import hashlib
import io
import json
from collections import Counter
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
CAT = ROOT / 'platforms/roku/catalog'
SOURCE = 'Benchmark_RochaPlus_Catalogo.csv'
EXPECTED_SHA256 = '17095a366a0ec73ac6cc85be27469500d3a10aac4df89ebf137ae0c54d424914'


def convert(data, previous):
    if hashlib.sha256(data).hexdigest() != EXPECTED_SHA256:
        raise ValueError('Benchmark differs from the reviewed snapshot')
    rows = list(csv.DictReader(io.StringIO(data.decode('utf-8-sig')), delimiter=';'))
    if len(rows) != 788 or len({r['url'] for r in rows}) != 788:
        raise ValueError('Unexpected benchmark inventory')
    by_url = {r['url']: r for r in previous}
    active, pending = [], []
    for row in rows:
        old = by_url.get(row['url'], {})
        url = row['url'].strip()
        parsed = urlsplit(url)
        reasons = []
        if row['deteccao'] != 'video_audio':
            reasons.append('benchmark_' + row['deteccao'])
        if parsed.scheme != 'https':
            reasons.append('https_required_by_existing_roku_policy')
        if '.m3u8' not in url.lower():
            reasons.append('stream_format_unconfirmed')
        if not parsed.hostname or parsed.username or parsed.password:
            reasons.append('invalid_or_credentialed_url')
        if old.get('blocked') or old.get('quarantined'):
            reasons.append('previous_explicit_block')
        entry = {
            'id': old.get('id') or hashlib.sha256(url.encode()).hexdigest()[:16],
            'name': row['nome'], 'url': url,
            'group': old.get('group') or ('Esportes' if 'sport' in row['origem'].lower() else 'Geral'),
            'status': 'pending_review' if reasons else 'benchmark_av_detected',
            'approved': False,
            'evidence': {
                'report': SOURCE, 'source_sha256': EXPECTED_SHA256,
                'detection': row['deteccao'],
                'detection_seconds': float(row['tempo_deteccao_s']) if row['tempo_deteccao_s'] else None,
                'source_playlist': row['origem'], 'error': row['erro'],
                'roku_playback_verified': False, 'distribution_authorization': 'unverified',
            },
        }
        if old.get('logo'):
            entry['logo'] = old['logo']
        if reasons:
            entry['review_reasons'] = reasons
            pending.append(entry)
        else:
            active.append(entry)
    # Keep established order/IDs so existing favorite IDs remain meaningful.
    order = {r['url']: i for i, r in enumerate(previous)}
    active.sort(key=lambda r: (order.get(r['url'], len(previous)), r['name'].casefold()))
    manifest = {
        'source': SOURCE, 'source_sha256': EXPECTED_SHA256,
        'source_rows': len(rows), 'detections': dict(Counter(r['deteccao'] for r in rows)),
        'runtime_test_channels': len(active), 'pending_rows': len(pending),
        'positive_pending_rows': sum(r['evidence']['detection'] == 'video_audio' for r in pending),
        'roku_playback_verified': False, 'public_release_approved': False,
        'baseline_commit': '3ac4cb0090cea8f8d291896504af63f4a7dc025f',
    }
    return active, pending, manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    active, pending, manifest = convert((CAT / SOURCE).read_bytes(), json.loads((CAT / 'approved.json').read_text()))
    for name, value in [('benchmark-test.json', active), ('benchmark-pending.json', pending), ('benchmark-manifest.json', manifest)]:
        rendered = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
        path = CAT / name
        if args.check:
            if path.read_text() != rendered:
                raise ValueError('Generated catalogue is stale: ' + name)
        else:
            path.write_text(rendered)
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == '__main__':
    main()
