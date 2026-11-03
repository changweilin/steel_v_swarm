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
const method = grabMethod(game, '_applySnap');
const marker = "if (e.k === 'bunker')";
const block = grabBlock(method, marker);
if (!block.includes('this._seenBunkers.set') || !block.includes('Math.round')) throw new Error('Original bunker memory changed');
const values = [0.49999999999999994, 0.5, 0.5000000000000001, -0.5000000000000001, -0.5,
  -0.49999999999999994, 1.4999999999999998, 1.5, -1.5000000000000002, -1.5,
  1024.4999999999998, 1024.5, -1024.5000000000002, -1024.5, 0];
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let cases;
try {
  const page = await browser.newPage();
  cases = await page.evaluate(({marker, block, values}) => {
    const remember = new Function('e', marker + ' ' + block);
    const bits = v => {const b = new ArrayBuffer(8); new DataView(b).setFloat64(0, v, true);
      return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join('');};
    return values.map(value => {
      const context = {_seenBunkers: new Map()};
      remember.call(context, {k: 'bunker', x: value, z: -value, s: 'STEEL'});
      return {value, valueBits: bits(value), key: [...context._seenBunkers.keys()][0], legacy: Math.floor(value + .5)};
    });
  }, {marker, block, values});
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/minimap_bunker_rounding_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/minimap_bunker_rounding.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), cases,
});
console.log('MINIMAP_BUNKER_ROUNDING_CAPTURE_PASS cases=' + cases.length);
