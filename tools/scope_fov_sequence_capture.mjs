import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const source = resolve(process.env.SVS_SOURCE || join(root, '..', 'steel_vs_swarm'));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const provenance = JSON.parse(await readFile(join(root, 'data/provenance.json'), 'utf8'));
const sourceInputs = {}, contents = {};
for (const path of ['public/js/game.js', 'public/js/data.js', 'tools/audit_src.mjs']) {
  const bytes = await readFile(join(source, path));
  sourceInputs[path] = digest(bytes);
  if (sourceInputs[path] !== provenance.inputs[path]) throw new Error('Original input changed: ' + path);
  contents[path] = bytes.toString('utf8').replace(/\r\n?/g, '\n');
}
const {grabMethod} = await import(pathToFileURL(join(source, 'tools/audit_src.mjs')).href);
const method = grabMethod(contents['public/js/game.js'], '_updatePlayer');
const start = method.indexOf('    const wantFov = this.aiming ?');
const end = method.indexOf("    if (this.viewMode === 'tps')", start);
if (start < 0 || end < 0) throw new Error('Missing original FOV update');
const program = method.slice(start, end);
const expression = name => {
  const match = new RegExp('^export const ' + name + ' = [^;]+;', 'm').exec(contents['public/js/data.js']);
  if (!match) throw new Error('Missing original easing function: ' + name);
  return match[0].replace(/^export /, '');
};
const definitions = ['frictionFPS', 'lerpFPS'].map(expression).join('\n');
const sequences = [
  {name: 'zoom-and-release', steps: [...Array.from({length: 120}, () => [1 / 60, true]), ...Array.from({length: 120}, () => [1 / 60, false])]},
  {name: 'rapid-reversals', steps: Array.from({length: 120}, (_, i) => [[.005, .016, .033, .001][i % 4], Math.floor(i / 7) % 2 === 0])},
  {name: 'pause-and-resume', steps: [...Array.from({length: 15}, () => [.016, true]), ...Array.from({length: 20}, () => [0, true]),
    ...Array.from({length: 15}, () => [.016, false]), ...Array.from({length: 20}, () => [0, false]), [.25, true]]},
];
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let programs;
try {
  const page = await browser.newPage();
  programs = await page.evaluate(({program, definitions, sequences}) => {
    const run = new Function('dt', 'UNITS', definitions + '\n' + program);
    const bits = (v, wide = true) => {const b = new ArrayBuffer(wide ? 8 : 4), d = new DataView(b);
      if (wide) d.setFloat64(0, v, true); else d.setFloat32(0, v, true);
      return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join('');};
    return sequences.map(sequence => {
      let projections = 0;
      const camera = {fov: 68, updateProjectionMatrix: () => projections++};
      const client = {aiming: false, heroKind: 'test', baseFov: 68, camera};
      const frames = sequence.steps.map(([delta, aiming]) => {
        client.aiming = aiming;
        const before = projections;
        run.call(client, delta, {test: {zoomFov: 35}});
        return {deltaBits: bits(delta), aiming, fovBits: bits(camera.fov), fovFloatBits: bits(camera.fov, false),
          projectionChanged: projections !== before};
      });
      return {name: sequence.name, frames};
    });
  }, {program, definitions, sequences});
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/scope_fov_sequence_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/scope_fov_sequence.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), programs,
});
console.log('SCOPE_FOV_SEQUENCE_CAPTURE_PASS frames=' + programs.reduce((n, p) => n + p.frames.length, 0));
