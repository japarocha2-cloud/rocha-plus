import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {loadEngine,parse} from './run-tests.mjs';
export async function runCentralRokuTests({repo,asar}) {
 const {engine,simulatorVersion}=await loadEngine(asar),lab=path.join(repo,'platforms/roku-lab-visual');
 const sources=await Promise.all(['LabAccess.brs','CentralAccess.brs'].map(n=>fs.readFile(path.join(lab,'components',n),'utf8')));
 const fixtures=JSON.parse(await fs.readFile(path.join(repo,'experiments/central-rights/contract-fixtures.json'),'utf8'));
 const extra='\ncases=ParseJson("'+JSON.stringify(fixtures).replaceAll('"','""')+'")\nfor each c in cases\n m.labConfig.scope=c.scope\n Expect((labLeaseMillis(c.packet,0,c.uid,c.device)>0)=c.allowed,"shared contract: "+c.name)\nend for\n';
 const source=sources.join('\n').replace(/ReadAsciiFile\(/g,'LabRead(').replace(/CreateObject\(/g,'LabObject(')+'\n'+await fs.readFile(path.join(repo,'tests/roku-visual/lab-access-harness.brs'),'utf8')+'\n'+await fs.readFile(path.join(repo,'tests/roku-visual/central-access-harness.brs'),'utf8')+extra;
 const ast=parse(engine,source,'central-client.brs'),interpreter=new engine.Interpreter({post:false,entryPoint:false,stopOnCrash:false});interpreter.exec(ast.statements);
 const checks=interpreter.environment.getRootM().get(new engine.BrsString('checks')).elements.map(x=>x.toString());assert.equal(checks.length,26+fixtures.length);
 for(const n of ['Account.brs','LabAccess.brs','CentralAccess.brs'])parse(engine,await fs.readFile(path.join(lab,'components',n),'utf8'),n);
 const cfg=JSON.parse(await fs.readFile(path.join(lab,'config/central-access.json'),'utf8'));assert.equal(cfg.enabled,false);assert.equal(cfg.endpoint,'');
 return {passed:checks.length,failed:0,previousRelatedRegressions:14,newCases:12+fixtures.length,sharedConformanceCases:fixtures.length,tests:checks,engine:simulatorVersion,fixtureOnly:true,physicalPlayback:false};
}
