import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = path => readFile(join(root, path));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixture = JSON.parse(await read('tests/fixtures/scope_fov_sequence.json'));
const provenance = JSON.parse(await read('data/provenance.json'));

test('original FOV sequences preserve easing, reversals and paused frames', async () => {
  assert.equal(fixture.formatVersion, 1);
  assert.deepEqual(fixture.programs.map(row => row.name), ['zoom-and-release', 'rapid-reversals', 'pause-and-resume']);
  assert.equal(fixture.programs.reduce((n, row) => n + row.frames.length, 0), 431);
  for (const [path, hash] of Object.entries(fixture.source.inputs))
    assert.equal(digest((await read(path)).toString().replace(/\r\n?/g, '\n')), hash, path);
  for (const [path, hash] of Object.entries(fixture.source.sourceInputs)) {
    assert.equal(provenance.inputs[path], hash, path);
    if (process.env.SVS_SOURCE) assert.equal(digest(await readFile(join(resolve(process.env.SVS_SOURCE), path))), hash, path);
  }
  const paused = fixture.programs[2].frames;
  assert.equal(new Set(paused.slice(14, 35).map(row => row.fovBits)).size, 1);
  assert.ok(paused.slice(15, 35).every(row => row.projectionChanged));
  assert.ok(fixture.programs[0].frames.some(row => !row.projectionChanged));
});
