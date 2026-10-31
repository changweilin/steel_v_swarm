# Opus-unblocking fixes — outstanding work

Read [AGENTS.md](AGENTS.md). Select one task; its exclusive files are in the root
lease table. SN1, SN2, SN4-SN7 can run concurrently. SN8 waits for Opus O25/O26 and SN7.
SN9 runs last. Each task records only its current failure.

Local tools: process-local `SVS_SOURCE=C:/Users/user/Documents/app/steel_vs_swarm`,
`PW_CHROME=C:/Users/user/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe`
and Godot at
`C:/Users/user/AppData/Local/Temp/steel-v-swarm-godot/Godot_v4.7.2-stable_win64_console.exe`.

Isolate one suite with
`godot --headless --path . res://tests/run.tscn -- --fixture-suite=tests/<suite>.gd`.
`--headless` uses the dummy renderer, which keeps no `MultiMesh` buffer. Suites that
read instance transforms need a real driver, for example
`xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --resolution 320x240 res://tests/run.tscn -- --fixture-suite=...`.
A suite whose source changes needs the consumer plan refreshed before the runner
accepts it (see SN4 and SN7); registry edits stay with Opus.

## Presentation and lifecycle

- [ ] **SN1 — MultiMesh copies:** `scripts/multimesh_copy.gd` and its callers are
  done; `tests/view_occlusion_suite.gd` and the climb-arrow, aquatic, wildlife and
  petal `_retirement.tscn` scenes pass on a real driver. Remaining failures:
  `tests/structure_suite.gd` fails its tunnel, layered-blast and bridge cases only
  because `res://assets/worlds/berlin_1_summer.res` is missing (SN8). The
  `scenery_binding_retirement` and `scenery_host_retirement` scenes fail
  `Current scenery producer: data/worlds/berlin_1_autumn.json`: that file's SHA-256
  no longer matches the input hash recorded in `tests/fixtures/train_motion.json`.
  Request for Sol: regenerate the train capture after the world data settles.
- [ ] **SN2 — Preferences and field fog:** the `low_power` key check and the audio
  INI header validation are done; `fog_geometry.tscn` and `fog_retirement.tscn`
  pass, and no engine error is printed by either suite. Remaining failures sit
  outside the lease. `tests/mobile_suite.gd` row `{gyroSens: true, lookSens: null}`:
  `ConfigFile.set_value` erases a `null` value, so the stored file cannot express the
  source `Number(null)` clamp to 0.4. Request for the suite owner: store a JSON `null`
  as a non-numeric string such as `"null"`, which `normalize` already clamps to the
  minimum. `tests/audio_suite.gd` assertion "A centered synthesis layer bypasses
  panning and restores its captured normalization gain" expects `volume_linear` .35,
  but `scripts/audio_voice.gd` now routes it through `PcmGain.native_gain`. Request
  for Sol: confirm the expected silent-clip gain, then update one side.
- [ ] **SN6 — Cast effects:** add the original consumer to
  `scripts/combat_effects.gd` for the public `character`, `side`, `slot`, `fx`,
  `point`, `radius`, `duration`, `level`, `fraction`, `carrier`, `origin` and
  `cast_duration` reports. Match `public/js/game.js` and `castfx.js`: a hidden or
  removed caster anchors at the effect point, and carrier casts defer their
  destination effect until delivery. Never infer a generic effect from a passing
  publication fixture. Acceptance: a source-based native fixture for both branches,
  with `tests/cast_events_suite.gd` unchanged.

## Test fixtures

- [ ] **SN4 — Model suites:** `tests/burst_suite.gd` (units parented under a
  `BattleSimulation`, 0 failures) and the `scripts/civilian_body_builder.gd` owner fix
  (`tests/snapshot_suite.gd` no longer warns) are done. `tests/civilian_body_suite.gd`
  now reads `civilianBodyGeometry` one part at a time and runs in about a minute, but
  the runner still rejects it for the 256 MiB budget because the scanner in
  `tools/fixture_sections.mjs` lists every quoted section name as a preload. Requests
  for Opus: exclude keys passed to `Content.read_fixture_part` from the consumer
  plan, then refresh consumers for `burst_suite`, `civilian_body_suite`,
  `campaign_suite` and `death_sequence_suite` (their sources changed). Remaining
  here: `tests/body_suite.gd` cannot stream `bodyGeometry` while
  `tests/body_aim_suite.gd`, `body_combat_suite.gd` and `body_gait_suite.gd` iterate
  `fixtures.bodyGeometry`; those three need the same part-wise form (Models), after
  which `body_suite` follows. With a raised local budget the civilian suite reports
  4,020 outline-width failures ("appearance-adjusted bind-pose shell widths", width,
  minimum and maximum): the civilian shells never receive the appearance scaling.
  `burst_suite` still logs missing `assets/bodies/steel_s01.scn`-`steel_s12.scn`
  (Models), and its `integration` case needs the berlin_1 world (SN8).
- [ ] **SN7 — Shared fixture corrections:** all five corrections have landed:
  unique staging identity in `tools/fixture_json.mjs` (fixed-clock concurrent writes
  of both writers succeed and leave no stray file), explicit section arrays in the
  four `*_render.gd` scenes, the early-signal and once-only dialogue assertions,
  callback release in `tests/death_sequence_suite.gd` (leaks fell from 72 to 5), and
  byte-unit comparison in `tests/raster_compare.gd` (0/1/2 byte differences pass, 3
  fails, opaque and premultiplied). Remaining: the render scenes' raster comparisons
  (aquatic 6, death 3, glass 6) fail on the software driver and need the real-driver
  captures; `campaign_suite` still lists terrain failures from SN8; the source/native
  raster suites and `tests/campaign_art.tscn` frame 7 have not been rerun with the
  new comparator. Request for Opus (O25): the render scenes' section lists are new
  consumers, and `death_sequence_suite` still leaks 5 objects from `Main` fields and
  `room_world_*` scripts. Hand the 4,916 `deathSequences` failures (random order and
  frame scalars, identical before this change) to Terra.
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

## Integrated reruns

- [ ] **SN9 — Rerun and report:** after SN8, run the changed `*_network.gd` clocks (body, burst, camera, cockpit, death, footprint, mobile, projectile-visual, TPS and view; they count from `Session.launch_announced` and compare seats through `player_for`/`transport_for`), then
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
