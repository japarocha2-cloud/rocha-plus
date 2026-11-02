import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {loadEngine,parse} from './run-tests.mjs';
import {readZip} from '../../tools/roku_visual_lab.mjs';
export async function runLabClientTests({asar,repo}) {
 const lab=path.join(repo,'platforms/roku-lab-visual'),{engine,simulatorVersion}=await loadEngine(asar);
 const source=(await fs.readFile(path.join(lab,'components/LabAccess.brs'),'utf8')).replace(/ReadAsciiFile\(/g,'LabRead(').replace(/CreateObject\(/g,'LabObject(')+'\n'+await fs.readFile(path.join(repo,'tests/roku-visual/lab-access-harness.brs'),'utf8');
 const ast=parse(engine,source,'lab-access-harness.brs'),interpreter=new engine.Interpreter({post:false,entryPoint:false,stopOnCrash:false});interpreter.exec(ast.statements);
 const checks=interpreter.environment.getRootM().get(new engine.BrsString('checks'));
 return {passed:checks.elements.length,failed:0,tests:checks.elements.map(x=>x.toString()),engine:simulatorVersion,fixtureOnly:true};
}
export async function runLabPackageTests({repo,zip,privateAccountEmail}) {
 const files=readZip(await fs.readFile(zip)),prior=readZip(await fs.readFile(path.join(repo,'artifacts/roku-lab/20261102/followup/RochaPlus-Roku-LAB-0.6.5-CAPA-HABER-20261102.zip')));
 const map=JSON.parse(files['config/cover-map.json']),tests=[];
 assert.equal(Object.keys(map).length,578);assert(files['config/cover-map.json'].equals(prior['config/cover-map.json']));
 for(const uri of Object.values(map))assert(files[uri.replace('pkg:/','')].equals(prior[uri.replace('pkg:/','')]));
 for(const name of Object.keys(prior).filter(n=>n.startsWith('catalog/')))assert(files[name].equals(prior[name]));
 tests.push('all 578 artwork associations, textures and catalog bytes preserved');
 const config=JSON.parse(files['config/lab-access.json']);assert.equal(config.enabled,false);assert.equal(config.endpoint,'');assert.equal(config.scope,'homologation');assert.equal(config.environment,'roku-lab');
 assert.equal(JSON.parse(files['config/physical-lab-access.json']).mode,'account_homologation');assert(files['config/auth.json'].equals(prior['config/auth.json']));
 if(privateAccountEmail)for(const[name,b]of Object.entries(files).filter(([n])=>/\.(json|brs|xml)$/.test(n)))assert(!b.toString().toLowerCase().includes(privateAccountEmail.toLowerCase()),'private account must not be embedded '+name);
 tests.push('default locked, commercial config unchanged, no private account in distributable');
 assert(files.manifest.toString().includes('build_version=6'));assert(files['components/HomeScene.xml'].toString().includes('Roku LAB 0.6.6'));tests.push('manifest and visible version label agree on 0.6.6');
 const allowed=['components/Account.brs','components/ChannelBrowser.brs','components/HomeScene.xml','config/physical-lab-access.json','manifest'];
 const modified=Object.keys(prior).filter(n=>!files[n]?.equals(prior[n])).sort();assert.deepEqual(modified,allowed.sort());
 assert.deepEqual(Object.keys(files).filter(n=>!prior[n]).sort(),['components/LabAccess.brs','config/lab-access.json']);
 tests.push('package delta restricted to isolated LAB access and version UI');
 return {passed:tests.length,failed:0,tests,files:Object.keys(files).length,physicalExecuted:false};
}
