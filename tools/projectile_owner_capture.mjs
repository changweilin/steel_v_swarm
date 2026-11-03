import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';
import {projectileReferences} from './projectile_references.mjs';

const root=fileURLToPath(new URL('..',import.meta.url));
const source=resolve(process.argv[2]||process.env.SVS_SOURCE||join(root,'..','steel_vs_swarm'));
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const provenance=JSON.parse(await readFile(join(root,'data/provenance.json'),'utf8'));
const sourceInputs={};
for(const path of ['public/js/game.js','public/js/data.js','public/js/pool.js','out/forest_review/three.module.js','tools/audit_src.mjs']) {
  const bytes=await readFile(join(source,path));
  if(digest(bytes)!==provenance.inputs[path])throw new Error('Original projectile input changed: '+path);
  sourceInputs[path]=digest(bytes);
}
const game=(await readFile(join(source,'public/js/game.js'),'utf8')).replace(/\r\n?/g,'\n');
const {grabMethod}=await import(pathToFileURL(join(source,'tools/audit_src.mjs')).href);
const THREE=await import(pathToFileURL(join(source,'out/forest_review/three.module.js')).href);
const data=await import(pathToFileURL(join(source,'public/js/data.js')).href);
const {Pool}=await import(pathToFileURL(join(source,'public/js/pool.js')).href);
const poolMax=Number(/const PROJ_POOL_MAX = (\d+);/.exec(game)?.[1]);
const tracerPoolMax=Number(/const TRACER_POOL_MAX = (\d+);/.exec(game)?.[1]);
const spritePoolMax=Number(/const SPRITE_POOL_MAX = (\d+);/.exec(game)?.[1]);
const bulletRecMax=Number(/const BULLET_REC_MAX = (\d+);/.exec(game)?.[1]);
const fxShellMax=Number(/const FX_SHELL_MAX = (\d+);/.exec(game)?.[1]);
const fxMax=Number(/const FX_MAX = (\d+);/.exec(game)?.[1]);
for(const [name,value]of [['PROJ_POOL_MAX',poolMax],['TRACER_POOL_MAX',tracerPoolMax],['SPRITE_POOL_MAX',spritePoolMax],
  ['BULLET_REC_MAX',bulletRecMax],['FX_SHELL_MAX',fxShellMax],['FX_MAX',fxMax]])
  if(!Number.isSafeInteger(value)||value<1)throw new Error('Missing original presentation pool bound: '+name);
const fade=game.split('\n').find(line=>line.startsWith('function _tracerFade('));
if(!fade)throw new Error('Missing original tracer fade');
const tracerFade=new Function(fade+'\nreturn _tracerFade;')();
let created=0,disposed=0,released=0;
const scope={THREE,Pool,CHARACTERS:data.CHARACTERS,sideInfo:data.sideInfo,_shotColCache:new Map(),
  PROJ_POOL_MAX:poolMax,TRACER_POOL_MAX:tracerPoolMax,SPRITE_POOL_MAX:spritePoolMax,
  BULLET_REC_MAX:bulletRecMax,FX_SHELL_MAX:fxShellMax,FX_MAX:fxMax,_tracerFade:tracerFade,
  // Geometry is a declared probe; the original methods own every pool decision.
  projectileMesh:()=>{const mesh=new THREE.Object3D();mesh.userData.probe=created++;return mesh;},
  disposeTree:()=>disposed++};
const method=name=>new Function(...Object.keys(scope),'return ({'+grabMethod(game,name)+'})['+JSON.stringify(name)+'];')(...Object.values(scope));
const client={scene:new THREE.Scene(),_projPool:new Map(),side:'STEEL',ch:'t06',_shotCols:method('_shotCols'),
  _recPool:{release(record){if(record.mesh!==null)throw new Error('Source record still owns its recycled mesh');released++;}}};
const take=method('_takeProjectile'),drop=method('_dropBullet');
const definition=data.heroWeapon('t06','light',1);
const records=[];
for(let index=0;index<poolMax+1;index++) {
  const mesh=take.call(client,definition,false);client.scene.add(mesh);
  records.push({mesh});
}
const steps=[];
for(let index=records.length-1;index>=0;index--) {
  drop.call(client,records[index]);
  steps.push({index,cleared:records[index].mesh===null,free:[...client._projPool.values()][0].length,disposed,released});
}
const next=take.call(client,definition,false);
next.scale.set(2,3,4);client.scene.add(next);drop.call(client,{mesh:next});
const reused=take.call(client,definition,false);
const reuse={index:reused.userData.probe,scale:reused.scale.toArray(),visible:reused.visible,created};
let tracerCreated=0,tracerGeometryDisposed=0,tracerMaterialDisposed=0,shellReleased=0;
const tracerPoolClient={scene:new THREE.Scene(),effects:[],_fireTex:()=>null,_smokeTex:()=>null,
  _initFxPools:method('_initFxPools'),_tracer:method('_tracer'),_pushTracerFx:method('_pushTracerFx'),
  _releaseFxLine:method('_releaseFxLine'),_updateEffects:method('_updateEffects'),_freeEffect:method('_freeEffect')};
tracerPoolClient._initFxPools();
const tracerPrewarm=tracerPoolClient._tracerPool.size;
const fxShellPrewarm=tracerPoolClient._fxShellPool.size;
const instrumentLine=line=>{
  line.userData.probe=tracerCreated++;
  const disposeGeometry=line.geometry.dispose.bind(line.geometry);
  const disposeMaterial=line.material.dispose.bind(line.material);
  line.geometry.dispose=()=>{tracerGeometryDisposed++;disposeGeometry();};
  line.material.dispose=()=>{tracerMaterialDisposed++;disposeMaterial();};
  return line;
};
for(const line of tracerPoolClient._tracerPool._free)instrumentLine(line);
const makeTracer=tracerPoolClient._tracerPool._make;
tracerPoolClient._tracerPool._make=()=>instrumentLine(makeTracer());
const releaseShell=tracerPoolClient._fxShellPool.release.bind(tracerPoolClient._fxShellPool);
tracerPoolClient._fxShellPool.release=shell=>{
  if(shell?.obj!==undefined)shellReleased++;
  return releaseShell(shell);
};
const prewarmState={free:tracerPrewarm,created:tracerCreated,inScene:tracerPoolClient.scene.children.length,
  anyVisible:tracerPoolClient._tracerPool._free.some(line=>line.visible)};
const tracerAcquire=[];
for(let index=0;index<tracerPoolMax+1;index++) {
  tracerPoolClient._tracer(new THREE.Vector3(index,1,2),new THREE.Vector3(index,3,4),0x4fc3f7,.1);
  const shell=tracerPoolClient.effects.at(-1),line=shell.obj;
  tracerAcquire.push({index,probe:line.userData.probe,free:tracerPoolClient._tracerPool.size,created:tracerCreated,
    inScene:line.parent===tracerPoolClient.scene,visible:line.visible,opacity:line.material.opacity});
}
const tracerSteps=[],rawReleaseFxLine=tracerPoolClient._releaseFxLine;
const acquiredLines=tracerPoolClient.effects.map(shell=>shell.obj);
tracerPoolClient._releaseFxLine=function(line) {
  const index=acquiredLines.indexOf(line),hadShell=Boolean(line.userData.shell);
  rawReleaseFxLine.call(this,line);
  if(hadShell)tracerSteps.push({index,probe:line.userData.probe,cleared:line.userData.shell===null,
    visible:line.visible,inScene:line.parent!==null,free:this._tracerPool.size,
    geometryDisposed:tracerGeometryDisposed,materialDisposed:tracerMaterialDisposed,shellReleased});
};
tracerPoolClient._updateEffects(.2);
for(const line of acquiredLines)tracerPoolClient._releaseFxLine(line);
const idempotentRelease={free:tracerPoolClient._tracerPool.size,
  geometryDisposed:tracerGeometryDisposed,materialDisposed:tracerMaterialDisposed,shellReleased};
tracerPoolClient._releaseFxLine=rawReleaseFxLine;
tracerPoolClient._tracer(new THREE.Vector3(9,8,7),new THREE.Vector3(6,5,4),0xffb300,.25);
const reusedTracer=tracerPoolClient.effects.at(-1).obj;
const tracerReuse={probe:reusedTracer.userData.probe,free:tracerPoolClient._tracerPool.size,
  created:tracerCreated,visible:reusedTracer.visible,inScene:reusedTracer.parent===tracerPoolClient.scene,
  opacity:reusedTracer.material.opacity};
tracerPoolClient._updateEffects(.3);
tracerPoolClient._tracerPool.clear(line=>{line.geometry.dispose();line.material.dispose();});
const tracerPool={max:tracerPoolMax,prewarm:tracerPrewarm,fxShellMax,fxShellPrewarm,
  prewarmState,acquire:tracerAcquire,steps:tracerSteps,idempotent:idempotentRelease,reuse:tracerReuse};
const tracerClient={scene:new THREE.Scene(),effects:[],_fireTex:()=>null,_smokeTex:()=>null,
  _initFxPools:method('_initFxPools'),_tracer:method('_tracer'),_pushTracerFx:method('_pushTracerFx'),
  _releaseFxLine:method('_releaseFxLine'),_updateEffects:method('_updateEffects'),_freeEffect:method('_freeEffect')};
tracerClient._initFxPools();
const topTracer=tracerClient._tracerPool._free.at(-1);
const tracerGeometry=topTracer.geometry,tracerMaterial=topTracer.material;
const tracer=method('_tracer'),tracerUpdates=[];
for(const [start,end,color,ttl]of [
  [[1,2,3],[-4,5,-6],0x4fc3f7,.1],
  [[-8,7,-6],[5,-4,3],0xffb300,.35],
  [[100000001,.125,-.375],[100000009,3.25,.625],0xffffff,.2],
]) {
  tracerClient._tracer(new THREE.Vector3(...start),new THREE.Vector3(...end),color,ttl);
  const tracerLine=tracerClient.effects[0].obj;
  tracerUpdates.push({start,end,color,ttl,vertices:[...tracerLine.geometry.attributes.position.array],
    opacity:tracerLine.material.opacity,geometrySame:tracerLine.geometry===tracerGeometry,materialSame:tracerLine.material===tracerMaterial,
    freeDuringActive:tracerClient._tracerPool.size});
  tracerClient._updateEffects(ttl+.01);
  tracerClient._releaseFxLine(tracerLine);
}
tracerClient._tracerPool.clear(line=>{line.geometry.dispose();line.material.dispose();});
const bits=value=>{const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);return bytes.toString('hex');};
const tracerSequences=[];
for(const ttl of [.1,.35]) {
  const context={scene:new THREE.Scene(),effects:[],_fireTex:()=>null,_smokeTex:()=>null,
    _initFxPools:method('_initFxPools'),_tracer:method('_tracer'),_pushTracerFx:method('_pushTracerFx'),
    _releaseFxLine:method('_releaseFxLine'),_updateEffects:method('_updateEffects'),_freeEffect:method('_freeEffect')};
  context._initFxPools();
  tracer.call(context,new THREE.Vector3(1,2,3),new THREE.Vector3(-4,5,-6),0xffffff,ttl);
  const record=context.effects[0],sequenceLine=record.obj,frames=[];
  for(const delta of [0,.001,1/60,.017,.032,.04,.06,.09,.15,.2]) {
    context._updateEffects(delta);
    frames.push({deltaBits:bits(delta),ttlBits:bits(record.ttl),ageBits:bits(record.age),
      active:context.effects.length>0,visible:sequenceLine.visible,opacity:sequenceLine.material.opacity});
  }
  context._tracerPool.clear(line=>{line.geometry.dispose();line.material.dispose();});
  tracerSequences.push({ttlBits:bits(ttl),frames});
}
const captured=await projectileReferences(data,game,source);
const flight=captured.visualShells.filter(item=>item.character===definition.ch&&item.slot===definition.slot&&item.level===1);
if(flight.length!==4)throw new Error('Missing original ordinary/hit/range visual flight programs');
for(const [path,expected]of Object.entries(sourceInputs))
  if(digest(await readFile(join(source,path)))!==expected)throw new Error('Source changed during projectile capture: '+path);
const inputs={};
for(const path of ['tools/projectile_owner_capture.mjs','tools/projectile_references.mjs','tools/fixture_json.mjs'])
  inputs[path]=digest((await readFile(join(root,path),'utf8')).replace(/\r\n?/g,'\n'));
await writeFixtureJson(join(root,'data/projectile_presentation.json'),{formatVersion:1,source:{inputs,sourceInputs},
  poolMax,tracerPool,key:[definition.ch,definition.slot,'steel'].join('-'),steps,reuse,flight,tracerFrames:captured.tracerPresentation,tracerUpdates,tracerSequences});
console.log('PROJECTILE_OWNER_CAPTURE_PASS '+JSON.stringify({poolMax,tracerPoolMax,tracerPrewarm,created,disposed,steps:steps.length,tracerSteps:tracerSteps.length}));
