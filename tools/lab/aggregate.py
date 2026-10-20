#!/usr/bin/env python3
"""Merge all recovered cohorts without promoting any channel to production."""
import argparse
import csv
import json
import unicodedata
from pathlib import Path
from catalog import m3u
from run_android import consolidate


CATEGORY_ORDER = ['TV ao Vivo', 'Esportes', 'Infantil', 'Notícias', 'Filmes',
                  'Séries', 'Documentários', 'Música', 'Educação', 'Cultura',
                  'Entretenimento', 'Religiosos', 'Futebol', 'Outros']


def alphabetical(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', value.casefold())
                   if not unicodedata.combining(c))


def export_categories(result, out):
    """Publish evidence-approved LAB catalogues only; keep empty themes explicit."""
    directory = out / 'categories'
    directory.mkdir(parents=True, exist_ok=True)
    # Regeneration must not retain an old catalogue whose channels now fail.
    for pattern in ('*.json', '*.csv', '*.m3u'):
        for path in directory.glob(pattern):
            path.unlink()
    approved = [r for r in result['channels']
                if r['status'] == 'automatic_audiovisual_pass'
                and r.get('eligible') and not r.get('blocked')]
    groups = CATEGORY_ORDER + sorted({r['group'] for r in approved} - set(CATEGORY_ORDER), key=alphabetical)
    index = []
    fields = ['name', 'url', 'group', 'preferred', 'testedAt']
    for order, group in enumerate(groups, 1):
        selected = sorted((r for r in approved if r['group'] == group),
                          key=lambda r: (alphabetical(r['name']), r['url']))
        entry = {'order': order, 'category': group, 'validatedChannels': len(selected),
                 'status': 'available' if selected else 'awaiting_validated_channels',
                 'files': {}, 'productionApproved': False}
        if selected:
            stem = f'{order:02d}-' + alphabetical(group).replace(' ', '-')
            channels = [{**r, 'preferred': r['result'].get('preferred'),
                         'testedAt': r['result'].get('testedAt')} for r in selected]
            (directory / f'{stem}.json').write_text(json.dumps(channels, ensure_ascii=False, indent=2))
            with (directory / f'{stem}.csv').open('w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
                writer.writeheader()
                writer.writerows(channels)
            playlist = m3u(selected).replace('# LAB candidates only; not validated for production',
                '# LAB automatic pixel/PCM evidence; no production approval')
            # m3u() has its own sort: restore the same accent-insensitive order.
            lines = playlist.splitlines()[:2]
            for row in selected:
                lines.extend(m3u([row]).splitlines()[2:])
            (directory / f'{stem}.m3u').write_text('\n'.join(lines) + '\n')
            entry['files'] = {ext: f'categories/{stem}.{ext}' for ext in ['json', 'csv', 'm3u']}
        index.append(entry)
    (out / 'catalog-index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2))
    return index


def aggregate(inventory, reports):
    tested = {}
    for report in reports:
        for record in report:
            url = record['channelUrl']
            if url not in tested or record['testedAt'] >= tested[url]['testedAt']:
                tested[url] = record
    rows = []
    for candidate in inventory['candidates']:
        if not candidate['eligible'] or candidate.get('blocked'):
            continue
        result = tested.get(candidate['url'])
        status = 'pending'
        if result is not None:
            status = 'automatic_audiovisual_pass' if result.get('automaticAudiovisualPass') else 'failed_or_inconclusive'
        rows.append(dict(candidate, status=status, result=result, productionApproved=False))
    approved = [r for r in rows if r['status'] == 'automatic_audiovisual_pass']
    origins = {}
    for origin in inventory['sources']:
        selected = [r for r in rows if origin in r['origins']]
        origins[origin] = {'eligible': len(selected), 'tested': sum(r['result'] is not None for r in selected),
                           'automaticAudiovisualPass': sum(r['status'] == 'automatic_audiovisual_pass' for r in selected)}
    return {'sourcesComplete': inventory['complete'], 'sourceFailures': inventory['sourceFailures'],
            'inventorySummary': inventory['summary'],
            'summary': {'eligible': len(rows), 'tested': sum(r['result'] is not None for r in rows),
                        'pending': sum(r['result'] is None for r in rows), 'automaticAudiovisualPass': len(approved),
                        'failedOrInconclusive': sum(r['status'] == 'failed_or_inconclusive' for r in rows),
                        'productionApproved': 0,
                        'approvedByCategory': {g: sum(r['group'] == g for r in approved) for g in sorted({r['group'] for r in approved})}},
            'countsByOrigin': origins, 'channels': rows}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--inventory', default='build/lab/catalog/inventory.json')
    p.add_argument('--evidence', default='build/lab/collected')
    p.add_argument('--output', default='build/lab/final')
    args = p.parse_args()
    inventory = json.loads(Path(args.inventory).read_text())
    reports, failures = [], {}
    for path in Path(args.evidence).rglob('measured-results.json'):
        try:
            reports.append(json.loads(path.read_text()))
        except (ValueError, OSError) as error:
            failures[str(path)] = str(error)
    # A timed-out shard may still contain fully completed raw records. Preserve
    # these as tested/inconclusive; missing output evidence can never approve it.
    for path in Path(args.evidence).rglob('results.json'):
        try:
            raw = json.loads(path.read_text())
            if isinstance(raw, list) and all(isinstance(r, dict) and 'channelUrl' in r for r in raw):
                reports.append(consolidate(raw, path.parent))
        except (ValueError, OSError) as error:
            failures[str(path)] = str(error)
    result = aggregate(inventory, reports)
    result['reportReadFailures'] = failures
    result['evidenceReportFiles'] = [str(p) for p in Path(args.evidence).rglob('measured-results.json')]
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    fields = ['channelKey', 'name', 'url', 'group', 'status', 'preferred', 'testedAt']
    metrics = ['elapsedSeconds', 'progressSeconds', 'startupMilliseconds', 'bufferingMilliseconds', 'stalls', 'error']
    fields += [f'{phase}_{metric}' for phase in ['exo', 'vlc', 'confirmation'] for metric in metrics]
    with (out / 'results.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        for row in result['channels']:
            record = row['result'] or {}
            flat = {**row, 'preferred': record.get('preferred'), 'testedAt': record.get('testedAt')}
            for phase in ['exo', 'vlc', 'confirmation']:
                for metric in metrics:
                    flat[f'{phase}_{metric}'] = record.get(phase, {}).get(metric)
            writer.writerow(flat)
    approved = [r for r in result['channels'] if r['status'] == 'automatic_audiovisual_pass']
    export_categories(result, out)
    for filename, selected in [('automatic-audiovisual-pass.m3u', approved),
                               ('brazil-portuguese-pass.m3u', [r for r in approved if r['brazilOrPortuguese']]),
                               ('football-multilingual-pass.m3u', [r for r in approved if r['football']])]:
        playlist = m3u(selected).replace('# LAB candidates only; not validated for production',
          '# LAB automatic pixel/PCM evidence; no production approval')
        (out / filename).write_text(playlist)
    print(json.dumps(result['summary'], ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
