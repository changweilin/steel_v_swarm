# Sonnet — presentation, view, model presentation and leased fixes

## Scope

Apply the root ownership rules. Default to Claude Sonnet 5.5 at `medium` (`high`
for long tasks) for work with named files, an explicit source contract and a
runnable acceptance case. This workstream owns three file-disjoint lanes and the
`SN` leases; it never owns authority, shared shaders, shared numeric/font
semantics, rigs or shared publication.

| Lane | Owns (root rule) | Backlog |
| --- | --- | --- |
| Presentation | World/resource pipelines, audio, input, local feedback and combat presentation (rule 6) | [presentation.md](presentation.md) |
| View | View/scope, minimap, PiP, campaign presentation and the bounded UI allowlist (rules 3, 5) | [view.md](view.md) |
| Model presentation | Civilian assembly, markers/LOD/occlusion, damage/removal and missile geometry (rule 2b) | [models.md](models.md) |
| Leases | Files in the root lease table | [MIGRATION.md](MIGRATION.md) |

Read this file, then [MIGRATION.md](MIGRATION.md), then only the selected lane's
backlog or lease, and only the selected task's source producer, consumers and
fixtures. Search sibling lanes, Opus backlogs and research; do not load them whole.
Commands run from the repository root.

## Implementation contract

- Stay inside the selected lane or lease. Consume every other API read-only and
  make the smallest change that satisfies the named acceptance case.
- Prefer native Godot resources, Controls/containers, Camera3D, SubViewport,
  ResourceLoader, audio buses, particles, MultiMesh and existing utilities. Check
  existing helpers before adding one.
- Presentation, UI and test fixes must not spend resources, settle damage or
  purchases, change combat RNG or publish private state. Panels display source
  data and submit existing commands only.
- Preserve source order, clocks, nullish/zero distinctions, coordinate frames,
  double-to-native boundaries, cancellation, private materials and resource release.
  Keep strict tolerances and every assertion; never retune values to pass.
- Imported data, glTF and generated output change only through their existing
  tools. Shared manifests, fixture consumer plans and importer registries stay
  with Opus. Model lanes consume packed actor scenes; never pack on the dummy
  renderer or hand-tune graphs, hit cylinders, muzzles or animations.
- Unsupported source behavior stays explicitly unavailable.

## Escalate to Opus

Stop and record an exact request (target file, contract, acceptance case) in the
selected backlog when a fix needs a file outside the lane or lease, source
semantics stay ambiguous, it needs a shared shader/numeric/font/rig contract, it
reaches settlement, RNG order, privacy, membership or transport lifecycle, or a
strict fixture still fails after the named correction. Opus may then take the task
under its own lanes; ownership of the consumer files does not move.

## Isolation

- Use one session and one worktree per task. Lanes and leases are file-disjoint,
  so different lanes may run concurrently; tasks inside one lane run one at a
  time. SN5, SN8 and SN9 run alone because they use fixed outputs or shared ports.
- Fixed-output captures, shared `.godot` imports and publishers run serially even
  when source edits are independent.
- A fresh worktree has no `.godot/`, `build/` or ignored seasonal resources. Import
  there for local use only and never commit resulting `project.godot` changes.
- Use process-local `APPDATA`/`LOCALAPPDATA` under `build/sonnet-<task>-*` unless a
  lane backlog names an existing path. New reports go to `artifacts/sonnet/`;
  existing `artifacts/{sol,terra,flash}/` evidence stays valid at its path.

## Acceptance and updates

Use the original source oracle plus native lifecycle checks: real-driver pixels,
actual mixer output, populated models and empty engine error output. Runtime
changes require `tests/run.tscn`, runtime smoke and the affected ENet/WebSocket
case, one switch per run; source tooling also runs its Node tests. An unrun gate
is an open item, never a pass. Documentation-only changes require link/scope checks.

Only this directory's backlogs receive progress and exact requests. Delete a task
when its checks pass; deleting an `SN` task ends its lease. Keep root routers,
every `AGENTS.md`, research and Opus backlogs unchanged during routine work.
