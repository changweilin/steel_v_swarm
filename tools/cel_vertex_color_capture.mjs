import {mkdir,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';

const root=fileURLToPath(new URL('..',import.meta.url));
const source=resolve(process.argv[2]||process.env.SVS_SOURCE||join(root,'..','steel_vs_swarm'));
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const provenance=JSON.parse(await readFile(join(root,'data/provenance.json'),'utf8'));
const threePath='out/forest_review/three.module.js';
const three=await readFile(join(source,threePath));
if(provenance.inputs?.[threePath]!==digest(three))throw new Error('Refresh shared source metadata first: '+threePath);

// Corners run (-1,-1), (1,-1), (-1,1), (1,1). 1.06 is the Float32 world tint value.
const hdr=Math.fround(1.06);
const cases=[
  {name:'uncolored',albedoHex:0xc0c0c0,vertexColors:false,colorSize:3,colors:[]},
  {name:'hdr_rgb',albedoHex:0xc0c0c0,vertexColors:true,colorSize:3,colors:[hdr,hdr,hdr,.25,hdr,.5,hdr,.75,hdr,.5,.25,1]},
  {name:'signed_rgb',albedoHex:0xffffff,vertexColors:true,colorSize:3,colors:[-.25,.5,hdr,hdr,-.5,.25,.5,hdr,-1,1,1,1]},
  {name:'hdr_rgba',albedoHex:0xc0c0c0,vertexColors:true,colorSize:4,transparent:true,colors:[hdr,.5,.25,1,.25,hdr,.5,.75,.5,.25,hdr,.5,hdr,hdr,hdr,.25]},
  {name:'instance_tint',albedoHex:0xc0c0c0,vertexColors:true,colorSize:3,instanceColor:[.5,.75,1],colors:[hdr,hdr,hdr,hdr,.5,.25,.25,.5,hdr,.5,.5,.5]},
  {name:'instance_only',albedoHex:0xc0c0c0,vertexColors:false,colorSize:3,instanceColor:[.5,.75,1],colors:[]},
];
for(const item of cases)item.colors=item.colors.map(Math.fround);

const {chromiumOrNull,chromePath}=await import(pathToFileURL(join(source,'tools/pw.mjs')).href);
const chromium=await chromiumOrNull();
if(!chromium)throw new Error('Original development Playwright runtime is required');
const browser=await chromium.launch({headless:true,executablePath:chromePath()});
try {
  const page=await browser.newPage(),origin='http://godot-cel-color.invalid';
  // Serve the pinned source Three module locally; no app server or CDN is used.
  await page.route('**/*',route=>{
    const url=new URL(route.request().url());
    if(url.origin!==origin)return route.abort();
    if(url.pathname==='/')return route.fulfill({contentType:'text/html',body:
      '<script type="importmap">{"imports":{"three":"/three.module.js"}}</script>'});
    if(url.pathname==='/three.module.js')return route.fulfill({contentType:'text/javascript',body:three});
    return route.abort();
  });
  await page.goto(origin);
  const rasters=await page.evaluate(async({cases,size})=>{
    const THREE=await import('three');
    const canvas=document.createElement('canvas');
    const renderer=new THREE.WebGLRenderer({canvas,antialias:false,alpha:false,preserveDrawingBuffer:true});
    renderer.setPixelRatio(1);renderer.setSize(size,size,false);renderer.setClearColor(0x000000,1);
    const camera=new THREE.OrthographicCamera(-1,1,1,-1,.1,10);camera.position.z=1;
    const gl=renderer.getContext(),result=[];
    for(const item of cases){
      const geometry=new THREE.BufferGeometry();
      geometry.setAttribute('position',new THREE.BufferAttribute(new Float32Array([-1,-1,0,1,-1,0,-1,1,0,1,1,0]),3));
      if(item.colors.length)geometry.setAttribute('color',new THREE.BufferAttribute(new Float32Array(item.colors),item.colorSize));
      geometry.setIndex([0,1,2,2,1,3]);
      const material=new THREE.MeshBasicMaterial({color:item.albedoHex,vertexColors:item.vertexColors,transparent:!!item.transparent});
      let mesh=new THREE.Mesh(geometry,material);
      if(item.instanceColor){
        mesh=new THREE.InstancedMesh(geometry,material,1);
        mesh.setMatrixAt(0,new THREE.Matrix4());
        mesh.setColorAt(0,new THREE.Color().setRGB(...item.instanceColor,THREE.LinearSRGBColorSpace));
      }
      mesh.frustumCulled=false;
      const scene=new THREE.Scene();scene.add(mesh);
      renderer.render(scene,camera);
      const pixels=new Uint8Array(size*size*4);
      gl.readPixels(0,0,size,size,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
      const flipped=new Uint8Array(pixels.length);
      for(let row=0;row<size;row++)flipped.set(pixels.subarray((size-1-row)*size*4,(size-row)*size*4),row*size*4);
      result.push(btoa(String.fromCharCode(...flipped)));
      geometry.dispose();material.dispose();
    }
    renderer.dispose();
    return result;
  },{cases,size:24});
  if(digest(await readFile(join(source,threePath)))!==provenance.inputs[threePath])throw new Error('Source changed during capture: '+threePath);
  const inputs={};
  inputs['tools/cel_vertex_color_capture.mjs']=digest((await readFile(join(root,'tools/cel_vertex_color_capture.mjs'),'utf8')).replace(/\r\n?/g,'\n'));
  const fixtures=cases.map((item,index)=>({name:item.name,albedoHex:item.albedoHex,vertexColors:item.vertexColors,colorSize:item.colorSize,
    transparent:!!item.transparent,instanceColor:item.instanceColor??[],
    // Base64 float64 words keep colours away from Godot's decimal JSON parser.
    colors:Buffer.from(new Float64Array(item.colors).buffer).toString('base64'),size:24,rgba:rasters[index]}));
  await mkdir(join(root,'tests/fixtures'),{recursive:true});
  await writeFixtureJson(join(root,'tests/fixtures/cel_vertex_colors.json'),{formatVersion:1,
    source:{inputs,sourceInputs:{[threePath]:provenance.inputs[threePath]}},browser:browser.version(),cases:fixtures});
  console.log('CEL_VERTEX_COLOR_REFERENCES_PASS cases='+fixtures.length);
} finally {await browser.close();}
