import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/scope_fov.json'));
const provenance = JSON.parse(await read('data/provenance.json'));
const decode = bits => Buffer.from(bits, 'hex').readDoubleLE();

test('original player FOV clamps negative easing time and snaps near target', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.equal(fixture.samples.length, 11);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  for (const sample of fixture.samples) {
    assert.equal(decode(sample.currentBits), sample.current);
    assert.equal(decode(sample.wantedBits), sample.wanted);
    assert.equal(decode(sample.deltaBits), sample.delta);
  }
  for (const sample of fixture.samples.slice(0, 3)) {
    assert.equal(decode(sample.resultBits), sample.current);
    assert.equal(sample.projections, 1);
  }
  assert.equal(fixture.samples[6].projections, 0);
  assert.equal(decode(fixture.samples[7].resultBits), 68);
});
