# Opus-unblocking fixes — outstanding work

Read [AGENTS.md](AGENTS.md). Select one task; its exclusive files are in the root
lease table. SN4 and SN6 are blocked as recorded. SN8 waits for the colour consumers it records.
SN9 runs last. Each task records only its current failure.

Local tools: process-local `SVS_SOURCE=C:/Users/user/Documents/app/steel_vs_swarm`,
`PW_CHROME=C:/Users/user/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe`
and Godot at
`C:/Users/user/AppData/Local/Temp/steel-v-swarm-godot/Godot_v4.7.2-stable_win64_console.exe`.

Isolate one suite with
`godot --headless --path . res://tests/run.tscn -- --fixture-suite=tests/<suite>.gd`.
Headless runs use the dummy renderer, which cannot read back MultiMesh data and
rejects the fog scenes. On Linux run real-renderer checks as
`xvfb-run -a godot --rendering-driver opengl3 --path . <scene>`.

## Presentation and lifecycle

- [ ] **SN6 — Cast effects:** add the original consumer to
  `scripts/combat_effects.gd` for the public `character`, `side`, `slot`, `fx`,
  `point`, `radius`, `duration`, `level`, `fraction`, `carrier`, `origin` and
  `cast_duration` reports. Match `public/js/game.js` and `castfx.js`: a hidden or
  removed caster anchors at the effect point, and carrier casts defer their
  destination effect until delivery. Never infer a generic effect from a passing
  publication fixture. Acceptance: a source-based native fixture for both branches,
  with `tests/cast_events_suite.gd` unchanged. Blocked: the source is present now
  (`game.js:5311-5400` `cast_start`/`cast`, `5401-5411` `atkfx`), but the consumer
  needs `spawnCastFx`'s per-character data, which has no native counterpart:
  `PROFILE_ROWS`/`PROFILE_SIGNATURES`/`CFX` (`castfx.js:1780-1904`), `PARTICLE_RECIPES`
  (`castparticles.js`) and `spawnAuthoredCast` (`forge/combatCast.js`). A
  `tools/*_references.mjs` importer, its `data/` output and a fixture producer sit
  outside this lease, and the native simulation emits `ability_arrive`, not `atkfx`
  (`simulation.gd:4440`). Request to Opus/Sol: publish that profile data and its
  source-based fixture; this lease then adds only the anchor (`casterPos` null →
  report `point`, `groundY` from the caster height) and `carrier` deferral. A generic
  effect stays forbidden.

## Test fixtures

- [ ] **SN4 — Model suites:** `tests/body_suite.gd` and `tests/body_{aim,combat,gait}_suite.gd`
  now stream `bodyGeometry`, and `civilian_body_suite.gd` streams `civilianBodyGeometry`
  (the `body_suite` closure is 267,787,693 bytes against the unchanged 268,435,456). Do not
  raise the encoded-byte budget. Remaining: (1) `tests/burst_suite.gd` parents its fixture
  units under a `BattleSimulation`, but cannot run until `assets/bodies/steel_s01.scn` (and
  the other non-kami hero bodies) are published by Models. (2) `civilian_body_suite` fails
  4020 outline-width checks with the incremental reader: civilian `torso` and `pelvis`
  shells report `local_width` .06904542 / min .00303800 / max .00621409 against
  .06829454 / .00300496 / .00614651. Source semantics of `OutlineRules.local_uniforms` after
  appearance scaling need Opus before `scripts/civilian_body_builder.gd` changes. (3) The
  registered consumer hashes are stale for all edited suites (see the O25 request below);
  CI `tools/check_git_storage.mjs --verify-fixtures` stays red until they are published.
  Acceptance: `--fixture-suite=tests/{body,civilian_body,burst}_suite.gd` with empty engine
  error output, on a real driver for the MultiMesh sections.

## Generated content

- [ ] **SN8 — Baseline authored world:** `tools/import_worlds.gd` now refuses a bundle
  whose `deckReferences.sourceFingerprint` or `inputs["public/js/biomes.js"]` differs from
  `source` (verified on `berlin_1_autumn`, which lacks `deckProbes`), and binds O26B's colours:
  `SourceCelVertexColors.encode` into `ARRAY_CUSTOM2` and `material()` for vertex-colour
  surfaces (marine surfaces keep `ARRAY_COLOR`). Godot's JSON parser moves inline colour
  doubles by several ulps (1.3e-15 relative seen; the source values are all Float32-exact),
  so `_float32_colors` snaps values within 1e-12 of their Float32 neighbour and leaves the
  rest for `encode` to reject. `berlin_swap_1_summer` is regenerated end to end (capture,
  provenance, references, native import → `assets/worlds/berlin_swap_1_summer.res`). A scratch
  copy of `tests/worlds.gd` with swap-layout lookup reports exactly 267 failures, all the
  stale `ARRAY_COLOR` check at `tests/worlds.gd:306-314`; every other check passes.
  `berlin_1_{autumn,spring,summer}` are regenerated the same way
  (`data/worlds/` and `assets/worlds/` outputs). On a real GL driver (not `--headless`) a scratch
  copy of `tests/worlds.gd` that skips only the stale colour check at lines 306-314 and reads
  `node.material_override` before `mesh.surface_get_material` at line 278 passes all three
  (`WORLD_TEST_PASS`, ~2.58M checks each). The unmodified test fails on them for two test-side
  reasons: the dummy renderer cannot read `MultiMesh` instances, and non-`surfaces` entries
  such as `SourceMesh_14` (a `MultiMeshInstance3D`) keep their material in `material_override`,
  which the mesh-surface lookup misses (~265 "cel definitions" failures).
  Remaining, all outside this lease: (1) Sol: `tests/worlds.gd:106` finds the map entry with
  `entry.id == map_id`, so every `*_swap_*` bundle crashes; resolve `<id>_swap` through
  `entry.swapped_variants` as `WorldVariant.required` does. (2) Sol/Models: read colours at
  `tests/worlds.gd:306-314` from `ARRAY_CUSTOM2` (exact Float32, no 1/255 tolerance), and bind
  `scripts/{scenery_motion,fire_presentation,mine_presentation}.gd` and the tint copy at
  `scripts/scene_damage_geometry.gd:103` to `uSourceAlbedo` (the `ShaderMaterial` breaks their
  typed `StandardMaterial3D` reads). (3) Opus lane A: publish a numeric tape for inline
  world-chunk colours (`SourceFixtureSections.restore_numbers`) so the snap tolerance can go.
  (4) `tools/migrate_worlds.ps1` reports "Source world selection failed": under Windows
  PowerShell 5.1 `Start-Process -PassThru` leaves `ExitCode` null unless the process handle
  is cached (`$null = $p.Handle`). Not regenerated yet: the other bundles selected by smoke
  and the baseline transports, and `SMOKE_PASS`/transport runs, which wait on (2). The three
  `berlin_1_*` resources are regenerated but stay unqualified until `tests/worlds.gd` and the
  consumers in (2) are fixed. `scripts/room_world_resources.gd`,
  `scripts/world.gd` and the resources must agree, with no early simulation or fabricated
  map. Acceptance: `tests/worlds.tscn -- --bundle=<bundle>`, `SMOKE_PASS` and both baseline
  transport cases. Run alone.

## Requests to other owners

- **Sol — `tests/mobile_suite.gd`:** `mobileTouchPreferences` case 5 carries
  `lookSens: null`, but `ConfigFile.set_value(..., null)` erases the key, so the
  loader sees an absent key (default 1.0) instead of the source clamp of
  `Number(null)` (0.4). Write an empty string for a null fixture value before
  `ConfigFile.save`; `ControlPreferences.normalize` already maps it to the minimum.
  Acceptance: both `lookSens source scalar` assertions pass with no loader change.
- **Sol/Opus — `tests/audio_suite.gd::_buses`:** the centered player check still
  expects the logical gain .35; see the existing `audio_pcm_gain.gd::native_gain`
  request in the Sol backlog. The only remaining `audio_suite` failure.
- **Sol — scenery retirement scenes:** `scenery_binding_retirement` and
  `scenery_host_retirement` each fail one check, "Current scenery producer:
  data/worlds/berlin_1_autumn.json", a stale world producer hash. It clears with the
  corrected world references and SN8 regeneration.

- **Opus — O25 consumer refresh:** publish `refreshFixtureConsumers` for the edited
  `tests/{campaign,death_sequence,burst,civilian_body,body,body_aim,body_combat,body_gait}_suite.gd`;
  their registered hashes are stale and `check_git_storage.mjs --verify-fixtures` fails
  on them in CI. Other owners' sub-suites that `body_suite` preloads still fail on a real
  driver (flame and fire presentation, scene damage, NPC primitives); the streamed
  `body_suite`, `body_aim`, `body_combat` and `body_gait` checks themselves report none. Also unresolved on the shared side:
  `death_sequence_suite` reports 4916 failures (death-camera random order, topple
  and producer frames) with or without the lambda-cycle fix, and `campaign_suite`
  reports only the missing story terrain resources. The raster scenes
  (`aquatic`, `death`, `splat`) mismatch on the software GL renderer and need a
  real GPU run.

- **Models — remaining `MultiMesh.duplicate()` calls:** `scripts/dissolve_binding.gd`,
  `scripts/mobile_damage_geometry.gd` and `scripts/scene_damage_geometry.gd` still
  call `batch.multimesh.duplicate()`, which sets the buffer before the instance
  count in Godot 4.7.2. Use `MultiMeshCopy.of`. Acceptance: their dissolve and
  damage suites on a real driver with empty engine error output.

## Integrated reruns

- [ ] **SN9 — Rerun and report:** after SN8, run the changed `*_network.gd` clocks (body, burst, camera, cockpit, death, footprint, mobile, projectile-visual, TPS and view; they count from `Session.launch_announced` and compare seats through `player_for`/`transport_for`; parse-checked only so far), then
  the root suite, smoke and affected transports, one switch per run. Record each
  failure as an exact Opus request; do not fix authority or lifecycle code.
  - `-Bots` on both transports: `tests/bot_network.gd` now starts mid-lane with the
    target 30 m down the push direction. If it times out, check terrain/building LOS.
  - `-Rooms` on both transports: read `recoveries` in the client failure line. If it
    is zero, the second `_begin` has another source.
  - Aiming, campaign, controls, missile, reachability, room and SUPER clocks have
    not been run since their guard landed.
  - `-Campaign` reported `Unavailable` at `scripts/main.gd:246` in sequential runs;
    check port release before reading it as a mode timeout.
