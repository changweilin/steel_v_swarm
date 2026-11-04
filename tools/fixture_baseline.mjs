// Compares tests/run.tscn failures against the recorded known-failure baseline so CI fails
// only on new or increased failures. The baseline never certifies a path: it is the O23
// list of failures still awaiting owners, and should only shrink.
//
//   node tools/fixture_baseline.mjs check  <baseline.json> <report.jsonl> <stderr.log> <stdout.log>
//   node tools/fixture_baseline.mjs update <baseline.json> (<report.jsonl> <stderr.log> <stdout.log>)...
//
// Assertion failures come from the run's jsonl report, keyed by scope and description with
// measured values removed. Script and engine errors come from stderr, keyed by message and
// location; tests/run.gd _check echoes are skipped because the report already holds them.
import {existsSync, readFileSync, writeFileSync} from 'node:fs';

const [mode, baselinePath, ...runs] = process.argv.slice(2);
if (!['check', 'update'].includes(mode) || !baselinePath || runs.length === 0 || runs.length % 3 !== 0)
  throw new Error('Usage: fixture_baseline.mjs check|update <baseline.json> (<report.jsonl> <stderr.log> <stdout.log>)...');

const assertionKey = (scope, description) => scope + '\t' + description.replace(/ actual=[\s\S]*$/, '');
const engineKey = (message, location) => (message + '\t' + location).replace(/-?\d+(\.\d+)?(e[-+]?\d+)?/gi, '#');
const add = (counts, key) => counts[key] = (counts[key] || 0) + 1;

function read(report, stderr, stdout) {
  const output = readFileSync(stdout, 'utf8');
  if (!/^(TEST_FAIL count=|SOURCE_FIXTURE_PASS )/m.test(output)) throw new Error('Fixture run did not finish: ' + stdout);
  const assertions = {}, engine = {};
  for (const line of readFileSync(report, 'utf8').split(/\r?\n/)) {
    if (!line.trim()) continue;
    const record = JSON.parse(line);
    add(assertions, assertionKey(record.scope, record.description));
  }
  const lines = readFileSync(stderr, 'utf8').split(/\r?\n/);
  for (let index = 0; index < lines.length; index++) {
    const match = /^(SCRIPT ERROR|ERROR): (.*)$/.exec(lines[index]);
    if (!match) continue;
    const trace = lines.slice(index + 1, index + 6);
    const location = (trace.find(line => /^\s+at: /.test(line)) || '').trim();
    const frame = (trace.find(line => /^\s+\[0\] /.test(line)) || '').trim();
    if (/^\[0\] _check \(res:\/\/tests\/run\.gd:/.test(frame)) continue;
    add(engine, engineKey(match[1] + ': ' + match[2], location.startsWith('at: push_error') ? frame : location));
  }
  const scopes = [...output.matchAll(/^SOURCE_SUITE_BEGIN (\S+)/gm)].map(match => match[1]);
  if (/^SOURCE_CORE_BEGIN\r?$/m.test(output)) scopes.push('core');
  return {assertions, engine, scopes};
}

const merged = {assertions: {}, engine: {}, scopes: new Set()};
for (let index = 0; index < runs.length; index += 3) {
  const run = read(runs[index], runs[index + 1], runs[index + 2]);
  for (const kind of ['assertions', 'engine'])
    for (const [key, count] of Object.entries(run[kind])) merged[kind][key] = (merged[kind][key] || 0) + count;
  run.scopes.forEach(scope => merged.scopes.add(scope));
}

if (mode === 'update') {
  const sorted = counts => Object.fromEntries(Object.entries(counts).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
  writeFileSync(baselinePath, JSON.stringify({assertions: sorted(merged.assertions), engine: sorted(merged.engine)}, null, 1) + '\n');
  console.log('FIXTURE_BASELINE_WRITTEN assertions=' + Object.keys(merged.assertions).length + ' engine=' + Object.keys(merged.engine).length);
  process.exit(0);
}

if (!existsSync(baselinePath)) throw new Error('Missing fixture baseline: ' + baselinePath);
const baseline = JSON.parse(readFileSync(baselinePath, 'utf8'));
const regressions = [], improvements = [];
for (const kind of ['assertions', 'engine']) {
  const known = baseline[kind] || {};
  for (const [key, count] of Object.entries(merged[kind]))
    if (count > (known[key] || 0)) regressions.push(kind + ' ' + count + ' > ' + (known[key] || 0) + '  ' + key);
  // Assertion scopes are attributable to the suites this run executed; engine errors are not.
  if (kind === 'assertions')
    for (const [key, count] of Object.entries(known))
      if (merged.scopes.has(key.split('\t')[0]) && (merged[kind][key] || 0) < count)
        improvements.push(kind + ' ' + (merged[kind][key] || 0) + ' < ' + count + '  ' + key);
}
for (const line of improvements) console.log('FIXTURE_BASELINE_IMPROVED ' + line);
for (const line of regressions) console.log('FIXTURE_BASELINE_REGRESSION ' + line);
if (regressions.length) {
  console.log('FIXTURE_BASELINE_FAIL regressions=' + regressions.length + ' improved=' + improvements.length);
  process.exit(1);
}
console.log('FIXTURE_BASELINE_PASS improved=' + improvements.length);
