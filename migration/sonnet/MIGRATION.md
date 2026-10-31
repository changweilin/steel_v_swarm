# Opus-unblocking fixes — outstanding work

Read [AGENTS.md](AGENTS.md). Select one task; its exclusive files are in the root
lease table. SN1-SN7 can run concurrently. SN8 waits for Opus O25/O26 and SN7.
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
  with `tests/cast_events_suite.gd` unchanged. Blocked: `public/js/game.js` and
  `castfx.js` are absent from this checkout, so neither branch can be derived;
  run it where `SVS_SOURCE` exists and never substitute a generic effect.

## Test fixtures

- [ ] **SN4 — Model suites:** `tests/civilian_body_suite.gd` reads
  `civilianBodyGeometry` partition by partition and `tests/burst_suite.gd` parents
  its fixture units under a `BattleSimulation`; both edits are done but unpublished.
  Remaining: `tests/body_suite.gd` consumes `bodyGeometry` the same way (the other
  sections fit the 256 MiB budget once both large sections are excluded), retaining
  every row, nested frame sequence, rig reset and cross-frame state. Do not raise
  the encoded-byte budget. Blockers: (1) the consumer scan in
  `tools/fixture_sections.mjs::fixtureConsumers` treats any quoted section name as a
  whole-section dependency, so an incremental reader is still preloaded; the scan
  must skip names read through `Content.read_fixture_part` /
  `Content.fixture_registry`. (2) After that, run `refreshFixtureConsumers` for
  O25 because the edited suites changed their registered hashes. (3)
  `civilian_body_suite` then fails 4020 outline-width checks with the
  incremental reader: civilian `torso` and `pelvis` shells report `local_width`
  .06904542 / min .00303800 / max .00621409 against .06829454 / .00300496 /
  .00614651. Source semantics of `OutlineRules.local_uniforms` after appearance
  scaling need Opus before `scripts/civilian_body_builder.gd` changes. (4)
  `burst_suite` cannot run until `assets/bodies/steel_s01.scn` (and the other
  non-kami hero bodies) are published by Models.

## Generated content

- [ ] **SN5 — Companion scenes:** `assets/companions/guer_tank.scn` nodes 61/62 and
  `assets/companions/{steel,swarm,super}_main_battle_tank.scn` nodes 81/82 must match
  the captured `companionGeometry` world bounds and hierarchy within the existing
  tolerance. Change `tools/import_cockpits.gd`, then regenerate with
  `godot --path . res://tools/import_cockpits.tscn -- --companions` on a real driver.
  Acceptance: `tests/companion_suite.gd` with complete spawn, height and lifecycle
  scope. Run alone.
- [ ] **SN8 — Baseline authored world:** blocked by O25, O26 and SN7. After their
  contracts are accepted, bind them in `tools/source_world_meshes.gd` and
  `tools/import_worlds.gd`, then regenerate the bundles selected by smoke and the
  baseline transports through `tools/migrate_worlds.ps1`. All `berlin_1_*` captures
  lack `deckProbes`, so `tools/import_worlds.tscn` rejects them until the corrected
  `tools/world_references.mjs` reruns; the three existing `berlin_1_*` native
  resources are unqualified. `scripts/room_world_resources.gd`, `scripts/world.gd` and
  the generated seasonal resources must agree, with no early simulation or
  fabricated map. The complete manifest stays in Sol S1. Acceptance:
  `tests/worlds.tscn -- --bundle=<bundle>`, `SMOKE_PASS` and both baseline
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

- **Opus — O25 consumer refresh:** publish `refreshFixtureConsumers` after the
  edited `tests/{campaign,death_sequence,burst,civilian_body}_suite.gd` are accepted;
  their registered hashes are stale. Also unresolved on the shared side:
  `death_sequence_suite` reports 4916 failures (death-camera random order, topple
  and producer frames) with or without the lambda-cycle fix, and `campaign_suite`
  reports only the missing story terrain resources. The raster scenes
  (`aquatic`, `death`, `splat`) mismatch on the software GL renderer and need a
  real GPU run.

## Integrated reruns

- [ ] **SN9 — Rerun and report:** after SN3 and SN8, run the changed clocks, then
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
