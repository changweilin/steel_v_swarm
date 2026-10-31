import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/minimap_bunker_precision.json'));
const provenance = JSON.parse(await read('data/provenance.json'));
const decode = bits => Buffer.from(bits, 'hex').readDoubleLE();

test('original bunker memory retains unrounded snapshot positions', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.equal(fixture.frames.length, 4);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  assert.deepEqual(fixture.frames[0].records.map(row => row.key), ['0,0', '1,0']);
  assert.equal(Math.fround(fixture.frames[0].rows[0].x), Math.fround(fixture.frames[0].rows[1].x));
  for (const frame of fixture.frames) for (const row of frame.rows) {
    assert.equal(decode(row.xBits), row.x);
    assert.equal(decode(row.zBits), row.z);
  }
});
