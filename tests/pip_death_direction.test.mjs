import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/pip_death_direction.json'));
const provenance = JSON.parse(await read('data/provenance.json'));
const decode = hex => Buffer.from(hex, 'hex').readDoubleLE();

test('death-view direction capture retains source programs and inputs', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.equal(fixture.rows.length, 522);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  for (const row of fixture.rows) {
    assert.deepEqual(row.up, [0, 1, 0]);
    assert.equal(row.targetBits.length, 3);
    assert.equal(row.eyeBits.length, 3);
    assert.deepEqual(row.pointBits.map(decode), row.point);
    assert.deepEqual(row.enemyBits.map(decode), row.enemy);
    assert.equal(decode(row.groundBits), row.ground);
    for (const value of row.point) assert.equal(Math.fround(value), value);
  }
  const source = fixture.rows[0], fallback = fixture.rows[1];
  assert.deepEqual(source.targetBits.map(decode), [0, 1, 0]);
  assert.deepEqual(fallback.targetBits.map(decode), [0, 12, 0]);
  assert.deepEqual(source.enemy, source.point.filter((_, index) => index !== 1));
});
