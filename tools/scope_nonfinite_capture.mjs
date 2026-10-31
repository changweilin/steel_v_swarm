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
for (const path of ['public/js/data.js', 'tools/audit_src.mjs']) {
  sourceInputs[path] = digest(await readFile(join(source, path)));
  if (sourceInputs[path] !== provenance.inputs[path]) throw new Error('Original input changed: ' + path);
}
const data = (await readFile(join(source, 'public/js/data.js'), 'utf8')).replace(/\r\n?/g, '\n');
const {grabBlock, grabConst} = await import(pathToFileURL(join(source, 'tools/audit_src.mjs')).href);
const expression = name => {
  const match = new RegExp('^export const ' + name + ' = [\\s\\S]*?;', 'm').exec(data);
  if (!match) throw new Error('Missing original expression: ' + name);
  return match[0].replace(/^export /, '');
};
const definitions = [...['SCOPE', 'FOG_SIGHT', 'WEATHER_FOG_MASK'].map(name => grabConst(data, name)),
  ...['scopeRvmin', 'fogSightMultByDensity', 'scopeRvminFog'].map(expression),
  'const weatherFogStops = (d = 0) => ' + grabBlock(data, 'export const weatherFogStops = (d = 0) =>') + ';'].join('\n');
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let samples;
try {
  const page = await browser.newPage();
  samples = await page.evaluate(definitions => {
    const source = new Function(definitions + '\nreturn {scopeRvminFog, weatherFogStops};')();
    const inputs = ['NaN', '-Infinity', 'Infinity', -1, 0, .5, 2];
    const value = v => typeof v === 'number' ? v : v === 'NaN' ? NaN : v === 'Infinity' ? Infinity : -Infinity;
    const bits = v => {const b = new ArrayBuffer(8); new DataView(b).setFloat64(0, v, true);
      return [...new Uint8Array(b)].map(x => x.toString(16).padStart(2, '0')).join('');};
    return inputs.flatMap(fire => inputs.map(weather => {
      const f = value(fire), w = value(weather), stops = source.weatherFogStops(w);
      return {fire, weather, radiusBits: bits(source.scopeRvminFog(f, w)),
        stopBits: [bits(stops.r0), bits(stops.r1)]};
    }));
  }, definitions);
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/scope_nonfinite_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/scope_nonfinite.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), samples,
});
console.log('SCOPE_NONFINITE_CAPTURE_PASS samples=' + samples.length);
