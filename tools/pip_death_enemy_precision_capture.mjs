import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join, resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const source = resolve(process.env.SVS_SOURCE || join(root, '..', 'steel_vs_swarm'));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const provenance = JSON.parse(await readFile(join(root, 'data/provenance.json'), 'utf8'));
const sourceInputs = {};
for (const path of ['public/js/game.js', 'tools/audit_src.mjs']) {
  sourceInputs[path] = digest(await readFile(join(source, path)));
  if (sourceInputs[path] !== provenance.inputs[path]) throw new Error('Original input changed: ' + path);
}
const game = (await readFile(join(source, 'public/js/game.js'), 'utf8')).replace(/\r\n?/g, '\n');
const {grabMethod} = await import(pathToFileURL(join(source, 'tools/audit_src.mjs')).href);
const method = grabMethod(game, '_renderDeathCam');
const start = method.indexOf('    let src = null, best = Infinity;');
const end = method.indexOf('\n\n    const cam = this.pipCam;', start);
if (start < 0 || end < 0) throw new Error('Missing original death-view source selection');
const program = method.slice(start, end);
const tower = (id, x, z, extra = {}) => ({id, kind: 'tower', side: 'STEEL', position: [x, 0, z], ...extra});
const cases = [
  {name: 'x-above', enemy: [.5000000001, 0], rows: [tower(1, 0, 0), tower(2, 1, 0)]},
  {name: 'x-below', enemy: [.4999999999, 0], rows: [tower(2, 1, 0), tower(1, 0, 0)]},
  {name: 'z-above', enemy: [0, .5000000001], rows: [tower(1, 0, 0), tower(2, 0, 1)]},
  {name: 'negative', enemy: [-.5000000001, 0], rows: [tower(1, 0, 0), tower(2, -1, 0)]},
  {name: 'translated', enemy: [1024.50001, -2048], rows: [tower(1, 1024, -2048), tower(2, 1025, -2048)]},
  {name: 'exact-tie', enemy: [.5, 0], rows: [tower(7, 0, 0), tower(8, 1, 0)]},
  {name: 'dead-nearest', enemy: [.5000000001, 0], rows: [tower(1, 0, 0), tower(2, 1, 0, {dead: true})]},
  {name: 'base-fallback', enemy: [.5000000001, 0], rows: [tower(1, 0, 0, {dead: true}), {id: 3, kind: 'base', side: 'STEEL', position: [2, 0, 0]}]},
];
for (const sample of cases) for (const row of sample.rows) for (const value of row.position)
  if (!Object.is(value, Math.fround(value))) throw new Error('Source model positions must survive native storage');
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let programs;
try {
  const page = await browser.newPage();
  programs = await page.evaluate(({program, cases}) => {
    const run = new Function('ex', 'ez', program + '\nreturn src ? src.id : null;');
    const bits = value => {const b = new ArrayBuffer(8); new DataView(b).setFloat64(0, value, true);
      return [...new Uint8Array(b)].map(v => v.toString(16).padStart(2, '0')).join('');};
    return cases.map(sample => {
      const ents = sample.rows.map(row => ({...row, mesh: {position: {x: row.position[0], y: row.position[1], z: row.position[2]}}}));
      const selected = run.call({side: 'STEEL', ents: new Map(ents.map(row => [row.id, row]))}, ...sample.enemy);
      return {...sample, enemyBits: sample.enemy.map(bits), selected};
    });
  }, {program, cases});
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/pip_death_enemy_precision_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/pip_death_enemy_precision.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), programs,
});
console.log('PIP_DEATH_ENEMY_PRECISION_CAPTURE_PASS programs=' + programs.length);
