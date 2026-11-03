# Lane F — mech rigs, actor packing and gameplay NPC models

Read [AGENTS.md](AGENTS.md), including its model contract. Civilian assembly,
markers/LOD/occlusion, damage/removal and missile geometry (M3, M12-M15) are in
the [Sonnet model lane](../sonnet/models.md). Packed scenes alone do not certify
posed, rendered or transported bodies. Imported source/glTF must remain read-only.

## Construction and packing

- [ ] **M1 — Complete original actor content:** reconcile current source
  builders and model outputs for every pilot/faction/mercenary/SUPER appearance,
  both morph trees, combat attachments, NPCs, camp rosters, summons, holograms,
  carriers, civilians and tower/base/gun variants. Preserve source node/material/
  shared-reference identity, hidden parts, per-surface flags and original bounds.
  Missing content rejects preparation/casting before spending.
- [ ] **M2 — Clean instance lifecycle:** certify nonempty MultiMesh packing,
  source transforms/colour declarations, pristine third-instance creation,
  mutable-resource isolation, early cancellation and rendered/unrendered release.
  GLES3 material errors on uninitialized release remain a lifecycle risk to test;
  forcing a diagnostic raster pass alone does not certify the game lifecycle.
  Do not add custom cloning or a dummy-renderer packing fallback.

## Mech rigs and full pose order

- [ ] **M4 — Transform foundation:** certify quaternion/Euler callbacks,
  non-unit/extrapolated values, source multiplication order, conjugate-only
  inverse, signed/zero scales, mirrored/nonuniform/sheared matrices, singular
  results and logical pose state. Whole-body checks retain native transform
  precision; do not claim end-to-end double precision from scalar fixtures.
- [ ] **M5 — Locomotion:** certify original gait/state/weight/joint traces for
  biped/hop/aerial/quad/vehicle and cephalopod paths. Cover run/idle/hitch/frozen
  clocks, identity stagger, acceleration/turn damping, topology, wings/rotors,
  wheel/tread instance matrices and zero/nonfinite guards. Preserve exact source
  composition with aiming, morph, defense, combat and equipment post-passes.
- [ ] **M6 — Morph/jump/cast/species:** certify both-tree visibility/active-rig
  switching, paired/unpaired per-part interpolation, endpoint/half-way thresholds,
  alpha/depth restoration and inferred part plans. Finish jump latches/apex/
  landing, all eleven cast archetypes and species overwrite order, including
  bird/insect/cephalopod exceptions and source legacy single-tree behavior.
- [ ] **M7 — Aim/anatomy/equipment:** certify source world-frame stabilization,
  slot/forward axes, launcher blends, hands/bracing, gaze/fingers, bow/string/
  arrow, grip/dorsal mounts, carry/stow and floor/muzzle/envelope clearance.
  Compare reset and final traces separately so later writes cannot hide drift.
- [ ] **M8 — Weapon/defense poses:** certify immutable fire/cast identity,
  same-time distinct shots, both morph-form clocks, alternating barrels, heavy
  mechanisms, muzzle flashes, payload reparent/recovery, spinners and scene-local
  emission. Complete FPV cockpits, six-sided shields, style/stance/expansion/
  contact phases and reference-motion order with source depth/curve/outline hooks.
- [ ] **M9 — Authority/TPS pose contract:** certify hidden independent authority
  rigs, current next non-FX emitter, world-space camera-ray convergence and source
  eye/forward fallback. Preserve the final scoped shot's FPV ray with restored
  TPS port and one resource spend. Authority timing/heading/wiring is an Opus
  integration request; local view state and input state are Sonnet-owned.

## Gameplay NPCs and combat structures

- [ ] **M10 — NPC/static mounts:** certify source soldier/APC/tank/rocketeer/
  howitzer/helicopter and tower/base/camp/summon mounts, turret heading, pitch
  clamps, independent base-gun targets, source rounded height reports, recoil
  clocks and current muzzle selection. Visual-only target tracking must not
  become another combat decision system.
- [ ] **M11 — Clone/carrier variants:** certify clone entity-only deferred fire,
  per-pilot half-size kamikazes, faction bomber/hypersonic graphs and explicit
  rigless behavior. Compare remote body transforms, ground/deck/water clamps,
  previous-rendered-position LOD, cached surface/support and live shot memories.

## Source regeneration and acceptance

Coordinate canonical source capture/fixtures with lane A before packing. Existing
native model packer categories include:

```powershell
godot --path . res://tools/import_cockpits.tscn
godot --path . res://tools/import_cockpits.tscn -- --bodies
godot --path . res://tools/import_cockpits.tscn -- --companions
godot --path . res://tools/import_cockpits.tscn -- --civilian-parts
godot --path . res://tools/import_cockpits.tscn -- --first-person-shields
```

Use the same packer for the relevant projectile/hazard/loot/NPC-effect/weapon-
effect categories only when that owned model output changes, including repacks
requested by the Sonnet model lane. Keep packing on a
real driver. Dedicated source/native suites include `body_*_suite.gd`,
`npc_body_suite.gd` and `carrier_body_suite.gd`.

Complete populated real-driver render checks and existing transport cases
`-Bodies` and `-Tps` as relevant, one case per run,
plus root runtime gates. Full SUPER/BOSS scale, private/remote poses and
death/reentry/room cleanup must agree with source. Remove resolved items; retain
only active blockers and exact owner handoffs, without model-generation history.
