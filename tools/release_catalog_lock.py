"""Frozen release catalog lock (owner reference: LAB Cliente APK, 2026-11-17).

The official Android app (com.rochaplus.app) must ship exactly the catalog that
the approved LAB Cliente APK loads: branding/lab/c7_validated_selection.json.
This module verifies that file against catalog/official/release-manifest.json
(SHA-256, count, ordered IDs, CazéTV first in Esportes, protected channels) and,
with APK paths, verifies each built APK carries the same asset and compiled pin.

Count alone is never accepted as proof: ordered IDs and the byte SHA-256 are.
"""
import hashlib
import json
import re
import sys
import unicodedata
import zipfile
from pathlib import Path

MANIFEST = 'catalog/official/release-manifest.json'


def _identity(name):
    text = unicodedata.normalize('NFD', name.lower())
    text = re.sub(r'[̀-ͯ]', '', text)
    text = re.sub(r'\s*\((\d+p|geo-blocked|not 24/7)\)', '', text)
    text = re.sub(r'\s*\[[^\]]*\]', '', text)
    return re.sub(r'\s+', ' ', text).strip()


def ids_sha256(rows):
    return hashlib.sha256('\n'.join(r['id'] for r in rows).encode('utf-8')).hexdigest()


def describe(raw_bytes):
    """Facts about a selection file, computed the way the app loads it."""
    if raw_bytes.startswith(b'\xef\xbb\xbf') or b'\r' in raw_bytes:
        raise ValueError('seleção deve ser UTF-8 sem BOM e sem CRLF')
    data = json.loads(raw_bytes.decode('utf-8'))
    rows = data['channels']
    ids = [r['id'] for r in rows]
    if len(ids) != len(set(ids)):
        raise ValueError('IDs duplicados no catálogo')
    keys = [(_identity(r['name']), r['url']) for r in rows]
    if len(keys) != len(set(keys)):
        raise ValueError('canal duplicado (mesmo nome e link)')
    sports = [r for r in rows if r['group'] == 'Esportes']
    return {
        'sha256': hashlib.sha256(raw_bytes).hexdigest(),
        'count': len(rows),
        'idsSha256': ids_sha256(rows),
        'removals': len(data.get('removals') or []),
        'additionCount': data.get('additionCount'),
        'firstSportsId': sports[0]['id'] if sports else None,
        'firstSportsName': sports[0]['name'] if sports else '',
        'rows': {r['id']: r for r in rows},
    }


def load_manifest(root):
    return json.loads((Path(root) / MANIFEST).read_text(encoding='utf-8'))


def verify_selection(root, manifest=None):
    root = Path(root)
    manifest = manifest or load_manifest(root)
    _compare(describe((root / manifest['asset']).read_bytes()), manifest)
    return manifest


def _compare(facts, manifest):
    for key in ('sha256', 'count', 'idsSha256', 'removals', 'additionCount', 'firstSportsId'):
        if facts[key] != manifest[key]:
            raise ValueError(f'catálogo diverge do manifesto congelado: {key}')
    if _identity(facts['firstSportsName']).replace(' ', '') != 'cazetv':
        raise ValueError('CazéTV não é o primeiro canal de Esportes')
    for item in manifest['protected']:
        row = facts['rows'].get(item['id'])
        if not row or any(row[k] != item[k] for k in ('name', 'group')) or \
                hashlib.sha256(row['url'].encode('utf-8')).hexdigest() != item['urlSha256']:
            raise ValueError(f"canal protegido ausente ou alterado: {item['name']}")


def verify_apk(apk, manifest):
    """The built APK must bundle the pinned asset and compile its SHA-256 pin."""
    with zipfile.ZipFile(apk) as z:
        names = set(z.namelist())
        asset = 'assets/flutter_assets/' + manifest['asset']
        if asset not in names:
            raise ValueError('APK sem o catálogo congelado')
        _compare(describe(z.read(asset)), manifest)
        compiled = [n for n in names if n.endswith('/libapp.so')] or \
            [n for n in names if n.endswith('kernel_blob.bin')]
        if not compiled:
            raise ValueError('APK sem código Dart compilado')
        for name in compiled:
            blob = z.read(name)
            if manifest['sha256'].encode() not in blob or manifest['asset'].encode() not in blob:
                raise ValueError(f'{name}: app não fixa o catálogo congelado (catálogo aberto/importação)')
    return True


def main(argv):
    root = Path(__file__).resolve().parents[1]
    manifest = verify_selection(root)
    for apk in argv[1:]:
        verify_apk(apk, manifest)
        print(f'APK OK: {apk}')
    print(f"Catálogo congelado OK: {manifest['count']} canais, sha256 {manifest['sha256']}")


if __name__ == '__main__':
    try:
        main(sys.argv)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        print(f'BLOQUEADO: {error}')
        sys.exit(1)
