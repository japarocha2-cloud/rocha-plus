"""Read-only Git blob inventory. No deletion or dead-code decisions are automatic."""
import argparse
from collections import defaultdict
import hashlib
import io
import json
import posixpath
import re
import subprocess
import tempfile
from PIL import Image
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path


def git(*args):
    return subprocess.check_output(['git', *args])


def scan(ref):
    entries = git('ls-tree', '-r', '-z', ref).split(b'\0')
    rows, content, failures, special = [], {}, [], []
    for entry in filter(None, entries):
        meta, raw_path = entry.split(b'\t', 1)
        mode, kind, oid = meta.decode().split()
        name = raw_path.decode('utf-8')
        if kind != 'blob' or mode == '120000':
            special.append({'path': name, 'mode': mode, 'kind': kind})
            continue
        data = git('cat-file', 'blob', oid)
        rows.append({'path': name, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        try:
            if Path(name).suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp', '.gif'}:
                with Image.open(io.BytesIO(data)) as image:
                    image.verify()
                with Image.open(io.BytesIO(data)) as image:
                    image.load()
            elif name.endswith('.mp4'):
                with tempfile.NamedTemporaryFile(suffix='.mp4') as media:
                    media.write(data)
                    media.flush()
                    subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=format_name', media.name],
                                   capture_output=True, timeout=30, check=True)
            elif name.endswith('.json'):
                json.loads(data)
            elif name.endswith('.xml'):
                ET.fromstring(data)
            elif name.endswith('.zip'):
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    bad = archive.testzip()
                    if bad:
                        raise ValueError('CRC mismatch: ' + bad)
        except Exception as error:
            failures.append({'path': name, 'check': 'JSON/XML/ZIP/image decode/MP4 container', 'error': str(error)})
        if b'\0' not in data:
            try:
                content[name] = data.decode('utf-8')
            except UnicodeDecodeError:
                pass  # Binary/legacy encoding is not proof of corruption.
    paths = {r['path'] for r in rows}
    links = []
    for source, text in content.items():
        if not source.endswith('.md'):
            continue
        for target in re.findall(r'\]\(([^\s)]+)\)', text):
            if re.match(r'^(?:[a-zA-Z][a-zA-Z0-9+.-]*:|#|/)', target):
                continue
            target = target.split('#', 1)[0]
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(source), target))
            if resolved not in paths and not any(p.startswith(resolved.rstrip('/') + '/') for p in paths):
                links.append({'source': source, 'target': target, 'resolved': resolved,
                              'decision': 'review generated/external/historical target before changing'})
    local_failures = []
    for source, text in content.items():
        targets = []
        if source.endswith('.dart'):
            targets = [(t, posixpath.dirname(source)) for t in re.findall(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]", text)
                       if not re.match(r'^[a-z]+:', t)]
        if source.startswith('platforms/') and source.endswith(('.brs', '.xml', '.json')):
            root = '/'.join(source.split('/')[:2])
            targets += [(t, root) for t in re.findall(r'pkg:/([^"\'\s<>]+)', text)]
        for target, base in targets:
            resolved = posixpath.normpath(posixpath.join(base, target))
            if resolved not in paths and not any(p.startswith(resolved.rstrip('/') + '/') for p in paths):
                local_failures.append({'source': source, 'target': target, 'resolved': resolved})
    hashes = defaultdict(list)
    for row in rows:
        hashes[row['sha256']].append(row['path'])
    groups = []
    for digest, names in hashes.items():
        if len(names) < 2:
            continue
        refs = {name: [source for source, text in content.items()
                       if source != name and (name in text or Path(name).name in text)] for name in names}
        platforms = {n.split('/')[0] for n in names}
        groups.append({'sha256': digest, 'paths': names, 'textualReferenceCandidates': refs,
                       'classification': 'cross-root copies: preserve packaging/history pending review' if len(platforms) > 1 else 'same-root duplicates: review; no deletion authorized'})
    unreferenced = [row['path'] for row in rows if row['path'].split('/')[0] in {'branding', 'lib', 'platforms'}
                    and not any(source != row['path'] and (row['path'] in text or Path(row['path']).name in text)
                                for source, text in content.items())]
    return {'ref': ref, 'commit': git('rev-parse', ref).decode().strip(), 'files': rows,
            'duplicateGroups': groups, 'formatFailures': failures, 'specialEntries': special,
            'markdownTargetsToReview': links, 'localReferenceCandidatesToReview': local_failures, 'noTextualReferenceCandidates': unreferenced,
            'limits': 'MP4 container inspection does not decode every audio/video frame. No textual reference is NOT dead code. Imports, globs, package roots, generated paths, remote assets and runtime conventions require manual review. Binary decoding and remote link availability are not covered.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ref', action='append', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    report = [scan(ref) for ref in args.ref]
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for row in report:
        print(row['ref'], len(row['files']), 'files;', len(row['duplicateGroups']), 'duplicate groups;',
              len(row['formatFailures']), 'format failures;', len(row['markdownTargetsToReview']), 'links to review')
