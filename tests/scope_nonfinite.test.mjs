import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/scope_nonfinite.json'));
const provenance = JSON.parse(await read('data/provenance.json'));

test('original scope formulas treat NaN fog as zero and clamp infinities', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.equal(fixture.samples.length, 49);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  const at = (fire, weather) => fixture.samples.find(row => row.fire === fire && row.weather === weather);
  assert.equal(at('NaN', 'NaN').radiusBits, at(0, 0).radiusBits);
  assert.deepEqual(at(0, 'NaN').stopBits, at(0, 0).stopBits);
  assert.equal(at('Infinity', 'Infinity').radiusBits, at(2, 2).radiusBits);
  assert.equal(at('-Infinity', '-Infinity').radiusBits, at(-1, -1).radiusBits);
});
