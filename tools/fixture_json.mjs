import {randomUUID} from 'node:crypto';
import {open,rename,rm} from 'node:fs/promises';
import {Readable} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import {setTimeout as delay} from 'node:timers/promises';

async function publishFile(temporary,path) {
  for(let attempt=0;;attempt++) {
    try {await rename(temporary,path);return;}
    catch(error) {
      if(!['EPERM','EBUSY','EACCES'].includes(error.code)||attempt>=59)throw error;
      if(attempt%20===0)console.warn('SOURCE_JSON_PUBLISH_RETRY '+path);
      await delay(500);
    }
  }
}
export {publishFile as publishSourceFile};

// Each invocation owns a unique staging path, so a fixed clock cannot make two
// writers share one and a rejected exclusive open never removes a foreign file.
function stagingPath(path) {
  return path+'.partial-'+process.pid+'-'+Date.now()+'-'+randomUUID();
}

export async function writeSourceFile(path,data) {
  if(typeof path!=='string')throw new TypeError('Expected a source output path');
  const temporary=stagingPath(path);
  const handle=await open(temporary,'wx');
  let encoded=false;
  try {
    try {await handle.writeFile(data);}
    finally {await handle.close();}
    encoded=true;
    await publishFile(temporary,path);
  } catch(error) {
    if(!encoded)await rm(temporary,{force:true});
    else error.message+='; complete encoded capture retained at '+temporary;
    throw error;
  }
}

function encodeAtKey(key,value) {
  // Preserve native toJSON(key) semantics, including array indices.
  const text=JSON.stringify({[key]:value});
  return text==='{}'?undefined:text.slice(JSON.stringify(key).length+2,-1);
}

function* encodedChunks(key,value) {
  try {
    const encoded=encodeAtKey(key,value);
    if(encoded!==undefined)yield encoded;
    return;
  } catch(error) {
    if(!(error instanceof RangeError)||error.message!=='Invalid string length')throw error;
    if(value===null||typeof value!=='object'||'toJSON' in value)throw error;
  }
  // A single mesh can exceed V8's string limit even when rows are streamed.
  // Split only that oversized plain container; native JSON still encodes leaves.
  if(Array.isArray(value)) {
    yield '[';
    const length=value.length;
    for(let index=0;index<length;index++) {
      if(index)yield ',';
      const parts=encodedChunks(String(index),value[index]),first=parts.next();
      yield first.done?'null':first.value;
      yield*parts;
    }
    yield ']';
    return;
  }
  if(Object.getPrototypeOf(value)!==Object.prototype&&Object.getPrototypeOf(value)!==null)
    throw new TypeError('Oversized source JSON container must be plain');
  yield '{';
  let separator='';
  for(const childKey of Object.keys(value)) {
    const parts=encodedChunks(childKey,value[childKey]),first=parts.next();
    if(first.done)continue;
    yield separator+JSON.stringify(childKey)+':'+first.value;
    yield*parts;
    separator=',';
  }
  yield '}';
}

function* fixtureChunks(fixtures) {
  yield '{';
  let separator='';
  for(const key of Object.keys(fixtures)) {
    try {
      const value=fixtures[key];
      if(Array.isArray(value)&&!('toJSON' in value)) {
        yield separator+JSON.stringify(key)+':[';
        const length=value.length;
        for(let index=0;index<length;index++) {
          if(index)yield ',';
          const parts=encodedChunks(String(index),value[index]),first=parts.next();
          yield first.done?'null':first.value;
          yield*parts;
        }
        yield ']';
      } else {
        const parts=encodedChunks(key,value),first=parts.next();
        if(first.done)continue;
        yield separator+JSON.stringify(key)+':'+first.value;
        yield*parts;
      }
      separator=',';
    } catch(error) {
      throw new Error('Cannot encode source fixture section '+key+': '+String(error),{cause:error});
    }
  }
  yield '}';
}

// Fixture sections are plain records/arrays. Stream array rows so the complete
// corpus need not fit in V8's single-string limit; native JSON encodes values.
export async function writeFixtureJson(path,fixtures) {
  if(typeof path!=='string'||fixtures===null||typeof fixtures!=='object'||Array.isArray(fixtures)
    ||typeof fixtures.toJSON==='function')throw new TypeError('Expected a fixture file path and plain fixture sections');
  const temporary=stagingPath(path);
  const handle=await open(temporary,'wx');
  let encoded=false;
  try {
    await pipeline(Readable.from(fixtureChunks(fixtures),{objectMode:false}),handle.createWriteStream());
    encoded=true;
    await publishFile(temporary,path);
  } catch(error) {
    await handle.close().catch(()=>{});
    if(!encoded)await rm(temporary,{force:true});
    else error.message+='; complete encoded capture retained at '+temporary;
    throw error;
  }
}
