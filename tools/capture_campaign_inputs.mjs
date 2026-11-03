import { readFile, writeFile, mkdir, rename } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { gzipSync } from 'node:zlib';

// Source capture functions retain real OSM responses and verified Terrarium tiles in this workspace.
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const source = resolve(process.env.SVS_SOURCE || join(root, '..', 'steel_vs_swarm'));
const load = file => import(pathToFileURL(join(source, file)).href);
const { grabFn } = await load('tools/audit_src.mjs');
const { captureElevationFixture } = await load('tools/elevation_fixture.mjs');
const { readOsmCapture, loadElevationFixture, validateElevationFixture, elevationWorldBounds, osmMapRoadResponse } = await load('tools/osm_fixture.mjs');
const d = await load('public/js/data.js');
const script = await readFile(join(source, 'tools/capture_venue_roads.mjs'), 'utf8');
const captureMap = new Function(`${grabFn(script,'captureMap')}\nreturn captureMap;`)();
const campaign = JSON.parse(await readFile(join(root, 'data/campaign.json'), 'utf8'));
const selected = process.argv.slice(2);
const directory = join(root, 'data/source_campaign');
await mkdir(join(directory, 'elevation'), { recursive:true });
for (const id of [...new Set(campaign.maps.map(map=>map.source_id))]) {
  if(selected.length&&!selected.includes(id))continue;
  const maps = campaign.maps.filter(map=>map.source_id===id);
  // Campaign configs carry no teamSize; the variant key is the team size.
  const team = Number(Object.keys(maps[0].variants)[0]);
  const boxes = maps.map(map=>d.battleBBox(Object.values(map.variants)[0].config));
  const bbox = {minLat:Math.min(...boxes.map(b=>b.minLat)),maxLat:Math.max(...boxes.map(b=>b.maxLat)),
    minLng:Math.min(...boxes.map(b=>b.minLng)),maxLng:Math.max(...boxes.map(b=>b.maxLng))};
  const path = join(directory,id+'.json.gz'), elevationDir=join(directory,'elevation');
  const center = {lat:(bbox.minLat+bbox.maxLat)/2,lng:(bbox.minLng+bbox.maxLng)/2,rot:0};
  let retained = false;
  try {
    const previous=readOsmCapture(path),relief=loadElevationFixture(id,elevationDir,{validate:false});
    retained=JSON.stringify(previous.data.bbox)===JSON.stringify(bbox)&&relief&&validateElevationFixture(relief,{dir:elevationDir}).ok;
  } catch(error) { if(error.code!=='ENOENT')throw error; }
  if(retained){process.stdout.write(`${id}: retained original source capture\n`);continue;}
  const {raw,urls}=await captureMap(bbox),roads=osmMapRoadResponse(raw);
  if(!Array.isArray(roads.elements))throw new Error(`${id}: original OSM road response missing`);
  const venue = {id,name:maps[0].name};
  const relief=await captureElevationFixture({name:id,venue,team,bbox,center,
    bounds:elevationWorldBounds(bbox,center),outputDir:elevationDir,timeoutMs:20000,update:true});
  if(!relief?.fixture)throw new Error(`${id}: verified Terrarium capture missing`);
  const payload={version:1,schema:'venue-road-fixture-v1',name:id,team,venue,center,bbox,capturedAt:new Date().toISOString(),
    source:{roads:'https://api.openstreetmap.org/api/0.6/map.json',urls},queries:{roads:{version:'osm-map-json-0.6',text:urls.join('\n')}},
    responses:{osmMap:raw,roads}};
  await writeFile(path+'.tmp',gzipSync(Buffer.from(JSON.stringify(payload)+'\n'),{level:9}));
  await rename(path+'.tmp',path);
  process.stdout.write(`${id}: captured ${roads.elements.length} original roads\n`);
}
