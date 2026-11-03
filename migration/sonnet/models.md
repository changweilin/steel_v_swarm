# Model presentation lane — outstanding work

Read [AGENTS.md](AGENTS.md). This lane owns civilian assembly, markers/bars,
LOD/occlusion, damage/removal and missile geometry. Rigs, pose order, actor
packing and `tools/import_cockpits.gd` stay in [Opus lane F](../opus/models.md);
consume their packed scenes and pose outputs read-only. Imported source/glTF must
remain read-only and packed scenes alone do not certify rendered bodies.

## Inbound

- [ ] **Remaining `MultiMesh.duplicate()` calls:** `scripts/dissolve_binding.gd`,
  `scripts/mobile_damage_geometry.gd` and `scripts/scene_damage_geometry.gd` still
  call `batch.multimesh.duplicate()`, which sets the buffer before the instance
  count in Godot 4.7.2. Use `MultiMeshCopy.of`. Acceptance: their dissolve and
  damage suites on a real driver with empty engine error output.
- [ ] **Per-part view occlusion for batched buildings
  (`scripts/view_occlusion.gd`, SN1 lease while it lasts):** source
  `_registerViewOccluders` fades individual source meshes. Batches carry
  `noViewOcclusion` meta, so their parts never fade; fading a whole building would
  substitute different semantics. Required contract: fade members via
  `source_batch.vertex_starts`/`index_starts` (for example a per-member alpha
  attribute or split draw ranges) using each member's own bounds. Acceptance: a
  source building part that occludes the player fades alone while its siblings in
  the same batch stay opaque.

## Construction

- [ ] **M3 — Civilian assembly:** certify per-ID/profession component selection,
  original age/gender/height/waist geometry, material/rig reconstruction, shoulder/
  head scaling and local outline uniforms after final assembly. Retain source
  renderer neutrality independently of combat faction/spy metadata.
  `scripts/civilian_body_builder.gd` is leased to SN4 while that task remains.

## Markers, LOD and occlusion

- [ ] **M12 — Markers/bars/LOD/occlusion:** certify source billboard glyphs,
  head anchors/fades, civilian public following marks and overhead HP/shield bar
  creation/cache/removal. Finish source geometry LOD/hysteresis/stride/zoom,
  geoKeep/outline traversal and prefab visibility. Certify nine-sample TPS
  occlusion, actual MultiMesh instances, hidden geometry/BVH grazing precision,
  per-instance fade restoration and camera/PiP masks. Shared shader implementation
  is Opus-owned; it must not be replaced by a model-local approximation.

## Damage, removal and missile models

- [ ] **M13 — Building/static damage:** certify private mesh/material bindings,
  original deformation/normal/linear-colour/scar buffers, crack face/area/tie
  order, repair and alias restoration. Complete source combat-building damage,
  collapse/debris pose, map-building part-motion pause and model/world ownership
  clearance. HP/rubble/fire/salvage
  settlement stays in simulation; decorative world packing belongs to the
  presentation lane.
- [ ] **M14 — Mobile damage/removal:** certify opaque tint/scar exclusions,
  articulated anchors, part caps, stage draw ranges, guard materials and persistent
  smoke/cracks/flames. Preserve first-observation/healing/fog/collapse cleanup,
  death-authorized squash/fracture, silent removal and material-gated dissolve.
  Ghosts retain final pose/material aliases/outline state but no collider/target.
  Finish shader/weather/shadow composition, full raster and resource lifecycle.
- [ ] **M15 — Missile geometry/query:** certify standalone source bodies,
  animated/hidden/material-sided triangle selection, damage-stage geometry,
  nearest/tied hits and source outline triangles. Keep authority collision poses
  independent of interpolated views. Owner echo versus environmental stop priority,
  penetration exclusions, interpolation and minimap effects are consumer contracts
  to validate with the presentation lane and Opus, not new model-side damage
  settlement.

## Acceptance

Dedicated source/native suites include `civilian_body_suite.gd`,
`geometry_lod_suite.gd`, `view_occlusion_suite.gd`, `scene_damage_suite.gd`,
`mobile_damage_suite.gd`, `damage_fx_suite.gd`, `body_removal_suite.gd`,
`dissolve_suite.gd` and `missile_view_ray_suite.gd`. Run them on a real driver,
plus existing transport cases `-HeadMarks` and `-VitalBars` as relevant, one case
per run, and the root runtime gates. Request a repack from Opus lane F when a
packed model output must change; never pack on the dummy renderer.
