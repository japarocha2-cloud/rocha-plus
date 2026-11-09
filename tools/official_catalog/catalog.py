"""Deterministic offline adapters for the owner-frozen catalogue. No URL probes."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'ROCHA_CATALOGO_OFICIAL_CONGELADO_2026-11-08.json'
CSV = 'ROCHA_CATALOGO_479_CONGELADO_2026-11-08.csv'
PINS = {SOURCE: 'ce8a82a5e5cf637759f75f2dcf063fc6aff67b0832336860b82b6346cd10a2e9',
        CSV: '4a5355e5037f9aca1e4e65718acfd5d82e62813849a16f7081c6b63758fefd85'}
BASE = 'catalog/official/frozen/2026-11-08/'
ROKU = 'platforms/roku-lab-visual/'

def sha(raw): return hashlib.sha256(raw).hexdigest()
def encode(data): return (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode()
def read(root, path): return json.loads((root / path).read_bytes())

def frozen(root):
    for name, expected in PINS.items():
        raw = (root / BASE / name).read_bytes()
        if sha(raw) != expected: raise ValueError('Frozen source bytes changed: ' + name)
        if (root / 'catalog/official/backups' / expected).read_bytes() != raw:
            raise ValueError('Frozen backup changed: ' + name)
    doc = read(root, BASE + SOURCE)
    rows = doc['canais']
    if len(rows) != 479 or doc['quantidade_base'] != 479:
        raise ValueError('Frozen base must retain all 479 records')
    records = list(csv.DictReader(io.StringIO((root / BASE / CSV).read_text(encoding='utf-8-sig')), delimiter=';'))
    if len(records) != len(rows): raise ValueError('CSV count mismatch')
    for row, record in zip(rows, records):
        for key, value in row.items():
            if record[key] != str(value): raise ValueError('CSV / JSON field mismatch: ' + key)
    return doc

def build(root=ROOT):
    doc = frozen(root)
    old_roku = read(root, ROKU + 'catalog/commercial-lab-merged.json')
    old_android = read(root, 'branding/lab_candidates.json')
    overlays = read(root, 'catalog/official/overrides.json')
    if overlays['sourceSha256'] != PINS[SOURCE]: raise ValueError('Overlay provenance mismatch')
    names = {r['nome'] for r in doc['canais'] + doc['adicoes_aprovadas_fora_da_base']}
    if set(overlays['byName']) - names: raise ValueError('Unknown overlay target')
    rows = []; used = set(); mapped = []; cover_aliases = {}
    old_cover = read(root, ROKU + 'config/cover-map.json')
    for layer, records in [('base', doc['canais']), ('addition', doc['adicoes_aprovadas_fora_da_base'])]:
        for index, record in enumerate(records):
            name = record['nome']; url = record['url_atual']
            # Only exact matches, never infer an identity from a similar name.
            matches = [r for r in old_roku if r['name'] == name and r['url'] in {url, record.get('url_original', url)}]
            if len(matches) != 1: matches = [r for r in old_roku if r['name'] == name]
            prior = matches[0] if len(matches) == 1 else None
            key = prior['id'] if prior else sha(f'{PINS[SOURCE]}:{layer}:{index}'.encode())[:16]
            if key in used: key = sha(f'{PINS[SOURCE]}:{layer}:{index}'.encode())[:16]
            if key in used: raise ValueError('Duplicate catalogue ID')
            used.add(key)
            row = {'id': key, 'name': name, 'url': url, 'group': record['categoria'],
                   'sourceLayer': layer, 'sourceIndex': index,
                   'historicalStatus': record.get('status_historico'),
                   'availability': 'not-retested', 'updateNote': record['atualizacao']}
            candidates = [r for r in old_android if r.get('name') == name]
            if len(candidates) == 1 and candidates[0].get('logo'): row['logo'] = candidates[0]['logo']
            if prior:
                for field in ('logo', 'coverLocal', 'preferredEngine'):
                    if field in prior: row[field] = prior[field]
                if prior['id'] in old_cover: cover_aliases[key] = old_cover[prior['id']]
                mapped.append({'id': key, 'previousId': prior['id'], 'sourceLayer': layer, 'sourceIndex': index})
            overlay = overlays['byName'].get(name)
            if overlay:
                row['urls'] = overlay['urls']
                row['preferredUrlIndex'] = overlay['preferredUrlIndex']
                row['url'] = overlay['urls'][overlay['preferredUrlIndex']]
            rows.append(row)
    # Move CazéTV only, retaining every base record and all declared additions.
    caze = [r for r in rows if r['name'] == 'CazéTV']
    rest = [r for r in rows if r['name'] != 'CazéTV']
    first = next(i for i,r in enumerate(rest) if r['group'] == 'Esportes')
    rows = rest[:first] + caze + rest[first:]
    selection = {'schema': 'rocha.c7.selection.v1',
                 'provenance': {'kind': 'owner-selection', 'reference': 'Owner order 2026-11-08: frozen 479 + declared additions', 'sourceSha256': PINS[SOURCE]},
                 'previousSha256': None, 'removals': [], 'baseCount': 479, 'additionCount': len(doc['adicoes_aprovadas_fora_da_base']),
                 'channels': rows}
    raw = (json.dumps(selection, ensure_ascii=True, indent=2) + '\n').encode('ascii'); pin = sha(raw)
    # Difference evidence uses IDs/indices and URL hashes; no query strings/tokens in reports.
    differences = {'schema': 'rocha.catalog.diff.v1', 'sourceSha256': PINS[SOURCE],
                   'baseCount': 479, 'historicalReviewCount': sum(r['status_historico']=='Revisar PC' for r in doc['canais']),
                   'additionCount': len(doc['adicoes_aprovadas_fora_da_base']),
                   'effectiveCount': len(rows), 'runtimeSha256': pin,
                   'availabilityProbed': False, 'automaticDeletion': False,
                   'additions': [{'index':i, 'name':r['nome'], 'urlSha256':sha(r['url_atual'].encode())} for i,r in enumerate(doc['adicoes_aprovadas_fora_da_base'])],
                   'duplicatesPreserved': [{'name':'Telecine Action','reason':'Declared outside base and also present in base; no deduplication authorized'}],
                   'urlUpdates': [{'index':i,'name':r['nome'],'originalSha256':sha(r['url_original'].encode()),'currentSha256':sha(r['url_atual'].encode()),'note':r['atualizacao']} for i,r in enumerate(doc['canais']) if r['url_original']!=r['url_atual']],
                   'platforms': {}, 'rokuIdMappings': mapped}
    for platform, old in [('android',old_android), ('roku',old_roku)]:
        by_name = {}
        for r in rows: by_name.setdefault(r['name'], []).append(r)
        additional = []; changed=[]
        for r in old:
            matches=by_name.get(r['name'], [])
            if not matches:
                additional.append({'id':r.get('id'), 'name':r['name'], 'urlSha256':sha(r['url'].encode())})
            elif not any(r['url']==x['url'] for x in matches):
                changed.append({'name':r['name'], 'previousUrlSha256':sha(r['url'].encode()), 'currentUrlSha256':[sha(x['url'].encode()) for x in matches]})
        differences['platforms'][platform]={'previousCount':len(old), 'additionalPreservedInInventory':additional, 'urlDifferences':changed,
            'missingExactNamesInPrevious':[r['name'] for r in rows if not any(x['name']==r['name'] for x in old)]}
    # Cover IDs stay available, including entries outside this official selection.
    cover_map = dict(old_cover); cover_map.update(cover_aliases)
    constants = f"// Generated by tools/official_catalog/catalog.py; do not hand edit.\nconst officialCatalogSha256 = '{pin}';\n"
    adapter = '''' Generated SHA pin; no network or old-catalog fallback.
function readOfficialCatalogue() as Object
  raw = ReadAsciiFile("pkg:/catalog/official-selection.json")
  digest = CreateObject("roEVPDigest")
  digest.Setup("sha256")
  bytes = CreateObject("roByteArray")
  bytes.FromAsciiString(raw)
  digest.Update(bytes)
  if lcase(digest.Final()) <> "PIN" then return invalid
  manifest = ParseJson(raw)
  if type(manifest) <> "roAssociativeArray" then return invalid
  if manifest.baseCount <> 479 or manifest.channels.count() <> COUNT then return invalid
  return manifest.channels
end function
'''.replace('PIN',pin).replace('COUNT',str(len(rows)))
    return {'branding/c7/selection.json':raw,
            ROKU+'catalog/official-selection.json':raw,
            'lib/src/live/official_catalog_pin.dart':constants.encode(),
            ROKU+'components/OfficialCatalogue.brs':adapter.encode(),
            ROKU+'config/official-cover-map.json':encode(cover_map),
            'docs/lab/catalogo-unico-20261108/differences.json':encode(differences),
            'catalog/official/runtime.sha256':(pin+'\n').encode()}

def run(write=False, root=ROOT):
    products = build(root)
    for path, data in products.items():
        target = root/path
        if write:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        elif not target.exists() or target.read_bytes()!=data:
            raise ValueError('Generated adapter diverged: '+path)
    return len(products)

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='regenerate adapters; frozen originals are never written')
    args=parser.parse_args()
    print(f'{run(args.write)} adapter/integrity products verified; 479 base records preserved')
