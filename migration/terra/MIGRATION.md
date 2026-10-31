# Bounded visual consumers — outstanding work

Read [AGENTS.md](AGENTS.md). The root router assigns S12-S14 and S20 to Terra;
IDs and existing evidence paths are retained. Work one bounded fixture-backed
change at a time. These acceptance inventories do not authorize a whole-system
rewrite or edits to producer APIs. Complex work may use Sol 6.1 in this lane.

## View, scope, minimap and PiP

- [ ] **S12 — View/scope/observer:** certify FPV/TPS/spectator camera state,
  source clipping/ring order, recoil composition, view-lock acquisition/cycling,
  previous-rendered projection, scope gradients/fog/blur/FOV easing and freeze/
  death/respawn transitions. Preserve source unknown observer resources. Models
  owns occlusion/rig geometry; Opus owns authority heading, acknowledgements and
  populated LOS/target contract changes.
  Fog opacity must retain the original CSS ease-out curve and reversal-shortened
  durations, including repeated reversals, unchanged targets and zero-progress
  cancellation. Both fog transitions use wall time even when the game is paused
  or runs at a different speed. Native tween writes must reach shader uniforms in
  the same frame.
  Player FOV easing clamps a negative timestep to zero outside the original snap
  band; snapping inside that band remains independent of timestep. `node
  tools/scope_fov_capture.mjs`, `node --test tests/scope_fov.test.mjs` and
  `tests/scope_fov.tscn` compare eleven controlled Chromium programs, including
  snap boundaries. `node tools/scope_fov_sequence_capture.mjs`,
  `node --test tests/scope_fov_sequence.test.mjs` and real-driver
  `tests/scope_fov_sequence.tscn` compare 431 original easing, reversal and
  zero-timestep frames and their native camera FOV values. These controlled
  results do not qualify projection update timing, populated view transitions
  or transport.
  `node tools/scope_transition_capture.mjs` and real-driver
  `tests/scope_transition.tscn` compare original browser transitions and native
  uniforms and test paused, zero-speed and accelerated wall-clock transitions;
  these checks do not certify scope gradient/blur pixels or complete
  frame-order, freeze/death and populated view integration.
  Removing the overlay or an ancestor cancels both fog tweens and settles their
  retained targets, so reattachment cannot revive pre-detachment motion.
  `node tools/scope_detach_capture.mjs`, `node --test tests/scope_detach.test.mjs`
  and real-driver `tests/scope_detach.tscn` compare both original CSS fade
  directions, fresh transitions after reattachment and paused ancestor removal.
  These lifecycle probes do not certify source backdrop or weather pixels.
  Scope radius, visible weather-gradient stops and fire blur retain the original
  double-precision CSS serialization before native vector storage.
  `node tools/scope_values_capture.mjs`, `node --test tests/scope_values.test.mjs`
  and real-driver `tests/scope_values.tscn` compare 749 original browser HUD
  cases, including decimal rounding boundaries and exact input bits, against the
  shader parameters. An unscoped weather gradient also keeps its prior stops
  while fading to zero. `tests/scope_weather_retention.tscn` retains the original
  fade and mode-change programs, including the four shared-shader failures below.
  The underlying scope radius and weather-stop functions apply the original
  `value || 0` before clamping, including NaN and signed infinities. `node
  tools/scope_nonfinite_capture.mjs`, `node --test tests/scope_nonfinite.test.mjs`
  and `tests/scope_nonfinite.tscn` compare 49 Chromium input pairs against native
  double results. The overlay applies the same bounded density before setting
  targets and blur; repeated NaN input retains an unchanged fade and zero weather
  retains the prior gradient. These controlled probes do not qualify non-finite
  upstream data or shader pixels.
  These values do not qualify the shared shader or full pixels.
  `node tools/scope_raster_capture.mjs` and real-driver `tests/scope_raster.tscn`
  retain original CSS/HUD callback composition over controlled browser backgrounds.
  Keep the strict raster failures and exact byte witnesses in `build/scope_raster/`;
  transition-state success cannot discharge the shared ring-color, backdrop-blur
  and raster-comparator contracts below.
  Spectator pose writes preserve the original Y-then-X rotation from double
  angles before native storage. `node tools/spectator_native_capture.mjs` and
  real-driver `tests/spectator_native.tscn` retain original camera/state/HUD
  programs, actual Three camera quaternions and native exit ownership probes.
  Unknown remote magazines and movement resources remain null. These checks do
  not qualify populated ray queries, actor pixels, recipient publication or the
  shared main-to-camera angle transfer contract below.
  Followed-player HUD defaults retain the source's nullish power and truthy
  cooldown/resource rules, including empty upgrade dictionaries and `NaN`
  cooldowns; unknown magazines remain null. `node
  tools/spectator_hud_defaults_capture.mjs`,
  `node --test tests/spectator_hud_defaults.test.mjs` and
  `tests/spectator_hud_defaults.tscn` execute the original Chromium HUD method
  with controlled imported level-one definitions and compare missing, null,
  zero, negative and partially supplied data. These probes do not qualify real
  snapshot schema, populated transport or complete authored HUD rendering.
  The spectator roster preserves input order for equal side/player keys, including
  when nearest selection encounters equal-distance duplicate entries.
  `node tools/spectator_roster_capture.mjs`,
  `node --test tests/spectator_roster.test.mjs` and real-driver
  `tests/spectator_roster.tscn` compare the original Chromium roster, filtering,
  follow target and notice. Controlled duplicate rows do not qualify populated
  transport or upstream snapshot identity.
  Roster filtering applies source truthiness before converting a player ID to a
  string, so missing, null, numeric zero and NaN cannot become follow targets;
  the nonempty string `"0"` remains valid. `node
  tools/spectator_roster_pid_capture.mjs`,
  `node --test tests/spectator_roster_pid.test.mjs` and
  `tests/spectator_roster_pid.tscn` compare twelve original Chromium cases.
  The controlled rows do not establish the upstream recipient ID schema.
  Observer heading retains the previous value when a target heading is absent
  or null, and clamps nonpositive interpolation time to the original no-motion
  behavior. `node tools/spectator_heading_capture.mjs`,
  `node --test tests/spectator_heading.test.mjs` and real-driver
  `tests/spectator_heading.tscn` compare 300 original Chromium cases across
  follow modes, unbounded headings and delta boundaries. Controlled rows do not
  qualify populated snapshot delivery or complete camera rendering.
  Nearest-player selection compares squared distances in scalar doubles, in the
  source operation and stable reduction order; Vector3 squared-distance rounding
  can otherwise turn distinct candidates into a tie.
  `node tools/spectator_nearest_capture.mjs`,
  `node --test tests/spectator_nearest.test.mjs` and real-driver
  `tests/spectator_nearest.tscn` retain original selection/notice programs for
  Float32-representable positions, exact ties and non-finite comparisons. These
  controlled inputs do not recover position precision lost upstream or qualify
  populated observer delivery.
  Orbit anchor snapping compares the source double-precision distance against the
  strict threshold before interpolation; a Vector3 distance rounded to the
  threshold can otherwise smooth a target the original snaps to immediately.
  `node tools/spectator_snap_capture.mjs`,
  `node --test tests/spectator_snap.test.mjs` and real-driver
  `tests/spectator_snap.tscn` retain the original anchor branch for boundary,
  locked-view, first-anchor and moving-frame cases. These controlled positions do
  not establish upstream precision or populated observer delivery.
  Orbit anchor interpolation retains scalar doubles across frames and compares
  the unrounded anchor to the snap threshold; native Vector3 conversion occurs
  only when exposing the anchor. Resetting or assigning the anchor replaces all
  retained coordinates. `node tools/spectator_anchor_capture.mjs`,
  `node --test tests/spectator_anchor.test.mjs` and real-driver
  `tests/spectator_anchor.tscn` compare 454 original frames, including small
  motion, negative coordinates, view resets, nonpositive deltas and a snap after
  accumulated smoothing. They check double anchor, distance and coefficient bits
  as well as the exposed Float32 position. These controlled Float32 inputs do not
  recover upstream precision or qualify complete camera poses and delivery.
  FPV spectator eye coordinates preserve the source multiplication and addition
  order in scalar doubles before entering native Vector3 storage.
  `node tools/spectator_fpv_pose_capture.mjs`,
  `node --test tests/spectator_fpv_pose.test.mjs` and real-driver
  `tests/spectator_fpv_pose.tscn` compare 588 browser cases across controlled
  imported profiles, headings, native-representable positions and the flight
  threshold. These probes do not qualify upstream positions or headings, camera
  orientation matrices, populated actor rendering or delivery.
  Free spectator movement retains scalar position across frames, applies the
  original diagonal/boost operation order and clamps floor before ceiling. Mode
  changes carry the unrounded follow anchor into free movement, and nearest-player
  acquisition compares that retained position, including exact distance ties.
  `node tools/spectator_free_capture.mjs`,
  `node --test tests/spectator_free.test.mjs` and real-driver
  `tests/spectator_free.tscn` compare 312 original frames, scalar and native
  position bits, selection, resets and controlled terrain/ceiling transitions.
  World surface queries still receive native Vector3 coordinates; these controlled
  surfaces do not qualify populated terrain queries, the shared angle transfer,
  camera orientation or recipient delivery.
  Third-person follow and orbit retain scalar anchor/camera coordinates through
  the local pull calculation; native vectors are created at world-query and
  camera boundaries. Segment samples retain scalar interpolation and floor
  comparisons, while the legacy Vector3 pull callback remains supported.
  `node tools/spectator_tps_capture.mjs`,
  `node --test tests/spectator_tps.test.mjs` and real-driver
  `tests/spectator_tps_geometry.tscn` compare 630 clear cases, 24 controlled
  blocker/ridge cases and 48 moving orbit frames. The geometry scene checks the
  pull inputs and sample counts but excludes final hit-position equality;
  `tests/spectator_tps.tscn` retains the full strict gate and its two hit-distance
  failures below. Controlled query doubles do not certify actual world blockers,
  populated transport, browser `Math.hypot` or complete camera rendering.
  Lock-glow hit decay retains millisecond subtraction before division by 200;
  ring rotation derives its quaternion from the double phase before native
  storage. `node tools/lock_glow_capture.mjs` executes the original constructor
  and render callback under Node and Chromium, retaining both numeric results;
  Chromium is the browser-state oracle. Real-driver `tests/lock_glow.tscn`
  compares exact double states, native Float32 poses/material values, ring
  orientation and private resource release. Keep its strict scalar gate open
  until the shared pulse-sine contract below is accepted. The shared texture
  probe, measured-dimension probe and component states do not qualify glow
  texture pixels, actor bounds, populated targeting or full frame composition.
  `node tools/player_tps_anchor_capture.mjs`,
  `node --test tests/player_tps_anchor.test.mjs` and real-driver
  `tests/player_tps_anchor.tscn` retain the original Chromium shoulder/floor
  branch and strict native Float32 comparison for imported heights, controlled
  surfaces, pitches and unbounded headings. The shared authority contract below
  blocks changes to this consumer. `node tools/player_view_body_capture.mjs`,
  `node --test tests/player_view_body.test.mjs` and real-driver
  `tests/player_view_body.tscn` retain the original movement-threshold and heading
  traces; its strict gate also remains open pending the authority contract below.
  Neither controlled fixture qualifies upstream precision, populated surfaces,
  clipping, ring placement, transport or rendered body/camera poses.
  The original death page also renders a frontline inset after the death
  sequence. `PipDeathState.source` retains its stable nearest-live-allied-tower
  selection, first allied base fallback even if dead, and null for the elevated
  death-position fallback. It compares scalar double squared distances before
  native vector conversion. `node tools/pip_death_selection_capture.mjs`,
  `node --test tests/pip_death_selection.test.mjs` and
  `tests/pip_death_selection.tscn` execute the original Chromium method and
  check controlled native-representable coordinates, equal and near ties,
  hidden/missing models and source visibility restoration. A missing native
  model-availability flag cannot admit a source. `PipDeathState.source_coordinates`
  also preserves the enemy-base coordinates as scalar doubles until the distance
  comparison; `source` retains its existing Vector2 interface. `node
  tools/pip_death_enemy_precision_capture.mjs`,
  `node --test tests/pip_death_enemy_precision.test.mjs` and
  `tests/pip_death_enemy_precision.tscn` retain eight original selection cases,
  including near-ties that select a different tower after Vector2 rounding. This
  path still requires the recipient publication contract below before use.
  `PipDeathState.eye_position`
  retains the source's measured-top/zero/NaN fallback and ground-height eye
  offsets before native vector storage. `node tools/pip_death_pose_capture.mjs`,
  `node --test tests/pip_death_pose.test.mjs` and `tests/pip_death_pose.tscn`
  compare 48 original Chromium eye positions using controlled native-representable
  inputs and supplied ground heights. `PipDeathState.can_prepare` retains the
  original death/transition/game-over/side/config/frame gates, and its `viewport`
  keeps CSS-space scissor coordinates as scalar doubles through the strict
  minimum-size check. `node tools/pip_death_gate_capture.mjs`,
  `node --test tests/pip_death_gate.test.mjs` and `tests/pip_death_gate.tscn`
  retain 13 Chromium programs, including exact and sub-boundary sizes. Source
  camera preparation occurs before the separate size gate. These cases do not
  implement a native inset. `node tools/pip_death_direction_capture.mjs`,
  `node --test tests/pip_death_direction.test.mjs` and
  `tests/pip_death_direction.tscn` retain 522 original Chromium target/up-vector
  cases for both source and fallback cameras, including zero and tiny directions.
  The existing `CarrierRules.hypot2` candidate matches these controlled scalar
  target bits, but is not an accepted general browser-hypot binding; keep the
  shared numeric contract below open before wiring this consumer. The exact
  fixture inputs are restored from double bits because Godot JSON parsing can
  perturb decimal inputs. These cases do not qualify the camera matrix, actual terrain
  queries, frame-to-renderer conversion, death-page lifecycle, populated snapshot
  delivery and pixels remain open.
- [ ] **S13 — Minimap:** certify full/vicinity windows, warmup/draw deadlines,
  original baked pixels, lane grades/dash/miter rules, labels, remembered bunkers,
  neutral exclusions and public entity markers. Finish persistent exploration,
  per-source occlusion shadows, soft masks, pulse/observer bypass and ordered
  SubViewport composition against browser raster sequences. World blocker query
  semantics and recipient vision remain Opus-owned. Relevant checks include
  `minimap_*_suite.gd` and `tests/minimap_fog_render.tscn`.
  `node tools/minimap_native_capture.mjs` and real-driver
  `tests/minimap_native.tscn` retain original window/marker/cadence/lane/vision
  programs and atlas ownership. Run real-driver
  `tests/minimap_fog_render.tscn -- --source-capture --full-raster` for complete
  composition and persistent-mask sequences. The existing probe tolerance remains
  four bytes; probe-only success does not discharge the full-image gate.
  Diagnostics are retained under `build/minimap_fog/`. Controlled canvas inputs
  do not qualify the actual baked terrain base or populated recipient/query state.
  A due draw freezes the window, mode, viewer, actor and bunker records, missiles
  and pulse for all layers; interpolated positions are captured after the caller
  refreshes them and before fog construction. Later mode/snapshot changes cannot
  mix a new crop or markers with the previously scheduled fog and lane paths.
  `node tools/minimap_frame_capture.mjs`, `node --test tests/minimap_frame.test.mjs`
  and real-driver `tests/minimap_frame.tscn` retain original draw/toggle programs,
  delayed native draws, observer and faction frames, missiles, remembered bunkers,
  legend colors, source window/crop/marker geometry and room retirement. The
  controlled sources do not qualify complete fog pixels, actual baked terrain,
  populated delivery or platform performance.
  Remembered bunker records retain source coordinate inversion, rounded-key
  deduplication, insertion order and the latest allegiance through later empty
  snapshots. `node tools/minimap_bunker_capture.mjs`,
  `node --test tests/minimap_bunker.test.mjs` and real-driver
  `tests/minimap_bunker.tscn` compare seven original snapshot programs, committed
  frame isolation, bunker marker positions/colors and match reset. These inputs
  use native-representable positions. `remember_coordinates` additionally keeps
  supplied world coordinates as scalar doubles through deduplication, frame
  capture and marker projection. `node tools/minimap_bunker_precision_capture.mjs`,
  `node --test tests/minimap_bunker_precision.test.mjs` and
  `tests/minimap_bunker_precision.tscn` compare the original four snapshot
  sequences, including distinct values that collapse to one native vector. The
  key calculation also preserves JavaScript rounding immediately below half;
  `node tools/minimap_bunker_rounding_capture.mjs`,
  `node --test tests/minimap_bunker_rounding.test.mjs` and
  `tests/minimap_bunker_rounding.tscn` retain fifteen original rounding cases.
  The current snapshot path still supplies Vector3 positions; the publication
  contract below is required before this precision path can consume them. These
  probes do not qualify unrounded transport coordinates or marker pixels.
  Window edges retain scalar doubles through the committed terrain crop, marker,
  lane and hard/soft reveal plans; conversion occurs at the native drawing
  boundary. The label rounds the unconverted source width.
  `node tools/minimap_window_precision_capture.mjs`,
  `node --test tests/minimap_window_precision.test.mjs` and real-driver
  `tests/minimap_window_precision.tscn` compare 448 original source windows,
  projections, crops, labels and controlled reveal calls, including imported map
  bounds and zero/tiny axes. A live frame also checks the retained window across
  terrain changes. These probes use native-representable actor positions and do
  not qualify source position precision, baked terrain pixels, mask coverage or
  populated delivery.
  Marker and missile offsets are applied to the double projection before native
  primitive storage. `node tools/minimap_marker_precision_capture.mjs`,
  `node --test tests/minimap_marker_precision.test.mjs` and real-driver
  `tests/minimap_marker_precision.tscn` compare the original draw order and
  geometry for 96 controlled faction/observer frames, including the live canvas.
  These probes do not qualify marker edge coverage or populated actor rendering.
  `node tools/minimap_marker_raster_capture.mjs`,
  `node --test tests/minimap_marker_raster.test.mjs` and real-driver
  `tests/minimap_marker_raster.tscn` retain the original browser marker callback
  and isolated opaque rasters for fractional rectangles, circles, rings, bunker
  outlines, inherited widths, rotated arrows, clipping and overlaps. Keep the
  strict four-byte raster failures until the shared marker-coverage contract
  below is accepted; these probes do not qualify the full populated map.
  `node tools/minimap_label_capture.mjs`, `node --test tests/minimap_label.test.mjs`
  and real-driver `tests/minimap_label.tscn` retain the original Canvas label
  callback, measured advances and six opaque browser rasters. All six strict
  four-byte comparisons fail pending the shared font/raster contract below;
  the captured scale-1 desktop font environment does not qualify other DPI or
  populated minimap composition.
  `node tools/minimap_lane_raster_capture.mjs`,
  `node --test tests/minimap_lane_raster.test.mjs` and real-driver
  `tests/minimap_lane_raster.tscn` compare the original lane callback, segmented
  points, colors, dash patterns and ten opaque rasters. All ten strict four-byte
  raster cases fail pending the shared lane-renderer contract below; identity
  projection and controlled paths do not qualify real lane geometry or maps.
  `node tools/minimap_cadence_clock_capture.mjs`,
  `node --test tests/minimap_cadence_clock.test.mjs` and
  `tests/minimap_cadence_clock.tscn` retain original fractional-millisecond
  warmup and draw decisions, including exact double bits. The native cadence
  agrees when supplied the original timestamps; a simulation of the current
  integer-millisecond producers retains eight strict failures pending the shared
  clock contract below. This does not qualify real frame scheduling or fog pixels.
  `node tools/minimap_shadow_boundary_capture.mjs`,
  `node --test tests/minimap_shadow_boundary.test.mjs` and real-driver
  `tests/minimap_shadow_boundary.tscn` retain original shadow gate and tangent
  programs. One boundary case fails until the shared browser-distance contract
  below is accepted; controlled blockers do not qualify populated queries or fog
  raster coverage.
- [ ] **S14 — PiP:** certify original companion/decoy selection, stable order,
  ownership/death/lost-link gates, low-power limits, layout and camera offsets.
  Shared-world views must hide only their source body/cockpit while rendering,
  restore masks before copies and stop inactive viewports. Finish pixel,
  frame-order, performance and populated lifecycle/transport acceptance.
  Visibility loss through either the control or its ancestors, detachment and
  retirement must immediately disable updates, release the shared world and
  restore temporary layers. Reattachment requires fresh selection before drawing.
  `node tools/pip_capture.mjs` and real-driver `tests/pip_native.tscn` retain
  original selection/render decisions, layout and native lifecycle/pixel-isolation
  checks. A source detached or queued with an ancestor after selection must stop
  its own viewport before drawing; a queued PiP owner or owner ancestor releases
  every viewport and temporary layer at selection or the pre-draw boundary and
  cannot select again. Losing the last source restores the cockpit mask. A fresh
  selection is required after source reattachment.
  The selected pilot is weakly retained and rechecked before rendering; death,
  detachment, queued deletion of it or an ancestor, or freeing releases every
  viewport and temporary layer. Revival or reattachment needs a fresh selection.
  Hidden or detached PiP controls disconnect both global render callbacks;
  showing or reattaching reconnects them without restoring the retired selection.
  `node tools/pip_pilot_capture.mjs`, `node --test tests/pip_pilot.test.mjs` and
  real-driver `tests/pip_pilot.tscn` retain the original death/revival render
  decisions and native owner/source retirement checks. These controlled actors
  do not qualify populated transport or actual model pixels.
  Source selection, power limits and camera pose are refreshed before drawing.
  `node tools/pip_selection_capture.mjs`, `node --test tests/pip_selection.test.mjs`
  and real-driver `tests/pip_selection.tscn` compare 23 original render decisions
  for loss, death, recovery, insertion, removal, model replacement, movement and
  power changes. The real pre-draw test also checks controlled raster composition
  and world retirement. These cases do not qualify actual model pixels, populated
  transport, full frame ordering or performance.
  `node tools/pip_squad_order_capture.mjs`,
  `node --test tests/pip_squad_order.test.mjs` and `tests/pip_squad_order.tscn`
  compare source index sorting, stable ties and power limits with the selector
  and actual view. The selector matches all seven controlled programs when given
  indices; the view has five failures because its producer exposes no squad index
  and the consumer currently supplies zero for every actor. The source currently
  defaults to one squad member; these synthetic multiple-member cases do not
  establish support for populated multi-member gameplay.
  `node tools/pip_publication_capture.mjs`, `node --test tests/pip_publication.test.mjs`
  and `tests/pip_publication.tscn` compare the original selector on controlled
  snapshot membership with the native authority presentation. Keep the five
  failures across unpublished creation, loss, recovery and removal until the
  snapshot-lifetime contract below is accepted. These cases do not qualify
  populated delivery or actual model pixels.
  `node tools/pip_composition_capture.mjs`, `node --test tests/pip_composition.test.mjs`
  and real-driver `tests/pip_composition.tscn` compare the original Three.js/WebGL
  PiP render and complete opaque browser rasters at 320x568, 1440x900 and
  3840x2160, with one or two views. They retain same-frame scene color changes,
  faction borders, a declared foreground HUD layer, initially hidden cockpit and
  source models, low-power and resolution changes, hidden/reopened views, pilot
  death and lost-link cleanup. Source and native rasters currently agree byte for
  byte; do not loosen the shared raster tolerance. These controlled colors and
  empty scenes do not qualify actual source model pixels, authored HUD composition,
  DPI behavior, full-scene performance or populated transport. The separate
  `tests/pip_native.tscn` retains the full source-provenance gate below.
  Real-driver `tests/pip_model_isolation.tscn` also loads the authored Steel
  decoy, Super drone and T01 cockpit, including their native outline bindings.
  Its two-slot and production-selection frames match direct source-style hiding
  byte for byte, with visible controls for each excluded object and restored
  layers after rendering. These native-to-native comparisons do not qualify
  original model pixels, animated or damaged rigs, populated worlds or transport.
  `node tools/pip_window_capture.mjs`, `node --test tests/pip_window.test.mjs`
  and real-driver `tests/pip_window.tscn` compare the original WebGL border
  pixel bounds with the actual root-window PiP at eight controlled window/scale cases.
  Keep the seven strict failures and window witnesses below until the shared
  responsive-window contract is accepted. The non-unit ratios simulate the
  source CSS-to-framebuffer relation on a scale-1 display; they do not certify
  hardware DPI behavior, populated scene pixels or full HUD composition.
  Decoy and hero eye offsets are added as scalar doubles to the native model
  position before the camera vector enters Float32 storage. `tests/pip_pose.tscn`
  compares 26 original browser poses with Float32-representable model positions,
  including both signs and rounding boundaries, against the consumer plan and the
  actual camera. This does not qualify precision lost before the model position,
  camera rotation pixels, actor interpolation or populated source-model rendering.
  PiP yaw now consumes the existing `SourceQuaternion` axis-angle binding before
  native quaternion storage, so distinct source headings are not collapsed by
  an earlier Float32 angle conversion. `tests/pip_pose.tscn` retains that
  distinction; it does not establish exact source matrix composition.
  `tests/pip_orientation.tscn` retains the stricter original browser camera
  matrix and inverse-matrix gates, including inverse translation, across normal,
  boundary and unbounded reported yaw. The shared double-quaternion,
  browser-trigonometry and camera-transform contracts below remain open. A
  matching native quaternion alone cannot certify the final matrix bits or the
  Godot camera's render transform.

## Campaign presentation

- [ ] **S20 — Campaign presentation:** certify original crawl/pan/zoom/skip,
  portrait/art fallbacks, UTF-16 radio timing, stable portrait ties, timer
  cancellation, transitions and victory transcript/replay. Campaign maps and
  authority stage/progress eligibility remain explicit external contracts.
  Retain generation checks across synchronous `finishing` listeners; cancelled,
  replaced, detached or retiring cinematics must not schedule old completion work.
  Status visibility callbacks during retirement can replace or queue the owner;
  old disposal, empty-play and completion continuations must not affect that
  replacement or emit its predecessor's completion.
  Queued owner ancestors also reject new playback, finish and pending warning or
  completion callbacks; a queue during timer admission cannot start that timer.
  Synchronous visibility, initial layout or scene-selection callbacks may replace,
  dispose or retire playback; old construction cannot restart or overwrite it.
  Art-layer, crawl-section and ending-block admission callbacks may also replace,
  dispose or queue the owner or an ancestor. Retire only the unadmitted child
  after its native entry finishes; removing a child during its entry corrupts
  Godot's container bookkeeping and section `_ready` lifecycle. Ending descendants
  and finish-button theme callbacks keep that same admission guard until the
  complete ending is built, so retired work cannot mutate a replacement button.
  Empty sequence replacement disposes the previous scene before completing.
  `tests/campaign_lifecycle.tscn` covers these lifecycle contracts independently
  of the unresolved native story-art import and complete visual composition.
  Exit opacity applies once to the complete CanvasGroup, using the captured
  original curve. A separate native wall timer retains the 650 ms completion
  deadline; completing or pausing the visual tween cannot settle it early.
  Detachment invalidates pending completion and requires fresh playback after
  reattachment. `node tools/campaign_transition_capture.mjs` and real-driver
  `tests/campaign_transition.tscn` retain the original finish method/CSS, deadline
  boundaries and layered opacity rasters. Controlled color layers do not qualify
  actual story art, blur/vignette filters or complete cinematic composition.
  Crawl frames, art/camera transitions, hold feedback, input and the exit fade
  use wall time while the scene tree is paused or gameplay speed is zero.
  Real-driver `tests/campaign_wall_clock.tscn` checks those boundaries against
  the existing original crawl and CSS references. Its controlled art and coarse
  scheduling checks do not qualify exact transition pixels or hardware input.
  Art opacity retains the original 0.9 s cubic-bezier(0.4,0,0.2,1), stable scene
  order and independent state for every still-visible scene during rapid
  three-way changes. `node tools/campaign_art_capture.mjs` and real-driver
  `tests/campaign_art.tscn` retain original construction/selection methods,
  reversals, unchanged targets and first-frame layered color probes. Native
  SubViewports isolate the groups from the containing presentation CanvasGroup;
  use premultiplied blending with opacity applied to RGBA, and stop retired or
  transparent render targets. Preserve the strict frame-7 comparator failure
  and byte witness below. Declared colors do not qualify actual art decoding,
  fallback pixels, blur, framing, populated transitions or performance.
  The foreground keeps the original primary and fallback images as ordered,
  independently covered layers, including when they name the same image; both
  share the camera transform. `node tools/campaign_fallback_capture.mjs`,
  `node --test tests/campaign_fallback.test.mjs` and real-driver
  `tests/campaign_fallback.tscn` retain twelve controlled browser compositions.
  All unscaled cases and missing-image controls match; four scaled transparent
  cases remain strict failures pending the shared sampling contract below.
  The backdrop still selects a single image, and actual story art remains
  blocked on native encoding; these probes do not qualify the complete scene.
  The static backdrop expands by the original CSS inset before its centered
  scale; foreground motion does not move it. `node tools/campaign_backdrop_capture.mjs`,
  `node --test tests/campaign_backdrop.test.mjs` and real-driver
  `tests/campaign_backdrop.tscn` retain source bounds for twelve scale-1 viewports.
  The geometry comparison does not qualify image decoding, blur pixels, exact
  browser transform rounding or complete cinematic composition.
  The foreground uses the original CSS orientation boundary, clipped inner box,
  landscape borders and browser layout-unit inset; square viewports retain the
  portrait frame while the original camera function still selects its landscape
  pose. `node tools/campaign_frame_geometry_capture.mjs`,
  `node --test tests/campaign_frame_geometry.test.mjs` and real-driver
  `tests/campaign_frame_geometry.tscn` retain seventeen source frame sizes,
  camera targets and six controlled border rasters. Keep the three fractional
  raster failures and shared coverage contract below. These rasters omit the frame
  shadow and do not qualify original art, DPI or complete composition.
  The narrative card retains the original centered landscape/portrait bounds,
  CSS layout-unit quantization and bottom safe-area offset; square viewports use
  the portrait rule. The date and buffering/skip labels sit outside the crawl
  card, keeping its scroll viewport and finish control accessible. The source
  archive/date system bar is fixed to the viewport with its own 44 px horizontal
  and 5 px top padding, independent of the outer HUD's safe-area padding. `node
  tools/campaign_card_capture.mjs`, `node --test tests/campaign_card.test.mjs`
  and real-driver `tests/campaign_card.tscn` compare fifteen browser sizes and
  exercise the fixed bar, wrapped HUD labels, supplied safe insets and finish-button
  reachability. Native font advances determine the current bar's flex allocation;
  the native card border retains the captured source color, opacity and width,
  and the date label retains its source color and font size. Archive bold styling,
  source font metrics and actual text pixels remain unresolved.
  `node tools/campaign_sysbar_capture.mjs`,
  `node --test tests/campaign_sysbar.test.mjs` and real-driver
  `tests/campaign_sysbar.tscn` retain isolated source system-bar gradients and
  bottom borders at three controlled sizes. The native bar still lacks both;
  all three strict raster cases fail. A native gradient and border experiment
  also fails after the test freezes the bar size; the shared group-composition
  contract below retains the isolated alpha witness. These frames do not qualify
  the outer HUD gradient, typography or populated composition.
  These checks do not qualify source text wrapping, the card's typography,
  gradient, blur, clipped corners, hardware safe areas or complete cinematic pixels.
  Scene selection updates the original date, badge and title as distinct fields;
  the badge and title share a horizontal header and the title can truncate.
  `node tools/campaign_heading_capture.mjs`,
  `node --test tests/campaign_heading.test.mjs` and real-driver
  `tests/campaign_heading.tscn` retain original scene changes, repeated and invalid
  indices, imported text and usable portrait/landscape header geometry. Native
  font metrics and header styling still require their separate visual contracts.
  The header panel retains source orientation-dependent padding, background and
  bottom-border values. `node tools/campaign_header_capture.mjs`,
  `node --test tests/campaign_header.test.mjs` and real-driver
  `tests/campaign_header.tscn` check those values and the remaining crawl viewport
  in portrait, landscape and square cases. Badge and title retain their distinct
  source colors; sizes follow the source viewport-relative clamps, rounded to the
  integer sizes supported by Godot.
  Fractional font sizes, source font metrics, text baselines, fractional coverage,
  the parent card's effects and complete header pixels remain unqualified.
  Each crawl section retains the original separate badge and prefixed title,
  including the source marker gap. Their viewport-relative font size follows
  the captured source clamp, rounded to native integer font sizes, and the badge
  and title retain their distinct source colors; fractional sizes and source font
  metrics remain open. `node tools/campaign_header_capture.mjs`
  and `tests/campaign_header.tscn` retain both marker fields across resizes.
  `node tools/campaign_section_marker_capture.mjs`,
  `node --test tests/campaign_section_marker.test.mjs` and real-driver
  `tests/campaign_section_marker.tscn` compare the prologue and both first-chapter
  perspectives and check the marker controls at portrait/landscape sizes. The
  checks do not qualify source typography or complete section styling.
  The marker row retains the source bottom padding, solid border and margin to
  its paragraphs. `node tools/campaign_marker_geometry_capture.mjs`,
  `node --test tests/campaign_marker_geometry.test.mjs` and real-driver
  `tests/campaign_marker_geometry.tscn` check source border values, controlled
  section sizes including empty paragraphs, scroll bounds and focus progress. They
  do not qualify native text metrics, fractional border coverage or complete pixels.
  Crawl paragraphs remain separate, preserve original text and use the captured
  orientation-dependent inter-paragraph margin, color and viewport-relative
  font-size clamp. Font sizes round to native integers; fractional sizing and
  source font metrics remain unresolved. `node
  tools/campaign_paragraph_capture.mjs`, `node --test tests/campaign_paragraph.test.mjs`
  and real-driver `tests/campaign_paragraph.tscn` compare browser DOM content and
  margins, font sizes and color with native controls for the prologue and both
  first-chapter perspectives.
  These checks do not qualify text indent, line height, source wrapping or pixels.
  Active and inactive crawl sections retain the original opacity, 0.4 s ease
  transition and reversal-shortened durations. The initial selection, including a
  middle-chapter start, appears immediately; later changes animate independently
  on wall time. Each section isolates its content before applying group opacity
  and retires its render target and tween on removal.
  `node tools/campaign_section_opacity_capture.mjs`,
  `node --test tests/campaign_section_opacity.test.mjs` and real-driver
  `tests/campaign_section_opacity.tscn` compare original transition programs,
  initial and controlled overlapping-layer pixels inside the presentation group,
  and pause/visibility/retirement behavior. These controlled colors do not qualify
  actual text pixels, clipping at hardware DPI, full cinematic composition or
  the performance of populated sections.
  Section heights include the source bottom padding and reserved border width;
  the inter-section margin also precedes the ending block. `node
  tools/campaign_section_geometry_capture.mjs`,
  `node --test tests/campaign_section_geometry.test.mjs` and real-driver
  `tests/campaign_section_geometry.tscn` compare controlled scroll bounds, section
  offsets and focus progress in both orientations and a square viewport. Original
  dashed-border coverage is captured by
  `node tools/campaign_section_border_capture.mjs`,
  `node --test tests/campaign_section_border.test.mjs` and real-driver
  `tests/campaign_section_border.tscn`. The border remains undrawn pending the
  shared renderer contract below; actual text layout remains open.
  The crawl ending retains the source divider and distinct prologue/chapter notes.
  Prologue uses its original terminal button even when a caller supplies another
  label; a chapter uses its supplied label or the source fallback when empty.
  `node tools/campaign_ending_capture.mjs`, `node --test tests/campaign_ending.test.mjs`
  and real-driver `tests/campaign_ending.tscn` retain the original construction,
  both briefing labels and a real GUI click on the visible finish button.
  `node tools/campaign_ending_geometry_capture.mjs`,
  `node --test tests/campaign_ending_geometry.test.mjs` and real-driver
  `tests/campaign_ending_geometry.tscn` compare the source ending's padding,
  divider and note spacing, scroll limit and focus with controlled element heights
  in three orientations. The finish button also retains the computed source
  content insets, font size and pointer cursor. The `.btn.big` selector overrides
  the later, less-specific `.prologue-finish-btn` declarations.
  `node tools/campaign_finish_button_capture.mjs`,
  `node --test tests/campaign_finish_button.test.mjs` and real-driver
  `tests/campaign_finish_button.tscn` check those insets in normal, hover, pressed
  and disabled states and controlled content boxes at three viewport sizes. Actual typography,
  letter spacing, text wrapping, button colors, notch and the caller contract
  below remain unqualified.
  Foreground transforms retain the original 0.25 s cubic-bezier(0.1,0.8,0.3,1),
  whole-transform reversal shortening and unchanged-target behavior. Serialize
  source camera targets through `CssDecimal` before comparison; keep interpolation
  tuples and Bezier controls in double precision until native image storage.
  Resize reapplies the current pose without restarting its transition, while the
  blurred background remains fixed. `node tools/campaign_pose_capture.mjs` and
  real-driver `tests/campaign_pose.tscn` retain original camera functions and
  unrounded typed CSS samples for every original camera/orientation. Browser
  completion states also verify settled native coordinates. These probes do not
  qualify actual art/framing pixels, per-frame crawl/target delivery, complete
  populated cinematic composition or platform/DPI behavior.
  Crawl uses its own monotonic wall-frame timestamp, updated even while paused
  or at the scroll limit. Preserve the original 0.1 s delta cap, strict pause
  deadline and each DOM scroll write/read; hidden fractional accumulation changes
  the source's frame-rate-dependent pixel quantization. Fresh playback resets
  both the retained viewport position and frame clock. Original browser probes
  at scales 1/1.25/1.5/2 retain the same integer logical-pixel readback.
  `node tools/campaign_crawl_capture.mjs` and real-driver
  `tests/campaign_crawl.tscn` retain original controller methods and real browser/
  native scroll containers, including half-pixel, pause, gap, limit and replay
  cases. Declared geometry isolates scrolling; it does not qualify narrative
  layout, complete frame ordering, camera-target delivery or hardware DPI behavior.
  The crawl viewport retains the source landscape/portrait padding, including the
  portrait rule for square viewports. Section focus and deferred chapter jumps
  include its top inset; the bottom inset contributes to scroll clamping.
  `node tools/campaign_crawl_insets_capture.mjs`,
  `node --test tests/campaign_crawl_insets.test.mjs` and real-driver
  `tests/campaign_crawl_insets.tscn` compare original padded geometry, focus,
  camera targets, chapter jumps and native GUI wheel/touch propagation. Controlled
  section sizes do not qualify source typography, scrollbar pixels or hardware input.
  `node tools/campaign_scrollbar_capture.mjs`,
  `node --test tests/campaign_scrollbar.test.mjs` and real-driver
  `tests/campaign_scrollbar.tscn` retain original classic-scrollbar dimensions,
  controlled thumb rasters and scroll positions with the separate edge mask
  disabled. Keep the strict width and pixel failures and shared adapter contract
  below; these cases do not qualify overlay scrollbars, hardware DPI or input.
  `node tools/campaign_crawl_mask_capture.mjs`,
  `node --test tests/campaign_crawl_mask.test.mjs` and real-driver
  `tests/campaign_crawl_mask.tscn` retain original edge-mask pixels and unmasked
  controls. Keep the three strict mask failures and renderer contract below;
  controlled color layers do not qualify text, scrollbars or full cinematics.
  Camera-target delivery follows the original frame branch: paused or saturated
  automatic scrolling does not reevaluate focus solely because section geometry
  changed. Explicit scroll/resize producers retain their own focus updates.
  If scene selection synchronously replaces, disposes or retires playback, its
  old scroll update cannot deliver a camera target to the replacement. The
  deferred chapter jump also stops before selecting a scene in a replacement.
  Art-layer visibility callbacks may also replace or retire playback or select
  another scene synchronously; the superseded selection cannot continue its
  layer loop, overwrite the heading or create an obsolete opacity tween.
  `node tools/campaign_delivery_capture.mjs` and real-driver
  `tests/campaign_delivery.tscn` connect actual scroll controls to original
  nearest-section/camera functions, including gaps, ties, zero heights and
  per-scene serialized targets in both orientations. Controlled section geometry
  does not certify live typography, event-loop/render timing or full cinematics.
  Initial playback clamps the requested chapter once, before initial selection
  and the deferred jump. Layout must not deliver camera targets before that
  source callback. A middle-chapter jump retains the requested selection even
  when scroll clamping or zero-height sections makes focus choose another scene;
  retain any camera target already delivered to that other scene.
  `node tools/campaign_start_capture.mjs` and real-driver
  `tests/campaign_start.tscn` retain original `play`/focus/camera methods, browser
  scroll quantization, both orientations, out-of-range indexes and empty/clipped
  section geometry. Declared geometry and initial native layout probes do not
  certify narrative layout or full event-loop/render ordering.
  Skip input retains original millisecond clocks and strict 650/350 ms hold/tap
  boundaries. Cancelled or unpaired releases never become taps; finish-button
  exclusion follows the touch origin, and release/cancel never extends the crawl
  pause. Replacement callbacks must not inherit retired input state.
  `node tools/campaign_input_capture.mjs` and real-driver
  `tests/campaign_input.tscn` compare original handlers and directed native
  replacement callbacks. Event-target doubles and direct native input dispatch
  do not qualify hardware touch bundling, GUI button activation, source image
  buffering, crawl/art pixels or complete campaign/transport acceptance.
  `node tools/campaign_touch_bundle_capture.mjs`,
  `node --test tests/campaign_touch_bundle.test.mjs` and real-driver
  `tests/campaign_touch_bundle.tscn` additionally compare actual Chromium CDP
  two-contact event order with native touch dispatch for a ready chapter. A single
  CDP release of two contacts produces separate `touchend` callbacks and can
  trigger the source double tap; a grouped cancellation produces no tap. The
  tests also retain separate release deadlines and finish-button origins. CDP
  synthesis and direct native dispatch do not establish physical-device event
  bundling or GUI clicks.
  `node tools/campaign_button_input_capture.mjs`,
  `node --test tests/campaign_button_input.test.mjs` and real-driver
  `tests/campaign_button_input.tscn` compare actual Chromium controller/button
  events with native GUI dispatch for pending and ready clicks, cancellation and
  drags into, out of and back into the button. Native scroll start cancels the
  long-press feedback and retains the later touch-end clock. On a host without a
  touchscreen the test injects the native scroll-start notification at the
  captured browser cancellation, so it does not qualify gesture thresholds,
  physical-device behavior or full cinematic layout.
  Mouse long-press follows the source pointer lifetime: the first physical
  button starts the hold, additional buttons and wheel movement do not restart
  it, and the last physical button release cancels it. `node
  tools/campaign_mouse_buttons_capture.mjs`,
  `node --test tests/campaign_mouse_buttons.test.mjs` and real-driver
  `tests/campaign_mouse_buttons.tscn` compare Chromium's actual right, middle,
  side-button, wheel and overlapping left/right event sequences with native
  dispatch. These controlled events do not qualify hardware input or touch emulation.
  Mouse double-click skips or warns only after the second left-button release,
  matching browser `dblclick` ordering. An intervening mouse-button press cancels
  that pending double-click; wheel input does not. Replacement, finish and tree
  removal discard a pending press. Synchronous hold feedback callbacks must not
  deliver a retired long press, touch release, mouse press or finishing signal to
  a replacement, or consume its touch ownership. `node tools/campaign_double_click_capture.mjs`,
  `node --test tests/campaign_double_click.test.mjs` and real-driver
  `tests/campaign_double_click.tscn` retain actual Chromium mouse sequences and
  controlled native dispatch for ready, buffering and interrupted gestures.
  Hardware input and browser-specific click thresholds remain unqualified.
  A completed long press cancels and resets its feedback before checking the
  buffer, including repeated blocked attempts and a later successful skip.
  `node tools/campaign_hold_warning_capture.mjs`,
  `node --test tests/campaign_hold_warning.test.mjs` and real-driver
  `tests/campaign_hold_warning.tscn` retain the original warning/hold sequence.
  Hold feedback retains the original zero-coordinate fallback and viewport clamp,
  circumference targets, CSS ease/linear curves and reversal-shortened durations.
  Restarting an active hold resets progress without restarting its opacity fade.
  `node tools/campaign_hold_capture.mjs`, real-driver
  `tools/import_campaign_hold.tscn` and `tests/campaign_hold.tscn` retain the
  dedicated source identities and atomically published lossless native backplate.
  Keep PNG alpha-border processing out of that resource. Its isolated SubViewport
  and premultiplied texture opacity must also work inside the outer presentation
  group; `tests/campaign_hold_render.tscn -- --nested-presentation` retains that
  composition gate. Scope and hold consumers
  share `CssTransition`, with `tests/scope_transition.tscn` retaining its source
  oracle. Run `tests/campaign_hold_render.tscn` for the seven original pixel cases;
  static/group controls pass but dynamic native SVG stroke coverage remains an
  open shared-renderer contract below. Do not certify full cinematic pixels,
  fractional/DPI placement, hardware input, export or performance from these probes.
  Prologue playback continues while native image/font cache attempts run. Gesture
  skipping waits for every attempt; the explicit finish button retains its source
  bypass. A non-prologue chapter starts already ready, displays the original ready
  status and skip hint, and never starts another buffer. Replacing a prologue with
  a chapter must reject retired progress callbacks without hiding that status.
  `node tools/campaign_chapter_status_capture.mjs`,
  `node --test tests/campaign_chapter_status.test.mjs` and real-driver
  `tests/campaign_chapter_status.tscn` retain both original play branches, progress,
  immediate chapter skipping and replacement. Status visibility callbacks may
  retire, detach or queue the owner without starting stale buffering or clocks.
  The status and skip hint use the original computed font size; the hint changes
  between its original pending and ready foreground colors. `node
  tools/campaign_hint_style_capture.mjs`,
  `node --test tests/campaign_hint_style.test.mjs` and real-driver
  `tests/campaign_hint_style.tscn` compare three viewport sizes, prologue/chapter
  transitions and replacement from a synchronous hint theme callback. Source
  letter spacing and font metrics remain unqualified. The ready hint still lacks
  its two separate styled key badges. `node tools/campaign_hint_badges_capture.mjs`
  and `node --test tests/campaign_hint_badges.test.mjs` retain the original
  pending/ready/repeated-switch DOM and CSS, including a constrained-width flex
  case: the two badge boxes wrap internally and reach 27.5 by 32 px inside a
  120 px hint, rather than remaining fixed-size icons. Preserve their source text,
  padding, border, radius, flex gap and inherited letter spacing. Native layout
  and pixels still need the shared font contract and fractional coverage checks;
  these browser measurements use the captured local font environment and do not
  qualify native text or complete HUD pixels.
  Status text retains the original pending/ready/warning inherited colors and
  0.3 s ease transition, including shortened repeated reversals. Warning text is
  immediately red; later buffer progress restores inherited color without
  clearing the warning state. `node tools/campaign_status_color_capture.mjs`,
  `node --test tests/campaign_status_color.test.mjs` and real-driver
  `tests/campaign_status_color.tscn` compare browser color samples, repeated
  warnings, reversal timing, paused wall time and replacement callbacks. The
  original status element retains its warning class across finished playback;
  a retired warning timer cannot clear it during the exit fade or a later scene.
  `node tools/campaign_status_persistence_capture.mjs`,
  `node --test tests/campaign_status_persistence.test.mjs` and real-driver
  `tests/campaign_status_persistence.tscn` compare five original DOM/controller
  lifecycles through chapter playback and prologue replay. These probes reuse a
  single native presentation owner; they do not qualify host recreation. The
  warning status flashes with the original two 0.35 s ease cycles, centered scale
  and opacity; repeated warnings and progress do not restart it, while hiding and
  showing a retained warning does. `node tools/campaign_status_flash_capture.mjs`,
  `node --test tests/campaign_status_flash.test.mjs` and real-driver
  `tests/campaign_status_flash.tscn` compare browser animation values, lifecycle,
  paused wall time and a controlled composed viewport. The independently colored
  ready check, status spinner, text metrics and complete status pixels remain
  unqualified. Failed attempts count toward progress, not asset availability.
  Preserve independent 1800 ms
  warning deadlines, generation checks and decoder drains across replacement/exit,
  including pause and zero gameplay speed.
  Cache jobs stop admitting or publishing results as soon as their loader or an
  owner ancestor is queued for deletion, including during a progress callback.
  Original model warming currently has an empty base manifest; reject nonempty/custom manifests
  until their native preload contract is published. Keep retained successful
  resource-cache entries separate from cancelled owners and private scene state.
  `node tools/campaign_buffer_capture.mjs` and real-driver
  `tests/campaign_buffer.tscn` retain original cache/error/skip programs, native
  resource requests, held-decoder retirement and warning timers. Controlled art
  layers do not qualify actual story decoding, warning CSS/flash appearance,
  complete cinematic pixels or hardware input. Successful-image readiness and
  complete first-play loading still require the shared story-encoding contract
  below and publication of the remaining preload images (`assets/logo_flat.png`
  and `assets/loading/`) through Opus-owned `tools/import_source.mjs`, preserving
  the original paths, decoded bytes and explicit failure behavior.
  Automatic radio retains original empty-scene, UTF-16 timer, replacement/clear,
  viewer-relative portrait/guest and single-speaker endpoint behavior. A hidden
  portrait endpoint stays hidden when receiving a speaker update.
  `node tools/dialogue_native_capture.mjs` and real-driver
  `tests/dialogue_native.tscn` compare original Dialogue methods and actual native
  character/mech asset bindings. DOM probes observe mutations without qualifying
  CSS layout/filter pixels. Manual `next()` is source storybook inspection only;
  live gameplay must remain automatic. Portrait opacity retains the original
  initial 0.35/1 endpoints and 0.18 s ease-out transitions, including unchanged
  targets, repeated reversals, wall time and immediate retirement on clear.
  `node tools/dialogue_portrait_capture.mjs`, `node --test tests/dialogue_portrait.test.mjs`
  and real-driver `tests/dialogue_portrait.tscn` compare the original browser CSS
  and actual radio endpoint selection. The independent grayscale filter, faction
  frames and complete radio/transcript composition remain open.
  Radio and transcript callbacks retain absolute monotonic wall deadlines,
  including native timeouts that arrive early. Gameplay speed and SceneTree pause
  must not freeze their timers or the radio retirement tween. Reject duplicate
  delivered callbacks and retired-generation callbacks before scheduling work.
  `tests/dialogue_clock.tscn` checks strict deadline edges, replacement, actual
  paused zero/slow/fast timers and bar retirement; the original dialogue fixture
  retains every automatic line duration. These clock checks do not qualify radio
  mount/unmount CSS curves, transcript reveal motion or complete overlay pixels.
  Dialogue detachment cancels pending radio/transcript deadlines and native
  animations; reattachment requires fresh playback. Seal old radio references
  before visibility callbacks, and cancel superseded construction or clock
  continuations before admitting nodes or timers. A queued/detached transcript
  host or its ancestor must not construct, reveal or scroll from a pending
  deadline; a queued row ancestor also rejects the reveal. Queuing any dialogue
  owner ancestor rejects new commands, pending deadlines and unfinished native
  admission or layout work. Preserve replacement state during clear/dispose/
  expiry callbacks and release unadmitted portraits.
  Isolated radio, transcript and crawl-section layers also stop their render
  targets when initially hidden or detached; reattachment follows effective
  visibility and cannot restart a retired layer.
  `node tools/dialogue_owner_capture.mjs` executes original `_after`, `clear`
  and `dispose` with declared timer/DOM probes; real-driver
  `tests/dialogue_owner_retirement.tscn` checks these programs and native
  admission, reentrancy, paused detachment and retained-owner resource release.
  This scoped cancellation oracle does not qualify the full original dialogue
  dependency graph, layout, art/filter pixels or populated campaign delivery.
  Radio mount/unmount retains the original 320/400 ms ease-out/ease-in curves,
  14/10 px offsets and separate 420 ms removal deadline. Animate an isolated
  premultiplied SubViewport through Sprite2D so fractional translation samples
  the complete group without GUI pixel snapping. Hidden and retired groups must
  stop drawing, and replacement must cancel the old entrance/exit motion.
  `node tools/dialogue_motion_capture.mjs` and real-driver
  `tests/dialogue_motion.tscn` retain unrounded CSS Typed OM values and original
  removal methods. Controlled overlapping color layers qualify group animation,
  not actual radio layout, portrait filters, typography or complete overlay pixels.
  Radio width, centered bottom anchoring, padding, note/row gaps and avatar sizes
  follow the original viewport width and 720 px breakpoint. Dynamic content
  changes recompute the bottom anchor. `node tools/dialogue_radio_layout_capture.mjs`,
  `node --test tests/dialogue_radio_layout.test.mjs` and real-driver
  `tests/dialogue_radio_layout.tscn` compare 27 controlled browser geometries,
  resizing across the breakpoint and width cap, plus a long native dialogue line.
  Controlled content heights do not qualify native text wrapping, fractional
  inner layout, faction borders, gradients or
  complete radio composition.
  A single-speaker radio retains the empty third grid track and its trailing gap;
  showing or hiding the right endpoint updates that track without changing the
  left portrait or text. `node tools/dialogue_radio_grid_capture.mjs`,
  `node --test tests/dialogue_radio_grid.test.mjs` and real-driver
  `tests/dialogue_radio_grid.tscn` compare 48 controlled source geometries at
  four viewport sizes and check a real single-speaker scene. Controlled integer
  rectangles do not qualify fractional placement, typography or portrait pixels.
  Radio title and note remain separate, with the original gap, font size and
  neutral note color; the title and side border follow each speaker's faction.
  `node tools/dialogue_radio_note_capture.mjs`,
  `node --test tests/dialogue_radio_note.test.mjs` and real-driver
  `tests/dialogue_radio_note.tscn` execute original dialogue markup and compare
  empty and escaped fields across Steel, Swarm and mercenary speakers, plus long
  native text. `tests/dialogue_owner_retirement.tscn` also exercises cancellation
  during title admission.
  Source font weight, baselines, fractional glyph metrics, full flex wrapping,
  backdrop and faction-frame pixels still need their separate contracts.
  Radio speaker size, text color and speaker-to-line gap retain the original CSS;
  the dialogue font size changes at the same 720 px viewport breakpoint, including
  when an existing bar is resized. `node tools/dialogue_radio_text_capture.mjs`,
  `node --test tests/dialogue_radio_text.test.mjs` and real-driver
  `tests/dialogue_radio_text.tscn` compare original text updates and CSS at four
  viewport sizes, including empty, escaped and supplementary-plane text. Original
  font selection, letter spacing, line height, wrapping and pixels remain open.
  Layout continuations stop when font or size callbacks replace or clear the
  owner; the same fixture exercises both reentrant cases.
  Transcript rows retain original integer-millisecond stagger arithmetic and
  260 ms ease-out group opacity/6 px translation, independent of gameplay pause.
  Clear cancels pending reveals without hiding rows already revealed. Removing
  a row retires its tween and isolated render target before deferred destruction.
  Nearest scrolling uses transformed row bounds, oversized-row rules, current
  scrollbar ranges before native layout catches up, and visible inner bounds
  when propagating through multiple scroll ancestors.
  `node tools/dialogue_transcript_capture.mjs` executes original `Dialogue.scene`
  in Chromium; real-driver `tests/dialogue_transcript.tscn` retains original
  line/avatar/direction/timing programs, controlled reveal rasters and directed
  browser scroll geometry. These probes do not qualify source transcript padding,
  typography, full portrait/backplate composition or complete settlement layout.
  `node tools/dialogue_layout_capture.mjs` retains all authored base-settlement
  transcripts in both art modes at 360/720/721/1440 px widths, actual downloaded
  Noto font usage, pinned external font response hashes and original image bytes.
  `tests/dialogue_layout.test.mjs` verifies complete scenario coverage, source
  identity and sealed PNG crops using their exact fractional bounding rectangles.
  Retain CSS weight selection even when the font's internal family name contains
  `Thin`. Source references populate only `overTalk` in the original
  overlay markup over a declared constant backdrop; winner/statistics content,
  touch-device classes, native typography and full settlement acceptance remain
  unresolved. Preserve the native inner script scroller and absolute background
  portrait slots; portraits must not contribute an in-flow row or intrinsic height.
  `node tools/dialogue_body_capture.mjs` retains original CSS boxes with declared
  minimum-height rows and visible browser scrollbars. `tests/dialogue_body.tscn`
  checks the inner padding/gaps, reserved scrollbar width, viewport cap, responsive
  portrait geometry and viewport reattachment. The visible scrolling box retains
  fractional source layout units independently of Godot's rounded VBox allocation.
  These probes do not qualify header baselines, actual font wrapping, outer
  settlement spacing, rounded portrait clipping, gradient mattes or scrollbar
  pixels. Keep the shared font/material gates below before full composition.
  `node tools/dialogue_fonts_capture.mjs` extends the frozen font responses to
  every original radio/settlement character, preserving `zh-Hant` Canvas language
  selection. `tools/import_dialogue_fonts.tscn` atomically publishes the original
  WOFF2 bytes as a native Theme with separate 400/700 variation/fallback graphs,
  explicit glyph coverage and an embedded original licence. It rejects changed
  input hashes, missing subsets and silent system fallback. Run
  `tests/dialogue_fonts.tscn` for reload/identity/coverage and
  `tests/dialogue_font_metrics.tscn` for the separate strict browser-advance gate.
  Keep its current precision failures visible; resource publication does not
  qualify native typography or source line wrapping. Bind the Theme only after
  the shared advance contract below is accepted for the relevant text consumer.

## Integration and handoffs

- **Opus — player FOV projection boundary:** agree a source-faithful camera
  projection contract for `scripts/main.gd::_advance_view` and, if an adapter is
  required, `scripts/source_camera_projection.gd`. The source Three.js camera
  builds its perspective matrix from a double FOV, while the native camera FOV
  is stored as float32. A real OpenGL Compatibility probe compared the original
  Three.js perspective implementation (source CRLF SHA-256
  `c6eacae1ec5fd832160227ca7441311c8b30dee0419af87954fb9df6d105bf1f`)
  in V8 against `Camera3D.get_camera_projection()` for the 431 controlled FOV
  sequence frames; 179 matrices differ after source elements are converted to
  float32. At source FOV `51.9427649280755`, native FOV is
  `51.9427642822266`, source matrix x scale is `1.28306603431702`, and native is
  `1.28306591510773`; the 68-degree control agrees. The input/expected matrices,
  native probe and driver output are in `artifacts/terra/fov_projection_sequence.json`,
  `artifacts/terra/fov_projection_probe.tscn` and
  `artifacts/terra/fov-projection-sequence.log`. Acceptance: compare the actual
  Chromium Three.js projection and native render/previous-frame projection over
  zoom, reversal, viewport/aspect and near/far cases, without widening tolerances;
  retain view-lock ordering and authority boundaries. Terra binds an accepted
  projection contract separately. The controlled matrix comparison is not a
  populated view-lock or pixel test.

- **Opus — bunker snapshot coordinate precision:** define a recipient-visible
  scalar-double bunker coordinate contract in `scripts/unit.gd::snapshot`,
  `scripts/actor_snapshot.gd::project` and `scripts/simulation.gd` before Terra
  binds it in `scripts/minimap.gd::accept_snapshot`. The current snapshot
  publishes `global_position` as Vector3, which rounds source coordinates before
  the original `Math.round` deduplication and persistent marker storage. Preserve
  recipient visibility, snapshot order, source world-axis inversion and the
  original unrounded coordinates where authoritative source values exist; do not
  manufacture precision from an already-rounded Vector3. Acceptance: the source
  boundary cases in `tests/minimap_bunker_precision.tscn` pass through the real
  offline, ENet and WebSocket publication path, including replacement, memory
  persistence and match reset. Terra then wires the agreed fields separately.

- **Flash — death-page inset host:** expose an actual death-page frame and its
  effective visibility through `scripts/native_ui.gd` for a future Terra-owned
  frontline inset. Preserve the original `#deadCam` bounds, 16:9 aspect, 2 px
  border, desktop/touch width rules, caption, overlay stacking and the existing
  countdown/respawn lifecycle. Acceptance: original browser geometry and native
  frame agree across desktop, portrait and touch sizes; show, hide, detach and
  respawn immediately retire the inset without intercepting gameplay input.
  Do not display a generic or empty replacement while its camera is unavailable.
- **Opus — frontline inset publication:** define the recipient-view contract in
  `scripts/main.gd`, `scripts/simulation.gd` and, if needed,
  `scripts/actor_snapshot.gd` for the Terra death-view consumer. Publish the
  original enemy-base world coordinates as scalar doubles, snapshot-ordered actor identity, kind,
  side, death state, model availability/position and measured top height, plus
  death-sequence/game-over/respawn gates and the death position/terrain query.
  Preserve recipient visibility, prior-snapshot lifetime and combat authority;
  do not substitute live authority-only entities. Acceptance: original tower,
  base and no-source fallbacks plus death, respawn and game-over transitions
  agree offline and over ENet/WebSocket before binding `PipDeathState.source`
  and a Terra-owned camera/render consumer. The exact browser distance and
  camera orientation contracts below still apply to its pose.

- **Flash — cinematic chapter return label:** tracked in
  [F2](../flash/MIGRATION.md#ready-for-bounded-implementation). Terra retains
  `CampaignCinematic.play()` and its source-derived default/override contract;
  the caller correction requires no Terra producer or shared-label change.

- **Opus — shared campaign dialogue deadline fixture:** update
  `tests/campaign_suite.gd::dialogue_lifecycle` to advance a controlled wall
  clock before expecting the next radio line. The fixture currently emits a
  fresh timer immediately and expects delivery before its source deadline;
  `CampaignDialogue` correctly rearms that early signal, as retained by
  `tests/dialogue_clock.tscn`. Preserve the retired-generation cancellation
  check, verify that an early signal does not advance the line and that the
  deadline advances it once. Acceptance: both dialogue clock and campaign
  lifecycle assertions pass; the separate missing campaign terrain resources
  remain an independent acceptance gate.

- **Opus — PiP recipient snapshot lifetime:** define the recipient presentation
  boundary in `scripts/simulation.gd::apply_presentation_view`,
  `scripts/unit.gd` and, if needed, `scripts/main.gd::_receive_state`, before
  Terra binds `scripts/pip_view.gd` to it. The original client selects from its
  received entity map and updates a decoy's lost flag only on receipt. The native
  authority instead exposes live `units` and `special`; new units default to
  `presentation_visible = true`, and a removed carrier is erased and queued
  before the next presentation snapshot. In `tests/pip_publication.tscn`, a newly
  created decoy appears before publication, loss and recovery take effect early,
  and a removed decoy disappears while the prior snapshot still contains it.
  Acceptance: expose recipient snapshot membership, loss state and renderable
  lifetime through the publication boundary without changing combat authority;
  pass all eleven original selection steps and existing PiP lifecycle/composition
  tests, then verify offline, ENet and WebSocket with populated carriers. The
  controlled snapshot program alone does not qualify delivery or real model pixels.
  Also publish the original per-entity squad index (`e.si || 0`) through
  `scripts/actor_snapshot.gd`, `scripts/unit.gd` and the recipient presentation
  boundary, preserving received insertion order and distinguishing squad index
  from player `spawn_slot`. `scripts/pip_view.gd` currently hardcodes every index
  to zero: `tests/pip_squad_order.tscn` retains five failures when controlled
  source rows have distinct indices, although `PipViewState.sources` sorts them
  correctly. After the producer contract is agreed, Terra must feed the test's
  captured indices through that real publication path and bind the view to it.
  Acceptance includes all seven source order cases, default zero, equal-index
  stability, low-power limits and snapshot replacement before populated delivery.

- **Opus — responsive root window:** establish a shared full-client-area and
  pixel-ratio contract in `project.godot` and `scripts/main.gd::_build_ui` before
  Terra retargets the `PipView` window coordinates. The current canvas-items
  stretch fixes the visible viewport at 1440×900 and letterboxes other aspect
  ratios. With a real 320×568 window at display scale 1, the original Chromium
  PiP border bounds are `[10, 56, 58, 37]` pixels, while native bounds are
  `[2, 196, 56, 35]`; at 640×360 they are `[10, 56, 113, 72]` and
  `[36, 22, 100, 63]`. Even the same-aspect 720×450 window produces
  `[5, 28, 124, 78]` instead of `[10, 56, 126, 80]`, because fixed source
  margins are scaled. `tests/pip_window.tscn` keeps seven of eight original
  window/scale cases failing; captured bounds remain in
  `artifacts/terra/pip-window-report.json` and the 1440×900 control passes.
  New evidence requires an unused directory via `--evidence-dir`.
  Coordinate and clipping changes must preserve the main camera, HUD, minimap,
  scope and input consumers. Acceptance: the strict source/native border bounds
  and existing `tests/pip_composition.tscn` pass at portrait and landscape
  sizes, followed by actual hardware-DPI and populated match checks. Simulated
  pixel ratios alone do not qualify hardware-DPI or actor rendering.

- **Opus — shared player camera and body heading:** agree an authority/presentation
  contract for `scripts/simulation.gd::camera_origin_at`/`third_person_camera`
  and `scripts/unit.gd::advance_player_view` before Terra changes
  `scripts/camera_pose.gd::third_person_anchor` or
  `scripts/player_view_state.gd::advance_body`. The same helpers feed both the
  displayed camera/body and authority view origins, muzzle targeting, blast
  feedback and reported body headings. In controlled native-representable inputs,
  `tests/player_tps_anchor.tscn` currently disagrees with the captured Chromium
  query or camera Float32 values in 312 of 720 cases; the original method uses
  scalar-double shoulder, height and floor arithmetic before native conversion.
  `tests/player_view_body.tscn` retains 96 failing consecutive-frame assertions
  because native Vector3 squared-length rounding crosses the original strict
  threshold in both directions. Acceptance: preserve authority settlement and
  visibility while defining which side owns these boundaries, then pass both
  strict source fixtures, the player-view suite and populated TPS ENet/WebSocket
  cases. Terra binds an accepted presentation contract in a separate change;
  the controlled fixtures cannot establish upstream precision or populated worlds.

- **Sol — camera obstruction hit distance:** agree a source-faithful segment-hit
  contract for `scripts/world.gd::obstruction_hit` before Terra changes the
  collision binding in `scripts/spectator_camera.gd` and
  `scripts/camera_pose.gd`. The original `_blockerHitT` returns a scalar hit
  distance from the double-precision segment; the existing world API returns a
  native Vector3 hit position. In the controlled four-metre ray cases 652/653 of
  `tests/fixtures/spectator_tps.json`, constructing that native hit position and
  measuring it from the original anchor yields 3.99999989123131 m. The resulting
  final z is 1.6303430795669556 instead of 1.6303431987762451, so the strict
  `tests/spectator_tps.tscn` keeps both failures. Native/source witnesses are in
  `artifacts/terra/spectator-tps-final.json`; these are controlled rays, not a
  populated world qualification. Preserve collision masks, segment ordering and
  real blocker geometry. Acceptance: publish source-equivalent scalar distances
  for the original double endpoints, pass the strict captured and additional
  boundary cases without fabricated distances or wider tolerances, then verify
  actual world obstruction, terrain and player/spectator camera integration.
  Terra binds the accepted producer contract in a separate change.

- **Models — source camera quaternion composition:** provide a double-preserving
  yaw-to-basis contract in `scripts/source_quaternion.gd` for consumers including
  `PipView`. Original Three.js composes its camera matrix from double quaternion
  components before Float32 matrix storage; `SourceQuaternion.axis_angle` and
  `SourceQuaternion.basis` currently store the quaternion in Float32 first.
  Chromium quaternion and final matrix bits at normal, ±π/2 and large reported
  yaw are retained in `tests/fixtures/pip_composition.json::poseCases`, with
  before/after native basis and scalar witnesses in
  `artifacts/terra/pip-orientation-report.json`. At yaw 1000000.02, maximum
  basis error falls from 0.0188037753105164 to 0.000000059604644775390625,
  but the strict matrix gate still fails.
  Acceptance: direct results match every captured Float32 camera basis, with
  unbounded yaw, source operation order and no tolerance widening; preserve
  existing model and spectator APIs. The required browser sine/cosine and native
  camera-transform contracts remain Opus-owned below. After those are accepted,
  `tests/pip_orientation.tscn` must also pass through the actual PiP camera.
  Terra binds the accepted API separately.
- **Opus — PiP camera-transform boundary:** investigate a native camera binding
  in `scripts/source_camera_transform.gd` if an adapter is needed, preserving
  the original Three.js camera world and inverse transform in the existing
  `Camera3D`/`SubViewport` path. At yaw 1000000.02 the captured Float32 basis is
  retained by `Camera3D.transform.basis`, but both `global_basis` and
  `get_camera_transform()` differ by one Float32 ULP; the latter's
  `affine_inverse()` differs from the captured Three.js inverse as well.
  Godot 4.7.2's [`Camera3D`](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/camera_3d.cpp)
  orthonormalizes its camera transform, and its
  [`RendererSceneCull`](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_scene_cull.cpp)
  also orthonormalizes transforms sent through `RenderingServer`; simply toggling
  `set_disable_scale` or writing the same matrix directly cannot establish the
  captured view matrix. The project uses GL Compatibility, whose
  [GLES3 renderer](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_scene_gles3.cpp)
  takes an affine inverse after the server boundary. The native fixture mirrors
  that extra normalization and inverse in its CPU comparison. Twelve captured
  inverse translations differ, by up to 0.0001220703125 on the controlled
  Float32-representable model positions. The source matrix and inverse and both
  native values are recorded in
  `tests/fixtures/pip_composition.json::poseCases` and
  `artifacts/terra/pip-orientation-report.json`. This CPU comparison does not
  certify GPU uniforms or scene pixels. Acceptance: the original world and
  view-matrix rotation and translation cases pass `tests/pip_orientation.tscn`
  through the actual PiP camera after the Models quaternion and browser trig contracts,
  with no wider tolerance, plus real-driver PiP source-pixel comparisons.
- **Opus — browser pulse sine:** provide an accepted shared binding in
  `scripts/source_trigonometry.gd` for original browser `Math.sin` before Terra
  certifies bit-identical lock-glow scalar states. `tests/fixtures/lock_glow.json`
  retains original Node and Chromium constructor/callback outputs, runtime
  identities, pulse inputs and sine bits. Current native phase bits agree, but
  the native sine differs at large inputs and changes 249 halo-size/opacity and
  ring-scale double results; the strict scene deliberately remains failing.
  `artifacts/sol/lock-glow-differences.json` records each input and both sine
  bit patterns. The sampled native Float32 outputs and ring orientations agree;
  those checks cannot establish scalar parity. Acceptance: all captured scalar
  bits and additional argument-reduction boundaries agree with the original
  Chromium execution, without baked input tables, angle wrapping or tolerance
  changes. Node and Chromium sine bits also differ in part of this corpus;
  Node-only capture is insufficient to choose the shared browser binding. The
  same shared API must expose browser `Math.sin` and `Math.cos` for PiP yaw
  half-angles in `tests/fixtures/pip_composition.json::poseCases`; native scalar
  bits differ from Chromium for several captured inputs. Acceptance includes
  both functions and the PiP orientation cases without input-specific tables.

- **Opus — spectator angle transfer:** `scripts/main.gd::_advance_spectator`
  packs double `yaw`/`pitch` into `Vector2` before calling
  `SpectatorCamera.advance`, then unpacks its Float32 `Vector2` result. Agree a
  double-preserving producer/consumer contract with Terra before changing the
  camera API; the native pose writer cannot recover precision already discarded
  by this boundary. Preserve the source unbounded yaw and input increments, not
  a wrapped/canonicalized Euler substitute. Acceptance: repeated sub-Float32
  input increments at a large fractional yaw retain original free/orbit camera
  motion and orientation, plus existing FPV/TPS follow, zoom, reset and lifecycle
  behavior. Authority heading and gameplay settlement remain unchanged.
- **Opus — player look and view-lock angle transfer:** agree a double-preserving
  contract across `scripts/main.gd::_look`/`_advance_view`,
  `scripts/input_rules.gd::look` and Terra's `ViewLockState.advance`. The current
  `Vector2` arguments and results quantize base angles and lock increments;
  even the frozen branch rewrites angles. The original `_applyLook` retains
  1024.251199999997 after forty 0.00003-radian steps from 1024.25, while native
  remains at 1024.25. A frozen angle of 1024.25003 remains unchanged in the
  original and becomes 1024.25 natively; one captured tracking step ends at
  1024.236406260541 versus 1024.2364501953125. Read-only source and native
  programs are retained in `artifacts/terra/view-lock-precision-source.mjs` and
  `artifacts/terra/view-lock-precision.tscn`; the existing shared `rng.js`
  provenance mismatch still gates published captures. Acceptance: original
  free-look and lock sequences retain unbounded yaw, sub-Float32 increments,
  strict frozen no-op, pitch limits, inversion, recoil and previous-rendered
  projection across FPV/TPS; do not alter authority settlement. Terra updates
  its consumer separately after the producer contract is accepted.
- **Opus — view-lock scalar distance:** publish an accepted browser
  `Math.hypot(x, z)` binding in `scripts/source_numeric.gd`, checking the existing
  `CarrierRules.hypot2` implementation and its narrower carrier fixture first.
  `ViewLockState.advance` currently rounds target-minus-eye through `Vector3`
  and horizontal length through `Vector2` before tracking. With the same native
  Float32 inputs, the original Node program in
  `artifacts/terra/view-lock-precision-source.mjs` produces Float32 steps
  `[0.014999998733401299, 0.015000004321336746]`; the native diagnostic produces
  `[0.014999999664723873, 0.015000000596046448]`. These are controlled inputs,
  not a populated targeting or browser-bit qualification. Acceptance: the
  shared adapter matches original Chromium two-argument results across source
  coordinates, zero, subnormal and non-finite inputs without tables or wider
  tolerances. Include `tests/pip_death_direction.tscn` for both death-view
  target branches and further source cases before Terra binds this consumer.
  Terra then keeps subtraction in scalar doubles and validates both axes before
  native storage with the original view-lock program.
- **Opus — minimap shadow distance:** include `scripts/minimap_vision.gd::shadows`
  in the shared two-argument browser `Math.hypot` acceptance above. With the
  Float32-representable source `(0, 0)` and blocker center
  `(0.10029599815607071, 1.200152039527893)`, blocker radius
  `1.2043355866323489` and sight radius 100, Chromium computes distance
  `1.204335586632349` and draws a shadow; the current square-root calculation
  equals the blocker radius and rejects it. `tests/minimap_shadow_boundary.tscn`
  retains the failing boundary and six control cases. Acceptance: the shared
  adapter matches the source across inside, range and angular boundaries; Terra
  binds it separately and validates this scene, ordered shadow caps and fog
  composition without changing blocker-query semantics or raster tolerances.
### Shared-owner contracts required for presentation

- **Opus — minimap monotonic clock precision:** change the minimap draw timestamp
  producer in `scripts/main.gd` to preserve a shared monotonic sub-millisecond
  clock before Terra changes `scripts/minimap.gd::configure` and
  `accept_snapshot` to use that same clock for warmup and pulse deadlines.
  Both currently use `Time.get_ticks_msec()` divided by 1000; rounding them
  independently would mix deadline domains. In the original browser, init at
  100000.9 ms makes warmup end at 103000.9 ms: after a draw at 102800.1 ms,
  a 103000.4 ms frame is still suppressed. Integer-millisecond producers
  instead expire warmup and draw. `tests/minimap_cadence_clock.tscn` preserves
  eight such strict decision failures across four controlled programs while
  the same `MinimapCadence` accepts all source double timestamps exactly.
  Acceptance: use one monotonic clock with at least microsecond resolution for
  initialization, pulse observation, draw and fog; rewire the fixture from its
  explicit current-producer simulation to the accepted clock boundary and pass
  all source cases, including mode invalidation and pulse expiry, before full
  minimap/transport verification. Do not substitute game time or loosen gates.

- **Opus — fire-fog membership distance:** update
  `scripts/main.gd::_advance_view` to compare scalar-double planar distances with
  the original browser `Math.hypot` semantics, using the accepted shared numeric
  contract rather than rounding the difference through `Vector2`. The source
  `_updateEnvFog` excludes a pilot at native-representable `(12, 0.0010000000475)`
  from a radius-12 fire: Chromium measures `12.0000000416667`, while native
  `Vector2.length()` rounds to 12 and counts the pilot inside. From a 2.5 s dwell
  and 0.1 s step, source dwell/fog become 2.3/0 while native becomes 2.6/0.01818.
  `artifacts/terra/fire-fog-boundary/source.mjs` executes the original method in
  Chromium; `artifacts/terra/fire-fog-boundary/native.tscn` retains the strict
  native comparison. Eight of twelve controlled cases disagree across all four
  fire kinds. Preserve source `<=` boundaries, airborne exemptions, recovery,
  death reset and snapshot positions; acceptance requires all twelve cases plus
  translated centers, scaled radii and populated gameplay to agree. The related
  shared two-argument `Math.hypot` adapter request remains above.

- **Opus — spectator, minimap, PiP, scope and dialogue provenance:** reconcile the original
  `public/js/rng.js` dependency through `tools/import_source.mjs` and
  `data/provenance.json` before full spectator, minimap, dialogue, scope and PiP qualification.
  The captures `tests/fixtures/spectator_native.json`, `tests/fixtures/minimap_native.json`,
  `tests/fixtures/dialogue_native.json`, `tests/fixtures/dialogue_transcript.json`,
  `tests/fixtures/scope_raster.json` and `tests/fixtures/pip.json` declare
  `96773f680724e2fc8e695270333d41d3a18e539dabb88968dad0b9cb68fae654`,
  while shared provenance declares
  `c46913b415a75aa5f0d2366dd7bfcb4f8f26c1db913ecea2a74b40695dd78aaa`.
  Preserve the full captures and their source guards. Acceptance: original
  spectator, minimap, automatic radio, transcript, scope and PiP programs pass with the agreed
  complete source inputs and unchanged timing/asset comparisons;
  `tools/spectator_native_capture.mjs`, `tests/spectator_native.tscn`,
  `tools/minimap_native_capture.mjs`, `tests/minimap_native.tscn`,
  `tools/pip_capture.mjs`, `tests/pip_native.tscn`, `tools/scope_raster_capture.mjs`
  and `tests/scope_raster.tscn` must also accept the shared identity. The narrower
  cancellation oracle cannot substitute for these checks or certify populated
  delivery.
- **Flash — settlement transcript host:** tracked as blocked
  [F4](../flash/MIGRATION.md#blocked-on-accepted-producer-contracts). Terra keeps
  the inner dialogue geometry, 42vh cap, portrait slots and scrolling contract;
  accepted font/material bindings below remain prerequisites for full host pixels.
- **Opus — source text advances:** provide an accepted shared adapter in
  `scripts/source_font_metrics.gd` before Terra certifies source dialogue wrapping.
  Input is the published native Font, original text, pixel size and `zh-Hant`
  language; preserve original shaping/kerning and the captured CSS weight.
  The strict browser widths are in `tests/fixtures/dialogue_fonts.json`, and
  native public widths plus unrounded glyph sums are retained in
  `build/dialogue_fonts/metrics-report.json`. Native integer widths are not the
  same contract as browser fractional advances; disabling hinting/rounding or
  using native MSDF did not establish parity. Acceptance needs the complete
  source corpus, Latin/CJK/punctuation, both weights and all recorded sizes,
  without arbitrary spacing corrections, tolerance widening or a baked table of
  whole-string widths. Terra owns subsequent Label/row layout and pixel binding.
- **Opus — cinematic hint font metrics:** extend the accepted
  `scripts/source_font_metrics.gd` contract to the skip hint consumed by
  `scripts/campaign_cinematic.gd`. The source requests 12 px `Consolas`,
  `SF Mono`, `ui-monospace`, `monospace` with browser CJK fallback and 1.5 px
  letter spacing. Preserve fallback selection, shaping and fractional advances
  for individual flex items, including their internal wrapping. Acceptance:
  the pending and ready strings and both badge labels in
  `tests/fixtures/campaign_hint_badges.json` match source measurements at the
  three captured widths plus fractional widths and DPI cases without spacing
  retuning or whole-string lookup tables. Terra then implements and verifies the
  two badge controls, reentrant status changes and full hint composition.
- **Opus — transcript portrait matte and avatar frames:** agree accepted native
  bindings under `shaders/` for original `.dlg-art` and `.dlg-av` pixels before
  full transcript composition is accepted. Background portraits retain 150 px
  width, bottom alignment, whole-image opacity 0.22, right-side mirroring and
  `linear-gradient(to top, #000 30%, transparent)` alpha masking; the body clips
  them at its 8 px rounded boundary. Avatar frames retain the SWARM 16%/84%
  polygon, STEEL 2 px radius plus its 1 px outline at 2 px offset, and MERC
  3 px double border/6 px radius. Preserve original RGBA and premultiplied group
  composition without mutating imported textures. Source computed styles and
  populated pixels are in `tests/fixtures/dialogue_layout.json`; acceptance
  needs isolated material probes in both art modes, alpha-gradient endpoints,
  fractional placement and the complete native/source transcript composition
  after Terra publishes the captured fonts and container geometry.
- **Opus — radio portrait filter binding:** agree an isolated canvas-item shader
  contract under `shaders/` for the original `.dlg-row .dlg-av` grayscale filter.
  Source inactive portraits use opacity 0.35 and grayscale 0.75; `.on` uses opacity
  1 and no filter, with both channels transitioning for 0.18s ease-out. Native
  `CampaignDialogue` now retains the source opacity transition but has no grayscale.
  Preserve original portrait pixels/alpha and shared texture immutability; Terra
  binds the accepted material and complete transitions in a separate change.
  Acceptance: original CSS/native portraits at both endpoints, transition and
  reversal frames, across character/mech modes and guest/single-speaker cases.
  Passing state/asset-path checks in `tests/dialogue_native.tscn` cannot certify
  opacity, grayscale, faction frames or complete dialogue pixels.
- **Opus — story image encoding:** `tools/import_source.mjs` copies original
  story images verbatim under their original `.png` names, but all 70 PNG-named
  files in `assets/story/` contain JPEG JFIF bytes (`FF D8 FF E0`), and all 70
  have invalid native imports. The complete presence/encoding inventory is in
  `artifacts/sol/campaign-art-inventory.json`.
  Publish correctly encoded native PNGs through the shared importer while
  preserving immutable original source files and campaign path metadata; do not
  hand-edit image data or `.import` validity flags. Acceptance: every campaign
  art path loads normally and with mipmaps, fallback selection follows original
  semantics, and native art pixels match the original decoded images.
- **Opus — failed story load guard:** `scripts/content.gd::story_texture`
  calls `get_image()` without checking whether `load()` returned a texture when
  mipmaps are requested. Reject a failed native decode before dereferencing it,
  preserving the original fallback contract and explicit availability checks.
  Acceptance: invalid imports never crash mipmap generation; valid foreground,
  background and portrait paths remain reusable without corrupting cached art.

### Shared renderer contracts

- **Opus — cinematic fallback image composition:** provide source-faithful
  foreground image sampling and a backdrop binding under `shaders/` for
  `scripts/campaign_art_layer.gd`. Original CSS stacks primary and fallback
  images separately before applying the backdrop blur/brightness/saturation;
  the native backdrop still samples only one image. Foreground layers now keep
  both images, but linear filtering of transparent pixels differs from Chromium
  at the unchanged two-byte gate. In `tests/campaign_fallback.tscn`, the four
  32-to-64 px transparent cases each differ at 256 pixels; with both images at
  x=31 the browser RGBA is `[95,121,143,255]` and native is `[73,118,142,255]`.
  Six unscaled cases and both scaled missing-primary controls pass. Preserve
  premultiplied filtering, independent cover geometry, image order, camera pose,
  the shared group opacity and immutable source textures. Acceptance: all twelve
  strict original rasters plus fractional scaling, mismatched aspect ratios,
  alpha edges and independently loaded images pass without wider tolerances or
  case-specific images; then validate both layers before backdrop filtering,
  decoded story art and full cinematic composition. Terra binds the accepted
  renderer in a separate change.

- **Opus — source scrollbar geometry and input:** agree a shared native binding
  in `scripts/source_scrollbar.gd`, with a material under `shaders/` if needed,
  before Terra replaces the default scrollbar in `scripts/campaign_cinematic.gd`.
  The captured classic browser scrollbar has a 4 px transparent track and a
  2 px radius thumb in `rgba(95,208,242,0.25)`; native currently reserves 8 px.
  At 320×100 with overflow, source content is 316 px wide and native is 312 px.
  All captured scroll offsets and the no-overflow control pass, but the 16
  overflowing cases in `tests/campaign_scrollbar.tscn` retain 32 strict width
  and raster failures. A 4 px native-style diagnostic fixes width and matches
  both ends of the 320×100/400 px case, but differs at its midpoint by 14 pixels;
  in the 96×24/400 px case, the source thumb covers 17 rows and the diagnostic
  covers two, differing in 68 pixels at the unchanged two-byte gate. At (94,16),
  source RGBA is `[37,94,125,255]` and the diagnostic is `[20,60,90,255]`.
  Browser PNGs and sampled thumb bounds are in
  `tests/fixtures/campaign_scrollbar.json`; current and diagnostic images are in
  `artifacts/terra/campaign-scrollbar-probe-154cd6b2/`. The capture enables
  Chromium's classic scrollbar and disables only the separate viewport mask.
  Preserve source visibility, reserved width, minimum thumb, integer placement,
  color and rounded coverage, plus native scroll values, wheel/touch, thumb drag,
  track interaction and lifecycle. Chromium scrolling cancels the active pointer
  while preserving the subsequent `touchend`; native scroll-start notification
  cancels the button and cinematic hold. Preserve the touch stream, cancelled
  press and native button lifetime without guessing a fixed gesture threshold.
  Acceptance includes small movements, cancellation and multi-touch on real devices, the
  controlled source/native event programs, all seventeen scrollbar cases and
  additional fractional-size and DPI cases without wider tolerance or per-case
  baked images. Terra then binds the accepted adapter and
  checks the edge mask, populated narrative, scrolling and complete composition.

- **Opus — cinematic section dashed border:** agree a native material or
  rendering binding under `shaders/campaign_section_border.gdshader` for
  `scripts/campaign_crawl_section.gd`. The original one-pixel border is dashed
  `rgba(122,158,178,0.16)`; its dash positions and edge coverage vary with the
  section width. At the unchanged two-byte gate, the currently undrawn border
  differs in 76/81/248/248/501 pixels at widths 96/101/320/319/641. A native
  `draw_dashed_line` diagnostic using the captured initial three-pixel dash still
  differs in 63/66/211/208/430 pixels, with maximum channel difference 27 bytes.
  Original PNGs are in `tests/fixtures/campaign_section_border.json`; source,
  current and diagnostic images are in
  `artifacts/terra/campaign-section-border-probe-62fc93b4/`. Preserve the
  width-dependent dash placement, fractional coverage, source color and alpha,
  and place the line within the section's isolated opacity group before scroll
  clipping and the outer presentation fade. Acceptance: Opus validates all five
  original rasters and further fractional-width and DPI cases without wider
  tolerance or per-size baked images. Terra then binds the agreed renderer and
  checks `tests/campaign_section_border.tscn`, scrolling and full composition.

- **Opus — cinematic crawl edge mask:** publish an accepted binding in
  `shaders/campaign_crawl_mask.gdshader` for the scroll viewport consumed by
  `scripts/campaign_cinematic.gd`. The original viewport masks its already-composed
  contents with a vertical alpha gradient: transparent at 0%, opaque at 4% and
  95%, then transparent at 100%. The native scroll viewport currently has no mask.
  At the unchanged two-byte raster gate, the three original mask cases at 96×64,
  101×73 and 320×100 differ in 576, 707 and 2,880 pixels, with maximum channel
  differences of 137, 140 and 146 bytes; all three unmasked controls pass.
  At the top-right pixel of the 96×64 case, source RGBA is `[21,61,80,255]`
  and native is `[40,180,210,255]`. The original PNGs are retained in
  `tests/fixtures/campaign_crawl_mask.json`; isolated source/native images and
  witnesses are in `artifacts/terra/campaign-crawl-mask-9f0a12d8/`. The material
  contract uses viewport-local, unscrolled coordinates on already-composed
  premultiplied RGBA; scale both RGB and alpha by the original mask. Preserve
  scrolling and the outer presentation fade. Acceptance: Opus validates its
  material against the three enabled source rasters and additional fractional-size
  cases without wider tolerances or baked per-size images. Terra then binds the
  agreed material, adapts `tests/campaign_crawl_mask.tscn` to disable that binding
  for its unmasked controls, and checks all six rasters, visible scrollbars,
  populated text, touch scrolling and complete cinematic composition.

- **Opus — cinematic fractional frame coverage:** agree a native material or
  rendering binding under `shaders/campaign_frame*.gdshader` for the clipped
  foreground and its translucent one-pixel borders in
  `scripts/campaign_art_layer.gd`. The source and native frame/image bounds agree,
  but the unchanged two-byte `tests/campaign_frame_geometry.tscn` raster gate
  differs at 501×500, 377×376 and 641×640: respectively 1,000, 1,128 and 1,280
  pixels exceed two bytes, with maximum channel differences 23, 151 and 36.
  For 377×376 at row 188, source pixels 364/365 are `[48,144,208]` and
  `[29,39,45]`; native pixels are `[37,49,57]` and `[5,7,10]`. Captured source
  rasters are in `tests/fixtures/campaign_frame_geometry.json`; isolated native
  and source images can be regenerated with an unused `--evidence-dir`.
  Preserve the CSS layout-unit positions, clip/border order, alpha and camera
  transforms. Acceptance: all six captured rasters plus additional fractional
  frame positions pass without wider tolerance or per-size baked images, then
  recheck original art, shadows, DPI and populated cinematic composition.

- **Opus — cinematic system-bar group alpha:** agree a native binding for the
  source system-bar gradient and bottom border within the complete presentation
  opacity group consumed by `scripts/campaign_cinematic.gd`. With an opaque
  `[66,100,130]` backdrop, source border `[122,158,178]` at alpha 0.18 must remain
  visible. On the real Compatibility renderer, the controlled direct native
  rectangle yields `[76,110,139]`, while the same rectangle inside `CanvasGroup`
  yields unchanged `[66,100,130]`. At alpha 0.5, direct and grouped results are
  `[94,129,154]` and `[105,146,172]`, respectively. The isolated probe is
  `artifacts/terra/campaign-sysbar/group_probe.tscn`. Native gradient plus border
  still differs in 358/4,545/21,920 pixels at the unchanged two-byte gate for
  16×24, 101×50 and 320×75; source fixtures and controls are in
  `tests/campaign_sysbar.tscn`. Preserve source gradient/border layering,
  premultiplied alpha and the outer cinematic exit fade. Acceptance: all three
  source rasters and additional opacity, fractional-size and nested presentation
  cases pass without color retuning, per-size images or wider tolerance. Terra
  binds the accepted renderer and validates text and the complete HUD separately.

- **Opus — minimap lane raster:** agree source-faithful Canvas stroke bindings
  under `shaders/minimap_lane*.gdshader` for `scripts/minimap_lanes.gd`. The
  controlled `tests/minimap_lane_raster.tscn` confirms source segmentation,
  points, color, alpha, width and dash patterns but all ten raster comparisons
  fail at the unchanged four-byte gate. The solid horizontal case differs in
  216 pixels: at `(8,17)` source RGBA is `[135,142,150,255]` and native is
  `[174,179,184,255]`. The bridge turn, tunnel turn and overlap differ in
  225/178/458 pixels, with maximum channel differences of 145/158/119 bytes.
  Source/native PNGs and byte-domain witnesses are in
  `artifacts/terra/minimap-lane-raster-byte-a7c21/`; byte counts equal the
  normalized comparator counts for all ten cases. Preserve the source's 1.5 px
  width, 0.7 alpha, butt caps, miter limit, per-grade dash phase and splitting,
  subpixel positions, clipping, layer order and palette. Acceptance: all ten
  captured original rasters and additional fractional, grade-transition,
  clipped and zoomed paths pass without wider tolerance or per-path baked
  images, then validate actual map lanes and complete minimap composition.
  Terra binds the accepted renderer in a separate change.

- **Opus — minimap label font and raster:** agree a source-faithful Canvas text
  binding for `scripts/minimap.gd::_draw_label`, using the shared
  `scripts/source_font_metrics.gd` contract and a material under `shaders/` if
  needed. The source uses `10px monospace`, browser fallback glyphs,
  `textBaseline = bottom` and a backdrop sized from `measureText`; native uses
  a `SystemFont` and its own descent. In `tests/minimap_label.tscn`, source and
  native advances for `周遭 140m` are 45 and 50 px, and the original two-CJK
  `全部` advance is 20 px in both but still differs in 155 pixels. The six
  original rasters differ in 155/308/301/396/404/496 pixels at the unchanged
  four-byte gate; at `(7,206)` in `周遭 140m` source RGB is `[14,27,41]` and
  native is `[98,132,77]`. The original and native images and width report are
  in `artifacts/terra/minimap-label-a7c21/`. Explicit Consolas, Courier New and
  Lucida Console probes do not pass; retain their evidence directories alongside
  the default probe. Preserve source font and fallback selection, fractional
  advances, baseline, text coverage, label color and backdrop geometry. Acceptance:
  all six captured cases and additional Latin/CJK, fractional-size and DPI cases
  pass without widened tolerance or pre-rendered per-label images, followed by
  the full minimap composition and populated lifecycle checks. Terra binds the
  accepted renderer separately.

- **Opus — minimap marker coverage:** agree native bindings under
  `shaders/minimap_marker*.gdshader` before Terra replaces the marker drawing in
  `scripts/minimap.gd`. The original Canvas2D callback and Chromium PNGs in
  `tests/fixtures/minimap_marker_raster.json` disagree with the native draw calls
  in all twelve controlled cases at the existing four-byte gate: 1,032 pixels
  exceed four bytes in total, with maximum channel difference 117. Integer base,
  fractional tower, enemy hero and rotated-arrow cases differ in 156, 39, 82 and
  31 pixels respectively. Exact byte and native image evidence is in
  `artifacts/terra/minimap-markers/msaa0-ss1/`. Godot's
  [Compatibility renderer does not support 2D MSAA](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_antialiasing.html);
  configured 2x/4x/8x tests produced the same result. A separate CPU Lanczos
  downsampling experiment and disabling rectangle antialiasing did not pass the
  strict cases. Preserve source geometry, inherited line widths, subpixel
  placement, alpha composition, faction colors and draw order. Acceptance:
  `tests/minimap_marker_raster.tscn` passes every captured original raster and
  further rotated/overlap cases without wider tolerances or baked per-case images,
  followed by the complete minimap composition and populated lifecycle tests.
  Terra binds the accepted shared renderer in a separate change.
- **Opus — cinematic hold stroke coverage:** agree an accepted material in
  `shaders/cinematic_hold.gdshader` before Terra replaces the native SVG binding in
  `scripts/campaign_hold.gd`. Godot's native SVG raster retains the original
  geometry, dash targets and rounded caps but differs from browser coverage in
  the quarter/half/full and translucent-half progress cases by 104/199/372/165
  pixels at the unchanged two-byte threshold (maximum normalized errors
  0.187912/0.286275/0.243460/0.097732). Static backplate, translucent group and
  cancelled-dash controls pass. Keep the captured radius, width, color, dash
  array, source analytic circumference and distinct browser path length;
  cancellation must not leave a spurious rounded-cap dot. Acceptance: all seven
  original CSS/SVG cases in `tests/campaign_hold_render.tscn` and continuous
  progress/reversal frames, without width/color retuning, a finite baked-progress
  substitute or a looser raster tolerance. Source/native evidence is retained in
  `build/campaign_hold/`; Terra binds the accepted shared renderer in a separate change.
- **Opus — minimap mask raster contract:** agree source-faithful scratch-mask
  coverage and read/composition materials in `shaders/minimap_*.gdshader` before
  Terra changes the `MinimapMaskTile`/`MinimapFog` bindings. Native `draw_ellipse`
  and antialiased Polygon2D masks retain the source geometry but do not yet match
  original Canvas coverage and persistent source-over accumulation. At the
  unchanged four-byte tolerance, full composite frames 1–4 differ in
  422/515/1,610/784 pixels; exploration frames 1–5 differ in
  456/566/542/842/842 pixels, with maximum alpha difference 220/255. Direct alpha
  witnesses in `build/minimap_fog/report.json` confirm real coverage differences,
  independently of RGB premultiplication. Existing point probes still pass.
  Preserve per-source shadow clipping, hard/soft order, full-map exploration,
  vicinity resampling, pulse fill, observer bypass and reset. Acceptance: all
  twenty source/native raster comparisons from the ten-frame sequence in
  `tests/minimap_fog_render.tscn -- --source-capture --full-raster`, without
  widening tolerances or replacing persistent masks with a generic reveal.
- **Opus — source scope ring color:** `tools/view_references.mjs` currently
  selects `rgba(ringCss)[0]`, the transparent center stop, as `mask.ringColor`.
  Consequently `data/balance.json` contains `[0,0,0,0]`, and the native scope
  has no visible ring. Select the original visible ring stop and verify its
  repeated declarations agree before publishing through `tools/import_source.mjs`.
  Original CSS uses `rgba(150,200,230,0.4)` for the two-pixel ring; do not patch
  imported data or hardcode a replacement in `ScopeOverlay`. Acceptance: native
  source-config equality and the scoped-clear cases in `tests/scope_raster.tscn`,
  followed by full ordered fog composition at all three viewport sizes.
- **Opus — source scope backdrop composition:** finish `shaders/scope_mask.gdshader`
  against the original CSS Gaussian backdrop filter and layer/group ordering.
  Source scope mask/ring is z7, then the fire element's backdrop blur and gradient
  share its opacity at z8, followed by weather fog. Native mip-level sampling and
  successive opacity mixes are not a qualification of that composition. The
  unscoped 0.8-fire cases differ in 202,944 / 202,976 / 11,692 pixels at 640x360,
  360x640 and 128x128, with maxima 15 / 15 / 25 channel bytes. Preserve the source
  blur amount and scope-edge coverage; do not loosen the existing tolerance.
  Acceptance: original `tests/scope_raster.tscn` cases, including mixed fire/weather
  and high-density small scoped views, after the ring-color producer is corrected.
- **Opus — weather-gradient lifetime:** separate the weather gradient's mode and
  outer scoped stop from the current scope mode and ring radius in
  `shaders/scope_mask.gdshader`. The original `weatherFog` callback keeps its last
  CSS background when density reaches zero, while its opacity fades for 0.5 s;
  the scope ring and aiming mode can change independently during that fade. In
  `tests/fixtures/scope_values.json::programs`, a scoped weather gradient retains
  9.8/17.8 vmin while the ring moves to 22.4 vmin. Native currently reuses
  `radius_vmin` and `scoped` for both layers. `tests/scope_weather_retention.tscn`
  retains four failures across radius changes and scope toggles; the unscoped
  no-toggle fade passes. Preserve independent parameters and the original fade,
  gradients and ring composition. Acceptance: Terra binds the agreed parameters
  and updates this strict scene to read them, all captured retention programs and
  transition/raster tests pass, and no wider pixel tolerance is used.
- **Opus — raster comparator byte boundary:** `tests/raster_compare.gd` compares
  Color's Float32-normalized channel differences against double `2.0/255`.
  Opaque weather-only cases 2/8/14 in `build/scope_raster/report.json` have exact
  RGB8/RGBA8 differences no greater than two bytes, yet report 107/102/8 failed
  pixels because the normalized difference reaches `0.00784316658973694`.
  Preserve the two-byte tolerance and transparent premultiplied semantics while
  making the boundary numerically faithful. Acceptance includes exact 0/1/2/3
  byte differences, opaque and transparent buffers, and the source/native raster
  suites; Terra's witness records do not suppress the current strict failures.
  Also retain frame 7 of `tests/campaign_art.tscn`: every opaque channel differs
  by at most two bytes, yet the current normalized comparator reports 2,240
  pixels at `0.0078431386500597`. `build/campaign_art/report.json` records zero
  pixels over two bytes; the other twelve first-frame scene comparisons pass.

### Execution and producer boundaries

- Read only the selected task's source, fixture generator and acceptance commands.
  Run the root suite, smoke and relevant `-View`, `-Tps`, `-Pips` or `-Minimap`
  transport case after runtime edits, one switch per run. Campaign changes add
  lifecycle and real-driver composition checks. Passing component probes never
  establish populated delivery or complete pixels.
- Use process-local `APPDATA=build/terra-user` and
  `LOCALAPPDATA=build/terra-local`; new reports belong in `artifacts/terra/`.
  Existing `artifacts/sol/` and `build/` evidence is retained at its original path.
  Fixed-output captures, native imports and shared publishers run serially.
  Source tools here require process-local
  `SVS_SOURCE=C:/Users/user/Documents/app/steel_vs_swarm`; browser captures require
  `PW_CHROME=C:/Users/user/AppData/Local/ms-playwright/chromium-1234/chrome-win64/chrome.exe`.
  Godot is at
  `C:/Users/user/AppData/Local/Temp/steel-v-swarm-godot/Godot_v4.7.2-stable_win64_console.exe`.
  On this checkout, the same Godot version is also available at
  `artifacts/opus/godot/Godot_v4.7.2-stable_win64_console.exe`. A partial,
  hash-verified partial source copy is in `build/terra-source/`; it contains
  `public/js/game.js`, `public/js/data.js` and `tools/audit_src.mjs`, but is not
  a full source checkout. Its `out/forest_review/three.module.js` copy does not
  match the recorded hash and cannot be used for source captures.
  Chrome is available at `C:/Program Files/Google/Chrome/Application/chrome.exe`;
  the bundled Playwright entry is
  `C:/Users/WaylenChang0726/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs`.
  Set `PW_CHROME` and `PW_MODULE` explicitly when using these alternatives.
  This Chrome reports version 156.0.8078.73, while existing captures may have
  used another version; retain that distinction and the original-source hashes.
  Missing native worlds still block populated runtime/transport acceptance.
- **Sol — CSS/input/frame dependencies:** consume `scripts/css_transition.gd`,
  `scripts/css_decimal.gd`, local input/feedback and world/resource producers
  through their existing APIs. Record a local request before changing a payload,
  wall/game clock, cancellation or resource-ownership contract. Acceptance must
  include affected view and campaign source fixtures and lifecycle cases.
- **Sol — S21 quality propagation:** Terra owns quality bindings inside its
  allowlisted consumers. Sol retains `scripts/visual_preferences.gd` and S21
  world/audio/effect propagation. Any changed notification or constructor/live
  boundary requires an agreed producer contract and source preference plus
  affected scope/minimap/PiP/campaign regression cases before consumer wiring.
