#!/usr/bin/env python3
"""One reviewed FFmpeg report -> shared mobile/Android TV/Roku catalogue."""
import argparse,csv,json,re,hashlib,unicodedata
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BLOCKED=['1001 noites','30a golf kingdom','pluto tv esportes','canal do inter','band sports','times brasil','tv thathi','tv sul de minas','tv meio','tv difusora leste','tv encontro das aguas']
POPULAR=['globo','tv morena','sbt','band','redetv','rede tv','tv cultura','tv brasil','gazeta','redevida','rede vida','cancao nova','aparecida','jovem pan','cnn']
def normalized(name):
 s=''.join(c for c in unicodedata.normalize('NFKD',name.lower()) if not unicodedata.combining(c))
 return re.sub(r'\s*\(\d+p\)|\s*\[.*?\]','',s).strip()
def reason(row):
 n=normalized(row['name'])
 if 'record' in n or any(n==b or n.startswith(b+' ') for b in BLOCKED):return 'previously_blocked'
 if row['v4_status']!='completou_teste':return row['v4_status']
 if row['v4_exit_code']!='0' or row['probe_status']!='video_e_audio' or float(row['v4_decoded_seconds'] or 0)<29:return 'insufficient_decoding_evidence'
 if not row['url'].startswith(('https://','http://')) or '.m3u8' not in row['url'].lower():return 'format_not_integrated_across_platforms'
 return None
def group(row):
 n=normalized(row['name'])
 if '/sports.m3u' in row['source'] or any(t in n for t in ['sport','esport','futebol','espn']):return 'Esportes'
 if any(t in n for t in ['news','noticia','cnn','jovem pan']):return 'Notícias'
 if any(t in n for t in ['kids','cartoon','nick','gloob','infantil','toon']):return 'Infantil'
 return 'TV aberta'
def generate(report):
 rows=list(csv.DictReader(report.open(encoding='utf-8-sig'))); approved=[]; excluded=[];seen=set()
 for row in rows:
  rejection=reason(row)
  if row['url'] in seen:rejection='duplicate_url'
  if rejection:excluded.append({'name':row['name'],'url':row['url'],'reason':rejection});continue
  seen.add(row['url']);approved.append({'id':hashlib.sha256(row['url'].encode()).hexdigest()[:16],'name':row['name'],'url':row['url'],'group':group(row),'approved':True,'status':'approved','evidence':{'report':report.name,'decoded_seconds':float(row['v4_decoded_seconds']),'video_codec':row['video_codec'],'audio_codec':row['audio_codec']}})
 approved.sort(key=lambda c:next((i for i,t in enumerate(POPULAR) if t in normalized(c['name'])),len(POPULAR)))
 return approved,excluded
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('report',type=Path);args=ap.parse_args();a,q=generate(args.report)
 for path,items in [(ROOT/'catalog/approved.json',a),(ROOT/'catalog/quarantine.json',q),(ROOT/'platforms/roku/catalog/approved.json',a),(ROOT/'platforms/roku/catalog/quarantine.json',q)]:
  path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n')
 print(f'{len(a)} common approved; {len(q)} excluded')
