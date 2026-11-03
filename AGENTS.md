# Steel vs. Swarm — Godot Port

- Runtime code MUST be GDScript. Use Godot 4 native scenes, physics, animation,
  UI, audio, resource imports and MultiplayerAPI before adding custom systems.
- No add-ons, GDExtension, C#, JavaScript runtime, embedded browser or Node server.
  `tools/import_source.mjs` is an offline migration tool, not a runtime dependency.
- HP, damage, ammunition, purchases, respawns and outcomes settle only in
  `scripts/simulation.gd` on the authority, including offline matches.
- Offline, ENet and WebSocket sessions share one simulation and room lifecycle.
- Imported source data and glTF assets are read-only. Regenerate them with the
  import tool; never manually retune derived numbers.
- New gameplay implementations require source-based equivalence fixtures.
  Keep intentional blast coverage, planar penetration, building clamps,
  shield-budget overflow, bot limits and fire-rate budgets.
- Independent scenery randomness must never consume the combat RNG stream.
- Comments and documentation use English. Traditional Chinese UI and narrative
  content belong in `data/`.
- Unsupported mechanics must remain explicitly unavailable until their source
  semantics are implemented. Do not substitute a generic attack or fabricated map.
- Read the routing table in `MIGRATION.md`, then load only the selected workstream.
  A passing component fixture never establishes full match or delivery parity.
- Runtime changes require `tests/run.tscn`, the runtime smoke test and relevant
  ENet/WebSocket tests. Documentation-only changes require link/scope checks.

## Progressive context loading

1. Keep this file and the root `MIGRATION.md` as stable shared instructions.
2. Select one workstream and explicitly read its `AGENTS.md`, then its
   `MIGRATION.md` index and the one lane backlog it names. The selected instructions govern that workstream's assigned
   files even when those files live outside its documentation directory.
3. Read only the source, fixtures and acceptance commands needed for the task.
   Sibling workstream instructions, backlogs and research are opt-in context.

| Workstream | Instructions | Default model |
| --- | --- | --- |
| Presentation, view/campaign/UI, model presentation and leased fixes | [Sonnet](migration/sonnet/AGENTS.md) | Claude Sonnet 5.5 |
| Authority, integration, difficult source semantics, rigs and actor packing | [Opus](migration/opus/AGENTS.md) | Claude Opus 5.5 |

## Independent edits and stable prefixes

- Apply the exclusive file ownership rules in the root `MIGRATION.md` before
  editing. Read other owners' code as needed; leave their files untouched.
- Put progress, blockers and cross-owner requests only in the selected
  workstream's `MIGRATION.md`. A request names the target file, required contract
  and acceptance case; its owner implements it in a separate turn/change.
- Routine task completion must not edit root routers, any `AGENTS.md`, research,
  another workstream's backlog or shared test/import registries. Remove finished
  tasks directly; retain only constraints still needed by unfinished work.
- Load context in this order: stable root rules, stable selected rules, selected
  backlog, task-specific evidence. Append changing task material after stable
  instructions; do not inject sibling progress, timestamps or whole-tree dumps.
- Keep each model/workstream in its own conversation. Preserve tool definitions
  and model settings during a run. File layout reduces unrelated prefix changes;
  cache eligibility and hits still depend on the provider and harness.
- The nested instruction files are explicitly selected documents, not a claim
  that every client automatically discovers them. From the repository root,
  load the selected file manually; configure another client to do the same.
