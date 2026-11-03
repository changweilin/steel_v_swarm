import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/minimap_bunker_rounding.json'));
const provenance = JSON.parse(await read('data/provenance.json'));

test('original bunker keys preserve double rounding boundaries', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.equal(fixture.cases.length, 15);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  assert.equal(fixture.cases[0].key, '0,0');
  assert.equal(fixture.cases[0].legacy, 1);
  for (const sample of fixture.cases)
    assert.equal(Buffer.from(sample.valueBits, 'hex').readDoubleLE(), sample.value);
});
