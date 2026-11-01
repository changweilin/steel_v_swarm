import {createReadStream,createWriteStream} from 'node:fs';
import {mkdir,mkdtemp,readFile,rmdir,stat,unlink} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {once} from 'node:events';
import {finished} from 'node:stream/promises';
import {dirname,join} from 'node:path';
import {writeSourceFile,publishSourceFile,writeFixtureJson} from './fixture_json.mjs';

// Scan canonical importer JSON without decoding or rounding a single number.
// Values are streamed verbatim; nested frame sequences remain indivisible.
async function scanValues(path,hooks,highWaterMark=256*1024) {
  let phase='root',kind='',key='',keyBytes=[],escape=false,string=false,depth=0,index=0,start=-1;
  const source=createHash('sha256');
  const whitespace=value=>value===32||value===9||value===10||value===13;
  for await(const bytes of createReadStream(path,{highWaterMark})) {
    source.update(bytes);start=phase==='value'?0:-1;
    for(let i=0;i<bytes.length;i++) {
      const value=bytes[i];
      if(phase==='value') {
        if(string) {
          if(escape)escape=false;
          else if(value===92)escape=true;
          else if(value===34)string=false;
        } else if(depth===0&&(value===44||value===(kind==='object'?125:93))) {
          await hooks.write(bytes.subarray(start,i));await hooks.end();index++;
          start=-1;phase=value===44?'entry':'done';
        } else if(value===34)string=true;
        else if(value===123||value===91)depth++;
        else if(value===125||value===93)depth--;
        if(depth<0)throw new Error('Unbalanced canonical fixture value');
        continue;
      }
      if(whitespace(value))continue;
      if(phase==='root') {
        if(value!==123&&value!==91)throw new Error('Expected a fixture object or array');
        kind=value===123?'object':'array';phase='entry';continue;
      }
      if(phase==='done')throw new Error('Trailing data after canonical fixture document');
      if(phase==='key') {
        keyBytes.push(value);
        if(escape)escape=false;
        else if(value===92)escape=true;
        else if(value===34){key=JSON.parse(Buffer.from(keyBytes).toString('utf8'));phase='colon';}
        continue;
      }
      if(phase==='colon') {
        if(value!==58)throw new Error('Missing fixture property colon');
        phase='begin';continue;
      }
      if(phase==='entry') {
        if(value===(kind==='object'?125:93)){phase='done';continue;}
        if(kind==='object') {
          if(value!==34)throw new Error('Invalid fixture section key');
          keyBytes=[34];escape=false;phase='key';continue;
        }
        key=String(index);phase='begin';
      }
      if(phase==='begin') {
        await hooks.begin(key,value);phase='value';start=i;
        string=value===34;escape=false;depth=value===123||value===91?1:0;
      }
    }
    if(phase==='value')await hooks.write(bytes.subarray(start));
  }
  if(phase!=='done')throw new Error('Incomplete canonical fixture document');
  return {kind,count:index,sha256:source.digest('hex')};
}

function writer(path) {
  const stream=createWriteStream(path,{flags:'wx'}),hash=createHash('sha256');
  let bytes=0;
  return {async write(value){hash.update(value);bytes+=value.length;if(!stream.write(value))await once(stream,'drain');},
    async end(){stream.end();await finished(stream);return {bytes,sha256:hash.digest('hex')};}};
}

async function hashPartBody(hash,path,first=0,last=0) {
  const size=(await stat(path)).size;
  if(size>first+last)for await(const bytes of createReadStream(path,{start:first,end:size-last-1}))hash.update(bytes);
}

async function numericTapes(registry,directory) {
  // Godot's decimal JSON parser can lose one ULP at half-rounding boundaries.
  // Keep the emitted JSON untouched and accompany its numeric leaves with the
  // exact IEEE-754 values produced by the source JavaScript JSON parser.
  const visit=(value,number)=>{
    if(typeof value==='number')number(value);
    else if(Array.isArray(value))for(const item of value)visit(item,number);
    else if(value&&typeof value==='object')for(const item of Object.values(value))visit(item,number);
  };
  for(const section of Object.values(registry.sections))for(const part of section.parts) {
    const bytes=await readFile(join(directory,part.path));
    if(createHash('sha256').update(bytes).digest('hex')!==part.sha256)throw new Error('Original fixture partition changed before numeric capture: '+part.path);
    const value=JSON.parse(bytes);let count=0;visit(value,()=>count++);
    const numbers=Buffer.allocUnsafe(count*8);let offset=0;
    visit(value,number=>{numbers.writeDoubleLE(number,offset);offset+=8;});
    const sha256=createHash('sha256').update(numbers).digest('hex'),name='fixture_parts/numbers-'+sha256+'.f64';
    await writeSourceFile(join(directory,name),numbers);
    part.numbers={path:name,sha256,count,bytes:numbers.length};
  }
  registry.numericEncoding='f64-le';
}

export async function attachNumericTapes(path) {
  const previous=await readFile(path),registry=JSON.parse(previous);
  if(registry.fixtureFormat!=='source-sections-v1')throw new Error('Expected partitioned source fixtures');
  await numericTapes(registry,dirname(path));
  if(!(await readFile(path)).equals(previous))throw new Error('Source registry changed during numeric capture');
  await writeSourceFile(path,JSON.stringify(registry));
  console.log('SOURCE_FIXTURE_NUMBERS '+JSON.stringify({sections:registry.sectionOrder.length,encoding:registry.numericEncoding}));
}

export async function updateFixtureSections(path,values,{expectedRegistry,projectRoot,producer}={}) {
  const previous=await readFile(path),registry=JSON.parse(previous);
  if(expectedRegistry&&!previous.equals(expectedRegistry))throw new Error('Source fixture publication changed before section update');
  if(registry.fixtureFormat!=='source-sections-v1')throw new Error('Expected a partitioned source fixture registry');
  const temporary=join(dirname(path),'.fixture-update-'+process.pid+'-'+Date.now()+'.tmp');
  const index=temporary+'.index.tmp';
  await writeFixtureJson(temporary,values);
  const replacement=await partitionFixtures(temporary,index,{producer});
  if(replacement.producers)registry.producers={...registry.producers,...replacement.producers};
  for(const key of replacement.sectionOrder) {
    if(!registry.sections[key])registry.sectionOrder.push(key);
    registry.sections[key]=replacement.sections[key];
  }
  const hash=createHash('sha256');hash.update('{');
  for(const [position,key]of registry.sectionOrder.entries()) {
    if(position)hash.update(',');hash.update(JSON.stringify(key)+':');
    const section=registry.sections[key];
    if(section.kind==='array')hash.update('[');
    for(const [partIndex,part]of section.parts.entries()) {
      if(!part.path.startsWith('fixture_parts/')||part.path.includes('..')||part.path.includes('\\'))throw new Error('Invalid source fixture partition path');
      if(partIndex)hash.update(',');
      await hashPartBody(hash,join(dirname(path),part.path),section.kind==='array'?1:0,section.kind==='array'?1:0);
    }
    if(section.kind==='array')hash.update(']');
  }
  hash.update('}');registry.sourceSha256=hash.digest('hex');
  await numericTapes(registry,dirname(path));
  if(projectRoot)registry.consumers=await fixtureConsumers(projectRoot,new Set(registry.sectionOrder));
  if(!(await readFile(path)).equals(previous))throw new Error('Source fixture publication changed during section update');
  await writeSourceFile(path,JSON.stringify(registry));
  await unlink(temporary);await unlink(index);
}

export async function fixtureConsumers(projectRoot,keys) {
  const {readdir}=await import('node:fs/promises');
  const files=['run.gd',...(await readdir(join(projectRoot,'tests'))).filter(name=>name.endsWith('_suite.gd'))];
  const records=new Map(),classes=new Map();
  for(const file of files) {
    const path='tests/'+file,bytes=await readFile(join(projectRoot,path)),text=bytes.toString('utf8');
    records.set(path,{text,sha256:createHash('sha256').update(bytes).digest('hex')});
    const name=/^class_name (\w+)/m.exec(text)?.[1];if(name)classes.set(name,path);
  }
  const direct=new Map(),dependencies=new Map();
  for(const [path,{text}]of records) {
    const used=new Set();
    for(const match of text.matchAll(/\bfixtures\.([A-Za-z]\w*)/g))if(keys.has(match[1]))used.add(match[1]);
    // A section read part by part must not be preloaded whole against the encoded-byte budget.
    const preloaded=text.split('\n').filter(line=>!/\bContent\.(read_fixture_part|fixture_registry)\b/.test(line)).join('\n');
    for(const match of preloaded.matchAll(/"([A-Za-z]\w*)"/g))if(keys.has(match[1]))used.add(match[1]);
    direct.set(path,used);
    const deps=new Set([...text.matchAll(/res:\/\/(tests\/[A-Za-z0-9_]+\.gd)/g)].map(match=>match[1]).filter(name=>records.has(name)));
    for(const [name,target]of classes)if(target!==path&&new RegExp('\\b'+name+'\\b').test(text))deps.add(target);
    dependencies.set(path,deps);
  }
  const consumers={};
  for(const [path,record]of records) {
    const visited=new Set(),all=new Set();
    const visit=name=>{if(visited.has(name))return;visited.add(name);for(const key of direct.get(name))all.add(key);for(const child of dependencies.get(name))visit(child);};
    visit(path);
    consumers[path]={sha256:record.sha256,direct:[...keys].filter(key=>direct.get(path).has(key)),all:[...keys].filter(key=>all.has(key))};
  }
  return consumers;
}

export async function refreshFixtureConsumers(path,projectRoot) {
  const previous=await readFile(path),registry=JSON.parse(previous);
  if(registry.fixtureFormat!=='source-sections-v1')throw new Error('Expected partitioned source fixtures');
  registry.consumers=await fixtureConsumers(projectRoot,new Set(registry.sectionOrder));
  if(!(await readFile(path)).equals(previous))throw new Error('Source fixture publication changed during consumer registration');
  await writeSourceFile(path,JSON.stringify(registry));
  console.log('SOURCE_FIXTURE_CONSUMERS '+Object.keys(registry.consumers).length);
}

export async function partitionFixtures(input,output,{partBytes=8*1024*1024,highWaterMark,projectRoot,expectedSha256,producer}={}) {
  if(!Number.isSafeInteger(partBytes)||partBytes<1)throw new Error('Invalid fixture part byte budget');
  const directory=dirname(output),partsDirectory=join(directory,'fixture_parts');
  const sourceBytes=(await stat(input)).size;
  const producerKey=producer?createHash('sha256').update(JSON.stringify(producer)).digest('hex'):null;
  await mkdir(partsDirectory,{recursive:true});
  const work=await mkdtemp(join(directory,'.fixture-work-'));
  const records=[],seen=new Set();let raw;
  const scanned=await scanValues(input,{
    async begin(key,first){
      if(!/^[A-Za-z][A-Za-z0-9_]*$/.test(key)||seen.has(key))throw new Error('Invalid or duplicate fixture section: '+key);
      seen.add(key);raw={key,kind:first===91?'array':'value',path:join(work,key+'.json')};
      raw.sink=writer(raw.path);records.push(raw);
    },async write(bytes){await raw.sink.write(bytes);},async end(){Object.assign(raw,await raw.sink.end());delete raw.sink;}
  },highWaterMark);
  if(scanned.kind!=='object')throw new Error('Expected complete captured fixture sections');
  if(expectedSha256&&scanned.sha256!==expectedSha256)throw new Error('Source capture changed before fixture publication');
  const sections={};
  for(const record of records) {
    const parts=[];let sink,temporary,partCount=0,partSize=0,total=0;
    const beginPart=async()=>{temporary=join(work,record.key+'-part-'+parts.length+'.json');sink=writer(temporary);await sink.write(Buffer.from('['));partCount=0;partSize=1;};
    const closePart=async()=>{
      await sink.write(Buffer.from(']'));const encoded=await sink.end();
      const name=record.key+'-'+parts.length+'-'+encoded.sha256+'.json';
      await publishSourceFile(temporary,join(partsDirectory,name));
      parts.push({...encoded,path:'fixture_parts/'+name,count:partCount});sink=null;
    };
    if(record.kind==='array') {
      await scanValues(record.path,{
        async begin(){if(sink&&partSize>=partBytes)await closePart();if(!sink)await beginPart();if(partCount){await sink.write(Buffer.from(','));partSize++;}},
        async write(bytes){await sink.write(bytes);partSize+=bytes.length;},async end(){partCount++;total++;}
      },highWaterMark);
      if(!sink)await beginPart();await closePart();
      const hash=createHash('sha256');hash.update('[');
      for(const [index,part]of parts.entries()){if(index)hash.update(',');await hashPartBody(hash,join(directory,part.path),1,1);}hash.update(']');
      if(hash.digest('hex')!==record.sha256)throw new Error('Fixture array partition changed source bytes: '+record.key);
    } else {
      const name=record.key+'-0-'+record.sha256+'.json';
      await publishSourceFile(record.path,join(partsDirectory,name));
      parts.push({path:'fixture_parts/'+name,bytes:record.bytes,sha256:record.sha256});
    }
    sections[record.key]={kind:record.kind,sourceSha256:record.sha256,bytes:record.bytes,...(record.kind==='array'?{count:total}:{}),parts,...(producerKey?{producer:producerKey}: {})};
  }
  // Reconstruct the complete canonical root hash from the partitioned values.
  const reconstructed=createHash('sha256');reconstructed.update('{');
  for(const [index,record]of records.entries()) {
    if(index)reconstructed.update(',');reconstructed.update(JSON.stringify(record.key)+':');
    const section=sections[record.key];
    if(section.kind==='array') {
      reconstructed.update('[');
      for(const [partIndex,part]of section.parts.entries()){if(partIndex)reconstructed.update(',');await hashPartBody(reconstructed,join(directory,part.path),1,1);}reconstructed.update(']');
    } else await hashPartBody(reconstructed,join(directory,section.parts[0].path));
  }
  reconstructed.update('}');
  if(reconstructed.digest('hex')!==scanned.sha256)throw new Error('Partitioned fixture root differs from canonical source capture');
  const manifest={fixtureFormat:'source-sections-v1',sourceSha256:scanned.sha256,sectionOrder:records.map(record=>record.key),sections};
  if(producerKey)manifest.producers={[producerKey]:producer};
  if(projectRoot)manifest.consumers=await fixtureConsumers(projectRoot,new Set(manifest.sectionOrder));
  await numericTapes(manifest,directory);
  await writeSourceFile(output,JSON.stringify(manifest));
  for(const record of records)if(record.kind==='array')await unlink(record.path);
  await rmdir(work);
  const result={sections:records.length,parts:Object.values(sections).reduce((sum,section)=>sum+section.parts.length,0),
    largestPart:Math.max(0,...Object.values(sections).flatMap(section=>section.parts.map(part=>part.bytes))),sourceBytes};
  console.log('SOURCE_FIXTURE_SECTIONS '+JSON.stringify(result));
  return manifest;
}
