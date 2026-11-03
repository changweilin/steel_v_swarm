import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {publishWorldCapture} from './world_capture_publication.mjs';
import {verifyWorldProvenance} from './world_provenance.mjs';

const BIOMES='public/js/biomes.js',HELPER='tools/audit_src.mjs';
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const record=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const finite=value=>typeof value==='number'&&Number.isFinite(value);

async function referenceInputs(sourceDirectory) {
  const bytes={};
  for(const name of [BIOMES,HELPER]) {
    try {bytes[name]=await readFile(join(sourceDirectory,name));}
    catch(error){if(error.code==='ENOENT')throw new Error('Original deck reference input is missing: '+name);throw error;}
  }
  return {bytes,inputs:{[BIOMES]:digest(bytes[BIOMES]),[HELPER]:digest(bytes[HELPER])}};
}

// Execute the original makeDeckIndex only from the exact biomes.js bytes captured
// with this world. The extraction helper is not a world input, so its hash is
// sealed in deckReferences. Any drift leaves the published bundle untouched.
export async function generateWorldReferences(path,sourceDirectory) {
  const published=await readFile(path),world=JSON.parse(published.toString('utf8'));
  await verifyWorldProvenance(world,sourceDirectory);
  const declared=world.source.inputs[BIOMES];
  if(typeof declared!=='string')throw new Error('Captured world does not declare the original deck index input');
  if(!Array.isArray(world.decks)||!record(world.collision)||!finite(world.collision.deckThickness))
    throw new Error('Captured world lacks original deck geometry');
  const before=await referenceInputs(sourceDirectory);
  if(before.inputs[BIOMES]!==declared)throw new Error('Original deck index differs from the captured world input');
  // The hash query gives each helper revision its own module instance.
  const helper=pathToFileURL(join(sourceDirectory,HELPER)).href+'?sha256='+before.inputs[HELPER];
  const {grabFn}=await import(helper);
  const indexSource=grabFn(before.bytes[BIOMES].toString('utf8'),'makeDeckIndex');
  const tolerance=/const LONG_TOL = ([\d.]+)/.exec(indexSource);
  if(!tolerance)throw new Error('Original deck endpoint tolerance missing');
  const query=new Function(`${indexSource}\nreturn makeDeckIndex;`)()(world.decks);
  const deckProbes=world.decks.filter(d=>Math.hypot(d.x2-d.x1,d.z2-d.z1)>0).map(d=>{
    const dx=d.x2-d.x1,dz=d.z2-d.z1,length=Math.hypot(dx,dz);
    const x=Math.fround(d.x1+dx*.371+dz/length*d.hw*.173);
    const z=Math.fround(d.z1+dz*.371-dx/length*d.hw*.173);
    const y=d.y1+(d.y2-d.y1)*.371;
    return{x,z,y,upper:query(x,z,0,y-.03,y+.03),
      lower:query(x,z,0,y-.03,y+.03,true)-world.collision.deckThickness};
  });
  const after=await referenceInputs(sourceDirectory);
  if(Object.keys(before.inputs).some(name=>after.inputs[name]!==before.inputs[name]))
    throw new Error('Original deck reference inputs changed during generation');
  if(!(await readFile(path)).equals(published))throw new Error('Captured world changed during reference generation');
  world.collision.deckEndTolerance=Number(tolerance[1]);
  world.deckProbes=deckProbes;
  world.deckReferences={sourceFingerprint:world.source.fingerprint,
    producerSha256:digest(await readFile(fileURLToPath(import.meta.url))),inputs:before.inputs};
  // Rechecks storage and every captured input, then preserves all numeric bits.
  await publishWorldCapture(path,world,sourceDirectory);
  return {probes:deckProbes.length,tolerance:world.collision.deckEndTolerance};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const [bundle,...extra]=process.argv.slice(2);
  if(typeof bundle!=='string'||!/^[a-zA-Z0-9_]+$/.test(bundle)||extra.length)
    throw new Error('Select exactly one original source world bundle');
  const root=fileURLToPath(new URL('..',import.meta.url));
  const source=resolve(process.env.SVS_SOURCE||join(root,'..','steel_vs_swarm'));
  const result=await generateWorldReferences(join(root,'data/worlds',bundle+'.json'),source);
  console.log('Source layered-deck query references generated '+JSON.stringify({bundle,...result}));
}
