import {copyFile,mkdir,mkdtemp,readFile,readdir,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {deflateSync} from 'node:zlib';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {publishSourceFile,writeSourceFile} from './fixture_json.mjs';
import {captureGenerator,verifyGenerator} from './source_provenance.mjs';

// The original serves campaign art as JPEG bytes under .png names. Browsers
// sniff the content; Godot selects its importer by extension and rejects them.
// Decode each original in Chromium, the source runtime's decoder, and publish
// lossless PNG pixels under the authored path so campaign metadata is unchanged.
const folder='public/assets/story';
const manifestPath='data/story_images.json';
const format='story-native-png-v1';
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');

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
  if(rgb.length!==width*height*3)throw new Error('Unexpected story raster size');
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
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),
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
  if(!result.width||!result.height||rgba.length!==result.width*result.height*4)throw new Error('Incomplete original story decode');
  const rgb=Buffer.alloc(result.width*result.height*3);
  for(let i=0,j=0;i<rgba.length;i+=4,j+=3) {
    if(rgba[i+3]!==255)throw new Error('Original story art is not opaque; RGB publication would discard alpha');
    rgb[j]=rgba[i];rgb[j+1]=rgba[i+1];rgb[j+2]=rgba[i+2];
  }
  return {width:result.width,height:result.height,rgb};
}

export async function launchStoryDecoder(source,{playwrightModule,chrome}={}) {
  const runtime=await import(pathToFileURL(playwrightModule||join(source,'tools/pw.mjs')).href);
  const chromium=runtime.chromium||await runtime.chromiumOrNull();
  if(!chromium)throw new Error('Native story art requires the source development Playwright runtime');
  const executablePath=chrome||(typeof runtime.chromePath==='function'?runtime.chromePath():runtime.chromePath);
  return chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
}

// Decode the original files and write their native PNGs below `publicationRoot`.
// Returns the manifest; the caller writes it after every image is in place.
export async function encodeStoryImages(browser,source,publicationRoot,producer) {
  const names=(await readdir(join(source,folder),{withFileTypes:true}))
    .filter(entry=>!entry.name.endsWith('.import')).map(entry=>{
      if(!entry.isFile())throw new Error('Original story art is not an ordinary file: '+entry.name);
      return entry.name;
    }).sort((a,b)=>a.localeCompare(b,'en'));
  if(!names.length)throw new Error('Missing original story art');
  const page=await browser.newPage();
  const images={};
  for(const name of names) {
    if(!name.endsWith('.png'))throw new Error('Unsupported original story art name: '+name);
    const bytes=await readFile(join(source,folder,name));
    const decoded=await decode(page,bytes);
    const again=await decode(page,bytes);
    if(!decoded.rgb.equals(again.rgb))throw new Error('Original story decode is not deterministic: '+name);
    const png=encodeRgbPng(decoded.width,decoded.height,decoded.rgb);
    await writeSourceFile(join(publicationRoot,'assets/story',name),png);
    images['assets/story/'+name]={source:folder+'/'+name,sourceSha256:digest(bytes),
      sourceSignature:bytes.subarray(0,4).toString('hex'),width:decoded.width,height:decoded.height,
      rasterSha256:digest(decoded.rgb),sha256:digest(png)};
  }
  return {format,decoder:{browser:browser.version()},producer,images};
}

export async function writeStoryManifest(publicationRoot,manifest) {
  await writeSourceFile(join(publicationRoot,manifestPath),JSON.stringify(manifest,null,2)+'\n');
}

// Focused publication: re-encode only the campaign art of the published source
// snapshot. Every original must hash to its published provenance input, and every
// destination must be the verbatim original or this tool's previous output.
export async function publishStoryImages(root,source,options={}) {
  const provenanceBytes=await readFile(join(root,'data/provenance.json'));
  const inputs=JSON.parse(provenanceBytes).inputs;
  const expected=Object.keys(inputs).filter(name=>name.startsWith(folder+'/')).sort((a,b)=>a.localeCompare(b,'en'));
  let previous=null;
  try {previous=JSON.parse(await readFile(join(root,manifestPath),'utf8'));}
  catch(error){if(error.code!=='ENOENT')throw error;}
  if(previous&&previous.format!==format)throw new Error('Unknown native story manifest format');
  const listed=(await readdir(join(source,folder))).filter(name=>!name.endsWith('.import')).map(name=>folder+'/'+name).sort((a,b)=>a.localeCompare(b,'en'));
  if(listed.join('\n')!==expected.join('\n'))throw new Error('Original story art differs from published provenance; run the complete source importer first');
  const verify=async()=>{
    for(const name of expected) {
      if(digest(await readFile(join(source,name)))!==inputs[name])throw new Error('Original story art is stale: '+name);
      const target='assets/story/'+name.slice(folder.length+1),current=digest(await readFile(join(root,target)));
      if(current!==inputs[name]&&current!==previous?.images?.[target]?.sha256)
        throw new Error('Native story destination is neither the original nor its published encoding: '+target);
    }
  };
  await verify();
  const producer=await captureGenerator(root);
  const browser=await launchStoryDecoder(source,options);
  let manifest;
  try {
    // Encode into a capture directory first so an interrupted decode leaves the
    // published art untouched.
    const stage=await mkdtemp(join(root,'.story-capture-'));
    try {
      await mkdir(join(stage,'assets/story'),{recursive:true});
      manifest=await encodeStoryImages(browser,source,stage,producer);
      await verify();
      await verifyGenerator(root,producer);
      if(!(await readFile(join(root,'data/provenance.json'))).equals(provenanceBytes))
        throw new Error('Source publication changed during story encoding');
      for(const target of Object.keys(manifest.images)) {
        const temporary=join(root,target)+'.partial-story-'+process.pid+'-'+Date.now();
        await copyFile(join(stage,target),temporary);
        if(digest(await readFile(temporary))!==manifest.images[target].sha256)throw new Error('Story capture changed during publication: '+target);
        await publishSourceFile(temporary,join(root,target));
      }
    } finally {await rm(stage,{recursive:true,force:true});}
  } finally {await browser.close();}
  await writeStoryManifest(root,manifest);
  console.log('STORY_IMAGES_PUBLISHED '+JSON.stringify({images:Object.keys(manifest.images).length,decoder:manifest.decoder.browser}));
}
