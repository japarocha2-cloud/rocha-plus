import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {loadEngine,parse} from './run-tests.mjs';
export async function runReadinessRokuTests({repo,asar,galleryOverride}){
 const {engine,simulatorVersion,engineSha256}=await loadEngine(asar);
 const dir=path.join(repo,'platforms/roku-lab-visual/components');
 const browser=await fs.readFile(path.join(dir,'ChannelBrowser.brs'),'utf8');
 const gallery=galleryOverride??await fs.readFile(path.join(dir,'GalleryBrowser.brs'),'utf8');
 const source=(browser+'\n'+gallery).replace(/CreateObject\(/g,'TestCreateObject(').replace(/ReadAsciiFile\(/g,'TestReadAsciiFile(')+'\n'+await fs.readFile(path.join(repo,'tests/roku-visual/browser-harness.brs'),'utf8')+'\n'+await fs.readFile(path.join(repo,'tests/roku-visual/readiness-harness.brs'),'utf8');
 const ast=parse(engine,source,'readiness-harness.brs');
 const interpreter=new engine.Interpreter({post:false,entryPoint:false,stopOnCrash:false});interpreter.exec(ast.statements);
 const checks=interpreter.environment.getRootM().get(new engine.BrsString('passes')).elements.map(x=>x.toString());
 assert.equal(checks.length,41);
 return {passed:checks.length,failed:0,relatedRegressions:33,newChecks:8,tests:checks,engine:simulatorVersion,engineSha256,fixtureOnly:true,physicalPlayback:false,ramMeasured:false,fpsMeasured:false};
}
