# Authority, integration and difficult source semantics — outstanding work

Read [AGENTS.md](AGENTS.md). Current source metadata, fixture coverage and combined
runtime acceptance remain incomplete. Component results do not certify the build.
Publication and fixture commands are in [PUBLICATION.md](PUBLICATION.md); load them
only for lane A. Bounded fixes that blocked this backlog are in
[Sonnet](../sonnet/MIGRATION.md).

## Execution lanes

Select one lane per session and worktree. Files are exclusive between lanes; tasks
inside a lane run one at a time. A task that crosses lanes runs in lane E while
the other affected lane is idle. Shared publication in A stays single-writer.

| Lane | Tasks | Exclusive Opus files |
| --- | --- | --- |
| A — Publication | O25, O26A, O27 | `tools/import_source.mjs`, `tools/world_references.mjs`, other shared `tools/*_references.mjs`, `scripts/content.gd`, `data/` outside SN8's bundles |
| B — Render and numeric contracts | O26B, O3-O5 | `shaders/`, `scripts/source_cel_*.gd`, `scripts/source_outline_*.gd`, `scripts/source_texture_images.gd`, `scripts/source_fixture_sections.gd`, new shared numeric/font adapters, `tools/{outline,cel,texture}_*.mjs` |
| C — Simulation | O6-O17 | `scripts/simulation.gd`, `scripts/unit.gd`, remaining Opus `scripts/*_rules.gd`, `scripts/*_math.gd` and authority helpers |
| D — Session and rooms | O18-O22 | `scripts/session.gd`, Opus `scripts/room_*.gd`, `scripts/actor_snapshot.gd`, `scripts/match_recipe.gd`, `scripts/fatal_watchdog.gd` |
| E — Integration | O23, O24 | `scripts/main.gd`, `scenes/main.tscn`, `project.godot`, export presets, `.github/`, `tests/run.*`, `tests/validation.json`, `tools/test_network.ps1`, `tools/export_web.ps1` |

## Unblocking order

O25 and O26 come first: they release SN8, then every populated case. Sol and Terra
keep the full requests; find them by searching their backlogs for `**Opus`.

- [ ] **O25 — Source identity (lane A):** after SN7, choose one accepted snapshot, then
  refresh provenance, producer declarations and consumer plans once through
  `tools/import_source.mjs`. Covers original `rng.js`, `pool.js`, `lookPrefs.js`,
  `movePrefs.js`, `audio_references.mjs`, `projectile_references.mjs` and the SN7
  consumer changes. Requests: S4's three `rng.js` handoffs, "shared audio fixtures",
  "shared audio provenance/consumer publication", "original presentation pool
  provenance", "shared projectile fixture publication", "current particle
  provenance" and Terra's "spectator, minimap, PiP, scope and dialogue provenance".
- [ ] **O26 — World contracts:** complete before SN8.
  - **O26A (lane A):** "layered-deck reference provenance", including signed-zero
    preservation in `tools/world_references.mjs`.
  - **O26B (lane B):** "exact native source JSON numbers", "float vertex colors" and
    "cel resource metadata". Add "original sign emission" if the selected baseline
    bundle has active glow.
- [ ] **O27 — Story media (lane A):** publish `assets/logo_flat.png` and
  `assets/loading/` from the original checkout through `tools/import_source.mjs`.
  The offline copier preserves authored bytes and excludes source-editor `.import`
  descriptors; if they are also JPEG under PNG names, route them through
  `tools/story_images.mjs` rather than copying. Terra's "story image encoding" and
  "failed story load guard" are implemented (`data/story_images.json`,
  `tests/story_images.tscn`); the full importer's integrated story step has not yet
  run against a source checkout. Focused rerun:
  `node tools/import_source.mjs <source> --story-images [--playwright-module <path>]`,
  then `godot --headless --path . --import` and `res://tests/story_images.tscn`.

Remaining inbound requests follow their files: `shaders/` and shared numeric/font
adapters go to B, simulation and unit contracts to C, session and snapshot
contracts to D, and `scripts/main.gd` or `project.godot` contracts to E.

## Render fidelity

- [ ] **O3 — Full native surface shaders:** translate and mount original toon/
  built-in/School B programs, curve/ink/shadow hooks, material-style/light finish,
  custom vertex/instance attributes and typed uniforms. Compose alpha, shield,
  weather, occlusion and dissolve without losing source frames or material aliases.
  Finish source MRT outline sentinel, shield glyph orientation and alpha/HDR/post
  composition rather than accepting isolated shader compilation as equivalence.
  Captured GLSL/ShaderChunks are source data, not an implemented native shader.
- [ ] **O4 — Outlines and screen edges:** finish source shell visibility/LOD,
  world building detail and the separate screen-space world-edge pipeline.
  Certify world-scale normalization, mirrored/nonuniform/sheared/zero scales,
  source NDC clamps, local expansion, culling, camera masks and PiP isolation.
  Complete shader lighting/curvature agreement and real GPU pixels; a fixed-width
  fallback cannot establish source equivalence.
- [ ] **O5 — Texture/sampler acceptance:** finish colour-space output,
  anisotropy/filter/mip/native GPU equivalence, custom scalar/storage combinations,
  typed sampler and uniform bit fidelity, model/world material binding and
  authored mip handling. Preserve original negative zero, half/float channels,
  explicit null versus undefined, matrix fourth rows and source integer/bool
  coercion. Streaming resolution, virtual pages and demand/eviction lifecycle
  remain unimplemented. Use actual source GPU readback where CPU UV rules differ.

## Coupled simulation semantics

- [ ] **O6 — Weapons/targeting:** finish complete source muzzle/model-centre,
  animated visual-mesh envelopes, source reachability/report/impact timing and
  moving-target hit prediction and combined aiming/body/status behavior.
  Preserve authority lock throttles,
  confirmed-anchor hysteresis, target-dependent ranges, immutable launch frames,
  FNF continuation, direct/fan/line visibility and intentional blast coverage.
  Mesh/rig changes are Models handoffs; harmless effects are Sol handoffs.
- [ ] **O7 — Active abilities/status:** certify cast channels, squared
  interruption fractions, charges/cooldowns, shield/evasion/suppression/critical/
  elemental order, source defensive sectors, healing, phase/reflect and immunity.
  Finish weather/projectile/visibility/aiming/scenery interactions, source
  carrier/clone/summon/hologram lifetimes and complete entity targeting. Cube
  planes and tactical fog need combined LOS, barrier, poison and protection cases.
  Finish populated frame comparison for moving humans/bots, mixed carriers with
  live interception/terrain, lethal environmental paths and room recovery around respawn.
  Preserve bot decisions before advancing the clock, wave anchors based on the
  previous engagement state before recovery, environmental producers between
  carriers and persistent abilities,
  and final missile/history/index cleanup order. Shared combat settlement uses
  the source tick cadence while native movement and kinetic reports retain the
  physics cadence; an isolated scalar frame cannot certify a populated match.
  Preserve the complete dead-snapshot tick barrier, elemental-owner fire credit,
  timed loot affixes through respawn and the early stop when a bot ends a match.
  Populated healing acceptance must retain aura-source BOSS rejection, separate
  hero/entity visits, neutral and radius gates, and once-only start/end reports
  through replacement, owner death and inclusive expiry on both transports.
- [ ] **O8 — Carrier/companion settlement:** certify populated launch origins,
  fractional SUPER counts, bomber drops, kamikaze/hypersonic tracking/scatter,
  interception and owner changes with real terrain and targets. Zero budgets must not
  invent effects. Source companions retain distinct body/sight height bands,
  expiry/lethal swaps, assist/focus/credit rules and no invented summon lifetime.
  Missing generated model content must reject before spending.
  Preserve absent non-helicopter drone altitude through the original consuming
  zero conversion; never fabricate a generated constant. Keep explicit zero
  count overrides and their RNG budgets distinct from fractional defaults.
  Keep private flight/observer altitude, damage-body bands and published visual
  lift separate. Certify native hit areas and visual acquisition on terrain,
  decks and water against those distinct original coordinate frames.
  Populated carrier acceptance must retain separate bomber/kamikaze body rosters
  and the hypersonic hero roster, including dead, absent and restored owners,
  reverse traversal, shared scatter RNG and per-impact reports before settlement.
  Preserve source scalar launch rounding at the hypersonic dive apex; native
  single-precision scene coordinates must not feed back into the trajectory.
  Populated cast acceptance must retain the single captured launch origin and
  its public `carrier`, `origin` and `cast_duration` event contract across both
  transports; missing launch terrain must leave resources and stealth intact.
- [ ] **O9 — Traversal and visibility:** finish complete support/slope/climb/
  collision order on terrain, roofs, bridges, tunnels, galleries, scenery and
  frozen fluids. Preserve source planar progress, per-layer blast separation,
  rooftop height references, grazing-obstacle tolerance, registered pad anchors,
  native crowd pushes and source spawn/clearance. Certify dynamic blockers,
  environmental LOS/team sight, status/field visibility and audibility contracts.
- [ ] **O10 — Movement/environment:** certify charged jump/morph/lift/hover,
  altitude, sink/unbalance, shallow/full/frozen immersion, marine tide lift and
  ice floor/ceiling/DOT behavior in complete tick order. Integrate seven-dimensional
  weather, thermal history, solar/night accuracy, cadence/reload/cooldown/damage,
  independent snow/lightning, fire/quench and full surface/hazard effects.
- [ ] **O11 — Physical scenery:** finish source hazard/vehicle/mine/AA/relay
  seeding, connectivity/corridor pruning, environment indexing, destruction and
  flood movement/jump integration. Preserve source rubble blocking, co-located
  blocker selection, seeded salvage/fire, mine airborne exclusions and AA report
  budgets. Geometry/damage deformation and source scenes are external model inputs.
- [ ] **O12 — Waves/NPC/economy:** certify complete prefill/spacing/cohesion,
  mirrored jitter and combat draws, 8 Hz stepping, held-target/rescan ordering,
  weather/support/traversal and NPC blast settlement. Finish all eight upgrade
  tracks, lane creep upgrades, remote/dead purchases, assists/bounties/penalties,
  loot/affixes/salvage, battery overcharge/recharge deadlines and supply/heal gates.
- [ ] **O13 — Camps/civilians/stats:** finish camp placement/clearance,
  garrison protection/healing, tether/aggro, liberation/respawn and civilian/spy
  follow/away/wander/aid/death behavior. Preserve private spy identity, per-ID
  source body/appearance rules, interaction eligibility and event recipients.
  Complete per-body/squad/mode stats, damage/leaderboards, kill/assist/weighted
  last-hit credit and replay-safe public HUD data.
- [ ] **O14 — Bots:** integrate source difficulty/role policies, constructor
  draws, global/per-operation APM deadlines, threat/alert/scope search, bounded
  turns and action priorities with traversal, BOSS/SUPER and full frame order.
  Preserve original evasion inputs, history retention/backdating, every-third
  light report and resource settlement. Compare seeded complete matches.
- [ ] **O15 — Balance initialization:** certify source preference normalization,
  constructor-time building DPS redistribution, cached range/mobility midpoints,
  first-use reach/curvature/history/role caches and ordinary offline versus
  dedicated factory preferences. Preserve later-slider non-recomputation and
  surviving nonpositive HP after a capacity adjustment until actual damage kills.
- [ ] **O16 — Controls and owner ordering:** certify source wheel/RMB/F/keypad,
  frozen/blind gates, local cast-point capture, confirmed-lock eligibility,
  monotonic mode acknowledgement, empty-heavy fallback, recoil/echo/movement
  order, pre-kick launch direction and distinct RNG/resource budgets. Complete
  authoritative heading/camera/muzzle convergence and combined input/cast/
  purchase timing. Personal/touch/gyro prediction remains a Sol consumer.

## Modes and room lifecycle

- [ ] **O17 — BOSS/campaign/SUPER:** certify authored chapter maps/rosters,
  stage locks, segment upgrades/HP floors, dialogue gates, permanent BOSS death,
  immunity and progress eligibility. Finish SUPER fractional curves, absolute
  body/aim/collision scaling, separate spawn sampling, both-base repairs,
  third-faction stats, auto shop and mode-specific recovery/observer behavior.
  Require generated source resources; missing chapters or SUPER metadata stay
  unavailable. Full transitions, source frame order and chapter lifecycles remain open.
  Populated mode acceptance must retain non-healing HP floors below the authored
  building floor, floor-hit credit/vamp budgets and the source return before BOSS
  synchronization when a shield absorbs all HP damage or an HP floor is active.
- [ ] **O18 — Membership/readiness/loading:** certify logical-seat/physical-
  route separation, bot capacity/selection, ready cancellation, source loaded
  barrier and deferred authority population. Verify live ordinary seat/side edits,
  fixed join mode, unseated vision/input restrictions and no implicit actor
  replacement. Prebuild consumption and progress/error wiring must use Sol's
  actual resource state rather than starting simulation early.
  Positive populated-match acceptance still requires complete authored seasonal
  resources. Certify valid prebuild consumption, structure anchors and exactly-once
  population after all seats load; rejection coverage alone cannot establish this.
- [ ] **O19 — Observers/privacy:** certify explicit/late admission, capacity
  bypass, no readiness/progress contribution, shared world preparation and camera
  restoration. Complete recipient-specific snapshots/events, public special-role
  whitelists, clone/player identity, owner-only magazines/recharge/lift/view,
  status summaries and stale replica clearing across all populated modes.
  Keep complete source weather event frames independent of unit fog filtering,
  including hidden/removed target points, absolute strikes and repeated recipients.
  `tests/snapshot_events_suite.gd` and `-SnapshotEvents` guard publication;
  combined authored-world weather/render/actor-state acceptance remains open.
  Preserve hidden/removed-caster `cast`/`cast_start` reports, defensive radius
  and duration, explicit owner-only recipients and private weapon fields through
  both publication routes. `tests/cast_events_suite.gd` and `-SnapshotEvents`
  exercise original cast producers and native delivery; populated cast rendering,
  missing-caster effect anchors and simultaneous settlement still need combined
  authored-world acceptance.
  Preserve source field reports after actor removal, phase start/exit, reverse
  decoy termination order and once-only expiry through `tests/field_events_suite.gd`
  and `-SnapshotEvents`. Their mesh-free lifecycle fixtures do not certify field
  geometry, damage, crowd-control settlement, decorative identities or rendered
  effects; those still require combined authored-world acceptance.
- [ ] **O20 — Recovery/leave/cleanup:** certify retry backoff, held human
  seats, credential persistence/revisions, stale route revocation, explicit leave
  acknowledgement, owner-seat departure with retained battle bodies and no-human
  cleanup. Preserve latest-120 disconnected input/action FIFO, reliable ordering,
  unsent suffix retention and reclaim-before-flush. Test loss, delay and failure
  without crossing match IDs or leaking private state.
  Keep `tests/room_recovery_suite.gd` failed-head/partial-flush checks and
  `-RecoveryQueue` real-socket checks as transport guards. These isolate the
  native command seam without terrain or combat settlement; populated recovery,
  packet loss/delay and private actor-state acceptance still require authored
  worlds and the separate-process `-Recovery` cases.
- [ ] **O21 — Rematch/replay/fatal lifecycle:** certify retained seats and
  credentials, base re-roll/architecture seed, prebuild invalidation and old-round
  packet rejection. Verify complete quick-start recipes, authored-arena room size,
  source definition identity, isolated storage and story-free quick replays.
  Finish watchdog background-time exclusion, load/snapshot/disconnect errors,
  solo-only restart and first-failure propagation without killing a listener.
- [ ] **O22 — Room services/deployment:** implement only source-defined
  PIN/discovery/multiroom hosting, favorites, public/private directory policy,
  live geographic preparation/qualification, cache refresh and relay fallback.
  Finish remote creation, procedural/random recipes and unsupported custom maps
  when their original semantics exist; never fabricate a map or privacy guarantee.

## Full-build acceptance

- [ ] **O23 — Shared integration:** pull exact cross-owner interface requests,
  regenerate required content once, then run the full current fixture suite,
  populated runtime/render/lifecycle checks and both transports. Audit true
  source event/frame order and platform behavior; focused math or storage checks
  cannot substitute for complete match comparison. Resolve new failures before
  calling a path verified. Current `tests/run.tscn` cannot complete cleanly with
  failed world setup and owner-specific geometry/audio/scenery differences;
  engine errors remain failed acceptance even when a component's assertions pass.
  The current checkout has CRLF/LF byte drift in unchanged pinned fixture
  consumers. Preserve canonical Git bytes when publishing their plan; each owner
  must restore its captured source bytes before a clean local whole-suite rerun.
  Never normalize bytes inside the runtime hash check to hide this mismatch.
  Native fixture consumers must use the generated
  section plan and exact numeric tapes, preserving source order and tolerances.
  Populated core fixtures in `tests/run.gd` and layered blast/bridge/tunnel cases
  in `tests/structure_suite.gd` require the selected authored world;
  missing preparation is an explicit failed acceptance case. Core cases rebase
  source flat-ground heights onto the prepared ground (one shared offset where
  the source compares absolute hero eyes; missiles stay in the altitude frame).
  A case that aborts before freeing its match leaks that world into later cases.
  Campaign deployment still requires authored chapter terrain. Pull failures
  reported by SN9; presentation failures cannot certify populated traversal or
  field interactions.
- [ ] **O24 — Delivery:** certify native exports, mobile sensors/safe areas,
  Compatibility rendering, memory/performance, threaded audio on Web, browser
  single-player, Pages artifact contents and production native hosting. Complete
  transport loss/bandwidth/MTU and cleanup acceptance on the current build.
  Populated snapshots exceed the 64 KiB WebSocket default; validate the 1 MiB
  session buffer against the largest authored match and the Web client.

Baseline commands from the repository root:

```powershell
godot --headless --path . res://tests/run.tscn
godot --headless --path . -- --smoke
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -RecoveryQueue
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -SnapshotEvents
```

Select relevant existing case switches in `tools/test_network.ps1` one per run
for membership/loading/roster, observers, recovery/rematch/restart/fatal, balance,
controls, weapons, bots, BOSS, campaign and SUPER. The wrapper runs ENet and
WebSocket. Use `-Transport enet` and `-Transport websocket` separately when a
failure in the first transport would prevent the second from running. Add
world/model/render/export checks only as required by the change.

## Unsupported source paths

The current source has `SQUAD.N = 1`, `SQUAD.DMG = 1` and `support=false`.
Legacy formation/follow/body-swap/wing salvos and storm/boomerang/tree/moon/
harpoon/link/mine/infection/support helper branches have no active authored
`heroCast` producer. Keep them unavailable unless an active source producer is
found and implemented with original fixtures. This restriction does not disable
the source's active world mines, carriers, clones or autonomous summons.

Keep only current failures and exact interface requests here. Delete completed
items without copying old logs, passed assertion totals or superseded attempts.
