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
const {grabBlock, grabMethod} = await import(pathToFileURL(join(source, 'tools/audit_src.mjs')).href);
const snapshot = grabMethod(game, '_applySnap');
const marker = "if (e.k === 'bunker')";
const block = grabBlock(snapshot, marker);
if (!block.includes('this._seenBunkers.set') || !block.includes('Math.round')) throw new Error('Original bunker memory changed');
const projection = grabMethod(game, '_world2mm');
const snapshots = [
  [{k: 'bunker', x: .4999999999, z: 0, s: 'STEEL'}, {k: 'bunker', x: .5000000001, z: 0, s: 'SWARM'}],
  [{k: 'bunker', x: -.5000000001, z: 1.5000000001, s: 'GUER'}, {k: 'bunker', x: -.4999999999, z: 1.4999999999, s: 'MILI'}],
  [{k: 'bunker', x: .500000001, z: 0, s: 'MILI'}, {k: 'tower', x: 4, z: 3, s: 'STEEL'}],
  [],
];
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let frames;
try {
  const page = await browser.newPage();
  frames = await page.evaluate(({marker, block, projection, snapshots}) => {
    const remember = new Function('e', marker + ' ' + block);
    const Client = new Function('return class { ' + projection + ' }')();
    const context = {_seenBunkers: new Map()};
    const client = Object.assign(new Client(), {_mmWin: {x0: -200, x1: 200, z0: -200, z1: 200}});
    const bits = v => {const b = new ArrayBuffer(8); new DataView(b).setFloat64(0, v, true);
      return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join('');};
    return snapshots.map(rows => {
      for (const row of rows) remember.call(context, row);
      const records = [...context._seenBunkers].map(([key, row]) => {
        const [x, z] = client._world2mm(row.x, row.z, 220, 220);
        return {key, side: row.side, xBits: bits(row.x), zBits: bits(row.z), rectBits: [x - 2.5, z - 2.5, 5, 5].map(bits)};
      });
      return {rows: rows.map(row => ({...row, xBits: bits(row.x), zBits: bits(row.z)})), records};
    });
  }, {marker, block, projection, snapshots});
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/minimap_bunker_precision_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/minimap_bunker_precision.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), frames,
});
console.log('MINIMAP_BUNKER_PRECISION_CAPTURE_PASS frames=' + frames.length);
