import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {readZip,sha256} from '../../tools/roku_visual_lab.mjs';
export async function runFollowupTests({repo,newZip}) {
 const dir=path.join(repo,'docs/roku/technical-followup-20261102');
 const old=readZip(await fs.readFile(path.join(repo,'artifacts/roku-lab/20261102/RochaPlus-Roku-LAB-ANDROID-CAPAS-CATALOGO-20261102-v2.zip')));
 const current=readZip(await fs.readFile(newZip));
 const before=JSON.parse(await fs.readFile(path.join(dir,'cover-map-before.json'),'utf8'));
 const map=JSON.parse(current['config/cover-map.json']);
 const tests=[];
 assert.equal(Object.keys(before).length,577);
 for(const [id,uri] of Object.entries(before)){assert.equal(map[id],uri);assert(current[uri.replace('pkg:/','')].equals(old[uri.replace('pkg:/','')]));}
 tests.push('all 577 previous artwork associations and image bytes preserved');
 const changes=Object.keys(old).filter(p=>!current[p]?.equals(old[p])).sort();
 assert.deepEqual(changes,['config/cover-map.json','manifest']);
 const added=Object.keys(current).filter(p=>!old[p]);assert.equal(added.length,1);assert(added[0].startsWith('images/cache/'));
 tests.push('package delta contains only one image, map association and version; all code and catalogs byte-identical');
 const rows=JSON.parse(await fs.readFile(path.join(dir,'pending-30-audit.json'),'utf8'));
 const r=rows.find(x=>x.result==='recovered');assert.equal(r.rokuId,'d8766cba28a96cfe');
 const catalog=JSON.parse(current['catalog/commercial-lab-merged.json']);
 const c=catalog.find(x=>x.id===r.rokuId);assert.equal(sha256(Buffer.from(c.url)),r.streamSha256);
 assert.equal(r.approvedStatusTransferred,false);
 assert(r.androidMatches.some(x=>x.matchedBy==='exact_stream_and_normalized_channel_name'&&x.source==='github_actions_catalog_inventory'));
 const b=current[r.resolvedUri.replace('pkg:/','')];assert.equal(sha256(b),r.imageSha256);assert.equal(b.readUInt32BE(16),192);assert.equal(b.readUInt32BE(20),108);
 const original=await fs.readFile(path.join(repo,'artifacts/roku-lab/20261102/followup/ORIGINAL-beIN-Sports-Haber.jpg'));
 assert.equal(sha256(original),r.originalImageSha256);assert.equal(Object.keys(map).length,578);
 tests.push('new Haber association has exact source identity, preserved original and 192x108 PNG with matching hashes');
 return {passed:tests.length,failed:0,tests,physicalTestsExecuted:false};
}
