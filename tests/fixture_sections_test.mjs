import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdir,mkdtemp,readFile,writeFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import test from 'node:test';
import {fixtureConsumers,partitionFixtures,updateFixtureSections} from '../tools/fixture_sections.mjs';

test('a section read part by part is not a whole-section consumer dependency',async()=>{
  await mkdir('artifacts/fixture-section-tests',{recursive:true});
  const root=await mkdtemp(resolve('artifacts/fixture-section-tests/case-'));
  await mkdir(join(root,'tests'));
  await writeFile(join(root,'tests/run.gd'),'func run():\n\tvar rows: Array = fixtures.whole\n\tvar named: Variant = fixtures.get("quoted")\n');
  await writeFile(join(root,'tests/stream_suite.gd'),[
    'func run():',
    '\tvar section: Dictionary = Content.fixture_registry.get("sections", {}).get("streamed", {})',
    '\tvar items: Array = Content.read_fixture_part("streamed", 0)',
    ''].join('\n'));
  const consumers=await fixtureConsumers(root,new Set(['whole','quoted','streamed']));
  assert.deepEqual(consumers['tests/run.gd'].direct,['whole','quoted']);
  assert.deepEqual(consumers['tests/stream_suite.gd'].all,[]);
});

test('partitioning preserves every source byte, row order, signed zero and nested sequence',async()=>{
  await mkdir('artifacts/fixture-section-tests',{recursive:true});
  const root=await mkdtemp(resolve('artifacts/fixture-section-tests/case-'));
  const input=join(root,'raw.json'),output=join(root,'fixtures.json');
  const original='{"numbers":[-0,1e+300,1e-300,0.00000000000001],"frames":[{"frames":[{"label":"鋼鐵,}]\\\"/"},{"n":123.45678901234567}]},{"frames":[]}],"empty":[],"metadata":{"nil":null,"absentTag":{"$undefined":true}}}';
  await writeFile(input,original);
  const manifest=await partitionFixtures(input,output,{partBytes:10,highWaterMark:7});
  assert.equal(manifest.sourceSha256,createHash('sha256').update(original).digest('hex'));
  const values=[];
  for(const key of manifest.sectionOrder) {
    const section=manifest.sections[key],bodies=[];
    for(const part of section.parts) {
      const raw=await readFile(join(root,part.path),'utf8');
      assert.equal(createHash('sha256').update(raw).digest('hex'),part.sha256);
      const numeric=await readFile(join(root,part.numbers.path));
      assert.equal(createHash('sha256').update(numeric).digest('hex'),part.numbers.sha256);
      assert.equal(numeric.length,part.numbers.count*8);
      let cursor=0;
      const compare=value=>{
        if(typeof value==='number') {
          assert.ok(Object.is(numeric.readDoubleLE(cursor),value));cursor+=8;
        } else if(Array.isArray(value))value.forEach(compare);
        else if(value&&typeof value==='object')Object.values(value).forEach(compare);
      };
      compare(JSON.parse(raw));
      assert.equal(cursor,numeric.length);
      bodies.push(section.kind==='array'?raw.slice(1,-1):raw);
    }
    values.push(JSON.stringify(key)+':'+(section.kind==='array'?'['+bodies.join(',')+']':bodies[0]));
  }
  assert.equal('{'+values.join(',')+'}',original);
  assert.equal(manifest.sections.frames.count,2);
  assert.equal(manifest.sections.empty.count,0);
  assert.equal(manifest.numericEncoding,'f64-le');
});

test('a focused publication keeps every unrelated captured section and the corpus hash',async()=>{
  await mkdir('artifacts/fixture-section-tests',{recursive:true});
  const root=await mkdtemp(resolve('artifacts/fixture-section-tests/update-'));
  const input=join(root,'raw.json'),output=join(root,'fixtures.json');
  const original='{"untouched":[-0,{"value":12.350000000000001}],"replace":[1]}';
  await writeFile(input,original);
  const before=await partitionFixtures(input,output);
  await updateFixtureSections(output,{replace:[12.350000000000001],added:{flag:true}});
  const after=JSON.parse(await readFile(output));
  assert.deepEqual(after.sections.untouched,before.sections.untouched);
  assert.deepEqual(after.sectionOrder,['untouched','replace','added']);
  const expected='{"untouched":[-0,{"value":12.350000000000001}],"replace":[12.350000000000001],"added":{"flag":true}}';
  assert.equal(after.sourceSha256,createHash('sha256').update(expected).digest('hex'));
  const tape=await readFile(join(root,after.sections.replace.parts[0].numbers.path));
  assert.equal(tape.readDoubleLE(),12.350000000000001);
  const published=await readFile(output);
  await assert.rejects(updateFixtureSections(output,{replace:[]},{expectedRegistry:Buffer.from('stale registry')}),/changed before section update/);
  assert.deepEqual(await readFile(output),published);
});

test('a capture hash changed after stage validation cannot replace the fixture registry',async()=>{
  await mkdir('artifacts/fixture-section-tests',{recursive:true});
  const root=await mkdtemp(resolve('artifacts/fixture-section-tests/stale-'));
  const input=join(root,'raw.json'),output=join(root,'fixtures.json');
  await writeFile(input,'{"values":[1]}');await writeFile(output,'retained registry');
  await assert.rejects(partitionFixtures(input,output,{expectedSha256:'0'.repeat(64)}),/Source capture changed before fixture publication/);
  assert.equal(await readFile(output,'utf8'),'retained registry');
});

test('focused section registration publishes its producer and new native consumer plan together',async()=>{
  const root=await mkdtemp(resolve('artifacts/fixture-section-tests/register-'));
  await mkdir(join(root,'tests'),{recursive:true});
  await writeFile(join(root,'tests/run.gd'),'func run(fixtures):\n\treturn fixtures.original\n');
  await writeFile(join(root,'tests/example_suite.gd'),'func run(fixtures):\n\treturn fixtures.added\n');
  const input=join(root,'raw.json'),output=join(root,'fixtures.json');
  await writeFile(input,'{"original":[1]}');
  const originalProducer={format:'test',inputs:{original:'a'}};
  const first=await partitionFixtures(input,output,{producer:originalProducer,projectRoot:root});
  const producer={format:'test',inputs:{added:'b'}};
  await updateFixtureSections(output,{added:[2]},{producer,projectRoot:root});
  const result=JSON.parse(await readFile(output));
  assert.deepEqual(result.sections.original,first.sections.original);
  assert.deepEqual(result.producers[result.sections.original.producer],originalProducer);
  assert.deepEqual(result.producers[result.sections.added.producer],producer);
  assert.deepEqual(result.consumers['tests/example_suite.gd'].all,['added']);
  assert.deepEqual(result.consumers['tests/run.gd'].direct,['original']);
});
