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

## Presentation and lifecycle

- [ ] **SN1 — MultiMesh copies:** `MultiMeshCopy.duplicate_multimesh` has landed in
  the scenery, climb, aquatic, wildlife and petal presentations and
  `scripts/view_occlusion.gd`. The headless dummy renderer keeps no MultiMesh
  buffer, so instance assertions must run on a renderer: under
  Compatibility/llvmpipe, `view_occlusion_suite` has 0 failures and
  `structure_suite` fails only its three missing `berlin_1_summer` cases. Remaining:
  the scenery binding/host retirement scenes need `data/worlds/berlin_1_autumn.json`
  readable (`ERR_CANT_OPEN` here), and the structure layered cases need SN8's world.
- [ ] **SN2 — Preferences:** the `low_power` and INI-header guards have landed,
  and `tests/fog_geometry.tscn`/`tests/fog_retirement.tscn` pass without a fog change.
  `tests/mobile_suite.gd` still fails both "lookSens source scalar" checks for
  `mobileTouchPreferences` case 5: the suite writes `set_value("input","lookSens",null)`,
  which erases the key in Godot 4.7.2, so `load_save` returns the default 1 instead of
  the source's clamped 0.4. Owner request: persist a representable stored null
  (`tests/mobile_suite.gd` fixture preparation, or the `scripts/control_preferences.gd`
  save format). Acceptance: `mobile_suite` with zero failures and no engine errors.
  `tests/audio_suite.gd`'s remaining "centered synthesis layer" volume check is a
  Sol audio item, not SN2.
- [ ] **SN6 — Cast effects:** add the original consumer to
  `scripts/combat_effects.gd` for the public `character`, `side`, `slot`, `fx`,
  `point`, `radius`, `duration`, `level`, `fraction`, `carrier`, `origin` and
  `cast_duration` reports. Match `public/js/game.js` and `castfx.js`: a hidden or
  removed caster anchors at the effect point, and carrier casts defer their
  destination effect until delivery. Never infer a generic effect from a passing
  publication fixture. Acceptance: a source-based native fixture for both branches,
  with `tests/cast_events_suite.gd` unchanged.

## Test fixtures

- [ ] **SN3 — Network clocks:** the ten `tests/*_network.gd` clocks now count only
  after `Session.launch_announced`, and seat/transport routing goes through
  `Session.seats.player_for`/`transport_for` in the death, mobile, TPS and view
  scripts. All ten scenes parse cleanly. Acceptance: each passes its transport case
  in SN9; the death pair currently stops at the missing seasonal world.
- [ ] **SN4 — Model suites:** `burst_suite` (25,103 assertions; one explicit failure
  while its integration case lacks an authored world), `civilian_body_suite`
  (8,669,007 assertions, peak RSS ~1.5 GB) and `snapshot_suite` (no inconsistent-owner
  warnings) pass. `body_suite` consumes `bodyGeometry`, `bodyWeapons` and `bodyShield`
  per partition, but still exceeds the 256 MiB budget: its nested
  `tests/body_{aim,combat,gait}_suite.gd` read `fixtures.bodyGeometry` (~237 MiB).
  Request (Models suites, outside this lease): read it through
  `Content.read_fixture_part` with a single-quoted key, then refresh consumers and
  rerun `body_suite` at the default budget. Burst poses log missing
  `assets/bodies/steel_s01`-`s12.scn` (Models generated content).
- [ ] **SN7 — Shared fixture corrections:** the section arrays, dialogue clock,
  death-sequence cycle and exact-byte raster comparator have landed. The
  `tools/fixture_json.mjs::writeSourceFile` unique-staging fix is held for O25
  (86 `tests/fixtures/*.json` captures pin the current bytes; see that item).
  On Compatibility/llvmpipe, `tests/{aquatic,death,splat}_render.tscn` fail 6/6,
  3/6 and 4/6 cases with the new comparator, versus 6/6, 3/6 and 6/6 before it.
  Those raster failures belong to their render owners, not SN7.

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
