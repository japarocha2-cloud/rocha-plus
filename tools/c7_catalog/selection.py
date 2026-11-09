"""Offline, explicit owner-selection import. Never fetches or approves candidates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re

SCHEMA = 'rocha.c7.selection.v1'
CATEGORIES = ['TV ao Vivo','Esportes','Infantil','Notícias','Filmes','Séries','Documentários','Música','Educação','Cultura','Entretenimento','Reality','Religiosos','Futebol','Estilo de Vida','Viagens','Culinária','Comédia','Vida ao Ar Livre','Geral','Outros']
ALIASES = dict(zip(['live','tv aberta','open tv','sports','sport','esporte','kids','children','news','movies','films','series','documentary','documentaries','music','education','culture','entertainment','religious','religion','football','soccer','lifestyle','travel','cooking','comedy','outdoor','general','undefined'],['TV ao Vivo','TV ao Vivo','TV ao Vivo','Esportes','Esportes','Esportes','Infantil','Infantil','Notícias','Filmes','Filmes','Séries','Documentários','Documentários','Música','Educação','Cultura','Entretenimento','Religiosos','Religiosos','Futebol','Futebol','Estilo de Vida','Viagens','Culinária','Comédia','Vida ao Ar Livre','Geral','Outros']))

def digest(data): return hashlib.sha256(data).hexdigest()
def encoded(data): return (json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode()
def identity(name):
    value=re.sub(r'\s*\(\d+p\)|\s*\[not 24/7\]|\s*\[geo-blocked\]','',name.strip().lower())
    value=re.sub(r'[\u0300-\u036f]','',value)
    value=value.translate(str.maketrans(dict(zip('áàãâéêíóôõúç','aaaaeeiooouc'))))
    value=re.sub(r'^(recordtv|record tv|tv record)\b','record',value)
    return ' '.join(value.split())
def category(value):
    lookup={identity(c):c for c in CATEGORIES}|{identity(k):v for k,v in ALIASES.items()}
    for part in re.split(r'[;|]',str(value)):
        if identity(part) in lookup: return lookup[identity(part)]
    return 'Outros'
def caze(row): return row['group']=='Esportes' and identity(row['name']).replace(' ','')=='cazetv'
def first_caze(rows):
    featured=[r for r in rows if caze(r)]
    if not featured: return rows
    rest=[r for r in rows if not caze(r)]
    index=next((i for i,r in enumerate(rest) if r['group']=='Esportes'),len(rest))
    return rest[:index]+featured+rest[index:]
def blocked(row,tombstones):
    return any(row['id']==t['id'] or (identity(row['name'])==t['identity'] and
        (t.get('blockIdentity') is True or row['url']==t['url'])) for t in tombstones)
def normalize(rows,old):
    from urllib.parse import urlsplit
    result=[];ids=set()
    old_keys={(identity(r['name']),r['url']):r['id'] for r in old}
    for r in rows:
        if not isinstance(r,dict) or not isinstance(r.get('name'),str) or not r['name'].strip():raise ValueError('invalid channel name')
        uri=urlsplit(r.get('url',''))
        if uri.scheme not in ('http','https') or not uri.hostname or uri.username or uri.password or any(c.isspace() for c in r['url']):raise ValueError('invalid channel URL')
        row=dict(r)
        if any(r.get(k) is not None and not isinstance(r[k],str) for k in ('logo','preferredEngine')):raise ValueError('invalid channel metadata')
        if 'genres' in r and (not isinstance(r['genres'],list) or not all(isinstance(g,str) for g in r['genres'])):raise ValueError('invalid genres')
        row['id']=r.get('id') or old_keys.get((identity(r['name']),r['url'])) or digest((r['name']+'\0'+r['url']).encode())
        if not isinstance(row['id'],str) or not row['id'] or row['id'] in ids:raise ValueError('missing/duplicate channel ID')
        ids.add(row['id'])
        group=r.get('group',r.get('category','Outros'))
        if not isinstance(group,str):raise ValueError('invalid category metadata')
        if 'group' in r and 'category' in r and category(r['group'])!=category(r['category']):raise ValueError('conflicting categories')
        row['group']=category(group)
        if group!=row['group']:row['originalCategory']=group
        row.pop('category',None)
        result.append(row)
    return first_caze(result)

def read_head(store):
    path=store/'HEAD.json'
    if not path.exists():return None,None
    head=json.loads(path.read_bytes())
    if not isinstance(head,dict) or not re.fullmatch('[0-9a-f]{64}',str(head.get('sha256',''))):raise ValueError('invalid selection HEAD')
    raw=(store/'selections'/f"{head['sha256']}.json").read_bytes()
    if digest(raw)!=head['sha256']:raise ValueError('stored selection SHA-256 mismatch')
    return head,json.loads(raw)

def import_selection(store,source,expected_source,expected_head,kind,reference,seed,forbidden_hashes,apply=False,apply_removals=False):
    raw=source.read_bytes()
    if digest(raw)!=expected_source:raise ValueError('source SHA-256 mismatch')
    if expected_source in forbidden_hashes or digest(encoded(json.loads(raw))) in forbidden_hashes:raise ValueError('candidate/pending inventory is not an approved selection')
    if kind not in ('c6-original','owner-selection') or not reference.strip():raise ValueError('explicit source provenance required')
    supplied=json.loads(raw);rows=supplied.get('channels') if isinstance(supplied,dict) else supplied
    if not isinstance(rows,list) or not rows:raise ValueError('non-empty explicit selection required; no count guessed')
    head,previous=read_head(store)
    actual=head['sha256'] if head else 'none'
    if actual!=expected_head:raise ValueError('active selection changed; review diff against current HEAD')
    old=(previous or {}).get('channels',[])
    tombstones=list((previous or {}).get('removals',[]))
    tombstones += [t for t in seed if not any(p['id']==t['id'] for p in tombstones)]
    normalized=normalize(rows,old)
    excluded=[r for r in normalized if blocked(r,tombstones)]
    if excluded and not apply_removals:raise ValueError('removed channel reinclusion rejected; use authorized-removals filter, never reinstate')
    retained=[r for r in normalized if not blocked(r,tombstones)]
    if not retained:raise ValueError('selection would be empty')
    if any(caze(r) for r in old) and not any(caze(r) for r in retained):raise ValueError('CazéTV removal is not authorized by this C7 order')
    new_ids={r['id'] for r in retained}
    for row in old:
        if row['id'] not in new_ids and not any(t['id']==row['id'] for t in tombstones):
            tombstones.append({'id':row['id'],'identity':identity(row['name']),'url':row['url'],
                               'name':row['name'],'blockIdentity':not any(identity(r['name'])==identity(row['name']) for r in retained)})
    if any(blocked(r,tombstones) for r in retained):raise ValueError('selection conflicts with removal history')
    payload={'schema':SCHEMA,'provenance':{'kind':kind,'reference':reference,'sourceSha256':expected_source},
             'previousSha256':None if actual=='none' else actual,'channels':retained,'removals':tombstones}
    body=encoded(payload);sha=digest(body)
    diff={'previousSha256':actual,'sha256':sha,'sourceCount':len(rows),'selectedCount':len(retained),
          'addedIds':[r['id'] for r in retained if r['id'] not in {o['id'] for o in old}],
          'removedIds':[o['id'] for o in old if o['id'] not in new_ids],
          'authorizedExclusions':[r['id'] for r in excluded],
          'changedIds':[r['id'] for r in retained if any(o['id']==r['id'] and o!=r for o in old)],
          'applied':apply}
    if apply:
        for directory in ('sources','selections','diffs'):(store/directory).mkdir(parents=True,exist_ok=True)
        for target,data in [(store/'sources'/expected_source,raw),(store/'selections'/f'{sha}.json',body),(store/'diffs'/f'{sha}.json',encoded(diff))]:
            if target.exists() and target.read_bytes()!=data:raise ValueError('immutable backup collision')
            if not target.exists():target.write_bytes(data)
        pending=store/'HEAD.json.tmp';pending.write_bytes(encoded({'sha256':sha}))
        os.replace(pending,store/'HEAD.json')
    return diff

def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    imp=sub.add_parser('import');imp.add_argument('--source',type=Path,required=True);imp.add_argument('--expected-source-sha256',required=True);imp.add_argument('--expected-head',required=True)
    imp.add_argument('--provenance',choices=['c6-original','owner-selection'],required=True);imp.add_argument('--reference',required=True)
    imp.add_argument('--apply',action='store_true');imp.add_argument('--apply-authorized-removals',action='store_true')
    exp=sub.add_parser('export');exp.add_argument('--output',type=Path,required=True);exp.add_argument('--expected-output-sha256')
    verify=sub.add_parser('verify');verify.add_argument('--asset',type=Path,default=Path('branding/c7/selection.json'))
    for p in (imp,exp,verify):p.add_argument('--store',type=Path,default=Path('catalog/c7/store'))
    args=parser.parse_args();repo=Path(__file__).resolve().parents[2]
    if args.command=='verify':
        head,payload=read_head(args.store)
        if head is None:raise ValueError('original/owner selection not recovered; APK build must remain blocked')
        if not any(caze(r) for r in payload['channels']):raise ValueError('CazéTV is absent; supply the authorized selection, never auto-add candidates')
        if digest(args.asset.read_bytes())!=head['sha256']:raise ValueError('bundled asset does not match verified selection HEAD')
        visited=set();descendant=None
        current=head['sha256']
        while current:
            if current in visited or not re.fullmatch('[0-9a-f]{64}',str(current)):raise ValueError('invalid selection history')
            visited.add(current)
            body=(args.store/'selections'/f'{current}.json').read_bytes()
            if digest(body)!=current:raise ValueError('selection history SHA mismatch')
            data=json.loads(body)
            if data.get('schema')!=SCHEMA:raise ValueError('invalid schema')
            provenance=data['provenance']
            if not re.fullmatch('[0-9a-f]{64}',str(provenance.get('sourceSha256',''))):raise ValueError('invalid source hash')
            source=(args.store/'sources'/provenance['sourceSha256']).read_bytes()
            if digest(source)!=provenance['sourceSha256']:raise ValueError('source backup SHA mismatch')
            if normalize(data['channels'],[])!=data['channels']:raise ValueError('selected channels are not canonical')
            if any(blocked(r,data['removals']) for r in data['channels']):raise ValueError('removed channel in selected catalog')
            if descendant is not None:
                previous_removed={r['id'] for r in data['removals']}
                current_removed={r['id'] for r in descendant['removals']}
                missing={r['id'] for r in data['channels']}-{r['id'] for r in descendant['channels']}
                if not previous_removed.issubset(current_removed) or not missing.issubset(current_removed):raise ValueError('removal history lost')
            descendant=data
            current=data['previousSha256']
        print(json.dumps({'sha256':head['sha256'],'selectedCount':len(payload['channels']),'historyRevisionsVerified':len(visited),'externalImports':False}));return
    if args.command=='export':
        head,payload=read_head(args.store)
        if head is None:raise ValueError('approved source not installed; no candidate fallback')
        raw=(args.store/'selections'/f"{head['sha256']}.json").read_bytes()
        if args.output.exists():
            previous=args.output.read_bytes();old=digest(previous)
            archived=args.store/'selections'/f'{old}.json'
            if args.expected_output_sha256!=old or not archived.exists() or archived.read_bytes()!=previous:
                raise ValueError('existing export must match a reviewed immutable backup and expected output SHA')
        args.output.parent.mkdir(parents=True,exist_ok=True)
        pending=args.output.with_name(args.output.name+'.tmp');pending.write_bytes(raw);os.replace(pending,args.output)
        print(json.dumps({'sha256':head['sha256'],'output':str(args.output),'compileDefine':'ROCHA_C7_CATALOG_SHA256='+head['sha256']}));return
    seed=json.loads((repo/'docs/lab/c7-catalogo-20261108/authorized-removals.json').read_bytes())
    pending_reference=json.loads((repo/'catalog/c7/pending-inventory-reference.json').read_bytes())
    forbidden={pending_reference['sha256'],pending_reference['semanticSha256']}
    args.store.mkdir(parents=True,exist_ok=True);lock=args.store/'.import-lock'
    lock.mkdir() # Exclusive cross-platform lock; stale lock needs operator review.
    try:
        result=import_selection(args.store,args.source,args.expected_source_sha256,args.expected_head,args.provenance,args.reference,seed,forbidden,args.apply,args.apply_authorized_removals)
        print(json.dumps(result,ensure_ascii=False,indent=2))
    finally:lock.rmdir()
if __name__=='__main__':main()
