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
const data = contents['public/js/data.js'];
const expression = name => {
  const match = new RegExp('^export const ' + name + ' = [^;]+;', 'm').exec(data);
  if (!match) throw new Error('Missing original easing function: ' + name);
  return match[0].replace(/^export /, '');
};
const definitions = ['frictionFPS', 'lerpFPS'].map(expression).join('\n');
const cases = [
  {current: 68, wanted: 35, delta: -1}, {current: 68, wanted: 35, delta: -.001},
  {current: 68, wanted: 35, delta: 0}, {current: 68, wanted: 35, delta: .016},
  {current: 35, wanted: 68, delta: .1}, {current: 68, wanted: 35, delta: 1},
  {current: 68, wanted: 68, delta: -.1}, {current: 68.025, wanted: 68, delta: -.1},
  {current: 68.05, wanted: 68, delta: .016}, {current: 68.050000000001, wanted: 68, delta: .016},
  {current: 67.949999999999, wanted: 68, delta: .016},
];
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let samples;
try {
  const page = await browser.newPage();
  samples = await page.evaluate(({program, definitions, cases}) => {
    const run = new Function('dt', 'UNITS', definitions + '\n' + program);
    const bits = v => {const b = new ArrayBuffer(8); new DataView(b).setFloat64(0, v, true);
      return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join('');};
    return cases.map(row => {
      let projections = 0;
      const camera = {fov: row.current, updateProjectionMatrix: () => projections++};
      run.call({aiming: true, heroKind: 'test', baseFov: 68, camera}, row.delta, {test: {zoomFov: row.wanted}});
      return {...row, currentBits: bits(row.current), wantedBits: bits(row.wanted), deltaBits: bits(row.delta),
        resultBits: bits(camera.fov), projections};
    });
  }, {program, definitions, cases});
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/scope_fov_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/scope_fov.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), samples,
});
console.log('SCOPE_FOV_CAPTURE_PASS samples=' + samples.length);
