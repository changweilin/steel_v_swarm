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
const start = method.indexOf('    if (src) {');
const end = method.indexOf('\n\n    const r = this.renderer', start);
if (start < 0 || end < 0) throw new Error('Missing original death-view camera branches');
const program = method.slice(start, end);

const cases = [
  {point: [0, 0, 0], enemy: [0, 0], ground: 0},
  {point: [12, 5, -9], enemy: [100, -100], ground: 1.3},
  {point: [-2048, 2, 2048], enemy: [-2048, 2048], ground: -20.25},
  {point: [0, 0, 0], enemy: [0.10029599815607071, 1.200152039527893], ground: 0},
  {point: [0, 0, 0], enemy: [1e-300, -1e-300], ground: 0},
];
let seed = 0x8e23b179;
const random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 0x100000000);
for (let i = 0; i < 256; i++) {
  const point = [Math.fround((random() - .5) * 8192), Math.fround((random() - .5) * 512), Math.fround((random() - .5) * 8192)];
  const enemy = [(random() - .5) * 8192, (random() - .5) * 8192];
  cases.push({point, enemy, ground: (random() - .5) * 100});
}

const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let rows;
try {
  const page = await browser.newPage();
  rows = await page.evaluate(({program, cases}) => {
    const run = new Function('src', 'cam', 'ex', 'ez', program);
    const bits = value => {
      const buffer = new ArrayBuffer(8);
      new DataView(buffer).setFloat64(0, value, true);
      return [...new Uint8Array(buffer)].map(byte => byte.toString(16).padStart(2, '0')).join('');
    };
    return cases.flatMap(sample => ['source', 'fallback'].map(mode => {
      const {point, enemy, ground} = sample;
      const src = mode === 'source' ? {mesh: {position: {x: point[0], y: point[1], z: point[2]}}, dimTop: 14} : null;
      let target = [], up = [], eye = [];
      const cam = {position: {set: (...v) => eye = v}, up: {set: (...v) => up = v}, lookAt: (...v) => target = v};
      run.call({pos: {x: point[0], z: point[2]}, _surf: () => ground}, src, cam, ...enemy);
      return {...sample, mode, pointBits: point.map(bits), enemyBits: enemy.map(bits), groundBits: bits(ground),
        targetBits: target.map(bits), eyeBits: eye.map(bits), up};
    }));
  }, {program, cases});
} finally {
  await browser.close();
}
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/pip_death_direction_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/pip_death_direction.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), rows,
});
console.log('PIP_DEATH_DIRECTION_CAPTURE_PASS cases=' + rows.length);
