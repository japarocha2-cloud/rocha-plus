#!/usr/bin/env python3
"""Auditable LAB-only inventory. No playback or production approval is inferred."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import unicodedata
from urllib.parse import urlsplit, urlunsplit
from urllib.request import Request, urlopen

BASE = 'https://iptv-org.github.io/iptv/'
SOURCES = ['index.category.m3u', 'index.language.m3u', 'index.country.m3u'] + [
    f'categories/{x}.m3u' for x in ['movies', 'music', 'kids', 'documentary',
    'news', 'entertainment', 'general', 'sports']] + [
    f'languages/{x}.m3u' for x in ['eng', 'zho', 'spa', 'fra', 'ara', 'por']] + [
    f'countries/{x}.m3u' for x in ['us', 'uk', 'ca', 'au', 'de', 'fr', 'kr', 'br']]
CURRENT = {'countries/br.m3u', 'categories/sports.m3u'}
CATEGORIES = {'movies': 'Filmes', 'music': 'Música', 'kids': 'Infantil',
              'documentary': 'Documentários', 'news': 'Notícias',
              'entertainment': 'Entretenimento', 'general': 'TV ao Vivo',
              'sports': 'Esportes', 'religious': 'Religiosos', 'education': 'Educação',
              'culture': 'Cultura', 'animation': 'Infantil', 'series': 'Séries'}


def identity(name):
    value = unicodedata.normalize('NFD', name.lower())
    value = ''.join(x for x in value if unicodedata.category(x) != 'Mn')
    value = re.sub(r'\s*\(\d+p\)|\s*\[not 24/7\]', '', value)
    return ' '.join(value.split())


def normalize(url):
    p = urlsplit(url.strip())
    if p.scheme.lower() not in ('http', 'https') or not p.hostname or p.username or p.password:
        raise ValueError('Unsupported stream URL')
    host = p.hostname.lower()
    if ':' in host:
        host = f'[{host}]'
    port = p.port
    if port and (p.scheme.lower(), port) not in (('http', 80), ('https', 443)):
        host += f':{port}'
    # Do not reorder/delete query parameters: some URLs are signed.
    return urlunsplit((p.scheme.lower(), host, p.path or '/', p.query, ''))


def parse(text):
    attrs, name = {}, None
    for raw in text.lstrip('\ufeff').splitlines():
        line = raw.strip()
        if line.startswith('#EXTINF:'):
            attrs = dict(re.findall(r'([\w-]+)="([^"]*)"', line))
            # Split at the first comma outside quotes.
            match = re.match(r'#EXTINF:(?:[^",]|"[^"]*")*,(.*)', line)
            name = match.group(1).strip() if match else None
        elif line and not line.startswith('#'):
            if name:
                try:
                    yield {'name': name, 'url': normalize(line), 'id': attrs.get('tvg-id', ''),
                           'logo': attrs.get('tvg-logo'), 'group': attrs.get('group-title', ''),
                           'language': attrs.get('tvg-language', ''), 'country': attrs.get('tvg-country', '')}
                except (ValueError, UnicodeError):
                    pass
            attrs, name = {}, None


def football(name):
    n = identity(name)
    if re.search(r'\b(nfl|ncaa|rugby|american football|futebol americano|australian football)\b', n):
        return False
    return bool(re.search(r'\b(futebol|football|soccer|fifa|uefa|libertadores|premier league|la liga|bundesliga)\b', n))


def download(url):
    with urlopen(Request(url, headers={'User-Agent': 'RochaPlus-LAB/1.0'}), timeout=45) as response:
        return response.read().decode('utf-8-sig')


def blocked_names(root):
    text = (root / 'lib/src/live/channel_repository.dart').read_text()
    block = text.split('_blockedChannelNames = <String>{', 1)[1].split('};', 1)[0]
    return {identity(x) for x in re.findall(r"'([^']+)'", block)}


def build(snapshots, metadata, blocked=()):
    by_url, origin_counts = {}, {}
    by_id = {c['id']: c for c in metadata}
    for source, data in snapshots.items():
        entries = list(parse(data))
        origin_counts[source] = {'entries': len(entries), 'sha256': hashlib.sha256(data.encode()).hexdigest()}
        for entry in entries:
            row = by_url.setdefault(entry['url'], dict(entry, origins=set(), ids=set(), groups=set(), names=set()))
            row['origins'].add(source)
            row['ids'].update([entry['id']] if entry['id'] else [])
            row['groups'].update(x.lower() for x in entry['group'].split(';') if x)
            row['names'].add(entry['name'])
    output = []
    for url, row in sorted(by_url.items()):
        metas = [by_id[x] for x in sorted(row['ids']) if x in by_id]
        brazil = ('countries/br.m3u' in row['origins'] or
                  row['country'].upper() == 'BR' or any(m.get('country') == 'BR' for m in metas))
        portuguese = ('languages/por.m3u' in row['origins'] or
                      row['language'].lower() in ('por', 'pt', 'portuguese', 'português') or
                      any('por' in m.get('languages', []) for m in metas))
        soccer = any(football(n) for n in row['names'])
        excluded = any(identity(n) in blocked for n in row['names'])
        cats = set(row['groups'])
        for m in metas:
            cats.update(m.get('categories', []))
        for origin in row['origins']:
            if origin.startswith('categories/'):
                cats.add(Path(origin).stem)
        themes = sorted({CATEGORIES[c] for c in cats if c in CATEGORIES})
        reason = [x for x, yes in [('brazil', brazil), ('portuguese', portuguese), ('football_name', soccer)] if yes]
        group = 'Futebol' if soccer else next((x for x in ['Infantil', 'Filmes', 'Documentários', 'Música', 'Notícias', 'Entretenimento', 'Esportes', 'Religiosos', 'Educação', 'Cultura', 'Séries', 'TV ao Vivo'] if x in themes), 'Outros')
        output.append({'name': row['name'], 'url': url, 'logo': row['logo'], 'group': group,
                       'ids': sorted(row['ids']), 'origins': sorted(row['origins']),
                       'themes': themes, 'eligibilityReasons': reason,
                       'football': soccer, 'brazilOrPortuguese': brazil or portuguese,
                       'currentCatalog': bool(CURRENT & row['origins']),
                       'eligible': bool(reason) and not excluded, 'blocked': excluded,
                       'status': 'blocked' if excluded else ('pending' if reason else 'out_of_scope'),
                       'languageVerified': portuguese, 'footballNeedsReview': soccer,
                       'productionApproved': False})
    # Group alternate URLs by ID transitively, including multi-ID URL collisions.
    parent = {}
    def find(x):
        parent.setdefault(x, x)
        if parent[x] != x:
            parent[x] = find(parent[x])
        return parent[x]
    for row in output:
        keys = row['ids'] or ['url:' + row['url']]
        root = find(keys[0])
        for key in keys[1:]:
            parent[find(key)] = root
    for row in output:
        row['channelKey'] = find((row['ids'] or ['url:' + row['url']])[0])
    groups = {}
    for row in output:
        groups.setdefault(row['channelKey'], []).append(row['url'])
    for row in output:
        row['alternateUrls'] = [x for x in groups[row['channelKey']] if x != row['url']]
    eligible = [r for r in output if r['eligible']]
    return {'schemaVersion': 1, 'sources': origin_counts, 'candidates': output,
            'summary': {'rawEntries': sum(x['entries'] for x in origin_counts.values()),
                        'uniqueUrls': len(output), 'duplicateOccurrences': sum(x['entries'] for x in origin_counts.values()) - len(output),
                        'eligibleUrls': len(eligible), 'eligibleChannels': len({x['channelKey'] for x in eligible}),
                        'newEligibleUrls': sum(not x['currentCatalog'] for x in eligible),
                        'blockedUrls': sum(x['blocked'] for x in output), 'tested': 0, 'approved': 0,
                        'categories': {g: sum(x['group'] == g for x in eligible) for g in sorted({x['group'] for x in eligible})}}}


def m3u(rows):
    def clean(x):
        return str(x).replace('\r', ' ').replace('\n', ' ').replace('"', "'")
    lines = ['#EXTM3U', '# LAB candidates only; not validated for production']
    for row in sorted(rows, key=lambda x: (x['group'], x['name'], x['url'])):
        lines.extend([f'#EXTINF:-1 tvg-id="{clean(next(iter(row.get("ids", [])), ""))}" group-title="{clean(row["group"])}",{clean(row["name"])}', row['url']])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='build/lab/catalog')
    parser.add_argument('--cache', default='build/lab/sources')
    parser.add_argument('--offline', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    cache, out = Path(args.cache), Path(args.output)
    cache.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    failures = {}
    def get(source):
        path = cache / source.replace('/', '__')
        try:
            data = path.read_text() if args.offline else download(BASE + source)
            if not data.lstrip().startswith('#EXTM3U'):
                raise ValueError('Response is not an M3U playlist')
            path.write_text(data)
            return source, data, None
        except Exception as error:
            return source, None, str(error)
    snapshots = {}
    with ThreadPoolExecutor(max_workers=6) as pool:
        for source, data, error in pool.map(get, SOURCES):
            if error:
                failures[source] = error
            else:
                snapshots[source] = data
    meta_path = cache / 'channels.json'
    try:
        meta_text = meta_path.read_text() if args.offline else download('https://iptv-org.github.io/api/channels.json')
        metadata = json.loads(meta_text)
        meta_path.write_text(meta_text)
    except Exception as error:
        metadata = []
        failures['metadata'] = str(error)
    result = build(snapshots, metadata, blocked_names(root))
    result.update(createdAt=datetime.now(timezone.utc).isoformat(), sourceFailures=failures,
                  complete=not failures, metadataSha256=hashlib.sha256(json.dumps(metadata, sort_keys=True).encode()).hexdigest())
    (out / 'inventory.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    rows = [x for x in result['candidates'] if x['eligible']]
    (out / 'candidates.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2))
    with (out / 'candidates.csv').open('w', newline='') as f:
        fields = ['channelKey', 'name', 'url', 'group', 'status', 'origins', 'eligibilityReasons', 'alternateUrls']
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    for filename, selected in [('brazil-portuguese-candidates.m3u', [x for x in rows if x['brazilOrPortuguese']]),
                               ('football-multilingual-candidates.m3u', [x for x in rows if x['football']])]:
        (out / filename).write_text(m3u(selected))
    print(json.dumps({'summary': result['summary'], 'sourceFailures': failures}, ensure_ascii=False, indent=2))
    if not rows:
        raise SystemExit('No eligible inventory; refusing an empty successful run')


if __name__ == '__main__':
    main()
