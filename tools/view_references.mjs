import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

// Offline view-control oracles run the original client and exported helpers.
export async function viewReferences(d, gameSource, mainSource, source) {
  const { grabMethod, grabBlock } = await import(pathToFileURL(join(source, 'tools/audit_src.mjs')).href);
  const THREE = await import(pathToFileURL(join(source, 'out/forest_review/three.module.js')).href);
  const text = gameSource.replace(/\r\n?/g, '\n');
  const main = mainSource.replace(/\r\n?/g, '\n');
  const css = (await readFile(join(source, 'public/css/style.css'), 'utf8')).replace(/\r\n?/g, '\n');
  const scope = { ...d, THREE, lookPref: () => true, document: { body: { classList: { toggle() {} } } } };
  const method = name => new Function(...Object.keys(scope), `return function ${grabMethod(text, name).trimStart().slice(name.length)}`)(...Object.values(scope));
  const cone = method('_coneAcquire'), point = method('_entAimPoint'), foe = method('_isFoeEnt');
  const tick = method('_tickViewLock'), setUi = method('_setVlockUi'), applyLook = method('_applyLook'), cmd = method('_cmd'), maxRange = method('_maxRange');
  const envFog = method('_updateEnvFog'), weatherFog = method('_updateWeatherFog');
  const number = (body, pattern, label) => {
    const found = pattern.exec(body);
    if (!found) throw new Error('Missing original view-control seam: ' + label);
    return Number(found[1]);
  };
  const section = selector => {
    const at = css.indexOf(selector + ' {'), end = css.indexOf('\n}', at);
    if (at < 0 || end < at) throw new Error('Missing original view CSS: ' + selector);
    return css.slice(at, end + 2);
  };
  const rgba = body => [...body.matchAll(/rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)/g)].map(match => [Number(match[1]) / 255, Number(match[2]) / 255, Number(match[3]) / 255, Number(match[4])]);
  const ringCss = section('.scope-vig'), fireCss = section('.env-fog'), weatherCss = section('.weather-fog');
  // The two leading stops are the transparent scope centre; the ring is the repeated third stop.
  const ringStops = rgba(ringCss);
  if (ringStops.length !== 4 || JSON.stringify(ringStops[2]) !== JSON.stringify(ringStops[3])) throw new Error('Original scope ring gradient schema changed');
  const fireColors = rgba(fireCss);
  const weatherBody = grabBlock(main, 'weatherFog: (d) =>');
  const weatherLiteral = rgba(weatherBody);
  const edgeColors = [...weatherBody.matchAll(/rgba\((\d+),\s*(\d+),\s*(\d+),\s*\$\{edgeA\}\)/g)].map(match => [Number(match[1]) / 255, Number(match[2]) / 255, Number(match[3]) / 255, Number(d.WEATHER_FOG_MASK.EDGE_A.toFixed(2))]);
  if (weatherLiteral.length !== 4 || edgeColors.length !== 2 || JSON.stringify(weatherLiteral.slice(0, 2)) !== JSON.stringify(weatherLiteral.slice(2)) || JSON.stringify(edgeColors[0]) !== JSON.stringify(edgeColors[1])) throw new Error('Original scoped/unscoped weather mask palette diverged');
  const weatherColors = [...weatherLiteral.slice(0, 2), edgeColors[0]];
  const black = /#000\s+([\d.]+)%/.exec(fireCss);
  const fireStops = [...fireCss.matchAll(/\)\s+([\d.]+)%/g)].map(match => Number(match[1]) / 100);
  if (fireColors.length !== 2 || weatherColors.length !== 3 || !black || fireStops.length !== 2) throw new Error('Original view-mask gradient schema changed');
  fireColors.push([0, 0, 0, 1]); fireStops.push(Number(black[1]) / 100);
  weatherColors[2][3] = Number(d.WEATHER_FOG_MASK.EDGE_A.toFixed(2));
  const fovStart = text.indexOf('    const wantFov = this.aiming ?');
  const fovEnd = text.indexOf("    if (this.viewMode === 'tps')", fovStart);
  if (fovStart < 0 || fovEnd < fovStart) throw new Error('Missing original FOV block');
  const fovBlock = text.slice(fovStart, fovEnd);
  const rules = {
    seekInterval: number(grabMethod(text, '_tickViewLock'), /_vlockAt \|\| 0\) >= ([\d.]+)/, 'view-lock seek interval'),
    flatMinimum: number(grabMethod(text, '_tickViewLock'), /flat < ([\d.]+)/, 'view-lock flat minimum'),
    near: number(grabMethod(text, '_coneAcquire'), /v.z > -([\d.]+)/, 'view near-plane gate'),
    fogRecovery: number(grabMethod(text, '_updateEnvFog'), /-dt \* ([\d.]+)/, 'fire-fog recovery'),
    fovSpeed: number(fovBlock, /lerpFPS\(([\d.]+), dt\)/, 'FOV interpolation'),
    fovSnap: number(fovBlock, /wantFov\) > ([\d.]+)/, 'FOV snap threshold'),
    frameCap: number(text, /Math.min\(([\d.]+), raw\)/, 'client frame cap'),
    mask: { ringWidth: number(ringCss, /scope-r, [\d.]+vmin\) - ([\d.]+)px/, 'scope ring width'), ringColor: ringStops[2],
      fireColors, fireStops, weatherColors,
      fireTransition: number(fireCss, /transition: opacity ([\d.]+)s/, 'fire-fog transition'),
      weatherTransition: number(weatherCss, /transition: opacity ([\d.]+)s/, 'weather-fog transition'),
      blurPixels: number(grabBlock(main, 'envFog: (v) =>'), /\(f \* ([\d.]+)\)/, 'fire-fog blur'),
      weatherInnerMinimum: number(grabBlock(main, 'weatherFog: (d) =>'), /Math.max\(([\d.]+), r -/, 'weather inner minimum'),
      weatherInnerInset: number(grabBlock(main, 'weatherFog: (d) =>'), /r - ([\d.]+)\)/, 'weather inner inset') }
  };
  const viewScope = [];
  for (const fire of [-1, 0, .25, .8, 1, 2]) for (const weather of [-1, 0, .3, .9, 1, 2]) {
    viewScope.push({ fire, weather, radius: d.scopeRvminFog(fire, weather), stops: d.weatherFogStops(weather) });
  }
  const makeBlock = body => new Function(...Object.keys(scope), `return function(dt,shP=0,shY=0,shR=0) {\n${body}\n}`)(...Object.values(scope));
  const fov = makeBlock(fovBlock);
  const viewFov = [];
  const heroKinds=[...new Set(Object.entries(d.CHARACTERS).map(([id,hero])=>d.heroKindOf(id,hero.side)))];
  for (const kind of heroKinds) for (const air of [false, true]) {
    const base = air ? d.UNITS[kind].fovAir ?? d.UNITS[kind].fov : d.UNITS[kind].fov;
    const camera = new THREE.PerspectiveCamera(base, 1.6, .1, 2000);
    const ctx = { camera, baseFov: base, heroKind: kind, aiming: false }, steps = [];
    for (const input of [{ aiming: true, delta: .016 }, { aiming: true, delta: .033 }, { aiming: true, delta: .1 },
      { aiming: true, delta: 1 }, { aiming: true, delta: .016 }, { aiming: false, delta: .016 }, { aiming: false, delta: .1 }, { aiming: false, delta: 1 }]) {
      ctx.aiming = input.aiming; const before = camera.fov; fov.call(ctx, input.delta);
      steps.push({ ...input, before, wanted: input.aiming ? d.UNITS[kind].zoomFov ?? base : base, result: camera.fov });
    }
    viewFov.push({ kind, air, steps });
  }
  const fogResetAt = text.indexOf('    this._fireDwell = 0; this._swampDwell = 0;');
  if (fogResetAt < 0) throw new Error('Missing original death fog reset');
  const clearFog = makeBlock(text.slice(fogResetAt, text.indexOf('\n', fogResetAt)));
  const viewFog = [];
  for (const flight of [false, true]) {
    const ctx = { pos: new THREE.Vector3(), fires: [{ x: 0, z: 0, r: 8 }], _env: { air: false }, _fireDwell: 0, _scopeFog: 0, _weatherFogD: 0,
      _flying: () => flight, hud: {}, envFx: { getWeatherDynamics: () => ({ effectiveFog: .7 }) } };
    const steps = [];
    for (const input of [{ delta: 1, x: 0 }, { delta: 3, x: 8 }, { delta: 6, x: 0 }, { delta: .1, x: 8.001 },
      { delta: .5, x: 0, air: true }, { delta: 4, x: 9 }, { delta: .2, x: 0 }, { delta: 0, dead: true }]) {
      ctx.pos.x = input.x ?? 0; ctx._env.air = !!input.air;
      if (input.dead) clearFog.call(ctx, 0); else { envFog.call(ctx, input.delta); weatherFog.call(ctx); }
      steps.push({ ...input, weather: .7, result: { dwell: ctx._fireDwell, fire: ctx._scopeFog, weather: ctx._weatherFogD } });
    }
    viewFog.push({ flight, steps });
  }
  const V = values => new THREE.Vector3(...values.map(Math.fround));
  const entries = rows => rows.map((row, index) => ({ id: index + 1, side: row.side ?? 'SWARM', neutral: !!row.neutral, hero: !!row.hero,
    dead: !!row.dead, dimTop: 0, dimH: 0, cut: row.cut, mesh: { position: V(row.point), visible: row.visible !== false } }));
  const context = (entities, camera) => ({ side: 'STEEL', pos: V([0, 0, 0]), camera,
    canvas: { clientWidth: 1440, clientHeight: 900 }, _scopeFog: 0, _weatherFogD: 0, aiming: false,
    ents: new Map(entities.map(item => [item.id, item])), _entAimPoint: point, _isFoeEnt: foe, _coneAcquire: cone,
    _obstHitT: (...coords) => entities.find(item => item.mesh.position.toArray().every((value, index) => value === coords[index + 3]))?.cut ?? null });
  const candidates = ctx => [...ctx.ents.values()].map(item => ({ id: item.id, point: point.call(ctx, item).toArray(),
    eligible: foe.call(ctx, item) && item.mesh.visible && !item.dead, obstruction: item.cut ?? null }));
  const viewRosters = [];
  const layouts = [
    { name: 'left-to-right NPC/tower/hero', rows: [{ point: [8, 2, -100], hero: true }, { point: [-18, 2, -100] }, { point: [0, 2, -100] }] },
    { name: 'stable same-x order', rows: [{ point: [0, 10, -90] }, { point: [0, 2, -100] }, { point: [0, -8, -100] }] },
    { name: 'camera-behind and near gate', rows: [{ point: [0, 2, 0] }, { point: [0, 2, -.04] }, { point: [0, 2, -.06] }] },
    { name: 'eligibility', rows: [{ point: [0, 2, -100], side: 'STEEL' }, { point: [1, 2, -100], neutral: true },
      { point: [2, 2, -100], dead: true }, { point: [3, 2, -100], visible: false }, { point: [4, 2, -100] }] },
    { name: 'LOS tolerance', rows: [{ point: [0, 2, -100], cut: 98.9 }, { point: [1, 2, -100], cut: 99.5 }, { point: [-2, 2, -100] }] },
    { name: 'body-centre range', rows: [{ point: [0, 2, -200] }, { point: [0, 2, -199.9] }, { point: [0, 205, -20] }] },
  ];
  for (const layout of layouts) for (const viewport of [[1440, 900], [800, 1200], [0, 0]]) for (const scoped of [false, true]) for (const fog of [0, 1]) for (const keep of [null, 1, 2]) {
    const camera = new THREE.PerspectiveCamera(scoped ? 35 : 68, (viewport[0] || 1) / (viewport[1] || 1), .1, 2000);
    camera.position.set(0, 2, 0); camera.updateMatrixWorld(true);
    const ctx = context(entries(layout.rows), camera); ctx.aiming = scoped; ctx._weatherFogD = fog;
    ctx.canvas.clientWidth = viewport[0]; ctx.canvas.clientHeight = viewport[1];
    const options = { ndc: true, lim: d.VIEW_LOCK.EDGE, keepLim: d.VIEW_LOCK.DROP, hero: false, keepId: keep };
    const list = cone.call(ctx, 200, { ...options, list: true });
    viewRosters.push({ name: layout.name, viewport, scoped, fire: 0, fog, keep: keep ?? 0, reach: 200,
      position: ctx.pos.toArray(), frame: camera.matrixWorld.elements.slice(), projection: camera.projectionMatrix.elements.slice(), candidates: candidates(ctx),
      result: list.map(item => ({ id: item.ent.id, off: item.off, x: item.x })), choice: cone.call(ctx, 200, options)?.id ?? 0 });
  }
  // Probe view edges with the original camera inverse and acquisition method.
  for (const scoped of [false, true]) for (const keep of [null, 1]) for (const edge of [.99999, 1.00001, 1.24999, 1.25001]) {
    const camera = new THREE.PerspectiveCamera(68, 1.6, .1, 2000); camera.position.set(0, 2, 0); camera.updateMatrixWorld(true);
    const radius = d.scopeRvminFog(.5, .3) / 100 * 900;
    const ndc = scoped ? edge * radius * 2 / 1440 : edge;
    const point = new THREE.Vector3(ndc, 0, .5).unproject(camera);
    const ctx = context(entries([{ point: point.toArray() }]), camera); ctx.aiming = scoped; ctx._scopeFog = .5; ctx._weatherFogD = .3;
    const opt = { ndc: true, lim: d.VIEW_LOCK.EDGE, keepLim: d.VIEW_LOCK.DROP, hero: false, keepId: keep };
    viewRosters.push({ name: 'view-edge hysteresis', viewport: [1440, 900], scoped, fire: .5, fog: .3, keep: keep ?? 0, reach: 200,
      position: ctx.pos.toArray(), frame: camera.matrixWorld.elements.slice(), projection: camera.projectionMatrix.elements.slice(), candidates: candidates(ctx),
      result: cone.call(ctx, 200, { ...opt, list: true }).map(item => ({ id: item.ent.id, off: item.off, x: item.x })), choice: cone.call(ctx, 200, opt)?.id ?? 0 });
  }
  const rotationStart = text.indexOf('      this.camera.rotation.set(0, 0, 0);', text.indexOf('    const eye = this._eyeH();', text.indexOf('  _updatePlayer(')));
  const rotationEnd = text.indexOf('\n      this._cameraDeClip();', rotationStart);
  if (rotationStart < 0 || rotationEnd < rotationStart) throw new Error('Missing original FPV recoil composition');
  const composeCamera = makeBlock(text.slice(rotationStart, rotationEnd));
  const deadLockLine = '    this._vlockId = null; this._vlockPrev = null; this._setVlockUi(false);';
  if (!text.includes(deadLockLine)) throw new Error('Missing original dead view-lock reset');
  const clearLock = makeBlock(deadLockLine);
  const viewLocks = [];
  for (const pitch of [0, 1.4, -1.4]) for (const yaw of [0, 3.12, -3.12]) {
    const axis = new THREE.Euler(pitch, yaw, 0, 'YXZ');
    const entities = entries([-20, 0, 20].map(x => ({ point: new THREE.Vector3(x, 0, -100).applyEuler(axis).add(new THREE.Vector3(0, 2, 0)).toArray() })));
    const camera = new THREE.PerspectiveCamera(68, 1.6, .1, 2000); camera.position.set(0, 2, 0);
    const notifications = [];
    const ctx = Object.assign(context(entities, camera), { yaw, pitch, recoil: { p: .08, y: -.04 }, roll: .03,
      _vlockHold: false, _vlockNext: false, _vlockId: null, _vlockPrev: null, _vlockAt: 0, _vlockUi: false,
      dead: false, paused: false, shopOpen: false, hud: { feed: value => notifications.push(value) }, _applyLook: applyLook,
      _curWeapon: () => ({ def: d.heroWeapon('t01', 'light', 1) }), _maxRange: maxRange, _setVlockUi: setUi });
    composeCamera.call(ctx, 0); camera.updateMatrixWorld(true);
    const steps = [];
    for (const step of [{ kind: 'press', on: true, now: 10, delta: .016 }, { kind: 'tick', now: 10.016, delta: .016 },
      { kind: 'release', now: 10.03, delta: .016 }, { kind: 'press', on: true, now: 10.04, delta: .033 },
      { kind: 'tick', now: 10.18, delta: .05 }, { kind: 'hidden', id: 2, now: 10.2, delta: .02 },
      { kind: 'freeze', now: 10.23, delta: .02 }, { kind: 'thaw', now: 10.26, delta: .02 },
      { kind: 'paused', now: 10.3, delta: .03 }, { kind: 'resume', now: 10.4, delta: .03 },
      { kind: 'press', on: true, now: 10.5, delta: .016 }, { kind: 'death', now: 10.6, delta: 0 },
      { kind: 'press', on: true, now: 10.61, delta: .016 }, { kind: 'release', now: 10.7, delta: .016 },
      { kind: 'respawn', now: 10.8, delta: .016 }, { kind: 'press', on: true, now: 10.9, delta: .016 }, { kind: 'tick', now: 11.1, delta: .033 }]) {
      const before = [ctx.yaw, ctx.pitch]; notifications.length = 0;
      if (step.kind === 'press') cmd.call(ctx, 'lock', true);
      if (step.kind === 'release') cmd.call(ctx, 'lock', false);
      if (step.kind === 'hidden') ctx.ents.get(step.id).mesh.visible = false;
      if (step.kind === 'freeze') ctx.freezeLeft = 1;
      if (step.kind === 'thaw') ctx.freezeLeft = 0;
      if (step.kind === 'paused') ctx.paused = true;
      if (step.kind === 'resume') ctx.paused = false;
      if (step.kind === 'death') { clearLock.call(ctx, 0); ctx.dead = true; }
      if (step.kind === 'respawn') ctx.dead = false;
      const frame = camera.matrixWorld.elements.slice(), projection = camera.projectionMatrix.elements.slice();
      if (!ctx.dead) tick.call(ctx, step.delta, step.now);
      composeCamera.call(ctx, 0); camera.updateMatrixWorld(true);
      steps.push({ ...step, before, frame, projection, notices: notifications.slice(), candidates: candidates(ctx), result: { hold: ctx._vlockHold, cycle: ctx._vlockNext,
        target: ctx._vlockId ?? 0, previous: ctx._vlockPrev ?? 0, last_seek: ctx._vlockAt, lit: ctx._vlockUi, angles: [ctx.yaw, ctx.pitch],
        basis: camera.matrixWorld.elements.slice(0, 12) } });
    }
    viewLocks.push({ yaw, pitch, viewport: [1440, 900], position: [0, 0, 0], eye: [0, 2, 0], reach: maxRange.call(ctx, d.heroWeapon('t01', 'light', 1)), recoil: [.08, -.04, .03], steps });
  }
  const viewFoes = [];
  for (const side of ['STEEL', 'SWARM', 'SUPER', 'GUER']) for (const target of ['', 'STEEL', 'SWARM', 'SUPER', 'GUER', 'MILI']) for (const neutral of [false, true]) {
    viewFoes.push({ side, target, neutral, result: foe.call({ side }, { side: target, neutral }) });
  }
  return { rules, inputs: ['public/css/style.css'], fixtures: { viewScope, viewFov, viewFog, viewRosters, viewLocks, viewFoes } };
}
