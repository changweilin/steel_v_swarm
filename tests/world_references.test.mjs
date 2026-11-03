import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdir,mkdtemp,readFile,unlink,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {generateWorldReferences} from '../tools/world_references.mjs';
import {stringifySourceJson} from '../tools/source_json.mjs';

const artifacts=fileURLToPath(new URL('../artifacts/opus/world-references-tests/',import.meta.url));
const digest=value=>createHash('sha256').update(value).digest('hex');
const biomes=tolerance=>`export function other() { return 0; }
function makeDeckIndex(decks) {
  const LONG_TOL = ${tolerance};
  return (x, z, r, lo, hi, under) => under ? lo - LONG_TOL : hi + decks.length;
}
`;
// The fake extraction helper can run a side effect while the original index is extracted.
const helper=effect=>`import {readFileSync,writeFileSync} from 'node:fs';
export function grabFn(text, name) {
  ${effect}
  const start = text.indexOf('function ' + name + '(');
  let depth = 0;
  for (let index = text.indexOf('{', start); index < text.length; index++) {
    if (text[index] === '{') depth++;
    else if (text[index] === '}' && --depth === 0) return text.slice(start, index + 1);
  }
  throw new Error('missing ' + name);
}
`;

async function fixture({tolerance='1.5',effect='',declare=true}={}) {
  await mkdir(artifacts,{recursive:true});
  const root=await mkdtemp(join(artifacts,'run-')),sourceDirectory=join(root,'source');
  await mkdir(join(sourceDirectory,'public/js'),{recursive:true});await mkdir(join(sourceDirectory,'tools'));
  await writeFile(join(sourceDirectory,'public/js/biomes.js'),biomes(tolerance));
  await writeFile(join(sourceDirectory,'tools/audit_src.mjs'),helper(effect));
  await writeFile(join(sourceDirectory,'public/js/terrain.js'),'original terrain');
  const inputs={'public/js/terrain.js':digest('original terrain')};
  if(declare)inputs['public/js/biomes.js']=digest(biomes(tolerance));
  const source={identity:{map:'probe',teamSize:1,season:'winter'},inputs};
  source.inputFingerprint=digest(JSON.stringify(source));source.assets={};
  source.fingerprint=digest(JSON.stringify(source));
  const world={worldSourceVersion:2,meshCount:0,meshChunks:[],collision:{deckThickness:1.2,roofThickness:1},
    decks:[{x1:0,z1:0,y1:10,x2:4,z2:3,y2:12,hw:2},{x1:5,z1:5,y1:1,x2:5,z2:5,y2:1,hw:1}],
    marine:[{matrix:[1,-0,0,-0]}],sampler:[-0,0.1+0.2],source};
  const path=join(root,'world.json'),bytes=stringifySourceJson(world);
  await writeFile(path,bytes);
  return {root,sourceDirectory,path,bytes,world};
}

test('matching inputs publish original tolerance and deck queries with every captured bit retained',async()=>{
  const {sourceDirectory,path,world}=await fixture();
  assert.deepEqual(await generateWorldReferences(path,sourceDirectory),{probes:1,tolerance:1.5});
  const published=JSON.parse(await readFile(path,'utf8'));
  assert.equal(published.collision.deckEndTolerance,1.5);
  assert.equal(published.deckProbes.length,1);
  const [probe]=published.deckProbes;
  assert.equal(probe.x,Math.fround(4*.371+3/5*2*.173));
  assert.equal(probe.z,Math.fround(3*.371-4/5*2*.173));
  assert.equal(probe.y,10+2*.371);
  assert.equal(probe.upper,probe.y+.03+2);
  assert.equal(probe.lower,probe.y-.03-1.5-1.2);
  assert.ok(Object.is(published.marine[0].matrix[1],-0)&&Object.is(published.marine[0].matrix[3],-0));
  assert.ok(Object.is(published.sampler[0],-0));
  assert.equal(published.sampler[1],0.1+0.2);
  assert.deepEqual(published.source,world.source);
  assert.deepEqual(published.deckReferences.inputs,{
    'public/js/biomes.js':digest(biomes('1.5')),'tools/audit_src.mjs':digest(helper(''))});
  assert.equal(published.deckReferences.sourceFingerprint,world.source.fingerprint);
  assert.match(published.deckReferences.producerSha256,/^[a-f0-9]{64}$/);
  const first=await readFile(path);
  await generateWorldReferences(path,sourceDirectory);
  assert.ok((await readFile(path)).equals(first),'a rerun on unchanged inputs is byte-stable');
});

test('changed or missing original inputs reject before the bundle changes',async()=>{
  for(const mode of ['changed-biomes','missing-biomes','missing-helper','changed-world-input','undeclared']) {
    const {sourceDirectory,path,bytes}=await fixture({declare:mode!=='undeclared'});
    if(mode==='changed-biomes')await writeFile(join(sourceDirectory,'public/js/biomes.js'),biomes('2.5'));
    else if(mode==='missing-biomes')await unlink(join(sourceDirectory,'public/js/biomes.js'));
    else if(mode==='missing-helper')await unlink(join(sourceDirectory,'tools/audit_src.mjs'));
    else if(mode==='changed-world-input')await writeFile(join(sourceDirectory,'public/js/terrain.js'),'edited terrain');
    const expected={
      'changed-biomes':/Original world input changed or is missing: public\/js\/biomes\.js/,
      'missing-biomes':/Original world input changed or is missing: public\/js\/biomes\.js/,
      'missing-helper':/Original deck reference input is missing: tools\/audit_src\.mjs/,
      'changed-world-input':/Original world input changed or is missing: public\/js\/terrain\.js/,
      undeclared:/does not declare the original deck index input/}[mode];
    await assert.rejects(generateWorldReferences(path,sourceDirectory),expected,mode);
    assert.equal(await readFile(path,'utf8'),bytes,mode);
  }
});

test('bundles without sealed original provenance are rejected unchanged',async()=>{
  const {sourceDirectory,path}=await fixture();
  const legacy=stringifySourceJson({decks:[],collision:{deckThickness:1.2},source:{inputs:{}}});
  await writeFile(path,legacy);
  await assert.rejects(generateWorldReferences(path,sourceDirectory),/Missing original world provenance/);
  assert.equal(await readFile(path,'utf8'),legacy);
});

test('source edits during reference generation preserve the original bundle byte-for-byte',async()=>{
  const effects={
    biomes:`writeFileSync(new URL('../public/js/biomes.js', import.meta.url), text.replace('LONG_TOL = 1.5', 'LONG_TOL = 9'));`,
    helper:`writeFileSync(new URL(import.meta.url), readFileSync(new URL(import.meta.url), 'utf8') + '\\n');`,
  };
  for(const [mode,effect] of Object.entries(effects)) {
    const {sourceDirectory,path,bytes}=await fixture({effect});
    await assert.rejects(generateWorldReferences(path,sourceDirectory),/inputs changed during generation/,mode);
    assert.equal(await readFile(path,'utf8'),bytes,mode);
  }
});

test('a bundle replaced during reference generation is not overwritten',async()=>{
  const effect=`writeFileSync(new URL('../../world.json', import.meta.url), '{"replaced":true}');`;
  const {sourceDirectory,path}=await fixture({effect});
  await assert.rejects(generateWorldReferences(path,sourceDirectory),/Captured world changed during reference generation/);
  assert.equal(await readFile(path,'utf8'),'{"replaced":true}');
});
