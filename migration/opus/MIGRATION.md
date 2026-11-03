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
| A — Publication | O26A | `tools/import_source.mjs`, `tools/world_references.mjs`, other shared `tools/*_references.mjs`, `scripts/content.gd`, `data/` outside SN8's bundles |
| B — Render and numeric contracts | O26B, O3-O5 | `shaders/`, `scripts/source_cel_*.gd`, `scripts/source_outline_*.gd`, `scripts/source_texture_images.gd`, `scripts/source_fixture_sections.gd`, new shared numeric/font adapters, `tools/{outline,cel,texture}_*.mjs` |
| C — Simulation | O6-O17 | `scripts/simulation.gd`, `scripts/unit.gd`, remaining Opus `scripts/*_rules.gd`, `scripts/*_math.gd` and authority helpers |
| D — Session and rooms | O18-O22 | `scripts/session.gd`, Opus `scripts/room_*.gd`, `scripts/actor_snapshot.gd`, `scripts/match_recipe.gd`, `scripts/fatal_watchdog.gd` |
| E — Integration | O23, O24 | `scripts/main.gd`, `scenes/main.tscn`, `project.godot`, export presets, `.github/`, `tests/run.*`, `tests/validation.json`, `tools/test_network.ps1`, `tools/export_web.ps1` |

## Unblocking order

O26 comes first: it releases SN8, then every populated case. Sol and Terra keep
the full requests; find them by searching their backlogs for `**Opus`.

The accepted source snapshot is `changweilin/steel_vs_swarm` `634fcf23`, read
from its checkout: `data/provenance.json` pins those exact bytes, including their
line endings. Its deleted faction GLBs have no source consumer and were already
removed from the port. Point `SVS_SOURCE` at that checkout; a commit-exact export
has different line endings and fails the hash check.

Each complete capture redraws the source's unseeded `Math.random` content (audio
noise, animation phases, procedural textures) and the browser's rasters and
decoded PCM. Republishing therefore invalidates native resources derived from
those files, so publish a complete capture only for a source or producer change.

Requests from the published capture:

- **Sol — native audio catalogue:** rerun the audio importers against the
  published `data/audio_{clips,synth,move}.json`. Their noise realization and
  Chromium 151 PCM no longer match the catalogue. Acceptance: `audio_suite` returns
  to its one known `_buses` failure (`tests/audio_clip_suite.gd:30` adds 152 more)
  and `tests/audio_lifecycle.tscn` clears its 6 movement noise/oscillator failures.
- **Lane B — scope backdrop:** `shaders/scope_mask.gdshader` now blurs the composited
  scope layer with the browser's Skia structure (Gaussian to sigma 4, half-resolution
  above it, mirrored edges) and applies opacity to the blur and gradient as one group.
  `tests/scope_raster.tscn` retains 2 failures: case 4 (1 pixel) and case 10 (2 pixels)
  are 3/255 over two bytes at fire 0.35, weather 0.7. RGBA8 rounding after the fire
  layer or the horizontal pass does not explain them. A single pass costs up to 625
  samples per pixel at sigma 4 while fire fog shows, so `scripts/scope_overlay.gd`
  needs separate horizontal and vertical passes before Web and mobile delivery (O24).

- [ ] **O26 — World contracts:** complete before SN8.
  - **O26A (lane A):** "layered-deck reference provenance". The producer is
    finished: `tools/world_references.mjs` on a real `berlin_1_autumn` copy, with
    its captured inputs restored, changes only `collision.deckEndTolerance`,
    `deckProbes` and `deckReferences` and keeps all 99 negative zeros. Remaining is
    the SN8/Sol handoff. Every bundle pins an older `public/js/charPreview.js`
    than the accepted snapshot (`20051639` or `41be0416`), and current tools change
    the generator fingerprints, so `bake_worlds.mjs --reuse` cannot qualify them:
    each selected bundle needs a full recapture through `tools/migrate_worlds.ps1`,
    which already runs the reference step. Do not replace the declared hashes.
    `tools/import_worlds.gd` must reject a bundle unless
    `deckReferences.sourceFingerprint` equals `source.fingerprint` and
    `deckReferences.inputs["public/js/biomes.js"]` equals
    `source.inputs["public/js/biomes.js"]`. Acceptance: `tests/worlds.tscn --
    --bundle=<bundle>` accepts the regenerated bundle and rejects a copy with
    either field altered.
  - **O26B accepted; SN8/Sol binds it in `tools/source_world_meshes.gd`,
    `tools/import_worlds.gd` and `tests/worlds.gd`:**
    - Numbers: `SourceFixtureSections.restore_numbers(tree, float64_bytes)` returns
      `{ok, value}` or `{ok: false, error}`, leaving a rejected tree unchanged. Inline
      values need a published tape restored before `_decode`. `tests/numeric_tape.tscn`
      guards it. `tests/source_json.gd` must assert the restored value: bare
      `JSON.parse_string` still rounds 1,884 of the fixture's 13,280 words.
      SN8's request for a world-colour tape is declined: source colours are Float32, so
      `_float32_colors` recovers their exact bits, while a tape would change the chunk
      format and force a recapture of every bundle for no output change. Doubles that
      are not Float32-exact still need a tape.
    - Colours: for each surface with `vertexColors`, store
      `SourceCelVertexColors.encode(colors, colorSize, vertices).value` in
      `SourceCelVertexColors.ARRAY_SLOT` with `FORMAT` in the surface flags, instead of
      `ARRAY_COLOR`, and use `SourceCelVertexColors.material(base)`. Instance-tinted
      surfaces without vertex colours use `material(base, false)`. `tests/worlds.gd`
      compares that attribute byte-for-byte; remove the importer rejection and the
      1/255 tolerance. Each vertex grows from 4 to 16 colour bytes. `material()` returns
      one shared resource per equal surface state, because a world holds over 230,000
      surfaces and Godot caps material RIDs at 262,144 (exceeding it crashes). Never
      mutate its result: `tools/import_worlds.gd` still writes `render_priority` for
      `entry.water`, which is safe only while those surfaces stay marine. Mesh RIDs share
      that cap and a Berlin world uses 231,753, so two loaded worlds cannot coexist. These are
      `ShaderMaterial`s, so `albedo_color` consumers must use the `uSourceAlbedo`
      parameter: `scripts/scene_damage_geometry.gd` skips its tint copy, while the
      `waterfall_sheet` path in `scripts/scenery_motion.gd` and the typed reads in
      `scripts/fire_presentation.gd` and `scripts/mine_presentation.gd` fail. Bind or
      keep those surfaces out of this path before enabling it. The request's "both
      quality modes" has no port or source counterpart; Compatibility is the only
      renderer. `tests/cel_vertex_colors.tscn` needs a rendered session and passes
      source rasters from `tools/cel_vertex_color_capture.mjs`, not cel shading (O3).
      Negative lit albedo stays unrepresentable because the renderer's decode has no
      real inverse below zero; Berlin autumn and spring have no negative colours.
    - Cel metadata needs no code change: all 232,025 `berlin_1_autumn` declarations
      survive native reload. `assets/worlds/berlin_1_autumn.res` predates its
      recapture, so its `tests/worlds.tscn` run also fails vertices and winding;
      acceptance follows SN8 regeneration.
    - "original sign emission" stays open for bundles with active glow; Berlin autumn
      and spring have none, and the importer rejects any that appears.

Remaining inbound requests follow their files: `shaders/` and shared numeric/font
adapters go to B, simulation and unit contracts to C, session and snapshot
contracts to D, and `scripts/main.gd` or `project.godot` contracts to E.

Accepted contracts awaiting their consumers:

- **Terra:** `SourceNumeric.hypot(x, y)` matches Chromium 151 `Math.hypot` bits
  (`tests/source_numeric.tscn`, corpus from `tools/source_numeric_capture.mjs`); bind it
  in `ViewLockState.advance` and `MinimapVision.shadows`. Browser `Math.sin`/`cos` stays
  open: Chromium and Node disagree, so a native binding needs Chromium's own algorithm.
- **Sol:** a replica's `state_received` fires only for an accepted snapshot; rejected
  packets reach `Session.snapshot_heard`. `control_status.unbalanced` is published.
- **Sol:** `command.move_mag` carries the stick's double magnitude for `InputRules.moving`.
  Relay activation reaches `CombatEffects.spark` from `scripts/main.gd`.
- **Models/SN4 — civilian surface materials:** `MeshInstance3D` releases a surface override
  before its render instance, so `scripts/civilian_body_builder.gd::_part` keeps each one
  alive in mesh metadata; metadata on the part root is not enough. The user directed this
  one line past the SN4 lease; keep it when SN4 publishes that file.
- `tests/run.gd` fails a selected suite whose `run` takes other arguments, so
  `tests/audio_{move,clip}_suite.gd` stay under `tests/audio_lifecycle.tscn`.

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
  Compatibility treats `ALBEDO` as sRGB: `StandardMaterial3D` multiplies albedo,
  texture and vertex colour in encoded space, decodes with a cubic and presents with
  a toeless power curve, so unlit byte 16 outputs 11 and bytes up to 7 output 0.
  Only `shaders/source_vertex_color.gdshader.template` corrects this. Every other
  source material keeps the error, and lit output keeps the curve's dark toe.

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
  calling a path verified. Current `tests/run.tscn` completes on a real GL driver with
  the `berlin_1` worlds; its 180 failures belong to Sol audio and mobile preferences,
  SN4 body streaming and missing campaign terrain, and `burst_suite` stops at its
  script error. `--smoke` needs SN8's `berlin_swap_5_autumn`. Baseline ENet and WebSocket
  pass with empty error logs when a room rolls a generated world; until SN8 finishes, a
  roll of a missing `berlin_swap_1_*` fails the run at preload.
  Engine errors remain failed acceptance even when a component's assertions pass.
  Never normalize bytes inside the runtime hash check to hide a consumer mismatch.
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
  field interactions. CI's `tools/export_web.ps1` `fixtures` step runs
  `tests/run.tscn` on `opengl3_angle`; the headless dummy renderer drops
  MultiMesh and texture data. At `234abb7c`, both Windows ANGLE and Linux
  `xvfb-run` + `opengl3` reported 153 `audio_suite` failures (83 synthesis stem
  provenance, 14 native PCM bytes, 44 gain envelopes, 4 music). Those still
  need an owner. On llvmpipe, `texture_suite`'s 7 cel float-bit checks fail
  because unorm8 sampling is 1 ULP off there; they need ANGLE or a hardware GL
  driver. The `tests/body*_suite.gd` consumer hashes in `data/fixtures.json`
  await the SN4 refresh (`145461ac`).
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
