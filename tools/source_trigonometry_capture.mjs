import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';

// Captures Chromium's Math.sin/Math.cos bits for scripts/source_trigonometry.gd.
const root=fileURLToPath(new URL('..',import.meta.url));
const generator='tools/source_trigonometry_capture.mjs';
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const generatorHash=digest((await readFile(join(root,generator),'utf8')).replace(/\r\n?/g,'\n'));
const {chromium}=await import(pathToFileURL(process.env.PW_MODULE||'playwright').href);

const word=new DataView(new ArrayBuffer(8));
const bits=value=>{word.setFloat64(0,value,true);return word.getBigUint64(0,true).toString(16).padStart(16,'0');};
const number=text=>{word.setBigUint64(0,BigInt('0x'+text),true);return word.getFloat64(0,true);};
const step=(value,delta)=>{
  word.setFloat64(0,value,true);
  word.setBigUint64(0,word.getBigUint64(0,true)+BigInt(delta),true);
  return word.getFloat64(0,true);
};
const inputs=[0,-0,5e-324,-5e-324,2.2250738585072009e-308,2.2250738585072014e-308,1e-300,1e-160,
  2**-27,2**-26,2**-25,1.4901161193847656e-8,1e-8,0.5,1,-1,2,3,10,100,
  1e22,2**53,2**64,2**512,2**1023,1.7976931348623157e308,-1.7976931348623157e308,
  // The double closest to a multiple of pi/2 (Kahan/McDonald): deepest cancellation.
  6381956970095103*2**797,5.319372648326541e255,Infinity,-Infinity,NaN];
// Reduction boundaries: doubles nearest k*pi/4 and their neighbours.
for(const k of [1,2,3,4,5,6,7,8,16,100,1000,12345,1e5,1e6,1e8,2**30,1e12,2**52]) {
  const centre=k*Math.PI/4;
  for(let delta=-2;delta<=2;delta++)inputs.push(step(centre,delta),-step(centre,delta));
}
// Lock glow and PiP yaw families: performance.now()/1000*6 and half angles.
for(const seconds of [0.016,1,59.5,3600.25,86400.125,1e6+0.5,1e9/7,1e10+0.125])inputs.push(seconds*6,seconds*3);
// A fixed generator keeps the corpus reproducible; it is unrelated to any game stream.
let state=0x9e3779b97f4a7c15n;
const next=()=>{
  state^=(state<<13n)&0xffffffffffffffffn;state^=state>>7n;state^=(state<<17n)&0xffffffffffffffffn;
  return Number(state&0xfffffffffffffn)/2**52;
};
for(let index=0;index<6144;index++) {
  const family=index%4;
  // Uniform near the origin, at game-clock magnitudes, and log-uniform over the full range.
  const value=family===0?(next()*2-1)*8:family===1?(next()*2-1)*1e5:family===2?(next()*2-1)*1e11
    :(next()<.5?-1:1)*(1+next())*2**Math.floor(next()*1100-60);
  inputs.push(index%8<4?value:Math.fround(value));
}
const words=inputs.map(bits);
const browser=await chromium.launch({headless:true,executablePath:process.env.PW_CHROME});
const page=await browser.newPage();
const results=await page.evaluate(values=>{
  const view=new DataView(new ArrayBuffer(8));
  const read=text=>{view.setBigUint64(0,BigInt('0x'+text),true);return view.getFloat64(0,true);};
  const write=value=>{view.setFloat64(0,value,true);return view.getBigUint64(0,true).toString(16).padStart(16,'0');};
  return values.map(text=>[write(Math.sin(read(text))),write(Math.cos(read(text)))]);
},words);
const version=browser.version();
await browser.close();
let nodeDifferences=0;
const cases=words.map((text,index)=>{
  const value=number(text);
  if(bits(Math.sin(value))!==results[index][0]||bits(Math.cos(value))!==results[index][1])nodeDifferences++;
  return [text,results[index][0],results[index][1]];
});
if(number(results[0][1])!==1)throw new Error('Original trigonometry capture lost its zero case');
if(digest((await readFile(join(root,generator),'utf8')).replace(/\r\n?/g,'\n'))!==generatorHash)
  throw new Error('Trigonometry generator changed during capture');
await writeFixtureJson(join(root,'tests/fixtures/source_trigonometry.json'),{formatVersion:1,
  source:{inputs:{[generator]:generatorHash},browser:version,nodeDifferences},cases});
console.log('SOURCE_TRIGONOMETRY_REFERENCES_PASS cases='+cases.length+' browser='+version+' nodeDifferences='+nodeDifferences);
