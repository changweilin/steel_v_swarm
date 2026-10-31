# Native integration and resource pipelines — outstanding work

Read [AGENTS.md](AGENTS.md). S12-S14/S20 and their consumer handoffs are
Terra-owned; task IDs remain stable. Written implementations and source captures still
need current integrated acceptance. Shared shader translation and music envelope
semantics have separate Opus ownership; actor model construction is Models-owned.

## Seasonal resources and scenery

- [ ] **S1 — Complete world publication:** produce and qualify the complete
  original manifest, including ordinary seasons, both base assignments and
  authored campaign seasons. Enumerate current requirements and existing outputs
  from the tools; road-only resources cannot satisfy seasonal availability.
  Missing captures must never select an invented map or fallback season.
  Use `node tools/world_publication_inventory.mjs --summary` to compare exact
  seasonal bundle names against the imported catalog. Detailed JSON includes
  per-bundle source identity, LFS/malformed/missing states and native binary
  presence; legacy names remain unselected. This availability inventory never
  qualifies sidecars, source provenance, native reload, rendered content or full
  match parity. Cover it with `tests/world_publication_inventory.test.mjs` and
  the existing `tests/world_selection.test.mjs`.
- [ ] **S2 — World storage/packing acceptance:** verify ordered chunk/numeric
  sidecars, exact float64 bits, raw/GZIP shapes/hashes, complete feature tables,
  cancellation and atomic publication. Bound peak memory through traversal and
  ResourceSaver publication; finish resource reload, complete rendered appearance
  and populated lifecycle checks on the full set, including actual tunnel cases.
  Use all four seasons of `taroko_1_*`, `taroko_swap_1_*`, `taroko_2_*` and
  `taroko_swap_2_*` as original populated tunnel inputs: retain each freshly
  sampled world's 200 tunnel records and six decks, their geometry and source
  metadata through native packing/reload before rendered and traversal
  integration acceptance. Their source
  storage/provenance gates do not qualify native numbers, material fidelity,
  layered-deck references, tunnel pixels or full seasonal-world availability.
  Also qualify all four seasons of both base assignments for team sizes 3/4,
  each with 248 captured tunnels and 46 decks, and team size 5, with 239 tunnels
  and 50 decks. Preserve the distinct source geometry, cel programs and climb
  records; another team-size recipe cannot stand in for a required configuration.
  Qualify all four seasons of `berlin_1_*` and `berlin_swap_1_*` through native
  packing/reload with their own original elevation frame, deck tables and complete
  scenery. Preserve the source grid and lane-height words; old largest-variant
  elevation samples cannot stand in for these smaller configurations. Source
  storage/provenance and frame checks do not discharge native materials,
  rendered appearance, populated retention or transport acceptance.
  Berlin small-team capture provenance declares `public/js/charPreview.js` hash
  `20051639891092dd6ad2303a9c95c3484b7d778e567175e4548b2fed897686ea`.
  The original working tree changed that input after capture, so the current
  provenance gate rejects these archives. Obtain the matching original input or
  regenerate against stable source inputs before reuse/reference/native
  publication; do not replace declared hashes to make stale captures pass.
  Both capture and reuse revalidate complete original provenance immediately
  before atomic manifest publication. Retain the previous manifest and published
  sidecars when inputs, existing assets or declared missing assets change during
  capture. Keep `tests/world_capture_publication.test.mjs` with provenance and
  storage regression coverage. Publication-helper fingerprints participate in
  source identity; archived captures need regeneration before current-tool reuse.
  Capture/reuse publication also authenticates every referenced mesh chunk and
  numeric sidecar before replacing the manifest, then rechecks original provenance
  after that storage pass. Missing/corrupt dependencies or inconsistent chunk
  counts leave the previous manifest and cache files untouched. Keep raw and GZIP
  publication-boundary cases in `tests/world_capture_publication.test.mjs`.
  Keep compressed-candidate and existing-sidecar hashing streamed; never buffer
  a complete numeric sidecar just to determine its size or verify its digest.
  Run `tools/verify_world_source.mjs <bundle>` between capture/reuse and reference
  publication. It verifies the selected identity, contiguous chunks, every numeric
  dependency, streamed hashes and bounded GZIP extents without decoding complete
  numeric buffers into memory. A matching generator fingerprint never establishes
  that ignored/untracked sidecars are present. `tools/migrate_worlds.ps1` must stop
  before reference/native publication on any storage failure; this storage gate
  does not establish complete scenery, source provenance or rendered parity.
  Run `tools/verify_world_provenance.mjs <bundle>` separately for declared original
  input/asset bytes and both provenance fingerprints. Hash original files through
  bounded streams, reject paths/links outside the source root, and preserve
  declared missing-asset identity. `tools/migrate_worlds.ps1` runs this gate before
  references and again before native packing; source changes must stop publication.
  This gate does not establish generator freshness, extraction-helper/reference
  semantics, native shader fidelity or match parity. Keep the dedicated
  `tests/world_provenance.test.mjs` failure/immutability cases.
  Content-addressed mesh chunks also require length/hash validation before reuse;
  reject corrupt existing chunks without rewriting them. Cache verification by
  complete storage path: identical bytes can belong to both numeric and chunk
  namespaces, and raw/GZIP suffixes require independent native authentication.
  Keep the six cross-path corruption cases and valid repeated/shared-digest
  reads in `tests/world_storage.tscn`. Legacy packing must
  dispose its writer on failure while retaining the original manifest and any
  already-published sidecars. Keep the child-process failure cases in
  `tests/world_source.test.mjs` alongside native reload coverage.
  Native numeric/chunk GZIP must consume the complete single member emitted by
  the source writer. Godot's whole-buffer decoder ignores trailing data; retain
  the bounded `StreamPeerGZIP` input-consumption/extent check before native
  member validation. Reject second members, garbage tails and expanded output
  beyond the declared extent without changing the source files. Keep valid
  high-ratio/multi-window and numeric/chunk tail cases in `tests/world_storage.tscn`.
  The offline gate likewise requires the writer's single, unflagged GZIP member:
  stream raw DEFLATE, require exact compressed-input consumption, and validate
  native CRC32 plus ISIZE without retaining complete numeric buffers. Reject
  empty additional members, zero padding, unsupported header flags and truncated
  input as well as checksum/extent failures. Keep these numeric/chunk cases and
  high-ratio/multi-window probes in `tests/world_source.test.mjs`; offline Node
  must provide native CRC32 support. This storage contract does not qualify
  native source-number decoding, materials or complete seasonal worlds.
  Browser transfer, inline mesh chunks and final metadata publication must retain
  signed zero. `tools/source_json.mjs` uses native `JSON.rawJSON` and a copy-on-write
  adapter for the shared streaming publisher; reject unavailable native support
  instead of falling back to ordinary `JSON.stringify`. Capture fingerprints
  include the serialization helpers/storage writer, so prior captures require
  regeneration. Keep `tests/source_json.test.mjs` alongside storage regression tests.
  Browser and legacy mesh transfer share `tools/source_mesh_transfer.mjs`.
  Within one mesh, transmit identical large numeric arrays once, using full
  scalar-bit, rank and row-width equality, including signed zero. Retain first
  encounter order and independent transfers for any differing word/shape;
  never merge by approximate equality or a sampled/hash-only match. The helper
  belongs in serialization fingerprints. Keep `tests/source_mesh_transfer.test.mjs`
  and the original Chromium sphere probes in `tools/source_json_capture.mjs`;
  complete chunk bytes must equal the prior separate-field wire contract.
  Transfer large numeric parts as canonical base64 float64-LE frames through
  `tools/source_numeric_transfer.mjs`; retain JSON for captured metadata. Validate
  rank, row widths, exact byte extent, finite words and canonical base64 before
  writing. JSON and binary parts share the same ordered writer, hashing,
  publication and retirement path. Keep `tests/world_binary_transfer.test.mjs`,
  `tests/source_numeric_transfer.test.mjs` and both retirement-entry variants;
  raw/GZIP manifests and complete chunks must match the prior JSON-part output.
  Original Chromium sphere probes exercise the binary writer and native reload;
  that success never discharges the separate inline-number precision gate.
  `node tools/source_json_capture.mjs` records original Chromium sphere-buffer bits;
  real-driver `tests/source_json.tscn` checks JSON, sidecar and native resource
  roundtrips. Retain its strict inline-number failures until the shared native
  number-decoding contract below is accepted; binary-sidecar success does not
  certify complete source numerics or full worlds. Interrupted capture chunks
  without a completed manifest never count as a published seasonal bundle.
  Publish marine shader includes through the native atomic publisher before the
  containing world, retaining their final content-addressed paths. Reuse requires
  byte-hash verification and a fresh native load; corrupt existing includes must
  remain untouched. `tests/world_shader_publication.tscn` checks dependency reload
  and retained-reader isolation, not marine shader pixels or complete worlds.
  Existing Berlin and Taroko seasonal source captures are partial inputs, not
  world-set certification. Refresh stale generator fingerprints before source reuse.
  Decode elevation mosaics only for selected source venue IDs; base-swapped and
  campaign aliases retain their original `source_id` mapping and candidate order.
  Capture provenance includes Chromium version and JavaScript execution flags;
  reuse requires that same runtime identity as well as current source/generator
  fingerprints. Flat world-attribute capture retains normalized/interleaved
  getters, source scalar order and signed zero without temporary per-vertex
  arrays. Float64 capture buffers keep large copies outside the ordinary object
  heap; plain and typed scalar buffers retain identical inline JSON, f64-le
  frames, alias/rank decisions and raw/GZIP publication bytes. Transfer large
  meshes individually; batch inline records within 16 rows/4 MiB, sending an
  oversized row whole. Collect retired copies after their producer frame returns
  using a 64 MiB wire budget, retaining original mesh/chunk order and publication
  bytes. Keep both transport/attribute helpers in serialization fingerprints and
  `tests/world_mesh_transport.test.mjs`/`tests/world_attribute_capture.test.mjs` alongside binary
  transfer/storage cases. These bounds do not waive complete storage/provenance,
  resource reload or source/native appearance acceptance.
  Stop browser producers before disposing an interrupted mesh writer. Close its
  live numeric handles and remove only its successfully opened raw/GZIP temporary
  paths; retain published content-addressed sidecars and rejected existing files.
  Writer temporary identities must remain unique within one process and clock
  tick. Keep `tests/world_source.test.mjs` disposal/ownership checks alongside
  native reload coverage; they do not qualify world content or publication.
  Retirement drains admitted directory preparation, numeric opens/writes and
  atomic chunk publication before cleanup, including a still-running sibling
  after initialization fails. Concurrent callers share one retirement promise;
  cancelled operations cannot return a completed manifest. Retain completed
  manifests, published cache files and foreign temporary paths. Keep the delayed
  I/O cases in `tests/world_source_retirement.test.mjs` with storage acceptance.
- [ ] **S3 — Terrain/scenery content:** finish source triangular terrain,
  dry-band/wet-grid, water/swamp, imagery, OSM facilities/buildings, habitat,
  complete biome orchestration and edge geometry capture. Retain original
  divider-band classification order, image-colour/border-band classifiers,
  slab/roof/portal metadata and pad anchors. Reject uncaptured classifiers.
  World geometry production stays here; authority LOS/support/traversal is Opus.
  Regenerate remaining seasonal captures with per-variant elevation frames,
  including swapped layouts; older captures reused the largest variant's raw
  grid for smaller team sizes. Source provenance/storage cannot establish the sampled
  frame. Preserve each selected configuration's original `battleRect`, elevation
  layer center, Float32 writes and resampling order, including the matching source
  cache key; acquire coverage only for selected sizes. Keep
  `tests/world_elevation_capture.test.mjs` and the elevation-helper fingerprint:
  every source query and complete Float32 grid must match the original terrain
  sampling loop. This does not qualify complete terrain or populated worlds.
  Capture the original low-resolution imagery input with
  `node tools/capture_world_imagery.mjs <bundle>` and qualify it separately with
  `node tools/verify_world_imagery.mjs <bundle>`. Retain the original image entities,
  raw pre-style RGBA, separately styled display RGBA, projection constants and
  pixel-boundary probes. Source functions are extracted without executing unrelated
  module initialization; this isolated gate does not waive full-world RNG gates.
  Preserve transparent RGB, `validOnly`, null/undefined outcomes, source rounding,
  complete tile coverage and single-member GZIP extents. Keep
  `tests/world_imagery_*.test.mjs` with corruption, retirement and source-seam cases.
  These archives do not qualify high-resolution road observations, codecs on other
  platforms, native geography/classification, populated scenery or complete worlds.
  **Opus handoff:** implement the original double geographic projection in
  `scripts/source_world_geography.gd`, returning original latitude/longitude and
  rounded pixel coordinates from scalar client-frame `(x,z)` and captured metadata.
  Preserve operation order, radians, `Math.round`, bounds and nonfinite semantics;
  do not pass inputs through Float32 vectors or sample the styled image. Acceptance:
  exact `constantsLE`, `pointLE` and `projectionLE` words plus the raw-RGB/null/
  undefined probes in `data/world_imagery/*.json`, including pixel edges and alpha
  validity. Sol binds the accepted helper and raw pixel reader through
  `scripts/world.gd`/`tools/import_worlds.gd` in a separate change; retain the current
  imagery rejection until that complete contract is accepted.
- [ ] **S4 — Animated scenery:** certify trains, articulated pivots, boundary
  facilities and waterfalls against source frame order, endpoints, parent frames,
  wind and capped/zero deltas. Finish wildlife, petals/leaves and aquatic
  bubble/fish/jelly/detritus/vessel/wake motion, Float32 write order, source
  constructor-time power/density budgets, route/habitat admission and per-instance
  resource isolation. Finish original starting-time-dependent scenery selection;
  do not regenerate populations on a later preference change.
  Preserve source double Euler state and evaluate unbounded rotor spin before
  native Float32 storage, retaining the original YXZ order and wind reversal.
  `node tools/scenery_rotor_capture.mjs` and real-driver
  `tests/scenery_rotor.tscn` cover original part/edge/waterfall frame programs,
  large fractional rotor phases and long wind reversals. Their synthetic geometry
  isolates motion; these checks do not qualify scenery meshes or populated worlds.
  `node tools/train_motion_capture.mjs` and real-driver
  `tests/train_motion.tscn` retain the original train-driver programs plus the
  captured Berlin autumn routes, including native PackedScene disk reload.
  Preserve their source/path fingerprints and existing transform tolerances;
  route replay does not certify train model geometry, random constructor-phase
  selection or complete seasonal-world retention.
  Wildlife construction retains source `write(0, weather)` and constructor
  activity, then advances its own staggered route states; do not substitute an
  elapsed wind clock at construction or rebuild populations for live preferences.
  `node tools/wildlife_native_capture.mjs` and real-driver
  `tests/wildlife_native.tscn` cover original habitat/motion programs, capacity
  prefixes, full/low budgets, constructor activity boundaries and saved instance
  buffer isolation. Synthetic probe geometry does not qualify original animal
  meshes, rendered habitats or complete seasonal population/transport retention.
  Wildlife bindings close on native root deletion while surviving staging
  detachment and reparenting. Weak observers match generation and instance ID;
  queued roots reject frames. Rebinding or retirement during terrain queries
  cancels the old writer before subsequent queries or instance writes, releasing
  private buffers and borrowed callbacks with closed owners retained.
  `node tools/wildlife_writer_capture.mjs` and real-driver
  `tests/wildlife_retirement.tscn` isolate the original writer with explicit
  state/limb probes; they do not execute RNG, route construction or integration,
  qualify authored animal geometry, or replace the full wildlife gate above.
  **Opus handoff:** reconcile `data/provenance.json` through
  `tools/import_source.mjs` with the original `public/js/rng.js` consumed by
  wildlife initialization. The full capture genuinely executes that dependency;
  retain its source guard and the failing `tests/wildlife_native.tscn` check.
  Acceptance requires matching source provenance and the complete original
  constructor, capacity, habitat and integration programs without dropping RNG
  inputs or substituting the scoped writer oracle.
  Aquatic school headings retain an unbounded source double angle; derive the
  quaternion before native storage. `node tools/aquatic_native_capture.mjs` and
  real-driver `tests/aquatic_native.tscn` cover original bubbles, detritus, fish,
  jellies, vessel/wake frames and private buffers, including large environment
  clocks. Their probe geometry does not qualify source model pixels or full worlds.
  Aquatic hosts and independent detritus controllers retain private buffers,
  particle phases and bubble RNG across staging transfers. Physical root/leaf
  deletion closes the matching weak binding; obsolete or duplicated observers
  cannot retire replacements. Queued owners reject updates, and retirement seals
  aliased system dictionaries before releasing owned point controllers, native
  vertex/instance buffers and RNG references. Real-driver
  `tests/aquatic_retirement.tscn` uses explicit state/point/sphere probes to check
  those lifetimes with closed controllers retained. It does not replace original
  factory/frame qualification, material pixels or full seasonal-world acceptance.
  **Opus handoff:** reconcile `public/js/rng.js` in shared provenance through
  `tools/import_source.mjs`. Aquatic constructors and original bubble recycling
  genuinely execute that dependency; retain the full producer and failing
  `tests/aquatic_native.tscn` guard. Acceptance includes all original aquatic
  initialization, reset RNG, large-clock motion and vessel/wake programs without
  omitting source inputs or changing the existing transform tolerances.
  `node tools/aquatic_point_capture.mjs` captures original PointsMaterial pixels
  through locally fulfilled, fingerprinted source modules. Run real-driver
  `tests/aquatic_render.tscn -- --source-capture` for the independent six-case
  oracle; the default shared-fixture guard remains unchanged. Preserve the failed
  point-pixel gate until the shared shader contract below is accepted.
  Petal landing uses original XYZ orientation with a fixed horizontal tilt and
  the accumulated double orbit phase; do not quantize that phase before evaluating
  its quaternion. `node tools/petal_native_capture.mjs` and real-driver
  `tests/petal_native.tscn` retain seasonal/prewarm budgets, grounding/fade/re-lift,
  directed invalid-input boundaries and original render matrices. Large seeded
  phase cases also compare normalized orientation independently of tiny petal
  scale. Declared crown/quad probes do not qualify original foliage/flower meshes,
  material pixels or complete seasonal world composition.
  Petal controllers preserve their captured clock/population and private material
  bindings across staging transfers. Native root deletion closes the weak binding;
  generation/observer identity guards isolate replacements and duplicated roots.
  Queued roots and retired owners reject later frames, and interrupted landing
  queries stop before later callbacks, cached landing writes or instance updates.
  Real-driver `tests/petal_retirement.tscn` checks these ownership boundaries with
  explicit grounded/quad probes and retained closed owners. It does not qualify
  source planning, motion, animal/foliage geometry or rendered seasonal worlds.
  **Opus handoff:** reconcile the original `public/js/rng.js` provenance through
  `tools/import_source.mjs` before full petal qualification. Both
  `public/js/petals.js::petalRnd` and the original field constructor consume that
  dependency; retain the full capture and `tests/petal_native.tscn` source guard.
  Acceptance requires the original seasonal/full-low planning, prewarm and all
  frame/transition programs without omitting RNG or loosening existing tolerances.
  Borrowed scenery pivots and train visuals retain their controllers across
  staging detachment/reparenting, without rebuilding phases or private materials.
  Native deletion closes the binding through a weak observer; match its binding
  generation and instance identity so old or duplicated observers cannot retire
  a replacement. Queued pivots/visuals reject later updates, and terminal
  controllers release source/node/material references and reject reconfiguration.
  Real-driver `tests/scenery_binding_retirement.tscn` replays original motion/train
  programs and checks transfers, rebinding, duplication, paused deletion and
  retained-controller material/curve release. Its waterfall quad and empty train
  model isolate ownership; they do not qualify authored geometry, complete world
  retention or populated transport/prebuild barriers.
  Scenery hosts also close on source-root deletion, sealing aliased owned-node
  lists, landmark records, private batch caches and child controllers before
  callbacks. Late frame/camp commands cannot advance shared clocks or revive the
  host; retirement never resets the module-global wind/wave/gust phases.
  Independent camp events retain both removals, while replacement roots stop old
  cache/frame continuations. World stepping rejects queued/deleted source roots
  and stops subordinate updates when a callback replaces the host binding.
  Real-driver `tests/scenery_host_retirement.tscn` retains source-program replay,
  staging/duplicate/rebind checks, native private-buffer isolation and resource
  release with closed hosts retained. Cache/geometry/callback probes and the
  fresh clock-only fixture contract do not establish complete scenery pixels,
  seasonal publication or populated world/transport/prebuild acceptance.
  Climb-arrow owners preserve their source flow phase and private instance buffers
  across staging transfers, then close terminally on native root deletion.
  Generation/observer identity guards isolate replaced and duplicated roots;
  queued roots and retired owners reject later updates. Release borrowed route
  references without clearing the authority caller's accepted roster.
  `node tools/climb_arrow_capture.mjs` runs the original arrow constructor,
  unit-bar geometry and update callback with declared route probes. Real-driver
  `tests/climb_arrow_retirement.tscn` retains its initial/long-clock transforms,
  unchanged matrix tolerance and native private-buffer ownership checks. This
  presentation-only capture executes no authority route planner and cannot
  qualify route admission, populated traversal, material pixels or complete worlds.
- [ ] **S5 — Environment appearance:** finish cloud/fog-bank detail,
  precipitation, celestial bodies, deposits/scorch, contact effects,
  shoreline/underwater/waves/reflections and
  source wind/wave/gust/tide/ripple/vessel coupling. Bind the shared shader owner's
  accepted materials; certify weather style/low-power transitions and full
  seasonal rendered composition. Weather damage and hazards remain authority-owned.
  Marine surface hosts close on native root deletion while staging transfers
  preserve private materials and incremental scan progress. Retain the unbound
  scan-only source-fixture contract; queued bound roots and retired owners reject
  updates. Root generation/observer identity guards isolate replacements. Water
  and ground-code callbacks may replace or retire the scanner; stop old row/cell
  continuations and global ripple updates after either boundary. Reflection
  visibility callbacks also stop later opacity writes and revision commits.
  Retirement releases terrain callbacks, wave buffers and private child bindings,
  but never resets module-global ripple slots, packets or cooldown.
  `node tools/marine_native_capture.mjs` captures the original extracted packet,
  hash and six scanner/ripple programs with their actual source dependencies;
  real-driver `tests/marine_retirement.tscn` replays them alongside native
  root/material ownership checks. Declared shader/quad probes isolate lifetime;
  they do not certify original marine shader pixels, authored surface geometry,
  full seasonal retention or transport/prebuild barriers.
  Native weather owners configure once, then close terminally on detachment.
  Prepare sky, light and private particle resources before world admission;
  reentrant publications retain the newest weather and original construction
  seed. Seal resource maps and lightning records before callbacks, stop stale
  property/frame writes and preserve independent strike batches. Unbind retired
  environments immediately, then drain queued sky resources through one native
  `frame_post_draw` callback independently of the closed node before final release.
  `node tools/weather_owner_capture.mjs` retains twelve original Node/Chromium
  precipitation-profile cases; real-driver `tests/weather_retirement.tscn` checks
  native profile bindings, interruption, expiry and retained-owner resource release.
  Also run it with `-- --live-exit` for active-owner application shutdown. Setter
  probes isolate property-boundary cancellation; these checks do not qualify
  original sky/cloud/fog/precipitation pixels, particle trajectories, authored
  lightning geometry or complete seasonal/transport acceptance.
  Full `weatherFx.js` particle/rain-impact/lightning constructors execute the
  original `mulberry32`; they remain gated by the shared RNG provenance request
  below. Profile-only captures cannot replace that constructor dependency or
  qualify the current native GPU emitters as original particle trajectories.
  Fire flicker/drift uses the same local wall clock as loot, independently of
  incoming authority times and render deltas. Retain authored origin/scale doubles
  until final native Float32 writes; extinguished nodes keep their prior pose.
  The first visible smoke update disables depth writes and updates private source
  material metadata, preserving that state across later quench/recovery.
  `node tools/fire_clock_capture.mjs` and real-driver `tests/fire_clock.tscn`
  retain the original client/animation/weather functions, large clock phases,
  exact scalar/Float32 outputs and private packed-resource isolation. Their
  declared node probes use imported FX records; they do not qualify original
  constructor geometry, full shader pixels, populated worlds or transport delivery.
  Fire owners also close terminally on detachment. Complete private meshes,
  node indices, outline bindings and world pose before admission; reject late
  commands before sampling clocks. Sync/frame generations stop interrupted
  visibility, opacity and smoke-depth continuations. Retirement clears weather
  ownership without mutating the caller's dictionary, and world reuse acquires
  a fresh owner. Real-driver `tests/fire_retirement.tscn` replays the original
  frame oracle and checks reentrant cancellation plus deferred private-resource
  release while owners remain retained. It does not qualify the missing full
  constructor/shader/world or populated transport acceptance.
- [ ] **S6 — Room resources/prebuild:** finish populated seasonal-world retention,
  cancellation/retry and tree transfer in offline, ENet and WebSocket sessions.
  Isolated lifecycle fixtures cannot establish complete-world dependency retention
  or population/barrier behavior. Preserve request-time tickets across synchronous
  readiness callbacks and the complete map/environment/architecture identity;
  name-only edits must reuse one tree, with no early processing or population.
  Shared loading/barrier handlers are Opus integration requests.
  Resource retirement invalidates tickets and readiness immediately, then drains
  each native request independently of the retired node without waiting for its
  decoder. Pending `prepare()` calls return a signal that resolves to the native
  resource or cancellation; its waiter retains only a weak loader reference.
  Keep source requests active during SceneTree pause and preserve reentrant
  detach/reattach/replacement from progress callbacks. Run
  `tests/room_resource_retirement.tscn`, `tests/room_world_lifecycle.tscn` and
  WASAPI `tests/audio_loop_loading.tscn` for shared-drain regression coverage.
  Held decoder resources isolate lifecycle contracts; they do not certify actual
  seasonal scene content, populated-world retention or the transport barrier.
  Prebuild detachment also retires unfinished staging viewports, invalidates
  readiness and resolves pending transfers as cancellation. Reattachment requires
  a fresh request. Resource/build continuations and transfer waiters retain only
  weak owner references; destination loss must leave a valid ready tree reusable.
  Seal transfer ownership before native reparent callbacks, so a callback's fresh
  request cannot be cleared by the preceding transfer. Run
  `tests/prebuild_retirement.tscn` alongside existing room lifecycle checks.
  Recheck destination admission after synchronous reparent callbacks. A queued
  or detached destination cancels the transfer before processing is enabled;
  restore the same disabled world and its identity to staging only while the
  original cache generation remains current. Publish rollback ownership before
  reparent/readiness callbacks so fresh requests, clears and retirement win.
  Superseded cancelled transfers release their obsolete tree and viewport.
  Real-driver `tests/prebuild_transfer_cancellation.tscn` checks reuse without
  rebuilding, zero early process/physics ticks and replacement callbacks at
  destination entry, staging re-entry and rollback readiness. Its existing held
  fixture world does not certify seasonal geometry or populated transport barriers.
  Destination loss probes queue deletion at destination entry or detach during
  source exit. Removing an ancestor while its child is entering violates native
  tree notifications; use deferred deletion at that boundary.
  Staging viewport/world loss must cancel pending transfers and invalidate both
  building and ready state. Reject queued staging before allocation/build and
  revalidate factory callbacks before admitting their output. Notify replacement
  listeners after native tree-exit notifications finish; repeated transfer
  rollbacks must rebind loss observers to the restored generation. Run real-driver
  `tests/prebuild_stage_lifetime.tscn` with the retirement and transfer fixtures;
  held worlds isolate lifecycle behavior without qualifying seasonal content.
  Held build signals exercise retirement without qualifying seasonal geometry.

World workflow, from the repository root:

```powershell
node tools/bake_worlds.mjs --list-bundles
node tools/world_publication_inventory.mjs --summary
node tools/verify_world_source.mjs berlin_1_autumn
node tools/verify_world_provenance.mjs berlin_1_autumn
./tools/migrate_worlds.ps1 -Godot C:/path/to/godot_console.exe -Bundle berlin_1_autumn
godot --headless --path . res://tests/worlds.tscn -- --bundle=berlin_1_autumn
node --test tests/world_source.test.mjs tests/world_selection.test.mjs
godot --headless --path . res://tests/world_storage.tscn
godot --headless --path . res://tests/room_world_lifecycle.tscn
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy res://tests/seasonal_prebuild.tscn -- --bundle=berlin_1_autumn
```

The selected bundle is an example, not a substitute for completing the manifest.
The wrapper runs capture, source references and native packing sequentially.

## Audio playback and application binding

- [ ] **S7 — Source audio/native import:** certify decoded take order, full
  frames, normalization, mono/stereo routing, PCM/synthesis resources, retained
  BGM position/fallback, first gesture and independent sample RNG. Verify original
  sample rate/resampling, source codec failure and complete native audible output.
  `node tools/capture_audio_sample_waveforms.mjs <rate>` captures all seven
  original OGG takes through `_loadSamples`/`decodeAudioData` and `_playSample`.
  Bind original module/asset bytes, producer fingerprints and the matching SFX
  context's exact bytes, Chromium version and flags. Retain normal, missing,
  decode-failure and low-power loader programs; the BGM callback is a declared
  transport probe, not music playback. Keep complete decoded Float32 channels
  and all three jitter draws at each of three pans, at gain .35, in
  `data/audio_sample_waveforms/`.
  `tests/audio_sample_waveforms.test.mjs` authenticates this corpus and requires
  exact original linear interpolation, last-frame extrapolation, Float32 gain
  and EOF silence for both channels of every centered probe. Source reservation
  uses the original double jitter, independently of the Float32 AudioParam rate.
  `tests/audio_sample_mix_render.tscn` compares the complete 48,000 Hz corpus
  through WASAPI with an independent PCM timing tracer, never target-signal
  alignment. Its bounds contain measured input PCM conversion, interpolation's
  L1 gain and Float32 mixer error. Keep imported PCM, clip identity and logical
  duration immutable. Imported samples use `scripts/audio_sample_stream.gd` to
  feed source linear interpolation directly into native Float32 generators;
  do not requantize the output or scan/convert a complete take on the input frame.
  Prime only the existing driver-derived startup budget, then let the single
  context-owned `scripts/audio_sample_worker.gd` service one 128-frame refill
  per voice per pass at high priority. An empty worker sleeps on a native
  semaphore until admission or shutdown. Native buses and panners retain their
  channel/gain contracts; generic loop and synthesis callers remain separate.
  The independent PCM tracer precedes generator source frames by the known
  128-frame inactive refill, not a searched waveform offset. Godot 4.7.2's full
  generator input latency is 194 frames. Requalify it when changing Godot.
  Finish only after the native context has mixed the complete source body plus
  that latency. Keep feeding EOF silence until deferred retirement is received,
  including through UI stalls; stop and join the context worker before releasing
  native buses. Asynchronous feed failures retire their voice and reach the
  existing manager failure signal without redrawing or refunding its reservation.
  Reject unsupported sample codecs, loops, stereo stems, incomplete PCM and
  unrepresentable rates explicitly. Keep the native resource-retirement,
  manager-budget and panning checks with this waveform capture.
  Run this scene with `--stress` and each of `--stress-offset=0`,
  `--stress-offset=24` and `--stress-offset=48` to cover all captured rate/pan
  programs under the original 24-voice budget and a 1.2-second
  UI stall. Compare the complete summed waveform against independently traced
  source starts and require zero generator skips, immutable inputs and drained
  mixers/routes. Retain the manager's source selection/budget fixtures plus
  worker-start/queue rejection and real-underrun failure propagation in
  `tests/audio_manager_retirement.tscn`. Routing retirement must also join sample
  and movement workers together in `tests/audio_owner_retirement.tscn`.
  Full waveform agreement after the timing marker does not qualify physical
  input-to-device latency, driver suspension or device-rate changes.
  The matching-rate corpus does not qualify other device rates, the legacy
  catalogue's cross-rate decoded samples, physical audible delivery or complete
  music/noise publication. Keep S7 open until these distinct gates pass.
  The registered `tests/audio_suite.gd` centered-layer assertion still compares
  physical WAV volume with logical .35. Retain decoder compensation; the expected
  physical gain is `native_gain(wave, .35)` from the existing
  `scripts/audio_pcm_gain.gd` helper. Correct this Sol-owned assertion only with
  coordinated Opus republication of its consumer fingerprint in
  `data/fixtures.json`; editing the registered test alone rejects suite loading.
  Acceptance is the same centered bus and compensated physical gain, without a
  wider tolerance. The leased preference parser's malformed-ConfigFile engine
  error remains a separate root-suite acceptance issue.
  `node tools/capture_audio_sfx_rate.mjs <rate>` captures the original SFX
  synthesis at an explicit context rate without executing procedural music,
  movement construction or sample decoding. Keep its complete sound/gain corpus,
  shared original noise, post-envelope filters, source/producer fingerprints and
  Chromium identity in `data/audio_sfx_rates/`. The 48,000 Hz profile supplies
  source waveforms and stems for native mixer integration; it does not switch
  the resource catalogue. Bind matching-rate native resources before rate
  selection is available. `tests/audio_sfx_mix_render.tscn` compares every source
  sound/gain waveform through the actual device mixer, using a separate PCM
  timing tracer and the existing quantization/envelope/filter error budgets.
  Run it with WASAPI at the captured device rate; its private muted routes do not
  establish complete audible delivery. `tests/audio_synthesis_import.tscn` checks
  the shared import factory against existing resource identities and rejects
  malformed captures. Keep WAV decoder compensation at the playback boundary
  (`scripts/audio_pcm_gain.gd`); preserve captured PCM, logical gains and generator
  gains. Requalify this decoder contract when changing the Godot version.
  Preserve the original context's shared noise across synthesis, movement and
  music; do not silently combine an isolated rate profile with another capture's
  noise generation when publishing a complete native catalogue.
  `node tools/capture_audio_move_rate.mjs <rate>` extends an existing SFX rate
  archive with original movement graphs, oscillator periods and filter impulses.
  Reuse its exact archived noise buffer without another `_buildNoise` call;
  bind the parent archive bytes, source/producer fingerprints and Chromium
  version/flags before publication. `tools/audio_move_import.gd` is the shared
  native bank factory for the existing importer and explicit rate captures.
  `tests/audio_move_rate_import.tscn` checks matching-rate native reload and
  unchanged legacy resource identity. Keep `tests/audio_move_rate.test.mjs`
  alongside the SFX capture tests. Tonal oscillators use complete integer cycles
  at the native rate when one original period has a fractional frame count;
  retain the cycle count in the bank, playback phase and resource fingerprint.
  Preserve legacy one-period resource identities. A compatible shared-noise
  music cohort remains required before switching the runtime catalogue.
  Full publication and samples-only retention must load and verify every
  synthesis/movement/music dependency and reject missing or differing shared
  noise fingerprints/context rates before changing the catalogue. Decode every
  referenced sample through a fresh native load and authenticate its semantic
  fingerprint; both its numeric `sampleRate` declaration and every PCM stream
  rate must match that same context. Samples-only retention validates both the
  previous index's samples and newly imported samples before copying retained
  resource metadata. A matching original audio-module hash does not make captures
  at different context rates interchangeable. Keep missing/corrupt clips,
  missing/string/mismatched rate declarations, actual PCM-rate changes and the
  real 48,000 Hz source-take collision with the shipped 47,360 Hz cohort in
  `tests/audio_resource_catalogue.tscn`; every rejection retains the published
  catalogue and leaves the partial candidate unbound. Oscillator
  period representation rates are independent of the shared noise context.
  Keep this gate in `tools/import_audio.gd` and the mismatched-cohort publication
  cases in `tests/audio_resource_catalogue.tscn`. A consistent declaration alone
  does not establish source waveform parity or qualify cross-rate reconstruction.
  Verify raw shared-noise Float32 bytes against their SHA-256 before movement
  PCM conversion or rate-profile qualification. Reuse `tools/audio_noise_import.gd`
  for exact one-second dimensions, canonical encoding and finite-word checks;
  `tests/audio_noise_import.tscn` compares the actual original capture generations
  and retains the existing movement resource identity after verified import.
  Preserve the existing 47,360 Hz music representation and its integral onsets;
  do not relabel or rescale captured SFX rates. Run `tests/audio_sfx_rate.test.mjs`
  alongside full-source capture checks. Other device rates, codecs, resampling
  and delivery remain separate acceptance requirements.
  Keep SFX clips content-addressed by PCM, full-precision normalization gains,
  stream format/rate/loop layout and original take/source identity. Publish the
  catalogue last through the atomic native resource publisher; never overwrite
  an existing fingerprint path or remove a prior catalogue's referenced clips.
  New sample libraries read a fresh catalogue snapshot and verify every clip
  before registering the complete batch. Synthesis, music fallback and movement
  also use verified content-addressed resources behind the same catalogue switch.
  One `BattleAudio` owner shares a lazy index snapshot across all consumers;
  late loads retain that generation, while acquisition can retry until a valid
  index exists. Regenerate legacy catalogues with `tools/import_audio.tscn`.
  Samples-only publication retains a complete index only when its source agrees
  and every retained dependency verifies; it cannot establish a missing full index.
  `tests/audio_catalogue.tscn` covers native reload, staged replacement and
  retained-reader isolation; `tests/audio_resources.tscn` checks original PCM and
  take order. `tests/audio_resource_catalogue.tscn` covers staged interruption,
  complete index replacement, delayed reads, exact resource identities, partial
  import retention and corruption rejection. These checks do not establish codec
  parity, actual device suspension, audible waveform parity or transport delivery.
- [ ] **S8 — Mixer and voice lifecycle:** certify native SFX/BGM settings,
  panning, bus/filter order, initial dedup timestamp, cap reservation grace and
  playing-stream lifetime. Malformed legacy negative SFX polarity stays explicitly
  unavailable; do not convert it into positive gain. Music envelope correctness
  is an Opus-owned blocker, not a tolerance adjustment here.
  Music, ambience, fallback and loop-player detachment is terminal: stop timers,
  release streams, disconnect envelopes and reject reattachment or late commands.
  Routing retirement must stop every live consumer before removing native buses,
  including SFX and movement workers. Track admitted children before callbacks;
  reentrant disposal cannot resume configuration or allocate another voice.
  `tests/audio_owner_retirement.tscn` checks native routing loss, paused detachment,
  held-decoder drainage and isolated original music/ambience/movement programs.
  Its isolated source gate does not replace full lifecycle provenance acceptance.
  Manager configuration and unlock must stop after synchronous retirement;
  queued owners/routes reject playback before touching deduplication or RNG.
  Reentrant voice/player admission cannot continue allocating, consume a take
  after cancellation or reserve a partially started voice. Manager retirement
  closes all consumers and emits one routing retirement notification.
  `tests/audio_manager_retirement.tscn` combines these native interruption cases
  with isolated original gate/count/sample programs from
  `data/audio_manager/fixtures.json`. Keep its exact numeric tapes and producer
  fingerprints; this dedicated capture does not discharge shared fixture gates.
  Validate every previously admitted SFX player after native admission callbacks;
  cancellation of the current/earlier player or routing stops later allocations
  and rejects the voice before playback or budget reservation. Once routing is
  bound, failed admission retires the owner and disconnects the old route observer.
  Preserve already-consumed private sample draws. Physical player loss closes the
  voice and stops all stems, while ordinary stem completion still waits for the
  remaining stems. Keep these sample/synthesis cases and route-drain checks in
  `tests/audio_manager_retirement.tscn` alongside native mixer captures.
- [ ] **S9 — Movement/location audio:** certify lazy permanent location beds,
  source channel allocation, noise/oscillator reconstruction, synchronized frame
  timing, filter modulation, tunnel/fluid/terrain queries and low-power ownership.
  Verify fade-out retention, driver suspension, buffer latency, thread shutdown,
  scheduling/performance and threaded Web export with actual mixer output.
  Keep source admission in scalar doubles: subtract native coordinate components
  before `sqrt(dx * dx + dz * dz + dy * dy)` in that order. Pan and camp distance
  reuse `CarrierRules.hypot2`; density interpolation must not round intermediate
  cell coordinates through native vectors. `node tools/audio_scene_precision_capture.mjs`
  executes original selection/location methods and the literal 32-character
  profile table under Node and Chromium without unrelated data-module/RNG startup;
  `tests/audio_scene_precision.tscn` compares exact Float64 parameters, 200 m
  admission, near-equal winner order, hero flight thresholds, winning stomp
  queries, planar panning/camp and cached four-cell interpolation. Keep
  `tests/audio_scene_precision.test.mjs` and the existing numeric-transfer tests.
  These character/terrain-query probes do not certify actor constructors, actual
  terrain admission, mixer delivery or populated frames.
  `node tools/capture_audio_move_waveforms.mjs <rate>` captures the original
  static movement graphs with the exact archived shared noise, including dry,
  blended and wet stomp. `tests/audio_move_waveforms.tscn` compares every frame
  through private muted native routes. Use independent WAV/generator timing
  traces, source-measured oscillator-table errors, original filter impulses and
  PCM conversion bounds; never align by searching the audio being tested.
  Add `--automation` to that capture command and `-- --automation` to the native
  scene to exercise the original `setMove`/`_stopMove` gain, pan, complementary
  dry/wet and stop curves. Keep source-recorded targets/times/time constants in
  `data/audio_move_automation/`; native cases submit those future commands through
  the real mixer queue and require zero late control frames. Bound dynamic
  numerical error with the source target gain maximum and the same independent
  oscillator/filter/PCM limits. With `--max-fps 240` and native user arguments
  `-- --automation --live`, deliver output controls during playback after the
  engine's input samples have already been generated. Preserve source timing
  while the output frame is still editable; only rate commands share the input
  generation frontier. `tests/audio_move_command_frontier.tscn` covers these
  source targets, genuinely late output commands and pending-command retirement.
  Keep the live native delivery cursors in its artifact. These scoped programs
  do not certify game-frame event delivery, changing playback rates/filter
  cutoffs, device suspension or complete audible delivery.
  Capture and inspect `--rates` separately to replay source rates 0.5, 1.8 and
  0.8 through the original graph. Preserve the API rate and each bound
  AudioParam's original multiplication target; dividing that target back by its
  base is not a bit-preserving inverse. Rate-scaled band-passes use
  `scripts/audio_move_filter.gd` because block-level native property updates
  cannot reproduce their sample-accurate source automation. Fixed filters stay
  native, including the initial unity-rate segment of a variable branch. Keep
  synchronized raw/native captures and transfer both input and output history
  before its first rate change; do not reset the filter or crossfade another bed.
  `tests/audio_move_filter.tscn` checks original Chromium impulses,
  Float64 control previews and exact state across arbitrary buffer boundaries.
  Batch processing must preserve all four control channels, final state and the
  existing service budget. Drain ready captures before the one-millisecond idle
  poll. Extend `tests/audio_move_render.tscn -- --stress` with `--rate-stress` to
  exercise concurrent changing rates, then restore constant-rate conditions for
  the original phase and lifetime checks. Keep peak pump time, service gaps and
  native/custom filter modes alongside the existing failure cursors.
  Rate-dependent oscillator reconstruction remains unqualified: the current
  fixed waveform tables have large source-measured errors under changing rates.
  A rate matrix admitted by those model bounds does not certify full source
  waveform parity. Retain actual residuals and finish that representation before
  claiming complete rate/cutoff fidelity or publishing a matching-rate catalogue.
  Use `node tools/capture_audio_move_oscillators.mjs 48000` to isolate the four
  original oscillators from filtering/mixing. `data/audio_move_oscillators/`
  retains complete raw oscillator output and an independent constant-source/Gain
  observation with identical frequency targets in the same render quantum.
  Preserve both parent profile hashes, original source and producer fingerprints.
  `tests/audio_move_oscillators.test.mjs` authenticates the archive and recomputes
  scalar-control, measured-control and rounded-phase-increment period errors.
  The archive also contains all 36 band-limited tables for the three original
  shapes. Extraction checks custom Fourier coefficients and shared normalization
  against each built-in waveform before capturing the culled tables. Chromium's
  [AudioParam implementation](https://github.com/chromium/chromium/blob/151.0.7922.34/third_party/blink/renderer/modules/webaudio/audio_param_handler.cc)
  uses Float32 grouped target updates; its
  [oscillator](https://github.com/chromium/chromium/blob/151.0.7922.34/third_party/blink/renderer/modules/webaudio/oscillator_handler.cc)
  and [periodic wave](https://github.com/chromium/chromium/blob/151.0.7922.34/third_party/blink/renderer/modules/webaudio/periodic_wave.cc)
  retain frequency-dependent band-limited tables and interpolation.
  `scripts/audio_move_oscillator.gd` reproduces the a-rate table selection,
  Float32 phase increments and two/three/five-point interpolation from observed
  frequency words. `tests/audio_move_oscillator.tscn` requires bit-exact output for
  the four original rate programs and three AudioParam-input boundary programs,
  including mixed interpolation groups, large frequency jumps and near-Nyquist
  values, plus the four original constant-rate programs. Preserve the original
  k-rate Float32 SIMD lane recurrence and its accurate quantum-end phase reset;
  a-rate uses double phase accumulation. Initial value events and even no-op
  future rate targets affect source path selection. Four-frame source groups
  survive non-quantum caller boundaries; incomplete/invalid groups reject before
  advancing phase. `scripts/audio_param_curve.gd` generates source Float32
  target curves in complete 128-frame render quanta. Preserve grouped updates,
  fractional starts, scalar tails, convergence and the empty previous-event span
  at an exact quantum boundary. `tests/audio_param_curve.tscn` requires bit-exact
  frequency words and command-to-oscillator output, plus all 21 captured movement
  and numerical-boundary parameter programs. Gain, pan, both dry/wet targets and
  every rate-bound frequency retain independent source curves. Command words use
  the existing Float64 numeric transfer codec; do not route fractional timestamps
  through the unresolved shared inline-number decoder. Late commands, incomplete
  quanta, underflowed Float32 constants and unimplemented coincident instant/
  target event types reject explicitly.
  `scripts/audio_move_source_dsp.gd` binds those curves and oscillators through
  the optional device-rate wave-table input on `AudioMove`/`AudioMoveVoice`.
  Keep source filter-frequency words and independent dry/wet curves; never
  reconstruct physical frequency through scalar divide/multiply round trips.
  Preserve the exact native fixed-filter prefix until the first changed sample.
  Source processing consumes complete 128-frame quanta within the existing
  input-ahead and two-period output reserve. Relative source commands retain
  their original timestamps; late gain/pan/wet commands still use the output
  frontier, while rates share the generated-input frontier. Non-unity initial
  rates and uncaptured detuning remain unavailable in this path.
  Run `tests/audio_move_source_dsp.tscn`, then add `--source-curves` to all four
  static/automation/live/rate modes of `tests/audio_move_waveforms.tscn`.
  This removes fixed-period model errors from the existing strict native bounds.
  Queue preplanned source commands before input priming, retaining no-op rate
  events in the live output-control corpus. Also run
  `tests/audio_move_render.tscn -- --stress --rate-stress --source-curves` for
  concurrent playback, UI stalls, exact physical LFO phase and route retirement.
  `tools/audio_move_wave_import.gd` builds native Float32 wave-bank resources
  only from the complete current producer/source declarations and exact parent
  archive bytes. Bind the movement resource's full identity, original graphs,
  device rate and all three ordered table families; native disk reload must
  preserve every table word, including signed zero. Optional movement owners
  retain isolated snapshots and reject another noise/movement cohort before
  allocating players. Keep `tests/audio_move_wave_import.tscn` with the existing
  oscillator, DSP and native mixer gates. Matching-rate catalogue publication,
  game-frame delivery and device suspension remain required before selecting this
  optional path in normal resource loading. Keep the archive's
  `rateOscillatorsQualified` false until that integration passes. Never enlarge
  native waveform bounds or enable a runtime catalogue from isolated observations.
  Keep the deadline-bound feeder on Godot's native high-priority thread. Commit
  at most one 128-frame native refill per voice/pass, retaining admission order
  and draining ready captures before idle polling; a delayed voice must not
  monopolize service while later voices exhaust their unchanged reserve.
  Reuse oscillator table selection only for exactly equal physical frequency
  words and keep interpolation scratch private, preserving mixed two/three/five-
  point paths and Float64 operation order. The five repeated source-curve stress
  tapes in `artifacts/sol/audio-move-stress-refill-*.json` cover the existing
  32 UI stalls/rate changes per run on one WASAPI configuration. They do not
  qualify sustained CPU contention, other devices/drivers or platform delivery.
  Keep the existing buffering and strict skip checks.
  Discard each input's native startup history before advancing the common
  source clock. Requalify `AudioGeneratorFeed.input_latency_frames` against
  Godot's [server lookahead](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/audio/audio_server.cpp)
  and [generator startup](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/audio/effects/audio_stream_generator.cpp)
  on engine upgrades. Replace stripped input history with a separately reported
  output prefix rounded to native refill blocks. Preserve the original
  two-period service reserve and input-ahead budget; otherwise stripping history
  can consume the final refill even without a scheduling delay.
  `tests/audio_generator_buffers.tscn` reproduces this loss at an off-block
  cursor and checks the replacement independently of driver timing. Do not mask
  branch phase errors with arbitrary buffering or output-dependent error bounds.
  Reuse panning coefficients only for an exactly unchanged double control value;
  retain per-sample evaluation during automation and the existing buffer latency.
  Movement owners and voices retire permanently on tree exit; reattachment must
  reject configuration rather than reconnecting signals to stopped DSP state.
  Use a fresh owner for new playback. Stopped workers release pending mixer
  references and explicitly reject later submissions; the caller must release
  the rejected voice. Deferred startup and reentrant registration callbacks cannot
  reactivate retiring nodes or allocate new native voices after queued deletion.
  Run WASAPI `tests/audio_move_retirement.tscn` and `tests/audio_move_render.tscn`
  alongside source lifecycle checks. Native frames and shutdown probes do not
  certify audible waveform parity, device suspension or threaded Web delivery.
  Service permanent voices in admission order with a one-millisecond worker
  poll. Failed middle voices must not skip later voices; submissions during a
  service pass join its next pass. `tests/audio_move_retirement.tscn` verifies
  these races with a real worker. Run `tests/audio_move_render.tscn -- --stress`
  for 32 repeated 150 ms UI interruptions with unchanged continuity/skip checks.
  One WASAPI device configuration does not certify other drivers/rates, sustained
  CPU contention or platform delivery. Keep the two-period startup budget aligned
  to Godot's native 128-frame resampler refills instead of truncating it to the
  driver period. `tests/audio_generator_buffers.tscn` reproduces the former
  480-frame driver's 64-frame shortfall at an off-block cursor and verifies
  native refills across driver sizes. Do not hide scheduling failures by
  increasing the budget, changing coefficient math,
  branch order or automation clocks, or relaxing strict underrun checks.
  Requalify the block size against the installed engine's native
  [resampler contract](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/audio/audio_stream.h)
  on engine upgrades; failure diagnostics must retain current output skips,
  playback position, free ring frames, unread source captures and maximum service
  gaps. Keep measured per-call time alongside those cursors in native captures.
- [ ] **S10 — Event/frame audio integration:** certify immediate local fire,
  cast/purchase reports, death/leave and remote events in their source order.
  Cover deduplication across snapshot/RPC delivery and all offline/ENet/WebSocket
  lifecycles, including source clock suspension and independent wall deadlines.
  `tests/audio_context_clock.tscn` compares the silent SFX context against an
  independent, active native PCM bus beyond bus auto-disable, through paused
  zero/slow/fast SceneTree scales and bounded capture overflow. Preserve exact
  native frame deltas. This does not qualify physical driver suspension, rate
  changes or event delivery; retain the distinct source-context and wall clocks.

Relevant existing checks include `audio_*_suite.gd`,
`tests/audio_pan_render.tscn` and `tests/audio_move_render.tscn`. Source capture
and native sample checks do not replace audible/mixer/transport acceptance.

Audio workflow, from the repository root:

```powershell
node tools/audio_mixer_references.mjs C:/path/to/steel_vs_swarm
node tools/audio_lifecycle_references.mjs C:/path/to/steel_vs_swarm
node tools/audio_manager_references.mjs C:/path/to/steel_vs_swarm
godot --headless --path . res://tools/import_audio.tscn
godot --headless --path . res://tests/audio_resources.tscn
godot --headless --path . res://tests/audio_lifecycle.tscn
godot --headless --audio-driver WASAPI --path . res://tests/audio_loop_loading.tscn
godot --headless --audio-driver WASAPI --path . res://tests/audio_owner_retirement.tscn
godot --headless --audio-driver WASAPI --path . res://tests/audio_manager_retirement.tscn
godot --headless --audio-driver WASAPI --path . res://tests/audio_pan_render.tscn
godot --headless --audio-driver WASAPI --path . res://tests/audio_move_render.tscn
```

`data/audio_mixer.json` is a dedicated Sol oracle, independent of the shared
fixture registry. Regenerate it after changing its source captures or generators;
its tool fingerprints normalize text line endings. Mixer capture covers the
active device rate; captured reference rates alone do not certify other native
device rates, codec/resampling behavior, audible output or populated transports.
Native audio publication must keep using the atomic resource publisher.
`data/audio_lifecycle.json` retains the original streamed-state, ambience-envelope,
movement and location/source-selection oracles. It does not include the shared
music envelope adapter. Retiring a pending audio player must not wait for decode;
drain the request without capturing the retired node or consuming another
player's completion. Keep imported loop properties immutable and retain each
player's position when pausing/resuming.

## Owner controls and local feedback

- [ ] **S11 — Personal input state:** certify preference restoration, look and
  movement gates, multi-pointer ownership, tap/hold/drag/cancel boundaries,
  focus/overlay release and gyro watchdog/orientation. Do not double-rotate
  screen-axis sensor data or fabricate an identity pose from missing sensors.
  Physical hardware, hybrid-device/DPI detection and mobile exports remain open;
  synthetic decision fixtures cannot certify them.
  Keep stick `x`/`y`/`mag` in doubles until the existing UI `Vector2` boundary.
  Sprint and look integration consume the original radial magnitude, never a
  length reconstructed from rounded vector components. Pointer subtraction and
  all tap/drag distances reuse scalar `CarrierRules.hypot2`; drag-look multiplies
  the original double sensitivity scale before native storage. Preserve source
  zero-axis signs and clear all scalar stick fields before release callbacks.
  `node tools/touch_precision_capture.mjs` runs the original constructor and
  handlers under Node and Chromium; `tests/touch_precision.tscn` retains exact
  scalar words, native look/axis writes and strict dead-zone/sprint/tap/fire
  decisions. Keep `tests/touch_precision.test.mjs`, numeric-transfer tests and
  `tests/touch_reset.tscn` together. DOM/capture/layout transport probes do not
  certify physical pointer delivery, Flash-owned node lifetime or mobile exports.
  Native gyro owners configure once and retire terminally on tree exit. Stop the
  retained sensor state, disconnect its look/failure and preference subscriptions,
  and reject queued or late commands. Preserve the stopped state for existing
  viewport basis-reset consumers; release the borrowed preference owner. A status
  or look callback may retire the owner synchronously, so cancel subsequent
  preference writes, watchdog work and sensor fallback. Fresh sensor starts reset
  accumulated angles. `node tools/gyro_owner_capture.mjs` executes the original
  Gyro constructor/start/stop/motion methods with event/timer transport probes;
  real-driver `tests/gyro_retirement.tscn` checks those programs, retained-owner
  cleanup, queued deletion, reattachment and callback interruption. These checks
  do not certify real sensor delivery, native permission handling, hardware
  orientation, hybrid/DPI behavior, complete input integration or mobile exports.
  Touch reset seals the old pointer/gesture roster before release callbacks;
  nested resets must not duplicate releases or clear newly admitted holds/taps.
  Pending move/release/frame and haptic continuations stop after reset or blocking,
  while unrelated old holds still release in source order. A new hold for the
  same action supersedes an old release. `node tools/touch_reset_capture.mjs`
  executes the original reset/fire-handoff methods for all gesture/button and
  blocked combinations; real-driver `tests/touch_reset.tscn` checks their event
  order plus directed callback interruption and same-pointer-ID replacement.
  The source DOM/stick-paint probes and native state-only checks do not certify
  Flash-owned control-node lifetime, hardware pointer capture, complete input
  publication, populated transport behavior or mobile exports.
  Flash owns the control-wrapper reset correction and node-lifetime acceptance
  in [F1](../flash/MIGRATION.md#ready-for-bounded-implementation). Keep
  `TouchState` release/reentry contracts stable while that task is implemented;
  S11 retains hardware input and populated publication/transport acceptance.
- [ ] **S15 — Local feedback:** finish integrated immutable rounded control
  publication, rising-edge notices and replay rejection. Keep the source
  eligibility, silent rejection, optimistic cast/defense and shared fire/cast
  clock contracts covered by `tests/local_controls.tscn` and
  `tests/audio_lifecycle.tscn`. Complete owner movement/reaction and
  unbalance-notice binding from actual flight/sinking state, without inventing
  authority timers or client-side resource settlement.

Local-feedback references are captured with `node tools/local_controls_capture.mjs`
and `node tools/audio_lifecycle_references.mjs`. Run the corresponding native
scenes before integrated acceptance; neither scene certifies populated snapshots.

## Projectile and screen effects

- [ ] **S16 — Reports/flight effects:** certify NPC shot styles, human/bot
  reports, local fan/remote plasma/lance/ion fallbacks, nearest current muzzle
  callbacks and private versus public shot cadence. Preserve pre-fire initial
  emitters, compressed reverse-order bursts, source crowding limits and contact
  star gates. Complete moving-shot interpolation, geographic collision and immediate
  impact/prediction timing. These effects never repeat damaging settlement.
  Keep owner-pose clocks monotonic and terminal deadlines nondecreasing;
  `tests/projectile_lifecycle.tscn` covers stale/equal-clock packets before and
  after terminal-guard reclamation. Populated transports still require acceptance.
  Native owner exit must clear active rounds, visual-shell model references,
  tracers and every model pool; late calls cannot resume that owner. Reattached
  worlds acquire a fresh presentation owner. Seal record removal before native
  visibility callbacks and stop continuations after collision/impact retirement.
  Keep the original per-variant pool bound and LIFO order, dispose overflow and
  reset root scale on reuse. Regenerate `data/projectile_presentation.json` with
  `node tools/projectile_owner_capture.mjs`; never manually retune its bound.
  Real-driver `tests/projectile_owner_retirement.tscn` verifies current original
  acquisition/drop programs, ordinary/hit/range flight, actual packed models and
  interrupted native ownership. These cases do not qualify all projectile styles,
  moving snapshot interpolation, complete pixels or populated transport behavior.
  Tracers retain one two-vertex dynamic ArrayMesh and private material across
  reuse. Update its culling override with the vertex buffer; native raster probes
  must still draw after endpoints move outside the original surface bounds.
  Release clears the old trace record before visibility callbacks and may return
  a line only once. Preserve original double TTL/age accumulation and fade order.
  The ownership scene includes source endpoint/frame programs, exact scalar bits
  and real-driver buffer/culling-pixel checks. It requires a rendered session.
  Verify retired buffers and private materials after deferred destruction and a
  completed rendered frame, including lines that were actually visible.
  Original tracer prewarm/free-stack bounds remain unqualified until the pool
  provenance contract below is resolved. Preserve the shared oldest-first
  `FX_MAX` budget and reverse fade/expiry order across
  `ProjectilePresentation.traces` and `CombatEffects.effects`, after visual-shell
  movement. Source crowding gates count both owners. Regenerate the scoped oracle
  with `node tools/effect_order_capture.mjs`; real-driver
  `tests/presentation_effect_order.tscn` checks mixed insertion, zero-delta trimming,
  exact lifetime/fade scalars, both quality gates and reentrant owner retirement.
  Its unbuilt-world and callback probes do not qualify full effect pixels,
  original tracer pool limits or populated transport behavior.
- [ ] **S17 — Impact/particles:** certify muzzle/contact/explosion layers,
  source fire/smoke/embers, texture/opacity/depth rules, pooling/oldest-first
  budgets, victim first-observation/healing/re-entry gates and guard peak rules.
  Finish original mechanical-debris random ordering, lossless instance colors,
  source comic texture import, bounce/shrink and ordered death/eviction behavior
  across both quality modes. `node tools/destruction_capture.mjs` captures the
  original particle states/textures; `tests/destruction_native.tscn` retains the
  strict native checks (`-- --comic` or `-- --mechanical` selects one family).
  Body-bound damage/guard materials are a Models contract; event producers are Opus.
- [ ] **S18 — Hit/death screen presentation:** certify hitstop order, damage
  bearings, immutable blood/glint drops, CSS decimal/gradient/blur composition,
  private vitality branches, hurt flash and reset/replay gates. Finish death
  camera ownership, ground/aerial sequences, early respawn cancellation, red-rim/
  whiteout raster, shop layering, configurable wipe behavior and blast feedback
  timing. Authority impulses and death reports remain Opus-owned. Use
  `tests/splat_render.tscn`, `tests/death_render.tscn` and affected transport cases.
  Preserve source camera setup outside measured death-method RNG consumption.
  `node tools/death_overlay_capture.mjs` captures camera states and CSS;
  `tests/death_native.tscn` checks component state without replacing shared camera
  ownership/respawn integration. Run `tests/death_render.tscn -- --source-capture`
  on the real driver for independently fingerprinted CSS raster acceptance.
- [ ] **S19 — Loot/fields/missiles:** certify native airdrop descent/landing,
  loot/relay/threat effects, cube/fog presentation, interpolated missile views,
  smoke/intercept/fracture timing and model-owner triangle queries. Finish
  source-conforming flood/pothole meshes and relay activation starbursts. Preserve
  silent removal versus genuine impact and source owner/round lifetime gates.
  Water conformance consumes explicit original immediate-child water flags,
  geometry parameters and double positions. Preserve `radiusTop ?? radius ?? 6`,
  zero radii, the source 28-triangle fan, per-add Float32 normal accumulation and
  retained non-water poses. Flagged water without geometry parameters follows
  the prop-height branch; current flood `brokenGroundGeometry` has no parameters,
  while pothole's cylinder is rebuilt. Never infer either branch from bounds.
  `node tools/water_conformance_capture.mjs` captures the original method and
  fixed unit-ring geometry under Node and original Chromium; runtime
  `data/water_conformance.json` retains Chromium's float64 radial words before
  radius multiplication. Keep the recorded cross-runtime query differences;
  native trigonometric quadrant residues are not the original geometry.
  Real-driver `tests/water_conformance.tscn` checks strict source query/vertex/
  normal words, material/shared-mesh isolation, populated PackedScene reload and
  interrupted construction. Controlled surface responses and primitive/prop
  probes do not qualify original entity constructors, world surface admission,
  conformed material pixels, damage/outline binding or populated transports.
  The component remains unconnected until the owner contracts below are accepted.
  Mine visibility retains the original zero-initialized absolute throttle clock,
  strict 0.12 s wall-time interval and three-argument compensated distance before
  sight/opacity decisions. Native Float32 observer/anchor components enter double
  subtraction directly; a Float32 vector length changes edge behavior. Preserve
  hidden opacity and per-instance material isolation. `node tools/mine_view_capture.mjs`
  executes the original controller under both Node and the original Chromium
  runtime; real-driver `tests/mine_view.tscn` retains exact distance/time bits,
  near-threshold states and world clock binding. Constructor geometry/shading and
  terrain height probes do not qualify original mine shape, imagery-derived
  camouflage, complete world coordinates, trigger settlement or transport delivery.
  Mine owners retire terminally on detachment and reject queued/late calls before
  clock providers, throttle reservation or model acquisition. Prepare private
  meshes and world pose before admission; seal the entire roster before terminal
  visibility callbacks. Reentrant synchronization and eligible view updates
  supersede old opacity/visibility continuations. World reuse acquires fresh
  owners. Real-driver `tests/mine_retirement.tscn` replays the original visibility
  oracle and checks interrupted admission/removal, clock callbacks, nested view
  updates and deferred private-resource release with closed owners retained.
  It does not qualify the uncaptured imagery/geometry or populated round delivery.
  Missile retirement is terminal and idempotent. Seal it before fracture callbacks,
  stop interrupted observation/model continuations, and release packed models,
  persistent damage children, copied materials and private ray buffers even while
  the closed owner remains retained. Reattachment requires a fresh owner.
  `node tools/missile_owner_capture.mjs` and real-driver
  `tests/missile_owner_retirement.tscn` retain original interpolation/smoke/removal
  programs plus native admission, damaged-owner and deferred-resource checks.
  Declared source geometry/damage probes do not qualify missile shape, damage
  semantics, complete pixels, ray triangles or populated transport delivery.
  **Models — `scripts/missile_view_ray.gd`:** reject retired/queued owners before
  reading global transforms, model nodes or persistent damage geometry. Acceptance:
  ray queries during a reentrant terminal fracture callback, after retirement and
  after tree detachment return no hit without dereferencing released resources.
  Fog circles/rings retain original expanded triangle order, normals and exact
  Float32 UV writes, including native resource reload. Reuse immutable meshes by
  exact radius parameters while retaining private per-fog opacity materials.
  `node tools/fog_geometry_capture.mjs` and real-driver
  `tests/fog_geometry.tscn` retain the actual source constructor and all six layers.
  Buffer/material checks do not qualify composed pixels, clocks or capacity.
  Fog owners close terminally on tree exit and reject late geometry acquisition.
  Complete all layers, pose and membership before native admission; seal removals
  before visibility callbacks and stop superseded synchronization after admission,
  removal or ally replacement. Retirement clears the immutable mesh cache while
  deferring native child destruction; world reuse requires a fresh owner.
  Real-driver `tests/fog_retirement.tscn` reuses the original geometry oracle and
  checks reentrant interruption plus root/material/cache release with retained
  owners. These lifecycle checks do not resolve the delivery contract below.
  **Opus — `scripts/main.gd` fog delivery contract:** reconcile the current
  snapshot-derived `BattleWorld.sync_fogs` age/expiry with original `fog_spawn`
  receipt and render-frame effect deltas. Original fog visuals belong to the
  same oldest-first `FX_MAX` list as tracers and other effects; authority duration
  must not silently replace that client lifetime. Acceptance: zero/capped frame
  deltas, paused authority clocks, late observation and mixed-effect eviction
  retain the original birth/fade/removal sequence before full fog qualification.
  Keep loot bob/airdrop descent on the local wall clock, independent of incoming
  authority clocks; creation and frame updates must use that same time base while
  rotation still consumes the source frame delta. Accumulate rotation in double
  state instead of feeding Node3D Float32 Euler values back into later updates.
  Derive quaternions before native storage so large source angles do not lose
  their fractional phase. Validate exact source IEEE-754 phase/delta bits and
  rendered orientation rather than canonicalized native Euler representations.
  `node tools/loot_clock_capture.mjs`
  and real-driver `tests/loot_clock.tscn` cover the original methods and world
  binding, not complete loot geometry or populated pickup/transport settlement.
  The clock producer executes only the captured original constants/functions;
  do not import the entire source data module or its unrelated RNG dependencies.
  Retain strict hashes for every executed source input and the fixture writer.
  Run the same programs in Node and original Chromium, require matching double
  phase/landing tapes, and publish the browser's pose outputs. Preserve the
  declared constructor probes and all long-rotation/zero-clock cases; this gate
  still cannot establish source constructor geometry or complete rendered pixels.
  Collectible owners close terminally on detachment; world reuse acquires fresh
  owners. Seal all entry references before visibility callbacks, prepare pose
  and private outline bindings before admission, and stop superseded sync/frame
  continuations. Existing IDs retain their original first-observation metadata;
  removal and later reuse create fresh objects. `node tools/collectible_owner_capture.mjs`
  executes the original constructors and snapshot/frame methods for eighteen
  programs; real-driver `tests/collectible_retirement.tscn` checks those states,
  reentrant replacement/retirement and deferred root/private-material release.
  Declared source geometry/toon/outline and terrain probes do not qualify shape,
  shading, complete world coordinates, pickup settlement or transport delivery.
- [ ] **S21 — Remaining quality consumers:** finish curated visual-style
  propagation, render-resolution scaling, world-text rebuilds and remaining
  low-power effect/audio consumers. Verify source constructor versus live-update
  boundaries, persistence and whole-scene rendering. Shared main-scene/renderer
  wiring and shader changes require exact Opus handoffs.
  `node tools/visual_preferences_capture.mjs` and
  `tests/visual_preferences.tscn` retain source preference transactions, native
  ConfigFile reload and scalar marine uniform/reflection contracts. Preserve
  initialized shader-default baselines when testing material isolation; lazy
  real-driver compilation is not a material mutation. These checks do not
  establish whole-water pixels, signage rebuilds or dynamic resolution behavior.
  World captures retain per-mesh `sourceWorldText` constructor profiles, accepted
  copies/styles, atlas size, admission/drop counts and exact vertex glow. Native
  mesh resources retain the matching `source_world_text` metadata and existing
  `source_cel_geometry` frame; prefab sign-item coordinates remain local to that
  frame. Language/profile reconstruction remains unavailable until source
  candidate selection and font/atlas behavior are implemented. Do not substitute
  generic Label3D text, invented translations or a global atlas-quality setting.
  Run `tests/world_text_capture.test.mjs` for capture/storage contracts and
  real-driver `tests/world_text_import.tscn -- --non-glowing` for native reload.
  The default scene is an explicit unsupported-glow rejection (expected exit 1).

## Integration and handoffs

Run the current component references, real-driver resource/render checks and
root runtime gates for the affected behavior. Inspect existing transport case
switches for `-Loading`, `-Mobile`, `-Controls`, `-View`, `-Tps`, `-Pips`,
`-Minimap`, `-Projectiles`, `-Deaths` and `-Blasts`; invoke one switch per run.
Cross-owner changes stay as exact requests in this file until their owner pulls
them. Remove completed items; no dated checkpoints or copied validation history.

### Shared-owner contract required for world publication

- **Opus — source publisher temporary ownership:**
  `tools/fixture_json.mjs::writeSourceFile` uses PID plus `Date.now()` for its
  temporary path and removes that path after a failed exclusive write, including
  `EEXIST`. Two same-process writes to one chunk within one clock tick therefore
  collide; the rejected opener deletes the first writer's temporary file.
  Isolated concurrent 8 MiB writes with a fixed clock both reject (`ENOENT` and
  `EEXIST`) and leave no publication. Give each invocation a unique temporary
  identity and remove only successfully opened files. Preserve atomic rename,
  completed-capture retention and existing retry semantics for both source-file
  and fixture-JSON writers. Acceptance: fixed-clock concurrent writes cannot
  delete another writer's staging file; rejected exclusive opens retain foreign
  bytes, and failed encodes clean up only their own incomplete output. Sol's
  serial chunk hash/reuse checks do not discharge this shared publisher contract.

### Local execution constraints

- In this worktree, source tools need
  `$env:SVS_SOURCE='C:/Users/user/Documents/app/steel_vs_swarm'`; the default
  sibling source checkout does not exist. The required/output presence inventory
  is [world-inventory.json](../../artifacts/sol/world-inventory.json). Presence
  does not establish source fingerprints, dependency integrity or native parity.
  Browser captures also need process-local `PW_CHROME` pointing to
  `C:/Users/user/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe`;
  the sandbox's default Playwright browser cache is empty.
- Godot 4.7.2 is available at
  `C:/Users/user/AppData/Local/Temp/steel-v-swarm-godot/Godot_v4.7.2-stable_win64_console.exe`.
  Set process-local `APPDATA` to this worktree's `build/sol-user` and
  `LOCALAPPDATA` to `build/sol-local` for isolated test preferences and caches.
- Runtime smoke and both loading transports fail on missing seasonal native
  resources; produce the selected original bundles before repeating populated
  acceptance. Root-suite failures in other owners' fixtures do not authorize
  changing their production code or shared reference registries here.
  Root and selected NPC-shot suites also reject stale consumer dependencies.
  Projectile transport timeouts and a rendered smoke timeout without `SMOKE_PASS`
  leave integrated effect delivery unqualified; isolated effect-order acceptance
  cannot discharge these gates.
  Native font/codec caches can be generated in an isolated minimal Godot project
  from identical source assets and import descriptors, then copied into the
  ignored `.godot/imported` directory. Avoid broad editor imports that rewrite
  the shared project settings. An automatic `--quit-after` exit without
  `SMOKE_PASS` is not a passing smoke test.
- `tests/world_storage.tscn` consumes the artifacts generated by
  `node --test tests/world_source.test.mjs`. Its float64 decode/disk-reload checks
  do not establish complete world geometry, rendered appearance or delivery.

### Shared-owner contracts required for world/audio acceptance

- **Opus — exact native source JSON numbers:** expose a reusable validated
  numeric-tape boundary in `scripts/source_fixture_sections.gd` before Sol
  certifies native inline world values. Its existing `load_part` honors
  `numericEncoding: f64-le`, and `_restore_numbers` already restores source words;
  avoid a second decimal parser. The public contract must accept a captured value
  tree plus native float64 bytes, preserve tree shape, reject incomplete/extra
  words and retain the fixture loader's hash/path validation. World callers
  validate their own storage paths/hashes before restoration. The original
  Chromium small sphere has 14 double-bit
  mismatches in each position/normal array after Godot JSON parsing; the large
  sphere has 928 per array on the direct JSON path, while its float64 sidecars
  remain exact. Native resource reload retains the already-decoded small-array
  differences. `artifacts/sol/source-json/report.json` records authoritative
  expected/actual bytes; for example `0000004026a681bc` becomes `ffffff3f26a681bc`.
  Sol binds the accepted contract in `tools/source_world_meshes.gd` and
  `tools/import_worlds.gd`. Acceptance: every original JSON/inline/sidecar/reloaded
  field in `tests/source_json.tscn`, signed zero and difficult finite doubles,
  without numeric retuning, decimal correction tables or tolerance widening.
- **Opus — layered-deck reference provenance:**
  `tools/world_references.mjs` executes the live original `makeDeckIndex` without
  checking the selected world's captured `source.inputs`. It can overwrite
  `collision.deckEndTolerance` and `deckProbes` using different source while
  retaining the old source fingerprint and reporting success. An isolated
  reproduction is retained in `artifacts/sol/deck-provenance-reproduction.json`;
  it never edits an actual captured bundle. Bind the deck-reference producer and
  native-import consumer to matching original biomes/extraction-helper inputs,
  and reject missing or mismatched selected bundles before publication.
  Acceptance: changed/missing source hashes and source changes during reference
  generation preserve the original bundle byte-for-byte; matching inputs retain
  original endpoint tolerance and upper/lower deck query results. This reference
  generator includes authority query semantics and remains a separate shared-owner
  change. Sol's wrapper rechecks declared world inputs before/after references;
  it cannot certify the standalone oracle or extraction-helper contract.
  Preserve signed zero when rewriting the complete bundle as well: ordinary
  `JSON.stringify(data)` erases corrected inline metadata even when the oracle
  itself leaves that data unchanged. Bind the accepted source-number publication
  helper and retain reference results plus all unrelated captured numeric bits.
  The isolated `berlin_1_winter` rewrite erases 99 captured negative zeros in
  marine matrices, water-obstacle shapes and sampler matrices. Exact field paths
  and the preserved original-manifest checksum are retained in
  `artifacts/sol/berlin-winter-reference-proof.json`. Keep the original winter
  capture unchanged; it has no accepted layered-deck references or native
  seasonal resource until this producer contract is corrected. Raw chunk/numeric
  caches still require storage verification before reuse and do not establish
  native-world availability.
- **Opus — float vertex colors:** agree the native mesh/shader attribute contract
  in `scripts/source_cel_*.gd` and `shaders/` before Sol changes
  `tools/import_worlds.gd` to bind it. Original Berlin autumn `SourceMesh_5`
  contains active vertex colors up to `1.059999942779541`; Godot `ARRAY_COLOR`
  stores that value as `1.0`. Preserve source RGB/RGBA values, including signed
  and HDR channels, without clamping or loosening the verifier. The importer
  explicitly rejects these active channels until the shared shader accepts
  lossless storage. Acceptance: regenerate `berlin_1_autumn`, pass original
  surface-color checks in `tests/worlds.tscn` and source/native pixel comparison.
  The freshly recaptured, completely storage-verified Berlin spring bundle also
  stops on mesh 5: 4,944 of its 22,537,287 RGB components exceed one. The first
  is blue at vertex 146,852 (component 440,558), with the same maximum above.
  Exact source buffer identity and surface declarations are retained in
  [world-color-inventory.json](../../artifacts/sol/world-color-inventory.json);
  the current real-driver rejection is in `build/sol-berlin-spring-import.log`.
  Require lossless native disk reload and colored/uncolored source/native pixels
  in both quality modes before Sol binds the accepted storage contract.
- **Opus — cel resource metadata:** resolve the source/native material-table
  mismatch through `scripts/source_cel_data.gd` or its serialized consumer
  contract. Acceptance: `SourceCelData.material_source(material)` equals the
  captured per-surface `cel` declaration after native resource reload;
  `tests/worlds.tscn -- --bundle=berlin_1_autumn` must retain its exact material
  checks. Passing isolated material metadata probes does not qualify full worlds.
- Keep rejected candidates outside normal world selection, for example under
  `artifacts/sol/unqualified-worlds/`. The current worktree has no qualified
  seasonal native bundle. Prebuild transfer/lifecycle checks cannot discharge
  failed geometry/material qualification or establish absent candidate resources.
- **Opus — shared audio fixtures:** refresh the existing audio routing/state
  fields in `data/fixtures.json` through `tools/import_source.mjs` and
  `tools/model_references.mjs`. In particular, `tests/audio_suite.gd` still needs
  the source `audioEvents`/`audioPan` fields before it reaches its routing,
  preference and lifecycle checks. Preserve the producers in
  `tools/audio_references.mjs` and `tools/audio_pan_capture.mjs`; do not invent
  outputs or relax the entry guard. The independent native resource/mixer scenes
  use Sol-owned captures and cannot certify the missing shared decision fixtures.
  In `tests/audio_suite.gd::_buses`, compare the centered player's physical WAV
  gain with `audio_pcm_gain.gd::native_gain(stream, .35)` after decoder
  compensation. Preserve the source logical gain `.5 * .7`, centered SFX route
  and existing tolerance; do not assert the logical gain directly on the native
  WAV player. Acceptance: the shared routing checks run after fixture publication
  and verify both source gain semantics and the decoder boundary.
  The shared gate/count/sample sections still declare producer input
  `tools/audio_references.mjs` as
  `d1a87b6357256bf6059f017f3eee3f2bea8e4f6ccf74b445402d0b35cec084d1`,
  while the current normalized module is
  `3de024594ab66b555c6df2e54a2def16c957981acd4bd5c2666aaabc278df245`.
  Refresh those shared producer declarations through the importer; Sol's separate
  manager capture reuses the current recorder without editing this registry.
- **Opus — selected audio-suite dispatch:** `tests/run.gd::_run_fixture_suite`
  accepts registered `--fixture-suite=tests/audio_move_suite.gd`, then calls its
  three-argument `run(h, fixtures, metadata)` with two arguments and still prints
  `SOURCE_FIXTURE_PASS assertions=0` after the script error. Dispatch the declared
  audio metadata contract or explicitly reject unsupported selected signatures
  before execution; a script error must never produce a passing result.
  Acceptance: selected audio consumers execute their assertions with the same
  metadata as `tests/audio_lifecycle.tscn`, or fail explicitly with nonzero exit;
  retain source provenance/dependency checks and empty engine-error requirements.
- **Opus — shared audio provenance/consumer publication:** refresh
  `data/provenance.json` and the shared fixture consumer manifests through
  `tools/import_source.mjs`. Original `public/js/rng.js` and Sol's
  `data/audio_lifecycle.json` agree on SHA-256
  `96773f680724e2fc8e695270333d41d3a18e539dabb88968dad0b9cb68fae654`, while
  runtime provenance still declares
  `c46913b415a75aa5f0d2366dd7bfcb4f8f26c1db913ecea2a74b40695dd78aaa`.
  The lifecycle generator correctly refuses to overwrite this mismatch. Refresh
  dependency declarations for `tests/audio_clip_suite.gd` and
  `tests/audio_move_suite.gd` after their catalogue-based resource binding; preserve
  the original expected samples, control programs and strict fingerprint guards.
  Acceptance: `tests/audio_lifecycle.tscn` reaches its original programs without
  bypassing provenance, and the root suite accepts the current audio consumers.

### Shared-owner contracts required for local feedback

- **Opus — scalar touch-axis publication:** `scripts/main.gd::_physics_process`
  and `_advance_spectator` consume only `TouchState.axis`'s rounded native vector;
  the latter reconstructs magnitude with `motion.length()`, as does
  `scripts/input_rules.gd::moving` for the 0.02 movement gate. Agree a source
  scalar `(right, forward, magnitude)` consumer contract using the existing
  `TouchState.move_stick.x/y/mag`, preserving keyboard precedence, overlay release
  and the shared simulation command boundary before changing publication.
  Acceptance: original near-dead-zone, 0.02 movement, sprint and unit-radius
  states retain source decisions for player and spectator, while unchanged
  keyboard inputs and cancelled/reset sticks retain their existing behavior.
- **Opus — snapshot acceptance before feedback:** `scripts/session.gd::_snapshot`
  emits `state_received` even when `scripts/simulation.gd::apply_snapshot`
  rejects an older clock. `scripts/main.gd::_receive_state` then consumes the
  rejected control publication, optimistic cast state and presentation clock.
  Give the producer/consumer one round-scoped acceptance contract before those
  mutations. Acceptance: after newer freeze/EMP/cast/control edges, an older
  snapshot and duplicate snapshot cannot rewind state or rearm notices; later
  valid false/true edges still notify, and a new round accepts its initial clock.
  Preserve separately delivered tactical events and offline authority snapshots;
  component-local projectile guards cannot discharge this shared integration.
- **Opus — owner unbalance notice:** `scripts/actor_snapshot.gd` currently
  publishes `unbalLeft` but omits the `unbalanced` field consumed by
  `ControlStatusState` through `scripts/main.gd`. Publish an explicit owner-only
  boolean using actual flying/dead/drone/altitude/wind/sink/lift-lock state from
  `scripts/simulation.gd`, following the original client `_unbalanced()`.
  Use recipient-rounded `unbalLeft` for the status branch, not the raw authority
  deadline remainder. Existing `MovementRules.flight_unbalanced()` provides the
  predicate once given that recipient state. Acceptance: grounded/dead and
  below-threshold drones publish false; airborne sinking/lift-lock/status each
  independently publish true; exact altitude/lock and rounded-zero status
  boundaries retain source behavior. Repeated true snapshots emit one notice,
  false then true emits another, and replayed snapshots emit none. Do not infer
  this flag from `unbalLeft` alone or add client resource settlement.

### Shared-owner contracts required for projectile acceptance

- **Opus — original presentation pool provenance:** refresh `data/provenance.json`
  through `tools/import_source.mjs` before Sol captures original `_initFxPools`,
  `_releaseFxLine` and `Pool.release` together. Current original
  `public/js/pool.js` hashes to
  `58b938ad46b8c4afd0036612f143a4bdb52be72af6b9d45eb73ae229a690b84b`,
  while imported metadata declares
  `5040958ee9974e92e7cf25ad784bb92b0c76f02a6f8d9de60baa13b1cd5b987e`.
  The guard must reject this mixed identity; do not reuse an invented Pool or
  relax the fingerprint check. Acceptance: original prewarm, bounded LIFO release,
  overflow disposal and reentrant shell retirement execute against one accepted
  source snapshot. Sol's current supplied-line probes certify vertex/fade writes,
  not the absent pool qualification. The exact identities are retained in
  [tracer-pool-source.json](../../artifacts/sol/tracer-pool-source.json).
- **Opus — shared projectile fixture publication:** refresh `data/fixtures.json`
  through `tools/import_source.mjs` before full projectile acceptance. The shared
  `visualShells`, `projectileGeometry` and `tracerPresentation` sections declare
  `tools/projectile_references.mjs` as
  `44d833f86189b5e8a394249b3b7c4988144bb3093a2cc6014d9ea73602af2cd0`,
  while the current normalized producer is
  `9a8545ae29e9c1a51ab5fed6d35050028cbe78ff767a2125f24a8d5169c3ca35`.
  Preserve original flight, geometry, material and tracer expectations and the
  source fingerprint guards. Acceptance: the shared projectile suites consume
  current producers/consumers without substituting Sol's narrower ownership oracle.

### Shared-owner contracts required for particle acceptance

- **Opus — current particle provenance:** reconcile the original source inputs
  through `tools/import_source.mjs` and `data/provenance.json` before publishing
  another `tests/fixtures/destruction.json`. Its current capture disagrees with
  shared provenance for `public/js/rng.js`, `public/js/pool.js`,
  `public/js/lookPrefs.js` and `public/js/movePrefs.js`. Keep all four source
  guards and the strict particle comparisons. Acceptance: regenerate from the
  agreed original inputs, then execute both particle families on the real driver;
  a compiling fixture adapter does not qualify debris, comics or imported pixels.
- **Opus — debris source random contract:** the original default
  `vfx.debrisBurst()` path captured by `tools/destruction_references.mjs` consumes
  `Math.random` while constructing Three.js groups/materials/instance batches,
  before sampling chunk parameters. The first normal/small case consumes 73
  draws versus native `MechanicalDebris`'s 49, shifting the first scale from
  source `0.5774999856948853` to native `0.498750001192093` and later motion.
  Publish source-derived allocation/effect draw separation for Sol to consume;
  do not insert unexplained constant RNG burns or silently shift expected data.
  Preserve the distinct explicitly injected random callback used by seeded
  scenery bursts. Acceptance: all default and seeded cases retain their original
  parameters, draw order, bounce/spin/shrink and independent combat RNG streams.
- **Opus — lossless debris palette binding:** agree the shared cel shader
  contract in `shaders/` and `scripts/source_cel_*.gd` before Sol changes the
  `MechanicalDebris` MultiMesh binding. Current per-instance colors round source
  float32 `0.0930589661002159` to `0.093017578125` on the real OpenGL driver.
  Palette indices are exactly representable, but the accepted shader must resolve
  them to the original float32 palette/accent without half-float color loss.
  Keep original low-power two-batch/full-power four-batch topology and metal
  shading. Acceptance: strict matrix/color checks in `tests/destruction_native.tscn`
  and source/native pixels, including accent zero and both quality modes.
- **Opus — comic PNG import contract:** `tools/import_source.mjs` publishes
  `assets/ui/combat-comic-*.png` without source-preserving texture import settings.
  All 32 captured PNGs match original decoded pixels, while all 32 imported
  textures differ with `process/fix_alpha_border=true`. The first texture has
  6,506 changed transparent and 174 changed nonzero-alpha pixels; applying
  `Image.fix_alpha_edges()` to its original pixels reproduces the imported bytes
  exactly. Publish the
  explicit import configuration and reimport through the shared pipeline;
  leave original PNGs immutable. Acceptance: original captured RGBA bytes equal
  the imported `Texture2D.get_image()` bytes, then qualify native billboard pixels.
  Passing sprite scale/opacity/roll/pool state does not discharge this texture gate.

### Shared-owner contracts required for death presentation

- **Opus — source CSS inset-shadow raster:** fix the accepted shader contract in
  `shaders/death_rim_mask.gdshader`, `shaders/death_rim_present.gdshader` and the
  shared `shaders/splat_blur.gdshader` before Sol changes their viewport bindings.
  Current original CSS/native comparisons fail the rim cases at 640x360,
  360x640 and 128x128, with 44,308 / 53,001 / 5,837 mismatched pixels and maximum
  premultiplied-channel errors 0.027451 / 0.027451 / 0.023852. Whiteout cases
  pass at the existing tolerance. Acceptance: all six original raster cases in
  `tests/death_render.tscn -- --source-capture` pass without loosening
  `tests/raster_compare.gd`; retain source inset spread, blur, corner coverage and
  transparent composition. Diagnostics are in `build/death_render/`.
- **Opus — shared death integration fixture cleanup:**
  `tests/death_sequence_suite.gd::run` stores a lambda on each RefCounted sequence
  that captures the same sequence strongly. Clear its callbacks after each case
  or use an explicitly typed `WeakRef`; retain its `_lifecycle` assertions against
  `scripts/main.gd` and `scripts/unit.gd`. Acceptance: source sequence checks and
  camera ownership/early respawn/reset integration pass with no ObjectDB/resource
  leaks or engine errors at exit. Sol's source-only `tests/death_native.tscn`
  avoids that cycle but does not certify the omitted shared lifecycle checks.

### Shared-owner contracts required for loot frame integration

- **Opus — relay activation delivery:** `scripts/main.gd` must deliver accepted
  public relay events to the existing `CombatEffects.spark` consumer, separately
  from pilot-only supply notices. Original `game.js`'s relay event branch emits
  one `starburst` at `(ev.x, terrain.heightAt(ev.x, -ev.z) + 9, -ev.z)`, radius 8,
  with the event side's source color or `0x66ffe0` for an absent side. It does not
  render snapshot `relay_progress` or a strike/progress ring. Preserve source
  height-query order, existing oldest-first effect budgets and event replay
  rejection. Acceptance: allied/enemy/absent-side events and spectator delivery
  produce one original activation effect per accepted event; stale/duplicate
  events emit none and ordinary progress snapshots emit no invented visual.
- **Models/Opus — original water hazard bindings:** preserve original
  `userData.water`, geometry-parameter presence/nullish radius fields and double
  `source_trs.p` for every immediate source child through
  `tools/model_references.mjs`, `tools/import_cockpits.gd` and the shared import
  publication. The existing packed flood/pothole scenes omit the water flag and
  parameters. Publish actual constructor seed/radius identity as well: current
  hazard profiles use seed 0 and one default radius; uniform root scaling cannot
  replace `buildHazard(kind, entityId, scaledRadius)` because prop sizes and water
  offsets remain independent of that radius. Opus then binds
  `WaterConformance.apply(group, bindings, cx, cz, cy, surface)` in
  `scripts/unit.gd::_build_model` after original world placement and before
  pristine dimensions, damage, collapse and outline/material geometry binding.
  `surface(x,z)` must execute original `_surf(x,z,terrain.heightAt(x,z))` ordering
  and retain the bridge/terrain admission contract, rather than selecting the
  highest deck unconditionally. Acceptance: populated original flood/pothole
  models, multiple IDs/radii and sloped/raised-deck cases retain exact query and
  geometry words, source prop/offset behavior, bounds and damage/outline binding
  without mutating another instance; then run smoke and both transports. Keep
  the synthetic conformance gate separate from that complete integration.
- **Opus — capped/hitstop frame delivery:** `scripts/main.gd::_process` obtains
  the accepted delta from `PresentationFrame.advance`, while the independently
  processing loot/airdrop nodes receive raw engine deltas. Original
  `BattleClient` passes its single adjusted `dt` to `_updateLoot` and
  `_updateAirdrop`, alongside continuous local wall time. Agree one main-to-world
  frame contract so Sol can expose the matching consumers without double-stepping
  or introducing another hitstop budget. Acceptance: long stalls retain the
  source delta cap; hitstop freezes spin but wall-clock bob/descent phases retain
  original behavior; snapshot bursts never restart either clock. Keep authority
  simulation time and resource settlement unchanged.
- **Opus — native loot orientation assertions:** when refreshing shared
  `lootVisuals` / `airdropVisuals`, update `tests/scene_suite.gd` and
  `tests/supply_suite.gd` to distinguish source double phase from the native
  quaternion pose. Node3D canonicalizes Euler representations after quaternion
  writes, so raw Euler-vector equality is not a valid pose comparison across
  complete turns. Preserve source phase/delta bits as demonstrated by
  `tools/loot_clock_capture.mjs`; assert the double phase on presentation state
  and source quaternion orientation on the actual node. Acceptance includes
  both short original programs and fractional large-angle states without
  increasing pose tolerances or changing authority behavior.

### Shared-owner contracts required for renderer quality

- **Opus — original aquatic point compositing:** qualify
  `shaders/aquatic_points.gdshader` against original Three.js PointsMaterial
  color/opacity composition, retaining vertex colors, depth, perspective size
  attenuation and pixel-ratio behavior. All six original cases in
  `tests/aquatic_render.tscn -- --source-capture` currently fail at the unchanged
  two-byte tolerance: 392/32/120/6/392/8 pixels, each with maximum channel error
  44/255. Source/native images are in `build/aquatic_render/`; the capture uses
  original material construction and source colors, not invented palette values.
  Acceptance: all six source rasters and native motion/buffer isolation checks,
  with no source-color retuning or tolerance increase. Point-state equivalence
  does not qualify point colors, transparency or complete water composition.
- **Opus — source resolution governor integration:** `scripts/main.gd` currently
  reads `get_viewport().scaling_3d_scale` for PiP but never applies the original
  `_dpr` / `_applyRes` / `_tickResGov` renderer contract. Agree the native DPI,
  frame/load metrics and visibility inputs through `scripts/main.gd`,
  `scenes/main.tscn` and `project.godot` before exposing render-scale behavior.
  Preserve source low-power DPR 1, touch DPR cap 1.5, desktop cap 2 and desktop
  dynamic scale 1; the touch governor retains spike/hidden-frame exclusion,
  complexity weighting, recovery cooldown and permanent reversal shutdown.
  Acceptance: source-oracle frame programs, actual viewport dimensions and PiP
  scaling agree across low-power changes, resize and visibility transitions.
  Do not substitute a fixed low-resolution toggle for the source governor.
- **Opus — original sign emission:** agree a lossless per-vertex `signGlow`
  binding in `scripts/source_cel_*.gd` and `shaders/`, using captured
  `sourceWorldText.glow` and the original text atlas. Original
  `worldtext.js::applySignGlow` multiplies atlas-sampled emissive radiance by the
  interpolated vertex attribute, so unlit civic plates and backlit tactical
  plates share one mesh/material. Preserve Float32 values, single-sided front/
  back geometry, source UV inset and atlas sampling; do not apply one emission
  amount to every plate. Acceptance: mixed zero/nonzero source glow and lit/unlit
  raster fixtures match before Sol enables the native import path. The importer
  currently rejects active glow instead of silently dropping the attribute.

### Terra boundary contracts

- **Terra — shared raster comparator dependency:** the unresolved byte-boundary
  request lives in Terra's backlog and targets Opus-owned `tests/raster_compare.gd`.
  Sol must retain its campaign-independent raster failures and existing tolerances
  until Opus accepts that contract; do not duplicate or locally patch the helper.
- **Sol — presentation producers consumed by Terra:** keep source CSS helpers,
  input/control publications, frame clocks, world queries and resource contracts
  stable while Terra changes visual consumers. Changes to `scripts/css_transition.gd`
  or `scripts/css_decimal.gd` require scope and campaign regression cases as well
  as the direct source oracle. Shared main/session/shader changes remain Opus-owned.
