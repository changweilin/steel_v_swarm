# Opus — authority, integration and difficult source semantics

## Scope

Apply the root ownership rules. Default to Claude Opus for ambiguous source
semantics, coupled state machines, numeric/shader fidelity and failure-sensitive
integration, plus mech rigs, pose order and actor packing (lane F). This
workstream owns the shared integration surfaces; it does not gain permission to
edit Sonnet lane or leased files, even when it takes an escalated Sonnet task.

Read this file, then [MIGRATION.md](MIGRATION.md), select one execution lane, then
read the selected source producer, native consumers and fixtures. Pull only an
explicitly relevant handoff from another workstream; do not load every sibling
backlog. Commands run from the repository root.

## Authority contract

- All gameplay settlement remains in `scripts/simulation.gd` on the authority.
  Offline, ENet and WebSocket use the same commands, simulation and room lifecycle.
- Trace the active original producer before adding behavior. A dormant helper is
  not an authored mechanic. Source `support=false` and the current one-body squad
  contract prohibit generic support fleets, wing salvos and manual body swaps.
- Preserve blast coverage, planar penetration, building clamps, shield overflow,
  target/LOS bands, stable tie order, bot/APM limits and fire/resource budgets.
- Keep combat RNG distinct from scenery, visual, room and independent respawn
  randomness. Verify draw order as well as final values.
- Logical seats, physical routes, private actor state and match IDs are separate
  contracts. Check cancellation, stale work/packets, reentry, leave and owner death.
- Source fixtures must execute the original seam. Do not weaken pixel/numeric
  tolerances, fabricate missing metadata or replace a source-specific effect to
  force acceptance. Unknown shader/audio shapes remain explicitly unavailable.
- Serialize shared source/fixture publication and registration. Reuse existing
  atomic writers and strict manifests; do not mutate generated data by hand.

## Lane F model contract

- Original source/glTF and derived data are read-only. Change the existing
  offline builder/export/packer path and regenerate; do not hand-retune graphs,
  hit cylinders, muzzles, body scales or animations.
- Use native PackedScene, ArrayMesh, AnimationPlayer, MultiMesh and scene-local
  resources. Preserve hidden nodes, original hierarchy/IDs, material aliases,
  emitter references, logical Euler/quaternion state, signed TRS, source pose
  composition and immutable event identity: distinct same-clock shots advance
  separately, replaying one event does not.
- Keep visual meshes, authority collision/aim volumes and owner camera rulers
  distinct. Authority-body rigs are read-only pose suppliers to simulation. Do not
  invent rigs for rigless carriers or missing species; unsupported node/material/
  reference types reject explicitly.
- Real-renderer packing is mandatory for nonempty MultiMesh content. Pack/reload
  fresh independent instances and check early-cancel/unrendered release as well as
  destruction. Never publish over another owner's active capture.

## Integration and acceptance

Pull a cross-owner request only for the named interface and acceptance case;
implement shared wiring here, leaving its producer/consumer files with their
owners. For runtime changes run the full fixture scene, runtime smoke and
affected ENet/WebSocket cases, plus source/render/platform checks relevant to the
change. Engine errors invalidate a clean run even when assertions pass.
Record an unresolved failure and its current impact in this backlog. Neither
old passes nor a focused run establish complete parity. Documentation-only work
requires link/scope checks without regeneration or game execution.

## Context and updates

Keep root routing, instructions and research stable. Update only this directory's
`MIGRATION.md` for ordinary work; remove resolved items with no future dependency.
Do not copy historical logs or completed checkpoints into prompts. Append current
task evidence after stable instructions and keep unrelated workstreams unloaded.
