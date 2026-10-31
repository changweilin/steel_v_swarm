# Steel vs. Swarm — Godot

Native GDScript migration project for `steel_vs_swarm`. Requires standard
Godot 4.7.2. Import `project.godot` in Godot and press **F5** to run the project.
The game runs without Node.js, a browser, npm or add-ons.

## Browser single-player and GitHub Pages

The `Play on GitHub Pages` workflow validates pull requests and builds/deploys
`main` on push or manual dispatch. In repository **Settings → Pages → Build and
deployment**, select **GitHub Actions** as the source. After a successful run,
open `https://changweilin.github.io/steel_v_swarm/` and choose single-player;
remaining seats use the existing authority-controlled bots. The workflow also
uploads the exported site as the `web-game` artifact.

The Web preset uses Godot's official single-threaded WebAssembly export and
Compatibility renderer, so Pages does not need custom COOP/COEP headers. It
bundles the OFL-licensed Noto Sans TC font for Chinese text. Network lobby
controls are unavailable in this export; native LAN/server exports remain
available. Browser play requires WebGL 2 and an active tab. Click the game to
focus keyboard/mouse input; browser audio may require a user gesture.

On Windows, install matching Godot **4.7.2** export templates, then build locally:

```powershell
./tools/export_web.ps1 -Godot C:/path/to/Godot_v4.7.2-stable_win64_console.exe
python -m pip install playwright==1.58.0
python -m playwright install chromium
python tools/test_web.py build/web
python -m http.server 8000 --directory build/web
```

Open `http://localhost:8000/`; exported HTML must be served over HTTP(S).
`export_web.ps1` requires Windows and checks script import, `tests/run.tscn`,
the solo runtime smoke test and both ENet/WebSocket transports before export.
Chromium then runs the exported solo smoke path under a nested URL, matching
repository Pages hosting. Diagnostic logs are uploaded even when CI fails.
Python and Playwright are development/test dependencies only.

**Current delivery blocker:** the complete seasonal world set and remaining
gameplay/render/transport/export acceptance are unfinished. Use the stable
[migration router](MIGRATION.md) to select the independent Flash, Sol, Opus or
Models backlog and its instructions. Component checks do not establish full
feature parity; completed checkpoints are not retained in the backlogs.

**Full feature parity is the staged acceptance target; the port is incomplete.**
The playable native project includes all 32 characters' source definitions and
90 terrain/road resources for the 18 qualified maps and five team sizes.
The complete original scenery producer, native support/clearance and platform
anchor paths are prepared but remain ungenerated and unverified. Source scenery
albedo capture/binding, native train paths, articulated/edge-facility/waterfall
motion, native wildlife/petal/leaf batches, aquatic bubbles/fish/jellies/detritus and
vessel/wake pivots are also prepared but unverified;
shader-specific textures, shaders, remaining
scenery animation, live map services and remaining gameplay are pending.
Season-specific world generation/loading is also prepared: ordinary maps require
all four source seasons; campaign maps retain their authored season. Existing
90 road-only resources cannot satisfy the new seasonal resource manifest.
See [MIGRATION.md](MIGRATION.md) for the exact implementation boundaries.

Three oversized source world captures use Git LFS. Install Git LFS before
cloning, or run `git lfs pull` in an existing checkout before rebuilding worlds
or running world-reference tests.

## Play

Choose a battlefield, team size (1–5), faction and pilot. Offline matches fill
remaining seats with bots. For LAN, create a room and let the other player join
your IP on UDP port 8620, then start the match. All peers need this Godot project;
the browser game's websocket protocol is different.

Network players mark themselves ready before the room host starts. The native
loading barrier waits for all sided players and the server's collision geometry;
authority units and match time begin after that barrier. Ready cancellation,
loading/reconnect ordering and the new waiting UI are implemented but unverified.

Room hosts can now add/remove bots and choose a valid faction/mercenary pilot or
the source random option before starting. Bot IDs/names persist while the room
is open. Random roles are assigned by the authority after map preparation;
explicit duplicates remain legal. Source role/AI construction references and
the native editor/transport path are written but ungenerated and unverified.

Players can change to a faction with free capacity and choose a faction-valid,
mercenary or random character inside the room. Changing side clears ready and
character; changing character retains ready. Host difficulty changes are shared
with the room and used by the next authority initialization, without retuning
already-active brains. These paths and prepared -Members transport fixtures are
unverified. Ordinary players can change seat/faction from the native pause menu
after launch, subject to shared seat capacity. Live changes update room metadata
and recipient vision while retaining the original authority hero. Unseating
provides global vision and stops new combat commands; character selection stays
room-only. The minimap follows the published vision slice, and the existing
observer camera handles a pilot outside that slice. SUPER keeps its source
locked seat UI and campaign selection remains in its authored briefing flow.
Original all-phase handler/publication references, native owner/privacy cases
and extended -Members transport cases are written and unexecuted.

The spectator camera state and HUD projection now have native implementations
and prepared original-method traces for all characters, flight forms and views.
They reuse CameraPose collision pulling and existing weapon/ability definitions;
remote magazines and maneuver resources remain unknown. Native Camera3D, F/Q/E,
wheel/free-flight/touch controls and shared stats/weapon/upgrade rendering are
connected. A prepared -Spectators transport case uses two native clients and
checks unseated roster exclusion, camera/body restoration and private HUD values.
Recipient-specific publication now keeps magazines, private recharge queues,
lift/jump and view state owner-only; spectators consume original public ability
summaries. Source-based CC/modifier/cast countdown projection and copied private
fire feedback are also prepared, including stale replica clearing. Special roles
now publish scene/model tags and original public flags rather than combat plans,
targets or timers; public player identity drives clone/muzzle lookup, and fresh
replicas no longer need private construction stats. Original role serialization
and real replica-building cases are written. The observer join button and
`--connect <address> --spectator` now register spectator mode, including into an
active match; spectators bypass game-seat capacity and share world preparation,
without authority respawn/reinitialization. Source admission/label references,
campaign-observer progress guards and -LateSpectators transport cases are written.
Complete snapshot/event privacy and transport/render/lifecycle certification
remain pending. Generation and execution are deferred.

Host return-to-room and relaunch now retain room seats/credentials, reset
ready/loading state and discard the previous battle. Native RPC channels carry
match IDs so delayed input, actions, snapshots and body events cannot cross
matches. Ordinary base assignments are re-rolled at creation/rematch; the
offline source importer and world baker now prepare both original assignments.
The swapped resources remain ungenerated. Architecture seed rollover is carried
in room settings; rebuilding building appearance from the new seed and
room-phase prebuilding remain pending. Source rematch cases and the two-launch
`-Rematch` transport fixture are written, with generation/execution deferred.

Recovery now includes a saved endpoint/seat credential in native ConfigFile.
Ordinary startup or `--resume` attempts to reclaim it; `--session-store <path>`
selects an isolated store. Explicit new-session selection/leave, expired-seat
rejection and revoked routes clear it. A write revision protects a newer
process's credential from an older process's revocation cleanup. Native test
scenes keep the player's default credential file untouched.

Native lobby player/room names use the original imported allowlist, cap and
fallback. Player names remain attached to logical seats through reclaim and
rematch; `--name <name>` sets a CLI player name. Room-name edits and synchronized
public/private metadata require the current host route, including after host
transfer. Public directory/PIN/discovery behavior remains pending. The source sanitizer/config/host-policy cases and
extended `-Rooms` cases are written, ungenerated and unexecuted.

Core lobby/deployment preferences now use native ConfigFile at user://lobby.cfg,
separate from recovery credentials. Player name and ordinary/SUPER team size,
room name, map ID, environment and difficulty restore through mode-specific keys;
faction/role choices retain the original shared and SUPER-specific fallback keys.
The environment menus include original random choices; room creation resolves
season, lunar day, time and seasonal weighted weather once using independent
room RNG. Room fields display those authority values after creation. Source
preference/environment programs and native storage/sampling cases are written;
generation and execution remain deferred. Complete favorites/deployment UI and
platform storage certification remain pending.

Native quick start now saves the complete qualified-map match recipe, including
resolved human/bot roles, controls and environment. The lobby button or
`--quick-restart` recreates a private offline room through normal readiness and
world preparation; `--quick-restart --listen enet` or `--listen websocket` hosts
that replay on the existing native transport. Saved map IDs/template signatures
reject missing or changed imported geometry. Base assignment is re-rolled relative
to the saved layout, with a fresh architecture seed; concrete environment and
lunar day remain fixed. Story-arena replays retain siege rules without personal
chapter dialogue/progress. Original source-session/launch oracles, native recipe
cases and `-QuickRestart` transport cases are written and unexecuted. Remote
multiroom creation, unsupported custom/favorite map recipes and full lifecycle/
render/platform certification remain pending.

Native fatal recovery now uses Godot Timer and AcceptDialog with the original
loading, snapshot and disconnect thresholds. Waiting for other players has its
own deadline; minimized/suspended time is excluded. Preparation errors preserve
their reason and failed rounds cannot launch or settle combat commands. Reliable
match-ID errors reach connected/rejoining clients without terminating a dedicated
listener. Close clears the current room/presentation; solo restart recreates the
saved match through quick start, or returns to the lobby without a supported
recipe. Remote sessions only close. Original watchdog/restart oracles, native
state/error cases, offline recovery/dialog scenes and -Fatal transport cases are
written; generation, compilation and all execution remain deferred.

Companion/decoy PiP now uses native SubViewport/Camera3D views of the shared
battle world. Source ownership/death/lost-link gates, stable ordering, low-power
limits, geometry and camera offsets have prepared original-method references.
Temporary camera exclusion layers hide each source body and the main cockpit
only while rendering, then restore original masks before any body/effect copies.
Inactive views stop rendering. Current one-body squads remain unchanged. Source
traces, native layer cases and offline/transport/render scenes are written and
unexecuted; full subview pixels/frame-order/performance certification is pending.

Faction head markers now use original captured arrow/ring images with native
billboard materials and the existing body/LOD callback. Original scale/top
anchors, fade/bob rules and relative priorities have source-method captures.
Civilian faction/following marks use public fields and never reveal spy identity.
Pose/material cases and offline/ENet/WebSocket/render scenes are prepared;
generation, compilation and all execution remain deferred.

Disconnected input/actions retain the source latest-120-message FIFO in memory.
Reclaim precedes flush, inputs/actions share one native reliable channel, and
match IDs prevent old commands from crossing into a rematch. Failed sends retain
the unsent suffix; successful native handoff removes messages without adding an
application acknowledgement/retry protocol. The source queue oracle, native
storage/replay cases, queued-order checks in `-Rooms`, and fresh-process
`-Recovery` ENet/WebSocket cases are written and unexecuted.

Same-session reconnect also retains the native scene with stable player IDs,
held human seats and the original retry/expiry schedules. Explicit remote leave
waits for authority acknowledgement; empty/abandoned room cleanup preserves the
dedicated listener. Room-host start/control requests retain their logical seat
permissions across reattach. This stage is ungenerated and unverified. Restart recovery,
full observer/reconnect certification and room administration remain pending. The
prepared transport fixture is selected with `tools/test_network.ps1 -Rooms`;
execution remains deferred until migration implementation is complete.

WASD/arrows move, mouse looks, left mouse fires, wheel/keypad +/- toggles scope
and light/heavy mode, and RMB/keypad / casts the current shield-stance ability.
Hold/release Space charges a ground jump or morph launch; Space/C ascends/descends
in flight. F toggles the defensive shield stance, Shift sprints, R reloads, Q/E requests abilities,
B opens the supply shop, M expands the map, G requests a nearby civilian to
follow, H sends them away, and Escape opens the battle menu.
Basic controller movement/look and action buttons use Godot's InputMap.

Only explicitly implemented abilities are available. The UI reports an
unavailable ability instead of inventing substitute behavior.

Tactical fog and cube fields now share authority lifecycle/visibility rules.
Fog contracts enemy sight and hides allies from observers outside its first
protecting field; toxic variants apply continuous corrosion and poison buildup.
Cube panels are independently destructible and retain distinct visual boxes,
damage bands and LOS planes. These implementations and their source-reference
suites remain unverified during the current migration work.

Clone, autonomous summon and hologram lifecycle/settlement are now implemented
with prepared source oracles. Dedicated source companion graphs have an offline
export and native scene packing path. They have not been generated or validated;
missing companion scenes keep the associated abilities unavailable. Climate,
NPC attraction, animation and remaining special fields are still pending.

Point-delivery carriers now have authority launch, scalar flight, fractional
arrival budgets and interception cancellation with prepared original tick
references. Source bomber, hypersonic and character-specific kamikaze scenes
have an offline export path. Their HP metadata, scenes and fixtures remain
ungenerated and unverified; missing content keeps carrier casts unavailable.

NPC source target priorities, hologram attraction and target-cache cadence now
have prepared source oracles. Shared lane creep upgrades unlock after all eight
tracks are maxed and apply to future waves. The native scrollable shop also
allows source remote/dead purchases; durability purchases do not revive a dead
pilot. These changes remain unverified, with wave prefill/cohesion, climate and
full NPC movement still pending.

Source prefill recipes, wave spawn jitter/spacing, planar progress, cohesion and
control/push rules now have native implementations and prepared original
references. NPC logic uses the original server period alongside native pilot
physics. Their migration data remains ungenerated; combined physical traversal,
climate, rendering and transport verification are still pending.

Dynamic source climate and persistent rain/snow/sand surface history now feed
authority movement, lift, cadence, reload/ability deadlines, rain damage,
fog/night accuracy, snow freezing and entity lightning/shockwaves. Weather uses
an independent seed and shared transport snapshots. Native sky, depth fog,
lighting and precipitation consume source palettes/profiles; the lobby exposes
all seasons, times and starting weather. Original weather/effect/damage/reload
oracles are prepared but unexecuted. Complete scenery/hazards, water appearance, detailed
cloud/precipitation layers, rendered deposits and complete integration remain
pending. Weather data generation, compilation and tests remain deferred.

Original triangular terrain sampling, water/swamp classification, dry corridors,
mirrored neutral-avoidance grids, marine tides, immersion/jump rules and frozen
fluid damage now have native paths and prepared source oracles. World baking
also captures original water/swamp meshes and profiles. Ice constraints preserve
the source floor/ceiling rules alongside native collision. Weapon and raw-burn
deaths share authority settlement. These world resources and references remain
ungenerated/unverified; full imagery/border classification, water appearance and
the complete scenery hazard roster is still pending.

Scenery lightning now uses the original quantized authority height grid,
wet/slab/obstacle/ring gates, independent location RNG and source live-fire cap.
Fire fields support original expiry, effective rain/snow extinguishing,
raw-weather damage intensity, proportional burn and neutral avoidance. Original
fire/smoke graph packing and animation references are prepared; canonical fire
graphs still need per-entity source geometry variation and full damage states.
Fire/scar snapshots, data/asset generation and all verification remain
unexecuted; permanent scorch rendering and the full scenery roster are pending.

Scene hazard/vehicle/mine/AA/relay generation, source HP/armor/EV rules, native
four-way lane connectivity and source corridor pruning now have unexecuted
reference paths. Authority destruction retains source rubble/fire/salvage.
Mines and AA ambush share the source threat cooldown; relays retain contested
decay, side-switch reset and one-time team vision. Flood zones preserve their
movement and jump effects. Source cash/ammo/affix loot uses authority settlement,
expiration and pickup order, with native source-scene rotation/bobbing. Mine
proximity visibility uses the original no-imagery visual and 3D distance ramp.
Original scene/loot/mine/collapse and flood fixtures are prepared but unexecuted.
Per-entity hazard geometry, damage/cracks/debris, full squad bodies and
complete scenery/presentation integration remain pending.

Timed airdrops now have source batch/placement/landing/pickup/reward paths and
unexecuted reference suites. Batteries preserve overcharge and shorten ability
and charge deadlines; medical supplies share source-aware authority healing,
including boss item rejection and remaining-segment caps. Allied civilian
followers now produce profession supplies; the complete boss/campaign
lifecycle remains pending. Original S/M/L crate/parachute
graphs, first-seen descent clocks and landed crate animation have an offline
export/native packing path. Native supply/loot/relay/threat notifications retain
the captured source HUD limit/lifetime. Public supply events survive missing
actor filtering, and the minimap excludes neutral scene bodies. These fixtures,
assets, HUD/render/runtime checks and transport cases remain ungenerated and
unverified.

Third-party camps and civilians now have authority lifecycle paths and prepared
original reference suites. Camps preserve garrison protection/healing, tethered
aggro, bunker/member respawn ordering and once-only civilian liberation.
Civilian/spy seeding, wandering, follow/away interaction, allied aid, signed kill
credits and retryable respawns retain source draw order; spy identity and private
AI state stay out of snapshots. Camp clearance uses original legacy-pillar and
grouped-building rules. Offline companion export prepares original camp models
and forty faction/profession civilian graphs. Per-ID body/appearance metadata
and hit volumes are source-derived, while full per-ID civilian mesh variation,
rig animation/marks and building visual clearance remain pending. All new
fixtures/assets, compilation, runtime, render and transport checks are deferred.

Regular-match faction counters now record original hero kills/deaths, paid
assists and weighted creep last hits in authority settlement. Public snapshots
copy these counters; replicas reject stale or unauthorized updates. Native HUD
rows retain source faction colors and Chinese labels. Original death-settlement
cases and snapshot isolation checks are prepared but unexecuted. Complete
squad/mode statistics, leaderboards and replay integration remain pending.

Bots now use the original four difficulty policies, role priorities, shared APM
deadlines, retreat/rally state machine, alert search, heavy/skill/guard/purchase
decisions and native body collision. Authority bot fire shares ammunition/power
settlement and preserves original immediate direct damage, heavy impact-report
reload backdating, threat decay and source RNG draw order. The lobby exposes bot
difficulty. Original decision/fire/history oracles, native wall checks and
`tools/test_network.ps1 -Bots` cases are prepared but unexecuted. Full frame-order,
mode/traversal and seeded complete-match verification remain pending.

Campaign BOSS/siege authority paths now preserve source weighted HP segments,
eight-track enrage, HP fraction during capacity upgrades, shield restoration,
transition invulnerability, absolute body/collision scale, permanent death and
revive rejection. Stage immunity and local BOSS/dialogue HP floors share damage
settlement and targeting; allied bot and base-support damage gates are source
based. The native segmented BOSS HUD retains original view/obstruction selection
and look-away hysteresis. Original lifecycle/HUD oracles and `-Bosses` transport
cases are prepared but unexecuted. Campaign resource generation, full transition
VFX, super mode and complete chapter certification remain pending.

Native campaign menus, pilot/art selection, six authored rosters/environments,
increasing chapter difficulty, faction progress and intro saves are now written.
Source prologue/chapter scenes use native text crawl, bounded pan/zoom, image
fallback and skip controls. Combat radio remains automatic and non-blocking;
victory unlocks the next chapter and displays the source base-stage transcript.
Campaign rooms share the normal authority lifecycle and select source base
assignment before launch. The exporter/capture/baker prepares both assignments
of every faction chapter map. Missing original resources disable deployment.
Source progress/deployment/dialogue/cinematic/spawn cases and `-Campaign`
transport cases are prepared but unexecuted; complete campaign certification
and its generated map resources remain pending.

After all implementation is complete, the deferred campaign pipeline is
`tools/import_source.mjs`, `tools/capture_campaign_inputs.mjs`, world baking,
`tools/world_references.mjs`, a second source import to capture the new structure
profiles, and native world/asset packing. Then run the complete fixture, runtime,
render and transport checks. These steps have not been executed for this work.

Server missile hologram/active drone-carrier attraction, phase loss, harmless front-sector reflection,
blindness/EMP report gates and reverse-order skill interception now have native
paths and prepared original references. Warheads use captured NPC damage through
the shared blast path. Original player bodies remain single units (`SQUAD.N=1`);
legacy wing salvos and removed saturation attacks remain unavailable. Full impact
presentation/timing remains pending. Confirmed lock halos/rings and independent
skill-preview sprites now use native materials/meshes and private authority
snapshots. The current authored roster retains the source's empty skill preview
lists; original helper cases exercise positive preview geometry separately.
All new assets, fixtures, compilation and validation remain deferred.

After the deferred source import, `tools/import_cockpits.tscn -- --hazards` packs
hazards/AA/relays/mines and `-- --loot` packs cash/ammo/affix loot plus S/M/L airdrops. These generation
steps, Godot compilation and all final validations remain deferred until the
complete migration implementation is ready.

Laser-guided launchers freeze the firing-time aim point. Fire-and-forget missiles
acquire the firing-time exact-ray target or an eligible hero in the source aim
cone, retaining a valid confirmed anchor; without a target they fly under
gravity. These warheads now travel and collide on the authority before dealing
blast damage.

Launch range uses the original target-dependent altitude frame. Confirmed
locks appear in the pilot's private HUD, refresh at the source quarter-second
interval and can continue for a missile already in flight after aim release.
Direct/blast target advice now reports geometric reachability and warns inside
the source arming/minimum-range distance. It uses source gun-local ports and
source spawn-time measured model centres. Source weapon-footprint rosters now
highlight the predicted direct, blast, fan and penetration victims. Shared
glow resources warn the whole shot, clear in the shop and disappear with hidden
targets. TPS/super/recoil camera behavior and animated visual-mesh queries remain
pending.

All 32 pilots now have source-built native first-person cockpit geometry.
Weapon roots follow source reload, recoil-kick and lob elevation limits;
aiming hides cockpit parts until the camera returns to its normal FOV. Morph
pilots select the matching ground/air weapon group. Animated weapon mirrors,
barrel progression, payload omission and muzzle flashes now follow source
events and clips. Scalar weapon poses now run on the authority without cockpit
meshes; local gun recoil follows the private simulation clock. Physical rounds
capture the shooter's original height frame for delayed settlement. Burst echoes
now advance source barrel/recoil/flash poses and pure visual shells/tracers without
additional combat spending. Native source projectile models follow private owner
poses and preserve source tail/opacity animation. Complete morph/body presentation,
remote/impact effects, client flight interpolation and TPS/super/recoil camera behavior
and final toon appearance are pending.

Unguided launchers now solve a 45-degree ground throw or a crosshair-selected
AA trajectory, lowering charge only when the low arc is blocked. A native dashed
arc shows the authority's launch solution. Firing below the minimum safe range
can damage the shooter and allies.

Ordinary gun rounds now fly under source gravity and stop at the first observed
enemy. Penetrating gun rounds pass through bodies and settle their planar line
damage once the trajectory hits scenery or reaches its range boundary. Beam and
rail attacks retain the source's instant behavior.

Base guns now launch two independent incoming missiles. They lose guidance when
the target escapes the launch envelope; intercepted missiles disappear without
blast damage and award the source bounty. Instant beams, kinetic shots and
penetrating lines can intercept them. Player FNF/lob warheads remain a separate
projectile family.

## Dedicated server

```powershell
godot --headless --path . -- --server --port 8620 --team-size 1
godot --headless --path . -- --server --websocket --port 8620 --team-size 1
```

ENet uses UDP. WebSocket uses TCP and accepts `ws://host:8620` in the join field.
For Internet hosting, run the same headless server on the hosting machine and
expose the selected transport. A TLS reverse proxy can terminate WSS upstream.
The first registered member holds room-host start/control permissions. All
sided players must ready before the host starts; remaining team slots are filled with
bots. The battle waits for loaded acknowledgements and native server geometry.
Disconnected human seats remain human and can reattach with their token. Fresh
spectators can prepare and observe an active match without a hero allocation.
This lifecycle stage is ungenerated/unverified.
Headless transport fixtures pass `--ready-start` to submit explicit ready/start
requests through the normal native protocol.

## Validation

Complete gameplay and integrated acceptance remain unfinished. The selected
workstream in [MIGRATION.md](MIGRATION.md) defines its outstanding source,
resource, render and transport checks. Earlier component results do not certify
the current build; runtime changes require the relevant checks below.

```powershell
godot --headless --path . res://tests/run.tscn
godot --headless --path . res://tests/worlds.tscn
godot --headless --path . -- --smoke
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Rooms
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Loading
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Roster
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Members
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -LobControl
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -KineticShots
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -MissileShots
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Reachability
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Footprints
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Cockpits
godot --headless --path . res://tests/lob_preview.tscn
godot --headless --path . res://tests/reachability.tscn
godot --headless --path . res://tests/models.tscn
godot --headless --path . res://tests/footprints.tscn
godot --headless --path . res://tests/cockpits.tscn
godot --headless --path . res://tests/muzzles.tscn
godot --headless --path . res://tests/cameras.tscn
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Cameras
godot --headless --path . res://tests/bursts.tscn
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Bursts
godot --headless --path . res://tests/projectile_visuals.tscn
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Projectiles
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Aiming
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -MissileDefenses
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Bodies
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Tps
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Spectators
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -LateSpectators
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Rematch
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Recovery
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -QuickRestart
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Fatal
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Pips
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -HeadMarks
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -VitalBars
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Minimap
./tools/test_network.ps1 -Godot C:/path/to/godot_console.exe -Balance
```

Prepared fatal recovery, native dialog, PiP, overhead marker/bar and native audio cases (also deferred):

```powershell
godot --headless --path . res://tests/fatal_restart.tscn -- --quick-restart
godot --headless --path . res://tests/fatal_restart.tscn -- --quick-restart --without-recipe
godot --path . res://tests/fatal_restart.tscn -- --quick-restart --capture-fatal
godot --headless --path . res://tests/pip_network.tscn -- --pip-test
godot --path . res://tests/pip_network.tscn -- --capture-pip
godot --headless --path . res://tests/head_mark_network.tscn -- --head-mark-test
godot --path . res://tests/head_mark_network.tscn -- --capture-head-marks
godot --headless --path . res://tests/vital_bar_network.tscn -- --vital-bar-test
godot --path . res://tests/vital_bar_network.tscn -- --capture-vital-bars
godot --headless --path . res://tests/minimap_network.tscn -- --minimap-test
godot --path . res://tests/minimap_network.tscn -- --capture-minimap
godot --path . res://tests/minimap_fog_render.tscn
godot --headless --path . res://tests/audio_pan_render.tscn
godot --headless --path . res://tests/audio_move_render.tscn
```

The prepared minimap suite executes original full/vicinity projection, shared
toggle, marker drawing and discovered-bunker recording seams. Native keyboard M
and touch map commands change world coverage at a fixed panel size. Marker
templates use Godot canvas primitives and retain original faction/outline styles;
discovered bunker positions survive fog until the room changes. Live satellite
services and full fog/pixel/runtime certification remain pending. These cases
have not been generated or executed.
Source warmup/steady draw gates now retain native canvas commands between draws;
the mode/metre legend uses native font measurement and captured source styling.
Prepared traces cover cadence transitions, toggle invalidation and label rounding.
World baking also prepares the original terrain minimap image, including its
hillshade, water and dark veil, as a native texture. Source HTML supplies canvas
dimensions; full/vicinity modes crop that same texture with linear sampling.
Prepared world checks compare every source/native raster byte. The current
offline bake still uses the original missing-satellite fallback.
Ground/bridge/tunnel lane styling now reuses the existing lane-surface samples
and native Line2D nodes with tiled dash textures. Original grade thresholds,
span boundaries, lane colors and unequal dash/gap intervals have prepared
source/native cases; sharp-turn and rendered dash-edge acceptance remain pending.
Prepared fog cases execute original sight/shadow/grid, relay/scout pulse and
actual canvas composition seams. Public cast reports retain the ability level
accepted before an upgrade or interruption. Native cropped mask atlases and
nested SubViewports now retain exploration and compose source-local shadowed
reveals below lanes and public markers. Full/near views, pulses, observers and
room cleanup share that lifecycle. The real-renderer scene prepares comparison
images under `tests/minimap-fog/` and checks interior color/exploration probes;
complete raster review and populated runtime/transport/performance certification
remain pending. None of these new cases has been generated or executed.

The test scene compares GDScript against fixtures evaluated by the original
JavaScript seams, and exercises authority, purchases, ammo, reload deadlines,
respawn and outcome settlement. Network checks use separate server/client
processes for both transports; `-LobControl` also checks private fire-control
snapshots and physical shot segments. `-Bursts` checks accepted and echo serials,
slot capture, duplicate rejection and one authority spend per burst. Echo pose
fixtures execute the original queue and weapon presentation across all pilots;
source projectile/tracer fixtures also verify native geometry, flight, opacity,
pooling and private owner poses. `-Projectiles` checks light/heavy meshes, moving
snapshot poses, echo emission and clearing. Impact particles, remote mounts,
client interpolation and view/body reaction remain pending.
Prepared `-Aiming` cases cover native confirmed locks, private source-helper
preview lists, incoming warnings, independent clearing and hidden targets. `-MissileDefenses`
prepares original hologram/active carrier redirect, permanent phase loss, reflection events and
harmless removal. Both suites remain unexecuted until final migration validation.
`-KineticShots` verifies light-round flight
and heavy-round termination events. `-MissileShots` checks base launches, missile
geometry/HP snapshots, fire commands, interception events and bounty replication.
`-Reachability` checks private target advice, clear/warning HUD transitions and
hidden-target removal. `tests/reachability_preview.tscn -- --capture-preview`
writes a rendered aiming HUD to `tests/reachability-preview.png` with a graphical
display. Reachability fixtures run the original source advisory/arc seams across
all pilot weapon tiers, including obstruction and warning boundaries.
Model-centre fixtures execute the source model builders and spawn measurement
block, including both mercenary factions and combined morph geometry. Native
acquisition checks include a cone-edge case that the former body midpoint misses.
Footprint fixtures evaluate the original client victim roster for every weapon
tier, including its separate 3D penetration basis and reused blast aim buffer.
`-Footprints` verifies a two-victim private roster, warning/normal glows, shop
clearing and hidden-target removal over both transports.
`tests/footprint_preview.tscn -- --capture-preview` writes two rendered glows to
`tests/footprint-preview.png` with a graphical display.
Cockpit fixtures compare all 32 original source graphs, indexed rest ports,
reload/kick/lob poses and aim/FOV/morph visibility. Another 1,456 original full
animation frames compare receiver/payload/finger mirrors, barrel progression,
duplicate events and shared fallback-cache aliases; source clip tracks use native
Animation resources. Flash fixtures cover lifetime, heavy size and aiming.
`-Cockpits` verifies authority serial/clock feedback, sequence/flash presentation,
reload presentation, private elevation and zoom/death hiding over both
transports. `tests/cockpit_preview.tscn -- --character m01 --capture-preview`
writes the native first-person view to `tests/cockpit-m01.png` with a graphical
display. Source gun-local origins and original FPV eye/nose anchors now drive
native combat. Registered-obstacle pullback and the original near plane also
drive local/replicated camera views; final shaders remain pending.
Add `--fire-feedback --feedback-slot heavy` to capture an accepted-shot flash in
`tests/cockpit-m01-fire.png` instead of the resting view.
Structural fixtures compare source blast layers and support-height references,
including bridge overflow, tunnel portals, gallery exits and all 90 accepted
world profiles. Native impact checks cover player warheads and SAM fuses.
`tests/missile_preview.tscn` writes a rendered missile to
`tests/missile-preview.png` with a graphical display.
`tests/lob_preview.tscn -- --capture-preview`
writes a rendered lob HUD/arc to `tests/lob-preview.png` with a graphical display.
World checks compare source mesh topology,
ray heights, layered bridge surfaces, tunnel portals and native player support
under source gravity at the configured physics rate. `--capture` writes a rendered battle view to
`tests/battle.png`; this command requires a graphical display.

`tests/muzzles.tscn` additionally compares the original complete launch seam
against native gun ports, camera reticle rays, physical launch vectors and Jolt
fire-control queries. Registered-layer muzzle surfaces retain original bridge,
tunnel and roof selection. `tests/cameras.tscn` verifies original eye/nose anchors,
clipping rules and native camera/replica binding; `-Cameras` checks both morph
forms over both transports. Full scenery, TPS/super/recoil camera behavior and
animated visual-mesh collision remain pending.

## Update imported content

```powershell
node --max-old-space-size=8192 tools/import_source.mjs ../steel_vs_swarm
godot --headless --path . res://tools/import_audio.tscn
godot --path . res://tools/import_cockpits.tscn
godot --path . res://tools/import_cockpits.tscn -- --projectiles
godot --path . res://tools/import_cockpits.tscn -- --bodies
godot --path . res://tools/import_cockpits.tscn -- --companions
godot --path . res://tools/import_cockpits.tscn -- --hazards
godot --path . res://tools/import_cockpits.tscn -- --loot
godot --path . res://tools/import_cockpits.tscn -- --civilian-parts
godot --path . res://tools/import_cockpits.tscn -- --npc-effects
godot --path . res://tools/import_cockpits.tscn -- --weapon-effects
godot --path . res://tools/import_cockpits.tscn -- --first-person-shields
node tools/bake_worlds.mjs --reuse
node tools/world_references.mjs <bundle>
godot --path . res://tools/import_worlds.tscn
```

This optional developer command evaluates the original balance/venue seams,
exports resolved values, copies existing glTF/audio/content resources, and
records SHA-256 provenance. It requires the source checkout and its development
Playwright/Chromium runtime for offline model measurement; ordinary play does
not. `PW_CHROME` can select an installed Chromium executable. Imported maps
include only presets admitted by the source's qualification
checks, with the source's active lane subsets and solved tower positions.
Model/world packing requires a real rendering driver to retain native MultiMesh
buffers. Headless mode installs Godot's dummy renderer and is rejected for
nonempty instanced model graphs; audio generation can remain headless. A hidden
build process can use the native Compatibility driver with `--disable-render-loop`.

The source importer also exports the original cockpit builders' geometry,
textures and pose/visibility fixtures. The native cockpit importer packs those
graphs into `assets/cockpits/*.scn`; `data/cockpits/` is development-only and is
excluded from exports. Runtime cockpit presentation loads only native scenes
and imported scalar metadata.
Export presets also exclude source-oracle fixtures, audio capture JSON, model
graph JSON, source geography captures and validation artifacts. Native packed
scenes, audio resources and runtime content JSON remain the delivery inputs.

`node tools/import_source.mjs ../steel_vs_swarm --audit-references` checks the
non-model source reference captures without publishing generated content.
Full capture streams fixture arrays to avoid V8's single-string size limit;
the larger Node heap above is still needed for the captured model graphs.
For audio capture tooling changes with unchanged original source inputs,
`node tools/import_audio_source.mjs ../steel_vs_swarm` refreshes the five audio
capture bundles before running `tools/import_audio.tscn`. It verifies every
recorded source hash first; changed source inputs require the complete importer.

Install the offline streaming reader with `npm ci --prefix tools --ignore-scripts`.
World source version 2 stores ordered gzip JSON mesh chunks and content-addressed
IEEE-754 numeric buffers, verified by SHA-256 and decoded with Godot's native APIs.
New numeric buffers use standard GZIP when it reduces storage; both compressed
and existing raw float64 buffers retain the same numeric bits and remain readable.
New numeric buffers use standard GZIP when it reduces storage; both compressed
and existing raw float64 buffers retain the same numeric bits and remain readable.
These are development inputs; delivery still uses packed native world resources.
`node tools/pack_world_source.mjs data/worlds/<world>.json` converts a large legacy
capture and preserves an original backup under `artifacts/source-world-backups/`.

World baking additionally uses the original development Playwright runtime,
cached Three.js modules and validated OSM/elevation captures. `SVS_SOURCE` can
select a different source checkout. Optional map IDs limit both world tools
(for example `berlin madrid`); pass them after `--` to Godot's importer/tests.
`node tools/bake_worlds.mjs --list-bundles` lists the complete source manifest
without launching a browser; `--bundle=berlin_1_autumn --reuse` captures one
exact original variant. For serial capture, deck references and native packing:

```powershell
./tools/migrate_worlds.ps1 -Godot C:/path/to/Godot_v4.7.2-stable_win64.exe -Bundle berlin_1_autumn
```

Omit `-Bundle` to process the full source manifest. Each tool owns its timeout
and timestamped logs; a failed step stops before publishing the next phase.
Individual completed captures can also be processed with
`node tools/world_references.mjs berlin_1_spring` and then
`godot --path . res://tools/import_worlds.tscn -- --bundle=berlin_1_spring`.
Run the reference step before native packing; it supplies the original deck query
endpoint tolerance and probe results. It processes exactly one bundle, executes
only the captured `biomes.js` bytes, records them with the extraction helper hash
in `deckReferences`, and leaves the bundle unchanged on any source drift. Bundle selection validates against the
same required manifest; the normal full import still rejects missing worlds.
The baker runs the original terrain and complete biome constructor offline, resamples
verified raw elevation tiles into the current battlefield frame, and rejects
incomplete coverage. Missing elevation coverage is captured into this project's
`data/source_elevation/`. Geographic imagery requests are omitted.

Generated world files use `map_team_season.json` / `.res`. Ordinary maps are baked
for all four original seasons; campaign maps use their authored chapter season.
Every resource embeds its source-accepted structure layers and map/team/season
identity. Native loading and the importer require the matching seasonal files;
legacy road-only files are excluded from the required manifest. Berlin 1 spring
and summer native resources have been generated; the remaining seasonal set
and complete updated world checks are unfinished.

Source modules, generator, map configuration, captures and tile hashes control
cache reuse. The native importer packs geometry and collision into compressed
Godot resources. Development JSON bundles and raw tiles are excluded from
exports. Runtime requires neither the source checkout nor the bake tools.

Super battle implementation is prepared but unverified. The native lobby mode
switch permits all source pilots and creates one third-faction human against
both full Bot factions. `--super` selects the same mode for an offline launch
or a dedicated `--server` host. The generated source tables cover all 101 legal
levels; native authority purchases/deaths share their recomputation path, and
combat, summons, body collision and FPV eye/forward offsets consume that state.
Respawn sampling uses an independent random generator. The native shop exposes
one Super track with automatic purchase enabled initially; wallet/HP/ammo always
settle on the authority. Third-faction projectile/carrier/summon export is
prepared. Before that metadata is generated, deployment remains unavailable.
Original Super reference cases and `tools/test_network.ps1 -Super` routes are
written but have not been generated or run. Full presentation, persistent mode
preferences, spectators/recovery and complete-match verification remain pending.
All verification still waits until the migration implementation is complete.

Native controls/recoil implementation is prepared but unverified. Wheel/keypad
+/- toggle scope and select heavy/light weapons; RMB/keypad / immediately casts
according to current shield stance. Arrow keys and additive numpad look retain
source rules. Authority fire applies source recoil after its shot, preserves
movement penalties and reverse impulses, and processes burst echoes without
second damage/ammo expenditure. Recoil randomness stays separate from combat.
Reliable aim acknowledgements keep later movement from undoing mode changes or
empty-heavy fallback. The owner receives private recoil/view state; local camera
look remains responsive. Source control/recoil references and native suites are
written, and `tools/test_network.ps1 -Controls` routes both transports through
real bindings, ordered shield/cast actions and an original recoil pulse trace.
Metadata generation and every compile/runtime/render/transport check are deferred
until all migration implementation is complete. Complete body/view feedback,
spectator controls and frame/traversal certification remain
pending.

Native touch/gyro and personal control settings are also written but unverified.
The lobby and battle menu share one native settings panel. The host chooses any,
kbm or pad for the whole room, including live changes; only any permits a player
to choose their own current controls. `--ctrl pad` also shows the virtual pad on
a desktop. Two sticks, action/shoulder/system buttons and original strict
empty-area double-tap-hold/drag firing feed shared controls. The shop remains
accessible while dead and has a touch-accessible return button. Button/HUD
mirroring, look inversion, level flight, sensitivities, sensor source and haptics
persist in `user://controls.cfg`. Browser localStorage is not a native save file.
Gyro uses Godot sensors on supported mobile exports; unavailable platforms or
missing sensor readings show a reason. Source mobile references and native
scalar/persistence suites are prepared. `tools/test_network.ps1 -Mobile` adds
actual touch/mode/release checks over both transports. Data generation, all
compilation/tests, sensor hardware, safe-area and populated mobile/render/export
verification remain deferred. ZR view-lock now has the further unverified
implementation below.

Native ZR view assistance is written with original acquisition/cycle references.
A press selects the next enemy from left to right; a hold tracks with the source
angular-speed budget and hysteresis. NPCs/towers participate, release retains the
cycle anchor, death clears it, and system look bypasses preference inversion while
respecting freeze. It changes ordinary view angles and does not confirm a weapon
lock or settle combat. Rendered cameras retain recoil/shake and source FOV easing.
Fire dwell and dense weather share original scope-radius rules with acquisition.
Native under-HUD ring/fog gradients use source palettes and anchors; Godot screen
mipmaps and Tween ease-out replace browser blur/CSS timing. Scalar suites and
`tools/test_network.ps1 -View` are prepared but unexecuted. Actual map LOS, live
rosters, shader raster/transition appearance, complete frame order, TPS/body/muzzle
integration and combined render/transport certification remain pending. No data
generation, compilation or tests have run for these changes.

Player TPS camera/state/occlusion is wired into the selectable native view but
remains ungenerated and unverified. It retains source visual-height scaling,
shoulder/floor/ring framing, local recoil, body turning, temporary FPV while
aiming and per-object occlusion fades using native TriangleMesh queries. Shared
source obstacle dimensions now drive dynamic camera clipping and native hazard
movement cylinders, including fixed AA/relay radii and collapsed rubble. Original
camera/mode/fade oracles and native suites are prepared. Body posing, private
authority muzzle convergence, heading separation, mode input and persisted
settings are connected below. Generation, compilation and all tests remain
deferred until the migration implementation is complete.

Full body scene export/packing and native `BodyRig` loading are prepared for
ordinary/mercenary/Super appearances. Shared rig references, morph part plans,
per-slot weapon event identity, payload recovery, spinner motion and moving
muzzle attachments are retained. The source energy shield now has a native
shader and scene-local materials with an independent presentation phase RNG.
`--bodies` packs these assets after source generation. Original hierarchy/event
and shield-clock suites are written but unexecuted; assets remain ungenerated.
Anatomical locomotion and morph/defense/combat pose driving are written below;
complete render shaders and owner/remote/TPS muzzle integration remain pending. No compilation,
generation or tests have run for this implementation.

Original per-part morph swap/post-pass driving is now written for the native
body rig. It preserves source inferred part pairs, signed transforms, rest-joint
settle, shrink/fade and material restoration, with prepared original traces and
complete-state native comparisons. Source trace storage uses lossless deltas.
Full locomotion/combat/equipment/shield ordering and remote hero binding are now
written below, including owner TPS. No generation, compilation or tests have run.

Source gait curves, movement state, animation weights and biped/hop/aerial poses are now
written for the native body rig. The driver retains human/animal limb profiles,
movement personality, weapon recoil, head/neck stabilization, held-arm bracing,
jump leg synchronization and tail compensation. Logical Euler angles preserve
source rotation order and accumulated revolutions independently of signed TRS.
Aerial rigs retain distinct fixed-wing, bird, insect, membrane, rotor and swim
motion, with private jet opacity/emission and stable-head axial waves.
Quad rigs retain walk/tripod/crawl and gallop phases, insect lift joints,
tentacle search/guard waves and rider stabilization. Wheel/track rigs use native
MultiMesh tread plates with signed travel, differential turning and suspension;
instance transforms/materials stay private to each body.
Vehicle source profiles include original APC/tank faction/Super bodies; current
hero assets use biped, quad or aerial rigs. Companion packing also retains
instanced geometry and bounds.
Original per-body traces and scalar/joint suites are prepared but unexecuted.
Legacy single-tree morph driving remains unsupported. The complete captured-rig
pass sequence and remote hero binding are written below; owner TPS remains pending.
Generation and tests remain deferred.

Body combat clocks and rigid weapon mechanisms are written with original
event-identity, recoil, aim/charge/release windows, muzzle flames, deployment and
blink behavior. Logical emission retains double precision beside native material
values. Source traces and complete-state native comparisons are prepared but
unexecuted; full frame ordering and remote game binding are written below.

Source jump-pose overlays now retain takeoff/landing latches, apex tuck, jump-peak
classification and separate biped/quad/insect landing loads. Original gait-plus-
jump traces and exact gate cases are prepared; compilation and tests remain
deferred. Anatomical/equipment/shield ordering is connected in the composed driver.

All eleven source cast-pose archetypes are written, with original directional
anticipation/strike curves, omni envelopes, per-clip durations and event expiry.
Prepared traces compose gait/cast/jump helpers across both skill slots and
direction modes. The complete body post-pass order and remote game binding are
written below; no generation, compilation or tests have run.

Species post-passes now retain aerial held-arm aiming, predatory posture,
ground-wing folding and slot-dependent tentacle convergence in the original
gait/cast/jump order. Original source blocks drive the prepared complete-node
references. World stabilization and anatomical/aim/equipment/shield integration
are composed in the frame driver; generation and tests remain deferred.

World-frame quaternion math, mounted-part stabilization, weapon-axis correction,
anatomical hand/gaze poses, burst hair flicks, bow draw/release and grip/stowed
equipment clearance are now written. Source references compare reset and final
body poses across mirrors, nonuniform scale, partial aim, raised soles and event
boundaries. Native-width math fixtures are prepared; no generation, compilation
or tests have run. Complete shield/reference-motion/morph ordering and remote
hero game binding are written; owner TPS and full muzzle integration remain pending.

Heroes now load captured body scenes and use a native presentation wrapper for
the complete gait/combat/morph/anatomical/aim/equipment sequence. Actor physics
and authority aiming retain ownership of movement and hit settlement. The local
FPV body stays hidden. Source LOD staggering accumulates time between distant
body updates, while spinners continue every frame. Weapon/cast delivery uses
presentation serials to reject replays without losing distinct same-time shots.
Revival/respawn snaps reset old presentation clocks. Original event/LOD/direction
and complete-frame comparisons plus `-Bodies` ENet/WebSocket checks are prepared
but unexecuted. Body scenes/fixtures remain ungenerated; missing scenes report
unavailable content. Owner TPS and muzzle/aim separation are wired below;
primary NPC binding is written below and final equivalence remains pending.

A hidden authority body now reuses the captured pose pipeline independently of
render cadence and LOD. Source TPS next-emitter selection and camera-ray
convergence have native helpers and prepared animated/fallback references,
including FPV pose freezes and TPS resumption. Every human authority pilot now
owns this graph; accepted rounds, lob controls and advisory origins select its
next port. Snapshots distinguish physical body heading from camera heading.
Native owner camera/occlusion and saved view selection retain the original
temporary FPV/restore order while aiming. The last scoped heavy round uses its
restored TPS port with the previous FPV camera ray, and immediate feedback guards
against stale scoped snapshots. Respawns reset local view/body orientation using
an authority generation. Local echoes advance their body once; public self-echo
notifications only consume transport identity. FX time aligns once to authority
monotonic time and keeps advancing independently of match-clock snapshots.
Prepared `-Tps` transport cases cover modes, ring framing, separate headings,
private last-heavy emission and stale snapshot rejection. Existing transport
fixtures explicitly select FPV. Complete death/revival cameras, carrier/civilian bodies,
animated mesh queries and source frame/render/transport certification remain
pending. Generation, compilation and tests remain deferred.

Body weapon/cast/charge notifications now use a separate reliable native channel
with visibility filtering and serial deduplication. Snapshot copies remain as
delivery fallback. Native rail/steady entry, release and cancellation now emit
the original charge-on/off transitions; source notification references and an
immediate-RPC-only body transport case are prepared but unexecuted.

Primary NPCs now load source-built soldier/APC/tank/rocketeer/howitzer/helicopter
body scenes with native gait, wheels/tracks, rigid recoil and rotors. Independent
vehicle turrets and aircraft gun pitch retain original shot memory, mechanical
limits and visual target-cache rules before the composed body pass. NPC shot
identity advances alternating emitters and recoil mounts once across immediate
and snapshot delivery. Source mount/muzzle/acquisition references, complete-node
native suites and a populated `-Bodies` NPC/replay case are prepared. These
changes remain ungenerated and unverified. Static/camp/summon binding and
MultiMesh occlusion are written below; remaining validation is still deferred.

Towers, source base batteries, actual camp rosters, all six autonomous summon
builders and the hologram/wingman alias now share the native captured body driver.
Buildings retain their orientation while mounts track independently. Each base
gun keeps its own target, rest angle and recoil; gameplay missile origins and
cooldowns retain their existing authority path. Missing body content rejects
camp preparation or casting before spending. NPC target-height reports preserve
the distinct ordinary/companion quantization rules, with captured garrison and
air-height fallback ports and individual snapshot tracer origins.

MultiMesh view occlusion now queries individual instances and fades their batch
with isolated material bindings. Material restoration keeps ongoing instance
animation and external replacements. Source cases cover empty/mixed/mirrored
batches, moving instances and instanced owner bounds; native resource-isolation
checks and expanded `-Bodies` static-mount transport cases are prepared.
These changes remain ungenerated and unverified. Complete surface/frame
integration, artillery arc production,
styled discharge/impact effects, final shaders and complete runtime/render/
transport certification remain pending. All tests remain deferred.

Carrier bodies now use the captured native body pipeline: per-pilot kamikaze
escorts retain the actual chassis and source root scale; bomber/hypersonic bodies
retain their original absence of a locomotion rig. Native attitude follows source
heading easing and displacement-derived hypersonic pitch in `YXZ` order. Casting
checks the actual pilot's carrier resources before spending. Clone shots now
drive only the firing entity, with its current muzzle sampled before the next
combat pass advances either morph tree. Original-method pose/event references
and native binding, cadence and replay cases are prepared. The remote position/
surface driver is written below; complete integration and populated transport/render certification remain pending; no
generation, compilation or test has run.

Per-ID civilian bodies now assemble native scenes exported from the original
body, hair, clothing, accessory and profession helpers. Source appearance RNG
selects the components and private palettes; waist, head/shoulder proportions,
source centering/height fit and team rings preserve the independent body stream.
The source articulated chains use the existing native biped pose pipeline.
Missing parts reject preparation; `--civilian-parts` packs the prepared graphs.
Original complete-model geometry, normals, colours and motion references cover
every occupation and all appearance categories, with native comparison suites
written. Assets remain ungenerated and all verification remains deferred;
head-marker visual certification, final surface shaders and complete frame/transport integration remain.
Prepared `-Bodies` transport cases also include clone, kamikaze, hypersonic and
per-ID civilian binding, event replay and unchanged authority resources/RNG.

Remote bodies now keep an independent native rendered transform. Original
planar/heading easing, stationary shot/nearest-enemy facing, carrier pitch and
previous-position LOD share the same visual frame; physics and hit volumes stay
authoritative. Offline and network bodies consume the same published snapshot,
retaining source ground/factory placement before the first frame. Ground sampling
retains accumulated-LOD caches and source
water/deck rules, while flight uses terrain/deck/closed-roof maxima. Native lane
profiles march source paths after initial weather setup and preserve strict
nearest-sample ordering. Original remote-frame/profile references and native
cadence, geometry-frame and resource-isolation suites are prepared. Standing
platform/blocker metadata, static pads, visibility re-entry and full integration/
render/transport certification remain pending. No generation or test has run.

NPC firing now has original gun/cannon, wingman-beam, compact-rocket and
eight-chord artillery presentation, with the source launch-angle barrel pose,
delayed endpoint stars and base-only launch flashes. Native pools and MultiMesh
batches retain the source layered colours, fade curves and nested effect limits;
immediate/snapshot replay cannot allocate another discharge. Shared muzzle,
contact and explosion bursts are written, and existing boom snapshots use the
same offline/network presentation entry. Effects use a separate visual RNG and
never settle combat. Original geometry/texture exports, `--npc-effects` packing,
source-method burst references and howitzer transport checks are prepared.
Missing resources stop rendered match preparation. Generation, compilation and
all tests remain deferred. Full hero discharges/fans, explosion producer coverage,
kamikaze embers, blast reactions, low-power preferences, remaining FX budgets,
visibility lifecycle and final shaders/render/transport certification remain.

Hero fan and lance effects now have native authored scene/mesh drivers. Offline
exports execute the original discharge geometry and retain each fan vertex's
ownership bin. Runtime clipping preserves the source sub-cone edges, elevation
limit, central reach and obstacle backoff; a vertex shader animates sweep
brightness without rotating the clipped cone. Full-width penetration channels,
source envelope curves, payload travel and delayed EMP release share the bounded
effect list. Instant hero fan/line and bot plasma snapshots use those drivers.
`--weapon-effects` packs their scenes; raw graphs stay out of exports. Source
geometry/fade/query fixtures and production event/resource checks are prepared.
Generation, compilation and tests remain deferred. Low-power
preferences and populated shader/render/transport certification remain pending.

Owner kinetic penetration now presents its launch-to-impact channel once at
terminal flight, independently of damage settlement. Immediate events and
snapshot copies share replay rejection; timestamped visual retirement prevents
older or same-clock snapshots from recreating the spent projectile. Pure visual
shells retain factory tail poses, draw source contact stars only on collision
and expire silently at range. Owner FX speed stays distinct from gravity
velocity. Original terminal/contact traces and native production/lifecycle
checks are prepared; generation, compilation and tests remain deferred. Remaining
terminal feedback still requires work.

Remote human and bot reports now share source weapon dispatch, visual shells
and compressed burst callbacks. Initial shots preserve their pre-fire emitter;
callbacks query the current nearest owner/clone muzzle. Same-pilot squad rigs
share one fire pose, surviving clones retain pilot identity, and duplicate
RPC/snapshot reports cannot repeat effects or callbacks. Private bot poses keep
every paid attack while public poses follow source report cadence. Prepared
`-Bodies` transport cases cover immediate delivery and replay.

Original local fan, remote plasma and missing-asset lance fallbacks are written.
Ion breath uses captured throat geometry plus native MultiMesh coils/arcs, with
source low-power counts, colours and fade curves. Source-method fixtures cover
fallback ordering, scatter, clipping, vertical/zero directions and actual ion
transforms. These paths remain ungenerated and unverified; all generation,
compilation and tests remain deferred until migration implementation is complete.

Fire/smoke sprites now use captured original textures and separate native
billboard pools. Embers retain source gravity; smoke/plumes retain frame-delta
drift and normalized delayed visibility. Kamikaze explosions include their
original ember burst. Pool prewarm/caps and the shared oldest-first effect budget
remain source-derived.

Observed HP/shield snapshots now present source victim contacts offline and on
replicas, including shield priority, building variants and camera-distance size
compensation. First observations, healing, replay and visibility re-entry cannot
invent a hit. Guard flashes target the original spawn material and retain the
stronger active peak. Source producer/tick/gate/guard references and native
resource/lifecycle checks are prepared; generation, compilation and tests remain
deferred. Remaining private damage/death/scenery reactions and populated
render/transport certification remain pending.

First-person shields now pack original six-sided geometry, per-pilot patterns
and native shield materials through `--first-person-shields`. The camera owns
the shield separately from cockpit visibility and weapon recoil. Source FPV/TPS,
defense/cast/death gates, horizontal expansion, hidden-frame clocks and style
retargeting are written. Snapshot vital loss selects either a shield flash or
the original red hurt vignette; first observations, healing, death and view
resets do not invent hits. Native UI timing retains browser ease-out keyframes
and the source repeated-hit animation guard. Original setup/update/snapshot/CSS
references and native scene/material/production checks are prepared; generation,
compilation and tests remain deferred. Blood, hitstop, death sequences and full
render/transport certification remain pending.

Blood/glint authority aggregation and native presentation state are written.
Actual primary-pilot losses merge by attacker until publication, preserving the
first bearing, optional human eye height and source rounding. Native state keeps
source camera projection, dose/drop curves, immutable stains, caps and fade/
clear behavior on an independent visual RNG. Original-method fixtures and native
resource checks are prepared. Native overlay/transport binding and compositing
are now written below. Generation, compilation and tests remain deferred.

Native glass overlays retain source DOM identity, immutable drop patterns,
percentage positions, exact decimal serialization and per-frame opacity. Pooled
SubViewport chains compose the original gradients, blur and alpha shadows once
per new stain or resize. Local publication serials reject replay; view/death/room
changes clear both source layers. Source DOM and landscape/portrait browser PNG
capture plus native lifecycle and `-Bodies` transport cases are prepared.
After all implementation and deferred imports, the rendered scene
`godot --path . res://tests/splat_render.tscn` compares native glass pixels with
the source PNGs and writes mismatches under `build/splat_render`. Raster/filter,
frame-order and full runtime/transport certification remain pending; no
generation, compilation or test has run.

Death camera transitions now have an unverified native state machine, synchronous
source effect callbacks, cockpit fire/smoke bands, independent Camera3D ownership
and respawn/room cancellation. Source CSS drives native red-rim pulse and climax
whiteout, with the shop remaining above the flash. Original initializer/update,
surface-query, effect-order and CSS fixtures are prepared. After all implementation
and source imports, run `godot --path . res://tests/death_render.tscn` for browser
pixel comparison and `tools/test_network.ps1 -Godot <path> -Deaths` for lethal
damage, early respawn, aerial climax and camera-release transport certification.
Exact blur raster/performance, TPS death-body presentation and configurable wipe
transitions remain pending; no generation, compilation or test has run.

Blast feedback now has unverified authority settlement for camera trauma,
ground lift and airborne impulse. Immediate owner projectile feedback and later
global reports retain separate replay guards and source tunnel/terrain points.
Original-method fixtures and `tools/test_network.ps1 -Godot <path> -Blasts`
cover delivery, accumulation and resource isolation over ENet and WebSocket.
Remaining producers and complete frame/packet timing still require migration
and certification. Generation, compilation and tests remain deferred.

Carrier completion now derives explosion flags/radii from original tick reports
and publishes them before delivery effects. Bomber mission expiry retains its
source fracture report and does not deliver unused payloads. Per-step source
fixtures cover report points, ordering and removal; they remain unexecuted.

Scenery collapse now shares the hitstop/effect clock and finalizes on expiry or
budget eviction. Captured dimensions and source profiles drive ID-seeded chunks
and shock rings without consuming combat or ordinary visual randomness. Replay,
removed-target and source-clock cases are prepared. Generation and tests remain
deferred.

Static damage geometry, private material tint, surface cracks and repair are now
written but unverified. Source geometry IDs preserve shared-hull deformation and
original full indices across material groups. Observed health bands emit one
destination burst; first appearance and fog re-entry establish a quiet baseline.
Original geometry/snapshot fixtures cover buffers, alias isolation and effect
order. Generation and tests remain deferred.

Mobile bodies now have unverified private opaque-material tint and articulated
local scars, with source exclusions, a twelve-part cap, stage opacity and light
damage draw ranges. Release restores material bindings; visibility re-entry and
healing avoid replaying hidden damage. Source fixtures cover indexed/non-indexed
parts, skin/material-array exclusions, joint motion and instance-buffer retention.
Hero and ordinary damage retain their distinct publication order. Removal
dissolve and complete raster/performance/
transport acceptance remain pending; no generation or tests have run.

Persistent low-health smoke, crack planes, authored flames and embers now have
unverified native groups. Original PNG/geometry capture and constructor/update
fixtures retain random order, stage reuse, visibility, local wind and separate
presentation/wall clocks. Healing, fog loss and collapse release each group;
combat resources and RNG stay authority-owned. GPU depth/transparency, full toon/
curve appearance, performance and combined render/transport acceptance remain
pending. No generation, compilation or tests have run.

Missiles now have unverified source-scene views separate from authority collision
bodies, with snapshot interpolation, jet animation, mobile damage and persistent
smoke/fire. Matching blast/intercept reports fracture the last rendered position;
silent removal and deflection preserve their source gates. Original puff geometry,
strict timing, fade and shared expiry are prepared alongside source-method and
publication-order fixtures. Interpolated owner aiming, complete packet/frame
timing and render/transport acceptance remain pending. No generation or tests
have run.

Known non-neutral body removal now has an unverified native retirement path.
Last-rendered models detach from gameplay actors; same-publication death IDs
authorize source stage-three damage, a seeded burst and static/mobile Y squash.
Silent removal stays immediate. Original-method fixtures cover lifetime, hidden
bodies, global FX eviction, repeat guards and resource isolation.

Remaining removal paths now have unverified material-gated dissolve. Original
GLSL noise functions feed native ShaderMaterial discard; private bindings retain
source anchors, material aliases, outline visibility and instance animation.
Civilian component flags preserve their distinct renderer neutrality. Deferred
source-method fixtures cover material support, grouped slots, clocks, neutral
collapse guards and ghost retirement. Full toon/weather/shadow appearance,
GPU raster, dynamic materials and combined render/transport acceptance remain
pending. No generation, compilation or tests have run.

Interpolated missiles now have an unverified visual triangle query, including
animated/hidden mesh parts, source material sides and persistent-damage meshes.
FPV echo shells stop at the nearest missile/environment hit while penetrating
shells skip missiles. Minimap missile markers follow rendered positions. Original
candidate/raycast fixtures and authority-state isolation cases are prepared.
Complete owner intent, ordinary-unit mesh queries, frame/precision and combined
render/transport acceptance remain pending; no generation or tests have run.

## Architecture

| Responsibility | Native implementation |
| --- | --- |
| Room lifecycle and transports | `Session`, `OfflineMultiplayerPeer`, `ENetMultiplayerPeer`, `WebSocketMultiplayerPeer`, RPC |
| Gameplay settlement | `BattleSimulation`, authority-only commands and snapshots |
| Collision and movement | Built-in Jolt, `CharacterBody3D`, `StaticBody3D`, native ray queries |
| Terrain and roads | Source-derived `ArrayMesh`, compressed `Resource`/`PackedScene`, native triangle/convex collision |
| Lane path sampling | `Curve3D`, `Path3D`, `PathFollow3D` |
| Model and animation import | `PackedScene`, captured rigid body rigs, `MultiMesh`, glTF and `AnimationPlayer` |
| Menu, HUD, shop and input | `Control`, `Container`, `CanvasLayer`, `InputMap` |
| Environment and audio | `WorldEnvironment`, `ProceduralSkyMaterial`, `DirectionalLight3D`, `AudioStreamPlayer` |

Game-specific math remains custom where the engine has no equivalent: source
range envelopes, shield budgets, damage falloff, fan bins, penetration zones
and deterministic uint32 replay. Engine primitives handle their supporting
physics, serialization and presentation.

## License

Game code and original assets retain the source's Apache-2.0 license; see
`LICENSE`. Imported audio retains its existing attribution in
`assets/audio/README.md`. Godot itself is distributed under the MIT license and
is not bundled with this project.
