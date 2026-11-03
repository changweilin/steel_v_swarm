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
const method = grabMethod(game, '_specRoster');
const cases = [
  {name: 'missing', mode: 'missing'}, {name: 'null', mode: 'null'},
  {name: 'zero', mode: 'zero'}, {name: 'negative-zero', mode: 'negative-zero'},
  {name: 'nan', mode: 'nan'}, {name: 'false', mode: 'false'},
  {name: 'empty', mode: 'empty'}, {name: 'string-zero', mode: 'string-zero'},
  {name: 'bot', mode: 'bot'}, {name: 'number', mode: 'number'},
  {name: 'inactive', mode: 'bot', act: false}, {name: 'nonhero', mode: 'bot', hero: false},
];
const {chromiumOrNull, chromePath} = await import(pathToFileURL(join(source, 'tools/pw.mjs')).href);
const chromium = await chromiumOrNull();
if (!chromium || !chromePath()) throw new Error('Chromium and Playwright are required');
const browser = await chromium.launch({headless: true, executablePath: chromePath()});
let programs;
try {
  const page = await browser.newPage();
  programs = await page.evaluate(({method, cases}) => {
    const Client = new Function('return class {\n' + method + '\n}')();
    const values = {null: null, zero: 0, 'negative-zero': -0, nan: NaN, false: false,
      empty: '', 'string-zero': '0', bot: 'b2', number: 1};
    return cases.map(sample => {
      const row = {tag: sample.name, hero: sample.hero ?? true, act: sample.act ?? true, side: 'STEEL'};
      if (sample.mode !== 'missing') row.pid = values[sample.mode];
      const client = Object.assign(new Client(), {ents: new Map([[1, row]])});
      return {...sample, included: client._specRoster().length !== 0};
    });
  }, {method, cases});
} finally { await browser.close(); }
for (const [path, hash] of Object.entries(sourceInputs))
  if (digest(await readFile(join(source, path))) !== hash) throw new Error('Original input changed during capture: ' + path);
const inputs = {};
for (const path of ['tools/spectator_roster_pid_capture.mjs', 'tools/fixture_json.mjs'])
  inputs[path] = digest((await readFile(join(root, path), 'utf8')).replace(/\r\n?/g, '\n'));
await writeFixtureJson(join(root, 'tests/fixtures/spectator_roster_pid.json'), {
  formatVersion: 1, source: {inputs, sourceInputs}, browser: browser.version(), programs,
});
console.log('SPECTATOR_ROSTER_PID_CAPTURE_PASS programs=' + programs.length);
