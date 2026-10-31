import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/pip_death_enemy_precision.json'));
const provenance = JSON.parse(await read('data/provenance.json'));

test('source selection preserves unrounded enemy coordinates', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.equal(fixture.programs.length, 8);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  for (const sample of fixture.programs)
    assert.deepEqual(sample.enemyBits.map(bits => Buffer.from(bits, 'hex').readDoubleLE()), sample.enemy);
  assert.deepEqual(fixture.programs.map(row => row.selected), [2, 1, 2, 2, 2, 7, 1, 3]);
  assert.equal(Math.fround(fixture.programs[0].enemy[0]), .5);
});
