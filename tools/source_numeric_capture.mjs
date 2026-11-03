import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';

const root=fileURLToPath(new URL('..',import.meta.url));
const generator='tools/source_numeric_capture.mjs';
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const generatorHash=digest((await readFile(join(root,generator),'utf8')).replace(/\r\n?/g,'\n'));
const {chromium}=await import(pathToFileURL(process.env.PW_MODULE||'playwright').href);

const word=new DataView(new ArrayBuffer(8));
const bits=value=>{word.setFloat64(0,value,true);return word.getBigUint64(0,true).toString(16).padStart(16,'0');};
const number=text=>{word.setBigUint64(0,BigInt('0x'+text),true);return word.getFloat64(0,true);};
const special=[0,-0,5e-324,-5e-324,2.2250738585072009e-308,2.2250738585072014e-308,1e-160,1e-200,1e154,1.7976931348623157e308,
  -1.7976931348623157e308,Infinity,-Infinity,NaN,1,-1,12,0.0010000000475,0.10029599815607071,1.200152039527893];
const pairs=[];
for(const x of special)for(const y of special)pairs.push([x,y]);
// A fixed generator keeps the corpus reproducible; it is unrelated to any game stream.
let state=0x9e3779b97f4a7c15n;
const next=()=>{
  state^=(state<<13n)&0xffffffffffffffffn;state^=state>>7n;state^=(state<<17n)&0xffffffffffffffffn;
  return Number(state&0xfffffffffffffn)/2**52;
};
for(let index=0;index<4096;index++) {
  const scale=index%4===0?1:index%4===1?1024:index%4===2?1e-3:1e150;
  const narrow=index%8<4;
  const x=(next()*2-1)*scale,y=(next()*2-1)*scale;
  pairs.push(narrow?[Math.fround(x),Math.fround(y)]:[x,y]);
}
const inputs=pairs.flat().map(bits);
const browser=await chromium.launch({headless:true,executablePath:process.env.PW_CHROME});
const page=await browser.newPage();
const results=await page.evaluate(values=>{
  const view=new DataView(new ArrayBuffer(8));
  const read=text=>{view.setBigUint64(0,BigInt('0x'+text),true);return view.getFloat64(0,true);};
  const write=value=>{view.setFloat64(0,value,true);return view.getBigUint64(0,true).toString(16).padStart(16,'0');};
  const output=[];
  for(let index=0;index<values.length;index+=2)output.push(write(Math.hypot(read(values[index]),read(values[index+1]))));
  return output;
},inputs);
const version=browser.version();
await browser.close();
let nodeDifferences=0;
const cases=pairs.map(([x,y],index)=>{
  if(bits(Math.hypot(x,y))!==results[index])nodeDifferences++;
  return [inputs[index*2],inputs[index*2+1],results[index]];
});
if(number(results[0])!==0)throw new Error('Original hypot capture lost its zero case');
if(digest((await readFile(join(root,generator),'utf8')).replace(/\r\n?/g,'\n'))!==generatorHash)
  throw new Error('Numeric generator changed during capture');
await writeFixtureJson(join(root,'tests/fixtures/source_hypot.json'),{formatVersion:1,
  source:{inputs:{[generator]:generatorHash},browser:version,nodeDifferences},cases});
console.log('SOURCE_HYPOT_REFERENCES_PASS cases='+cases.length+' browser='+version+' nodeDifferences='+nodeDifferences);
