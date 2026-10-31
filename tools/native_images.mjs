import {copyFile,mkdir,mkdtemp,readFile,readdir,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {deflateSync} from 'node:zlib';
import {dirname,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {publishSourceFile,writeSourceFile} from './fixture_json.mjs';
import {captureGenerator,verifyGenerator} from './source_provenance.mjs';

// The original serves campaign, loading and logo art under .png names, but most
// files hold JPEG bytes. Browsers sniff the content; Godot selects its importer
// by extension and rejects them. Real PNGs are copied verbatim. JPEGs are decoded
// in Chromium, the source runtime's decoder, and published as lossless PNG pixels
// under the authored path so every original reference is unchanged.
const sets=[
  {folder:'public/assets/story',target:'assets/story'},
  {folder:'public/assets/loading',target:'assets/loading'},
  {file:'public/assets/logo_flat.png',target:'assets/logo_flat.png'},
];
const manifestPath='data/native_images.json';
const format='native-images-v1';
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const pngSignature=Buffer.from([137,80,78,71,13,10,26,10]);
const jpegSignature=Buffer.from([255,216,255]);

const crcTable=Array.from({length:256},(_,n)=>{
  let c=n;
  for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;
  return c>>>0;
});
function crc32(bytes) {
  let c=0xffffffff;
  for(const value of bytes)c=crcTable[(c^value)&255]^(c>>>8);
  return (c^0xffffffff)>>>0;
}
function chunk(type,data) {
  const head=Buffer.alloc(8),tail=Buffer.alloc(4);
  head.writeUInt32BE(data.length,0);head.write(type,4,'latin1');
  tail.writeUInt32BE(crc32(Buffer.concat([head.subarray(4),data])),0);
  return Buffer.concat([head,data,tail]);
}

// Deterministic 8-bit RGB encoder: per-row minimum-sum filter selection, no
// colour/gamma chunks, so every PNG decoder returns exactly the decoded raster.
export function encodeRgbPng(width,height,rgb) {
  if(rgb.length!==width*height*3)throw new Error('Unexpected image raster size');
  const stride=width*3,filtered=Buffer.alloc((stride+1)*height),zero=Buffer.alloc(stride);
  const candidate=Buffer.alloc(stride);
  for(let y=0;y<height;y++) {
    const row=rgb.subarray(y*stride,(y+1)*stride),up=y?rgb.subarray((y-1)*stride,y*stride):zero;
    let best=-1,bestScore=Infinity,bestBytes=null;
    for(let type=0;type<5;type++) {
      let score=0;
      for(let x=0;x<stride;x++) {
        const a=x>=3?row[x-3]:0,b=up[x],c=x>=3?up[x-3]:0;
        let predictor=0;
        if(type===1)predictor=a;
        else if(type===2)predictor=b;
        else if(type===3)predictor=(a+b)>>1;
        else if(type===4) {
          const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);
          predictor=pa<=pb&&pa<=pc?a:pb<=pc?b:c;
        }
        const value=(row[x]-predictor)&255;
        candidate[x]=value;score+=value<128?value:256-value;
      }
      if(score<bestScore){best=type;bestScore=score;bestBytes=Buffer.from(candidate);}
    }
    const offset=y*(stride+1);
    filtered[offset]=best;bestBytes.copy(filtered,offset+1);
  }
  const header=Buffer.alloc(13);
  header.writeUInt32BE(width,0);header.writeUInt32BE(height,4);
  header[8]=8;header[9]=2;header[10]=0;header[11]=0;header[12]=0;
  return Buffer.concat([pngSignature,chunk('IHDR',header),
    chunk('IDAT',deflateSync(filtered,{level:9})),chunk('IEND',Buffer.alloc(0))]);
}

async function decode(page,bytes) {
  const result=await page.evaluate(async encoded=>{
    const raw=Uint8Array.from(atob(encoded),value=>value.charCodeAt(0));
    const url=URL.createObjectURL(new Blob([raw]));
    try {
      const image=new Image();image.src=url;await image.decode();
      const canvas=document.createElement('canvas');
      canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;
      const context=canvas.getContext('2d',{willReadFrequently:true,colorSpace:'srgb'});
      context.drawImage(image,0,0);
      const rgba=context.getImageData(0,0,canvas.width,canvas.height,{colorSpace:'srgb'}).data;
      let binary='';
      for(let i=0;i<rgba.length;i+=0x8000)binary+=String.fromCharCode(...rgba.subarray(i,i+0x8000));
      return {width:canvas.width,height:canvas.height,rgba:btoa(binary)};
    } finally {URL.revokeObjectURL(url);}
  },bytes.toString('base64'));
  const rgba=Buffer.from(result.rgba,'base64');
  if(!result.width||!result.height||rgba.length!==result.width*result.height*4)throw new Error('Incomplete original image decode');
  const rgb=Buffer.alloc(result.width*result.height*3);
  for(let i=0,j=0;i<rgba.length;i+=4,j+=3) {
    if(rgba[i+3]!==255)throw new Error('Original JPEG art is not opaque; RGB publication would discard alpha');
    rgb[j]=rgba[i];rgb[j+1]=rgba[i+1];rgb[j+2]=rgba[i+2];
  }
  return {width:result.width,height:result.height,rgb};
}

export async function launchImageDecoder(source,{playwrightModule,chrome}={}) {
  const runtime=await import(pathToFileURL(playwrightModule||join(source,'tools/pw.mjs')).href);
  const chromium=runtime.chromium||await runtime.chromiumOrNull();
  if(!chromium)throw new Error('Native image publication requires the source development Playwright runtime');
  const executablePath=chrome||(typeof runtime.chromePath==='function'?runtime.chromePath():runtime.chromePath);
  return chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
}

// Every original file published by this tool, as [source path, native path].
export async function nativeImageSources(source) {
  const files=[];
  for(const set of sets) {
    if(set.file){files.push([set.file,set.target]);continue;}
    const names=[];
    for(const entry of await readdir(join(source,set.folder),{withFileTypes:true})) {
      // Godot descriptors belong to the destination project, never to authored assets.
      if(entry.name.endsWith('.import'))continue;
      if(!entry.isFile())throw new Error('Original image is not an ordinary file: '+set.folder+'/'+entry.name);
      if(!entry.name.endsWith('.png'))throw new Error('Unsupported original image name: '+set.folder+'/'+entry.name);
      names.push(entry.name);
    }
    if(!names.length)throw new Error('Missing original images: '+set.folder);
    for(const name of names.sort((a,b)=>a.localeCompare(b,'en')))files.push([set.folder+'/'+name,set.target+'/'+name]);
  }
  return files;
}

// Write the native file of every original below `publicationRoot` and return
// the manifest; the caller writes it after every image is in place.
export async function encodeNativeImages(browser,source,publicationRoot,producer,onSource=()=>{}) {
  const page=await browser.newPage();
  const images={};
  for(const [name,target]of await nativeImageSources(source)) {
    const bytes=await readFile(join(source,name));
    await onSource(join(source,name));
    const entry={source:name,sourceSha256:digest(bytes)};
    let native;
    if(bytes.subarray(0,8).equals(pngSignature)) {
      native=bytes;entry.encoding='original-png';
    } else if(bytes.subarray(0,3).equals(jpegSignature)) {
      const decoded=await decode(page,bytes),again=await decode(page,bytes);
      if(!decoded.rgb.equals(again.rgb))throw new Error('Original image decode is not deterministic: '+name);
      native=encodeRgbPng(decoded.width,decoded.height,decoded.rgb);
      Object.assign(entry,{encoding:'chromium-jpeg-rgb-png',width:decoded.width,height:decoded.height,rasterSha256:digest(decoded.rgb)});
    } else throw new Error('Unsupported original image encoding: '+name);
    await mkdir(dirname(join(publicationRoot,target)),{recursive:true});
    await writeSourceFile(join(publicationRoot,target),native);
    entry.sha256=digest(native);
    images[target]=entry;
  }
  return {format,decoder:{browser:browser.version()},producer,images};
}

export async function writeNativeImageManifest(publicationRoot,manifest) {
  await writeSourceFile(join(publicationRoot,manifestPath),JSON.stringify(manifest,null,2)+'\n');
}

// A Git checkout may convert the captured CRLF text inputs to LF; binary inputs
// must match exactly. Any other difference is a different source snapshot.
async function sameInput(path,hash) {
  const bytes=await readFile(path);
  if(digest(bytes)===hash)return true;
  const text=bytes.toString('latin1');
  return !text.includes('\0')&&digest(Buffer.from(text.replace(/\r\n?/g,'\n').replace(/\n/g,'\r\n'),'latin1'))===hash;
}

// Focused publication of the native images for the published source snapshot.
// Every provenance input must still match, so new loading/logo inputs come from
// that same snapshot; each destination must be absent, the verbatim original or
// this tool's previous output.
export async function publishNativeImages(root,source,options={}) {
  const provenanceBytes=await readFile(join(root,'data/provenance.json'));
  const inputs=JSON.parse(provenanceBytes).inputs;
  let previous=null;
  try {previous=JSON.parse(await readFile(join(root,manifestPath),'utf8'));}
  catch(error){if(error.code!=='ENOENT')throw error;}
  if(previous&&previous.format!==format)throw new Error('Unknown native image manifest format');
  const files=await nativeImageSources(source);
  const listed=new Set(files.map(([name])=>name));
  for(const name of Object.keys(inputs))
    if(sets.some(set=>set.folder?name.startsWith(set.folder+'/'):name===set.file)&&!listed.has(name))
      throw new Error('Published original image is missing from the source: '+name);
  const verify=async()=>{
    for(const [name,hash]of Object.entries(inputs))
      if(!await sameInput(join(source,name),hash))throw new Error('Source differs from the published provenance snapshot: '+name);
    for(const [name,target]of files) {
      let current=null;
      try {current=digest(await readFile(join(root,target)));}
      catch(error){if(error.code!=='ENOENT')throw error;}
      const original=digest(await readFile(join(source,name)));
      if(current!==null&&current!==original&&current!==previous?.images?.[target]?.sha256)
        throw new Error('Native image destination is neither the original nor its published encoding: '+target);
    }
  };
  await verify();
  const producer=await captureGenerator(root);
  const browser=await launchImageDecoder(source,options);
  let manifest;
  try {
    // Encode into a capture directory first so an interrupted decode leaves the
    // published art untouched.
    const stage=await mkdtemp(join(root,'.image-capture-'));
    try {
      manifest=await encodeNativeImages(browser,source,stage,producer);
      await verify();
      await verifyGenerator(root,producer);
      if(!(await readFile(join(root,'data/provenance.json'))).equals(provenanceBytes))
        throw new Error('Source publication changed during native image encoding');
      for(const target of Object.keys(manifest.images)) {
        await mkdir(dirname(join(root,target)),{recursive:true});
        const temporary=join(root,target)+'.partial-image-'+process.pid+'-'+Date.now();
        await copyFile(join(stage,target),temporary);
        if(digest(await readFile(temporary))!==manifest.images[target].sha256)throw new Error('Image capture changed during publication: '+target);
        await publishSourceFile(temporary,join(root,target));
      }
    } finally {await rm(stage,{recursive:true,force:true});}
  } finally {await browser.close();}
  await writeNativeImageManifest(root,manifest);
  const counts={};
  for(const entry of Object.values(manifest.images))counts[entry.encoding]=(counts[entry.encoding]||0)+1;
  console.log('NATIVE_IMAGES_PUBLISHED '+JSON.stringify({images:Object.keys(manifest.images).length,encodings:counts,decoder:manifest.decoder.browser}));
}
