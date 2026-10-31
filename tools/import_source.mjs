import { readFile, mkdir } from 'node:fs/promises';
import { resolve, join, relative } from 'node:path';
import {copySourceTree as cp} from './source_copy.mjs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import {writeFixtureJson,writeSourceFile} from './fixture_json.mjs';
import {partitionFixtures,refreshFixtureConsumers} from './fixture_sections.mjs';
import {captureGenerator,verifyGenerator,captureSourceFiles,verifySourceFiles,captureWorkspaceInputs,verifyWorkspaceInputs} from './source_provenance.mjs';
import { combatReferences } from './combat_references.mjs';
import { outlineReferences } from './outline_references.mjs';
import { geometryLodReferences } from './geometry_lod_references.mjs';
import { projectileReferences } from './projectile_references.mjs';
import { lineReferences } from './line_references.mjs';
import { targetingReferences } from './targeting_references.mjs';
import { missileReferences } from './missile_references.mjs';
import { structureReferences } from './structure_references.mjs';
import { textureReferences } from './texture_references.mjs';
import { celUniformReferences } from './cel_uniform_references.mjs';
import { trainReferences } from './train_references.mjs';
import { sceneryMotionReferences } from './scenery_motion_references.mjs';
import { wildlifeReferences } from './wildlife_references.mjs';
import { petalReferences } from './petal_references.mjs';
import { aquaticReferences } from './aquatic_references.mjs';
import { marineReferences } from './marine_references.mjs';
import { visualReferences } from './visual_references.mjs';
import { balancePreferenceReferences } from './balance_preference_references.mjs';
import { balanceDefinitionReferences } from './balance_definition_references.mjs';
import { audioReferences } from './audio_references.mjs';
import { roomReferences } from './room_references.mjs';
import { sourceSideSwap } from './room_rematch_references.mjs';
import { spectatorReferences } from './spectator_references.mjs';
import { pipReferences } from './pip_references.mjs';
import { minimapReferences } from './minimap_references.mjs';
import { snapshotReferences, snapshotEventReferences, castEventReferences, fieldEventReferences } from './snapshot_references.mjs';
import { reachabilityReferences } from './reachability_references.mjs';
import { modelReferences } from './model_references.mjs';
import { hurtBearingReferences } from './hurt_bearing_references.mjs';
import { presentationFrameReferences } from './presentation_frame_references.mjs';
import { blastFeedbackReferences } from './blast_feedback_references.mjs';
import { footprintReferences } from './footprint_references.mjs';
import { cameraReferences } from './camera_references.mjs';
import { burstReferences } from './burst_references.mjs';
import { statusReferences } from './status_references.mjs';
import { tickReferences } from './tick_references.mjs';
import { deathReferences } from './death_references.mjs';
import { movementReferences } from './movement_references.mjs';
import { traversalReferences } from './traversal_references.mjs';
import { climbReferences } from './climb_references.mjs';
import { fieldReferences } from './field_references.mjs';
import { companionReferences } from './companion_references.mjs';
import { carrierReferences } from './carrier_references.mjs';
import { abilityRouteReferences } from './ability_route_references.mjs';
import { npcReferences } from './npc_references.mjs';
import { waveReferences } from './wave_references.mjs';
import { weatherReferences } from './weather_references.mjs';
import { environmentReferences } from './environment_references.mjs';
import { sceneryReferences } from './scenery_references.mjs';
import { sceneReferences } from './scene_references.mjs';
import { supplyReferences } from './supply_references.mjs';
import { thirdReferences } from './third_references.mjs';
import { matchReferences } from './match_references.mjs';
import { missileDefenseReferences } from './missile_defense_references.mjs';
import { aimingPresentationReferences } from './aiming_presentation_references.mjs';
import { botReferences } from './bot_references.mjs';
import { bossReferences } from './boss_references.mjs';
import { campaignReferences } from './campaign_references.mjs';
import { superReferences } from './super_references.mjs';
import { controlsReferences } from './controls_references.mjs';
import { mobileReferences } from './mobile_references.mjs';
import { combatFeedReferences } from './combat_feed_references.mjs';
import { viewReferences } from './view_references.mjs';
import { playerViewReferences } from './player_view_references.mjs';
import { locomotionReferences } from './locomotion_references.mjs';

// Offline migration only: evaluate the source's settlement seams instead of copying derived numbers.
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const source = resolve(process.argv[2] || join(root, '..', 'steel_vs_swarm'));
const outputIndex=process.argv.indexOf('--output-root');
if(outputIndex>=0&&(!process.argv[outputIndex+1]||process.argv[outputIndex+1].startsWith('--')))
  throw new Error('Expected a destination directory after --output-root');
const publicationRoot=outputIndex<0?root:resolve(process.argv[outputIndex+1]);
const auditReferencesOnly=process.argv.includes('--audit-references');
const stageIndex=process.argv.indexOf('--publish-stage');
const partitionIndex=process.argv.indexOf('--partition-fixtures');
const statusReferencesOnly=process.argv.includes('--status-references');
const botReferencesOnly=process.argv.includes('--bot-references');
const companionReferencesOnly=process.argv.includes('--companion-references');
const missileDefenseReferencesOnly=process.argv.includes('--missile-defense-references');
const abilityRoutesOnly=process.argv.includes('--ability-route-references');
const tickReferencesOnly=process.argv.includes('--tick-references');
const deathReferencesOnly=process.argv.includes('--death-references');
const snapshotEventsOnly=process.argv.includes('--snapshot-event-references');
if(process.argv.includes('--refresh-fixture-consumers')) {
  if(stageIndex>=0||partitionIndex>=0||outputIndex>=0||auditReferencesOnly||statusReferencesOnly||botReferencesOnly||companionReferencesOnly||missileDefenseReferencesOnly||abilityRoutesOnly||tickReferencesOnly||deathReferencesOnly||snapshotEventsOnly||process.argv.includes('--audio-music-gain'))
    throw new Error('Choose one source publication operation');
  await refreshFixtureConsumers(join(root,'data/fixtures.json'),root);
  process.exit(0);
}
if(statusReferencesOnly||botReferencesOnly||companionReferencesOnly||missileDefenseReferencesOnly||abilityRoutesOnly||tickReferencesOnly||deathReferencesOnly||snapshotEventsOnly) {
  if([statusReferencesOnly,botReferencesOnly,companionReferencesOnly,missileDefenseReferencesOnly,abilityRoutesOnly,tickReferencesOnly,deathReferencesOnly,snapshotEventsOnly].filter(Boolean).length!==1||stageIndex>=0||partitionIndex>=0||outputIndex>=0||auditReferencesOnly||process.argv.includes('--audio-music-gain'))
    throw new Error('Choose one source publication operation');
  const {publishReferenceSections}=await import('./source_stage.mjs');
  await publishReferenceSections(root,source,async()=>{
    const d=await import(pathToFileURL(join(source,'public/js/data.js')).href);
    const {BattleSim}=await import(pathToFileURL(join(source,'server/sim.js')).href);
    const {mulberry32}=await import(pathToFileURL(join(source,'public/js/rng.js')).href);
    const maps=JSON.parse(await readFile(join(root,'data/maps.json')));
    const config=maps[0].variants['1'].config;
    if(snapshotEventsOnly)return {snapshotEvents:snapshotEventReferences(BattleSim),castEvents:castEventReferences(d,BattleSim),fieldEvents:fieldEventReferences(d,BattleSim)};
    if(abilityRoutesOnly)return abilityRouteReferences(d,BattleSim);
    if(statusReferencesOnly)return statusReferences(d,BattleSim,config,mulberry32);
    if(tickReferencesOnly)return tickReferences(d,BattleSim,config,mulberry32,source);
    if(deathReferencesOnly)return deathReferences(d,BattleSim,config,mulberry32,source);
    if(companionReferencesOnly)return companionReferences(d,BattleSim,config,mulberry32);
    if(missileDefenseReferencesOnly){const {missileDefenseReferences}=await import('./missile_defense_references.mjs');return missileDefenseReferences(d,BattleSim,config,mulberry32);}
    const {botReferences}=await import('./bot_references.mjs');
    return (await botReferences(d,BattleSim,config,mulberry32,source)).fixtures;
  });
  process.exit(0);
}
if(partitionIndex>=0) {
  if(stageIndex>=0||outputIndex>=0||auditReferencesOnly||process.argv.includes('--audio-music-gain'))
    throw new Error('Choose one source publication operation');
  if(!process.argv[partitionIndex+1]||process.argv[partitionIndex+1].startsWith('--'))
    throw new Error('Expected a published complete capture after --partition-fixtures');
  const stage=resolve(process.argv[partitionIndex+1]);
  const previous=await readFile(join(root,'data/provenance.json'));
  if(!previous.equals(await readFile(join(stage,'data/provenance.json'))))
    throw new Error('Partition only the source capture already published in this project');
  const producer=JSON.parse(previous).producer;
  await verifyGenerator(root,producer);
  await verifyWorkspaceInputs(root,JSON.parse(previous).workspaceInputs);
  await partitionFixtures(join(stage,'data/fixtures.json'),join(root,'data/fixtures.json'),{projectRoot:root,producer});
  process.exit(0);
}
if(stageIndex>=0) {
  if(outputIndex>=0||auditReferencesOnly||process.argv.includes('--audio-music-gain'))
    throw new Error('Choose either source capture, read-only audit or completed-stage publication');
  if(!process.argv[stageIndex+1]||process.argv[stageIndex+1].startsWith('--'))
    throw new Error('Expected a completed capture directory after --publish-stage');
  const {publishSourceStage}=await import('./source_stage.mjs');
  await publishSourceStage(root,source,resolve(process.argv[stageIndex+1]));
  process.exit(0);
}
if(outputIndex>=0&&(auditReferencesOnly||process.argv.includes('--audio-music-gain')))
  throw new Error('--output-root applies only to a complete source capture');
if(process.argv.includes('--audio-music-gain')) {
  if(auditReferencesOnly)throw new Error('Choose either read-only reference audit or procedural gain publication');
  const option=name=>{const index=process.argv.indexOf(name);return index<0?undefined:resolve(process.argv[index+1]);};
  const {publishAudioMusicGain}=await import('./audio_music_gain_capture.mjs');
  await publishAudioMusicGain(root,source,{playwrightModule:option('--playwright-module'),chrome:option('--chrome')});
  process.exit(0);
}
if(process.argv.includes('--native-images')) {
  if(outputIndex>=0||auditReferencesOnly)throw new Error('Choose one source publication operation');
  const option=name=>{const index=process.argv.indexOf(name);return index<0?undefined:resolve(process.argv[index+1]);};
  const {publishNativeImages}=await import('./native_images.mjs');
  await publishNativeImages(root,source,{playwrightModule:option('--playwright-module'),chrome:option('--chrome')});
  process.exit(0);
}
const producer=auditReferencesOnly?null:await captureGenerator(root);
const sourceBefore=auditReferencesOnly?null:await captureSourceFiles(source);
const workspaceBefore=auditReferencesOnly?null:await captureWorkspaceInputs(root);
const assetInputs=new Set();
const recordAssetInput=path=>assetInputs.add(relative(source,path).replaceAll('\\','/'));
const load = file => import(pathToFileURL(join(source, file)).href);
const d = await load('public/js/data.js');
const v = await load('public/js/venues.js');
const { BattleSim, cumLen, pointAt } = await load('server/sim.js');
const { settleMapMetrics } = await load('public/js/mapRules.js');
const { sanitizeProcRelief } = await load('public/js/mapgen.js');
const { mulberry32 } = await load('public/js/rng.js');
const buildings = await load('public/js/mapBuilding.js');
const narrative = await load('public/js/story.js');
const civilianContent = await load('public/js/civilianContent.js');
const gameSource = await readFile(join(source, 'public/js/game.js'), 'utf8');
const mainSource = await readFile(join(source, 'public/js/main.js'), 'utf8');
const feedBody = /feed: \(text\) => \{([\s\S]*?)\n    \},/.exec(mainSource.replace(/\r\n/g, '\n'))?.[1];
const feedLimit = /feedBox.children.length > (\d+)/.exec(feedBody || '');
const feedLifetime = /setTimeout\(\(\) => div.remove\(\), (\d+)\)/.exec(feedBody || '');
if (!feedLimit || !feedLifetime) throw new Error('Source HUD feed rules missing');
const sprintMatch = /const boost = ax\.boost \? ([\d.]+) : 1/.exec(gameSource);
if (!sprintMatch) throw new Error('Source sprint seam not found');
const arcPoints = /const ARC_MAXP = (\d+);/.exec(gameSource);
const arcColors = /const col = fc.close \? (0x[\da-f]+) : !fc.ok \? (0x[\da-f]+) : fc.aa \? (0x[\da-f]+) : fc.high \? (0x[\da-f]+) :/.exec(gameSource);
if (!arcPoints || !arcColors) throw new Error('Source arc preview seam not found');
const coneAngle = /const LIM = opt\?\.lim \?\? ([\d.]+)/.exec(gameSource);
const lockInterval = /now - \(this\._lockAt \|\| 0\) < ([\d.]+)/.exec(gameSource);
const obstructionTolerance = /dB < ro\.distanceTo\(c\) - ([\d.]+)/.exec(gameSource);
if (!coneAngle || !lockInterval || !obstructionTolerance) throw new Error('Source acquisition seams not found');
const serialize = value => JSON.parse(JSON.stringify(value, (_, item) =>
  item instanceof Set ? [...item] : item instanceof Map ? Object.fromEntries(item) : item));
const constants = {};
for (const [key, value] of Object.entries(d)) {
  if (typeof value !== 'function') constants[key] = serialize(value);
}
const heroes = {};
function weaponDefinition(id, slot, level) {
  const def = d.heroWeapon(id, slot, level);
  return { ...def, area: d.aoeClass(def), trajectory: d.trajClass(def), reachRule: d.reachRule(def),
    burst: { count: d.fireBurstN(def), gap: d.fireBurstGap(def) },
    lanceRadius: d.lanceR(def), lancePen: d.lancePen(def),
    fanSubs: d.fanSubs(def), fanMaxBuildingHits: d.fanBuildingMaxHits(def),
    fanRangeFactors: Array.from({ length: d.fanSubs(def) }, (_, bin) => d.fanBinRangeF(def, bin)),
    projectile: { speed: d.shotV0(def), antiAirSpeed: d.shotV0(def, true), arm: d.armingOf(def), fuel: d.chaseCapS(def), flightCap: d.flightCapS(def),
      core: d.blastCoreR(def), launchDistance: d.guidedLaunchDist(def) },
    heavyMp: slot === 'heavy' ? d.heavyMpCost(def) : 0 };
}
for (const [id, ch] of Object.entries(d.CHARACTERS)) {
  heroes[id] = {
    ...ch, armor: d.heroArmor(id), radius: d.hitR({ hero:true, kind:ch.kind, ch:id }),
    height: d.hitH({ hero:true, kind:ch.kind, ch:id }), speed: d.heroMobility(ch.kind, ch.mods),
    colliders: {ground:d.selfCollider(d.heroTargetH(ch.kind,id),false),air:d.selfCollider(d.heroTargetH(ch.kind,id),true)},
    flySpeed: d.heroMobility(ch.kind, ch.mods, true),
    weapons: {}, abilities: {}, super: {weapons:{},abilities:{}},
  };
  for (const slot of ['light', 'heavy']) {
    heroes[id].weapons[slot] = Array.from({ length: d.ECON.UPGRADES[slot === 'light' ? 'lw' : 'hw'].max + 1 }, (_, i) => weaponDefinition(id,slot,i+1));
    heroes[id].super.weapons[slot] = Array.from({length:d.SUPER_UPG.MAX+1},(_,i)=>weaponDefinition(id,slot,d.superCombatLvl(i)));
  }
  for (const slot of ['def', 'atk']) {
    heroes[id].abilities[slot] = Array.from({ length: d.ECON.UPGRADES[slot].max + 1 }, (_, i) => d.heroAbility(id, slot, i + 1));
    heroes[id].super.abilities[slot] = Array.from({length:d.SUPER_UPG.MAX+1},(_,i)=>d.heroAbility(id,slot,d.superCombatLvl(i)));
  }
}
const maps = [];
const swapRoomSides = await sourceSideSwap(source);
function captureMapVariant(cfg, size) {
  cfg.defSide = ['SWARM', 'STEEL'].includes(cfg.defSide) ? cfg.defSide : null;
  cfg.super = !!cfg.super && !cfg.defSide;
  cfg.gen = ['mixed', 'random'].includes(cfg.gen?.mode) ? cfg.gen : null;
  cfg.procRelief = sanitizeProcRelief(cfg.procRelief);
  cfg.siege = !!cfg.defSide;
  // RoomHub settles these derived metrics before accepting the map for a battle.
  settleMapMetrics(cfg);
  const sim = new BattleSim(cfg);
  const wavePrefill = [];
  sim._spawnLaneWave = (lane,side,wave,lead) => wavePrefill.push({lane,side,wave,lead});
  sim._prefillLanes();
  return {
    config: cfg, bounds: d.battleRect(cfg),
    authority_bounds: {minX:sim.bounds.minX,maxX:sim.bounds.maxX,minZ:-sim.bounds.maxZ,maxZ:-sim.bounds.minZ},
    wave_prefill: wavePrefill,
    lane_turns:sim.lanes.map(lane=>d.laneTacticsXZ(lane).turns),
    bases: Object.fromEntries(Object.entries(cfg.bases).map(([side, ll]) => [side, d.llToXZ(...ll, cfg.center)])),
    lanes: cfg.lanes.map(lane => lane.map(ll => d.llToXZ(...ll, cfg.center))),
    hero_spawns: Object.fromEntries(['SWARM','STEEL'].map(side => [side,
      Array.from({length:size}, (_, slot) => {
        const [x,z] = sim._spawnPoint(side,slot);
        const [dx,dz] = sim._spawnAimDir(side,slot,x,z);
        return {position:[x,-z],direction:[dx,-dz]};
      })])),
    tower_sites: sim.towerSites.map(sites => sites.map(site => ({frac:site.frac,
      normals:Object.fromEntries(['STEEL','SWARM'].filter(side=>site[side]).map(side=>[side,[site[side].nx,-site[side].nz]])),
      ...Object.fromEntries(['STEEL','SWARM'].filter(side=>site[side]).map(side=>[side,[site[side].x,-site[side].z]]))}))),
    structures: [...sim.ents.values()].filter(e => ['base', 'tower'].includes(e.kind)).map(e =>
      ({ kind: e.kind, side: e.side, position: [e.x, e.y || 0, -e.z], lane: e.lane ?? 0, hp: e.hp, stage:e.sg })),
  };
}
for (const venue of v.VENUES.filter(item => !item.story)) {
  const available = v.venueAvailability(venue, 5);
  if (!available.available) continue;
  const variants = {};
  const swapped_variants = {};
  for (let size = d.TEAM.MIN; size <= d.TEAM.MAX; size++) {
    const config = v.venueConfig(venue, size);
    const swappedConfig = structuredClone(config);
    variants[size] = captureMapVariant(config, size);
    swapRoomSides(swappedConfig, 0);
    swapped_variants[size] = captureMapVariant(swappedConfig, size);
  }
  maps.push({ id: venue.id, name: venue.name, variants, swapped_variants });
}
const rng = mulberry32(123456789);
const unitVolumes=Object.fromEntries(Object.keys(d.UNITS).map(kind=>[kind,Object.fromEntries(['SWARM','STEEL','GUER','MILI','SUPER'].map(side=>
  [side,{radius:d.hitR({kind,side}),height:d.hitH({kind,side})}]))]));
console.log('SOURCE_CAPTURE_BEGIN missile-structure-camera-texture');
const missileReference = await missileReferences(d, BattleSim, maps[0].variants['1'].config, source, gameSource);
const structureReference = await structureReferences(d, BattleSim, maps[0].variants['1'].config, source, root, gameSource);
const reachabilityReference = await reachabilityReferences(d, gameSource, source);
const cameraReference = await cameraReferences(d, source, gameSource);
const textureReference = await textureReferences(source);
console.log('SOURCE_CAPTURE_DONE missile-structure-camera-texture');
let modelReference;
if (!auditReferencesOnly) {
  console.log('SOURCE_CAPTURE_BEGIN models');
  modelReference = await modelReferences(source, gameSource, cameraReference.profiles, textureReference);
  console.log('SOURCE_CAPTURE_DONE models');
}
const carrierReference = carrierReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32);
const npcReference = await npcReferences(d, BattleSim, maps[0].variants['1'].config, source);
const waveReference = waveReferences(d, BattleSim, maps[0].variants['1'].config, cumLen, pointAt, mulberry32);
const weatherReference = await weatherReferences(d, BattleSim, maps[0].variants['1'].config, source);
const aimingReference = await aimingPresentationReferences(d, gameSource, source);
const botReference = await botReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32, source);
const bossReference = await bossReferences(d, BattleSim, maps[0].variants['1'].config, source, gameSource);
const campaignReference = await campaignReferences(d, v, narrative, mainSource, source, captureMapVariant, BattleSim);
const superReference = await superReferences(d, BattleSim, maps[0].variants['1'].config, source, mulberry32);
const controlsReference = await controlsReferences(d, gameSource, source);
const outlineReference = await outlineReferences(source);
const geometryLodReference = await geometryLodReferences(source,d);
const traversalReference = await traversalReferences(d, source, gameSource);
const climbReference = await climbReferences(d, source, gameSource);
const mobileReference = await mobileReferences(gameSource, source);
const combatFeedReference = await combatFeedReferences(d, gameSource, source);
const viewReference = await viewReferences(d, gameSource, mainSource, source);
const playerViewReference = await playerViewReferences(d, gameSource, source);
const locomotionReference = await locomotionReferences(d, source);
const visualReference = await visualReferences(source);
const balancePreferenceReference = await balancePreferenceReferences(source);
const balanceDefinitionReference = await balanceDefinitionReferences(source);
const audioReference = await audioReferences(source,d);
const roomReference = await roomReferences(source, mobileReference.rules, d, maps[0].variants['5'], campaignReference.content);
const spectatorReference = await spectatorReferences(d, source, gameSource, cameraReference.heroView);
const pipReference = await pipReferences(source,d);
const minimapReference = await minimapReferences(source,d);
const presentationFrameReference = presentationFrameReferences(d, gameSource, BattleSim);
const glowOpacity = /opacity: warn \? ([\d.]+) : ([\d.]+)/.exec(gameSource);
const glowColor = /color: warn \? (0x[\da-f]+) : sideInfo\(this.side\).color/.exec(gameSource);
const glowSize = /sp.scale.setScalar\(Math.max\(([\d.]+), Math.max\(h, r \* 2\) \* ([\d.]+)\)\)/.exec(gameSource);
if (!glowOpacity || !glowColor || !glowSize) throw new Error('Source weapon glow style seams missing');
const fixtures = {
  ...snapshotReferences(d, BattleSim),
  ...spectatorReference.fixtures,
  ...pipReference.fixtures,
  ...minimapReference.fixtures,
  ...visualReference.fixtures,
  ...balancePreferenceReference.fixtures,
  ...balanceDefinitionReference.fixtures,
  ...audioReference.fixtures,
  ...roomReference.fixtures,
  ...await blastFeedbackReferences(d, gameSource, source, BattleSim),
  ...presentationFrameReference.fixtures,
  ...hurtBearingReferences(BattleSim),
  ...missileDefenseReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32),
  ...aimingReference.fixtures,
  ...botReference.fixtures,
  ...bossReference.fixtures,
  ...campaignReference.fixtures,
  ...superReference.fixtures,
  ...controlsReference.fixtures,
  ...outlineReference.fixtures,
  ...geometryLodReference.fixtures,
  ...traversalReference.fixtures,
  ...climbReference.fixtures,
  ...mobileReference.fixtures,
  ...combatFeedReference.fixtures,
  ...viewReference.fixtures,
  ...playerViewReference.fixtures,
  ...locomotionReference.fixtures,
  ...carrierReference.fixtures,
  ...abilityRouteReferences(d, BattleSim),
  ...npcReference.fixtures,
  ...waveReference.fixtures,
  ...weatherReference.fixtures,
  ...await environmentReferences(d, BattleSim, maps[0].variants['1'].config, source, gameSource),
  ...sceneryReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32, weatherReference.rules.surface),
  ...sceneReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32),
  ...supplyReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32),
  ...await thirdReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32, source),
  ...matchReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32),
  ...companionReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32),
  ...await fieldReferences(d, BattleSim, maps[0].variants['1'].config, source),
  ...await movementReferences(d, source, gameSource),
  ...statusReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32),
  ...await tickReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32, source),
  ...deathReferences(d, BattleSim, maps[0].variants['1'].config, mulberry32, source),
  ...burstReferences(d, gameSource),
  ...await footprintReferences(d, gameSource, source),
  ...(auditReferencesOnly ? {} : modelReference.fixtures),
  ...cameraReference.fixtures,
  ...structureReference.fixtures,
  ...textureReference,
  ...await celUniformReferences(source),
  ...await trainReferences(source),
  ...await sceneryMotionReferences(source),
  ...await marineReferences(source),
  ...await wildlifeReferences(source),
  ...await petalReferences(source),
  ...await aquaticReferences(source),
  ...missileReference.fixtures,
  ...combatReferences(d, BattleSim, maps[0].variants['1'].config, buildings),
  ...await projectileReferences(d, gameSource, source),
  ...lineReferences(d, BattleSim, maps[0].variants['1'].config, cameraReference.profiles),
  ...await targetingReferences(d, gameSource, source, BattleSim, maps[0].variants['1'].config, cameraReference.profiles),
  reachability: reachabilityReference.reachability,
  volumes: [
    ...Object.entries(d.CHARACTERS).map(([id, ch]) => {
      const actor = {hero:true, kind:ch.kind, ch:id};
      return {kind:ch.kind, side:ch.side, character:id, radius:d.hitR(actor), height:d.hitH(actor),
        eye:cameraReference.profiles[id].ground.eye, forward:cameraReference.profiles[id].ground.forward,
        ground:d.selfCollider(d.heroTargetH(ch.kind,id),false), air:d.selfCollider(d.heroTargetH(ch.kind,id),true)};
    }),
    ...Object.keys(d.UNITS).flatMap(kind => ['SWARM','STEEL'].map(side =>
      ({kind,side,character:'',radius:d.hitR({kind,side}),height:d.hitH({kind,side})}))),
  ],
  rng: Array.from({ length: 32 }, () => rng()),
  shield: [0, 10, 100].flatMap(sp => [0, .3, 1].flatMap(spPierce => [0, .5, 1].map(vsSp => {
    const def = { spPierce, vsSp, vsHp: 1.25 };
    return { def, damage: 80, shield: sp, result: d.shieldSplit(def, 80, sp) };
  }))),
  envelope: [50, 100].flatMap(range => [-150, -50, 0, 25, 100].flatMap(y => [0, 30, 80, 120].map(x =>
    ({ range, delta: [x, y, 0], result: d.inWeaponRange(range, x, 0, y) })))),
  falloff: Object.values(heroes).flatMap(h => Object.values(h.weapons).flatMap(tiers => tiers.map(def =>
    ({ def, samples: [0, .35, .6, 1].map(f => ({ distance: def.range * f, result: d.dmgFalloff(def, def.range * f) })) })))),
  fan: Object.values(heroes).flatMap(h => Object.values(h.weapons).flatMap(tiers => tiers.filter(def => def.fan).flatMap(def =>
    [0, def.fanSubs >> 1, def.fanSubs - 1].flatMap(bin => [0, .3, .7].flatMap(phi => [0.6, 7, 20].map(radius =>
      ({ def, bin, distance: def.range, phi, radius, result: d.fanBinHitD(def, bin, def.range, phi, radius) }))))))),
  zones: [0, 1, 3, 6, 10].flatMap(x => [-5, 0, 5].flatMap(z => [.6, 7, 20].map(radius =>
    ({ offset: [x, z], radius, beam: 5.4, result: d.lanceZones(x, z, radius, 5.4) })))),
};
if (auditReferencesOnly) {
  console.log('SOURCE_REFERENCE_AUDIT_PASS '+JSON.stringify({fixtureSections:Object.keys(fixtures).length}));
  process.exit(0);
}
await mkdir(join(publicationRoot, 'data'), { recursive: true });
for (const [name, value] of Object.entries({ balance: { constants, heroes, unitVolumes,
  structure: structureReference.rules,
  modelGeometry: modelReference.geometry,
  bodies: modelReference.bodyProfiles,
  headMarks: modelReference.headMarks,
  vitalBars: modelReference.vitalBars,
  bodyRules: {...modelReference.bodyRules,gait:locomotionReference.gait,locomotion:locomotionReference.locomotion,rotation:locomotionReference.rotation},
  cockpit: modelReference.cockpits,
  cockpitRules: modelReference.cockpitRules,
  projectileVisual: modelReference.projectileVisual,
  npcShots: modelReference.npcShots,
  weaponEffects: modelReference.weaponEffects,
  firstPersonShields: modelReference.firstPersonShields,
  hurtPresentation: modelReference.hurtPresentation,
  screenSplats: {blood:serialize(d.BLOOD),glint:serialize(d.GLINT),paint:modelReference.splatPaint},
  presentationFrame: presentationFrameReference.rules,
  destruction: modelReference.destruction,
  deathOverlay: modelReference.deathOverlay,
  companions: modelReference.companionProfiles,
  hazard_visuals: modelReference.hazardProfiles,
  loot_visuals: modelReference.lootProfiles,
  hud_feed: {maximum:Number(feedLimit[1]),lifetime:Number(feedLifetime[1])/1000},
  side_unknown: serialize(d.sideInfo(null)),
  civilian_appearance: {occupations:serialize(civilianContent.CIVILIAN_OCCUPATIONS),options:serialize(civilianContent.CIVILIAN_OPTIONS)},
  civilian_visuals: modelReference.civilianVisuals,
  hazard_volumes: Object.fromEntries([...Object.keys(d.HAZARDS),'aasite','relay'].map(kind=>[kind,{radius:d.hitR({kind}),height:d.hitH({kind})}])),
  carrier: carrierReference.rules,
  npc: npcReference.rules,
  wave_rules: waveReference.rules,
  weather: weatherReference.rules,
  cameraProfiles: cameraReference.profiles, cameraRules: cameraReference.rules,
  footprintGlow: { warningOpacity: Number(glowOpacity[1]), opacity: Number(glowOpacity[2]),
    warningColor: Number(glowColor[1]), minimumSize: Number(glowSize[1]), sizeFactor: Number(glowSize[2]) },
  aimingPresentation: aimingReference.rules,
  outline: outlineReference.rules,
  geometryLod: geometryLodReference.rules,
  bot: botReference.rules,
  siege: bossReference.rules,
  super: superReference.rules,
  controls: controlsReference.rules,
  mobile: mobileReference.rules,
  combatFeed: combatFeedReference.rules,
  view: viewReference.rules,
  playerView: playerViewReference.rules,
  visual: visualReference.rules,
  balancePreferences: {...balancePreferenceReference.rules,definitions:balanceDefinitionReference.rules},
  audio: {...audioReference.rules,nativeSamples:'res://assets/audio/native/catalogue.res'},
  rooms: roomReference.rules,
  spectator: spectatorReference.rules,
  pip: pipReference.rules,
  minimap: {...minimapReference.rules,context:modelReference.minimapContext},
  upgrade_curves:Object.fromEntries(Object.entries(d.ECON.UPGRADES).map(([key,up])=>[key,Array.from({length:up.max+1},(_,level)=>d.upgradeCurveMul(key,level))])),
  reachability: reachabilityReference.reachabilityRules,
  missile: {...missileReference.metadata,presentation:modelReference.destruction.missilePresentation},
  projectilePreview: { maxPoints: Number(arcPoints[1]), colors: Object.fromEntries(['close','blocked','aa','high'].map((key, i) => [key, Number(arcColors[i + 1])])) },
  targeting: { coneAngle: Number(coneAngle[1]), lockInterval: Number(lockInterval[1]), obstructionTolerance: Number(obstructionTolerance[1]) },
  movement: { sprint: Number(sprintMatch[1]), slope: traversalReference.rules, climb: climbReference.rules }, charge: Array.from({ length: 4 }, (_, i) => d.chargeF(i)),
  waves: Array.from({ length: 16 }, (_, i) => d.waveComp(i)) }, maps, fixtures,
  narrative: serialize(narrative), campaign: campaignReference.content, structures: structureReference.worlds })) {
  const target=join(publicationRoot,'data',`${name}.json`);
  if(name==='fixtures') {
    if(outputIndex>=0)await writeFixtureJson(target,value);
    else {
      const captured=target+'.capture.tmp';
      await writeFixtureJson(captured,value);
      await partitionFixtures(captured,target,{projectRoot:root,producer});
      const {unlink}=await import('node:fs/promises');await unlink(captured);
    }
  }
  else await writeSourceFile(target,JSON.stringify(value));
}
for (const folder of ['models/reference', 'models/combat', 'models/factions', 'characters', 'avatars', 'mechs', 'mech_avatars']) {
  await cp(join(source, 'public/assets', folder), join(publicationRoot, 'assets', folder), { recursive: true,onFile:recordAssetInput });
}
{
  // Story, loading and logo art: most originals are JPEG bytes under PNG names,
  // so publish native lossless encodings before provenance seals the capture.
  const {launchImageDecoder,encodeNativeImages,writeNativeImageManifest}=await import('./native_images.mjs');
  const browser=await launchImageDecoder(source);
  try {await writeNativeImageManifest(publicationRoot,await encodeNativeImages(browser,source,publicationRoot,producer,recordAssetInput));}
  finally {await browser.close();}
}
await mkdir(join(publicationRoot, 'assets/ui'), { recursive: true });
for (const [id,definition] of Object.entries(controlsReference.rules.statusIcons.definitions)) {
  await writeSourceFile(join(publicationRoot,'assets/ui',`status-${id}.svg`),`<svg xmlns="http://www.w3.org/2000/svg" width="112" height="112" viewBox="0 0 28 28">${definition.svg}</svg>`);
}
await writeSourceFile(join(publicationRoot, 'assets/ui/footprint-glow.png'), Buffer.from(modelReference.glowPng, 'base64'));
await writeSourceFile(join(publicationRoot,'assets/ui/shot-spark.png'),Buffer.from(modelReference.sparkPng,'base64'));
for(const [key,png]of Object.entries(modelReference.spriteTextures))
  await writeSourceFile(join(publicationRoot,'assets/ui',`combat-${key}.png`),Buffer.from(png,'base64'));
await mkdir(join(publicationRoot, 'data/cockpits'), { recursive: true });
await mkdir(join(publicationRoot, 'data/bodies'), { recursive: true });
for (const [key, graph] of Object.entries(modelReference.bodyGraphs))
  await writeFixtureJson(join(publicationRoot, 'data/bodies', `${key}.json`), graph);
for (const [character, graph] of Object.entries(modelReference.cockpitGraphs))
  await writeFixtureJson(join(publicationRoot, 'data/cockpits', `${character}.json`), graph);
await mkdir(join(publicationRoot, 'data/projectiles'), { recursive: true });
for (const [key, graph] of Object.entries(modelReference.projectileGraphs))
  await writeFixtureJson(join(publicationRoot, 'data/projectiles', `${key}.json`), graph);
await mkdir(join(publicationRoot, 'data/companions'), { recursive: true });
for (const [key, graph] of Object.entries(modelReference.companionGraphs))
  await writeFixtureJson(join(publicationRoot, 'data/companions', `${key}.json`), graph);
await mkdir(join(publicationRoot,'data/civilian_parts'),{recursive:true});
for(const [key,graph]of Object.entries(modelReference.civilianGraphs))
  await writeFixtureJson(join(publicationRoot,'data/civilian_parts',`${key}.json`),graph);
await mkdir(join(publicationRoot,'data/npc_effects'),{recursive:true});
for(const [key,graph]of Object.entries(modelReference.npcEffectGraphs))
  await writeFixtureJson(join(publicationRoot,'data/npc_effects',`${key}.json`),graph);
await mkdir(join(publicationRoot,'data/weapon_effects'),{recursive:true});
for(const [key,graph]of Object.entries(modelReference.weaponEffectGraphs))
  await writeFixtureJson(join(publicationRoot,'data/weapon_effects',`${key}.json`),graph);
await mkdir(join(publicationRoot,'data/first_person_shields'),{recursive:true});
for(const [key,graph]of Object.entries(modelReference.firstPersonShieldGraphs))
  await writeFixtureJson(join(publicationRoot,'data/first_person_shields',`${key}.json`),graph);
await mkdir(join(publicationRoot, 'data/hazards'), { recursive: true });
for(const [key,graph] of Object.entries(modelReference.hazardGraphs))
  await writeFixtureJson(join(publicationRoot, 'data/hazards', `${key}.json`), graph);
await mkdir(join(publicationRoot, 'data/loot'), { recursive: true });
for(const [key,graph] of Object.entries(modelReference.lootGraphs))
  await writeFixtureJson(join(publicationRoot, 'data/loot', `${key}.json`), graph);
await cp(join(source, 'public/audio'), join(publicationRoot, 'assets/audio'), { recursive: true,onFile:recordAssetInput });
await writeSourceFile(join(publicationRoot,'data/audio_clips.json'),JSON.stringify(modelReference.audioClips));
await writeSourceFile(join(publicationRoot,'data/audio_synth.json'),JSON.stringify(modelReference.audioSynth));
await writeSourceFile(join(publicationRoot,'data/audio_music.json'),JSON.stringify(modelReference.audioMusic));
await writeSourceFile(join(publicationRoot,'data/audio_move.json'),JSON.stringify(modelReference.audioMove));
await writeSourceFile(join(publicationRoot,'data/audio_probes.json'),JSON.stringify(modelReference.audioProbes));
await cp(join(source, 'LICENSE'), join(publicationRoot, 'LICENSE'),{onFile:recordAssetInput});
const inputs = ['public/index.html', 'public/js/data.js', 'public/js/balancePrefs.js', 'public/js/audio.js', 'public/js/venues.js', 'public/js/venueLanes.js', 'public/js/rng.js', 'public/js/game.js', 'public/js/main.js', 'public/js/biomes.js', 'public/js/ground.js', 'public/js/vfx.js', 'public/js/toon.js', 'public/js/mapBuilding.js', 'server/sim.js', 'out/forest_review/three.module.js'];
const hashes = {};
inputs.push('public/css/style.css');
inputs.push('public/js/lod.js');
inputs.push('public/js/geo3d.js');
for (const file of new Set([...inputs,...assetInputs, ...modelReference.inputs, ...botReference.inputs, ...campaignReference.inputs, ...mobileReference.inputs, ...climbReference.inputs, ...viewReference.inputs, ...playerViewReference.inputs, ...locomotionReference.inputs, ...visualReference.inputs, ...roomReference.inputs])) hashes[file] = createHash('sha256').update(await readFile(join(source, file))).digest('hex');
await verifySourceFiles(source,hashes,sourceBefore);
await verifyGenerator(root,producer);
await verifyWorkspaceInputs(root,workspaceBefore);
await writeSourceFile(join(publicationRoot, 'data/provenance.json'), JSON.stringify({ inputs: hashes,producer,workspaceInputs:workspaceBefore, heroes: Object.keys(heroes).length,
  qualifiedMaps: maps.length, runtime: 'GDScript', sourceLicense: 'Apache-2.0' }, null, 2));
console.log(`Imported ${Object.keys(heroes).length} heroes, ${maps.length} qualified maps and native glTF assets.`);
