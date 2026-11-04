// Prints a cache key for one packed world: the static closure of the packer scene and
// project autoloads (literal res:// paths plus class_name/autoload identifiers), every
// shader, project.godot and the bundle's capture. Gameplay-only scripts outside that
// closure no longer invalidate multi-minute world packs.
import {createHash} from 'node:crypto';
import {existsSync, readFileSync, readdirSync, statSync} from 'node:fs';
import {dirname, join, relative} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const bundle = process.argv[2];
if (!bundle || !/^[a-z0-9_]+$/.test(bundle)) throw new Error('Usage: node tools/world_pack_inputs.mjs <bundle>');
const capture = 'data/worlds/' + bundle + '.json';
if (!existsSync(join(root, capture))) throw new Error('Missing world capture: ' + capture);

const SCANNED = /\.(gd|gdshader|gdshaderinc|tscn|tres|template)$/;
const walk = folder => readdirSync(join(root, folder)).flatMap(name => {
  const path = folder + '/' + name;
  if (name.startsWith('.')) return [];
  return statSync(join(root, path)).isDirectory() ? walk(path) : [path];
});

const project = readFileSync(join(root, 'project.godot'), 'utf8');
const autoloads = new Map();
const section = /^\[autoload\]\s*$([\s\S]*?)(?=^\[)/m.exec(project);
for (const match of (section ? section[1] : '').matchAll(/^(\w+)="\*?res:\/\/([^"]+)"/gm)) autoloads.set(match[1], match[2]);
const globals = new Map(autoloads);
for (const path of [...walk('scripts'), ...walk('tools')].filter(path => path.endsWith('.gd'))) {
  const match = /^class_name\s+(\w+)/m.exec(readFileSync(join(root, path), 'utf8'));
  if (match) globals.set(match[1], path);
}

const closure = new Set();
const queue = ['tools/import_worlds.tscn', ...autoloads.values()];
while (queue.length) {
  const path = queue.pop();
  if (closure.has(path) || !existsSync(join(root, path)) || statSync(join(root, path)).isDirectory()) continue;
  closure.add(path);
  if (!SCANNED.test(path)) continue;
  const text = readFileSync(join(root, path), 'utf8').replace(/#.*$/gm, '');
  for (const match of text.matchAll(/res:\/\/([^"'\s)%]+)/g)) queue.push(match[1]);
  if (path.endsWith('.gd')) for (const match of text.matchAll(/\b[A-Z]\w*\b/g)) if (globals.has(match[0])) queue.push(globals.get(match[0]));
}
// Test fixtures are never read while packing.
closure.delete('data/fixtures.json');
for (const path of [...walk('shaders'), 'project.godot', capture, relative(root, fileURLToPath(import.meta.url)).replaceAll('\\', '/')]) closure.add(path);

const hash = createHash('sha256');
for (const path of [...closure].sort()) hash.update(path + '\0').update(readFileSync(join(root, path))).update('\0');
console.log(hash.digest('hex'));
