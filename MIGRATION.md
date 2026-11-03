# Migration router

Full feature parity requires outstanding implementation and integrated acceptance.
This file is a stable index; mutable work belongs in exactly one backlog below.
Imported definitions, packed scenes and passing component fixtures do not certify
a complete match, seasonal world set, transport lifecycle or platform delivery.

## Select one workstream

| Model | Scope | Instructions | Outstanding work |
| --- | --- | --- | --- |
| Claude Sonnet 5.5 | Presentation (world/resources, audio, input, combat effects), view (view/scope, minimap, PiP, campaign, bounded UI), model presentation (civilians, markers/LOD/occlusion, damage, missiles) and leased fixes | [AGENTS](migration/sonnet/AGENTS.md) | [Index](migration/sonnet/MIGRATION.md) |
| Claude Opus 5.5 | Authority, shared lifecycle, render/numeric contracts, publication, integration, mech rigs/actor packing and final acceptance | [AGENTS](migration/opus/AGENTS.md) | [Index](migration/opus/MIGRATION.md) |

Each workstream index lists its lanes and their backlogs; load only the selected
lane. These are task-routing defaults, not a universal intelligence ranking. Model
selection evidence and caching caveats are optional reading in
[MODEL_ROUTING.md](migration/MODEL_ROUTING.md). Routine work does not load it.

## Exclusive file ownership

Documentation directories are disjoint. Runtime files stay in their existing
locations; the following first-match rules give each file exactly one owner and
lane. Ownership follows responsibility: when Opus takes an escalated Sonnet task,
the files stay with their Sonnet lane and Opus records or implements only the
shared contract in its own files.

1. **Opus owns shared integration surfaces:** `scripts/main.gd`,
   `scripts/simulation.gd`, `scripts/session.gd`, `scripts/unit.gd`,
   `scripts/content.gd`, `scenes/main.tscn`, `project.godot`, export presets,
   `.github/`, `tests/run.gd`, `tests/run.tscn`, `tests/validation.json`,
   `tools/import_source.mjs`, `tools/world_references.mjs`,
   `tools/test_network.ps1` and `tools/export_web.ps1`. Shared fixture/manifest
   publication is serialized here.
2. **Actor geometry and posing** splits by file:
   - 2a. **Opus lane F owns rigs and packing:** `scripts/body_*.gd`,
     `scripts/cockpit_*.gd`, `scripts/authority_body_pose.gd`,
     `scripts/authority_weapon_pose.gd`, `scripts/source_quaternion.gd`,
     `scripts/source_euler.gd`, `scripts/gait_curves.gd`,
     `scripts/weapon_presentation.gd`, `scripts/carrier_body_motion.gd`,
     `scripts/first_person_shield.gd`, `scripts/shield_presentation.gd` and
     `tools/import_cockpits.gd`/`.tscn`. Native actor/model scene outputs belong
     here; imported source/glTF stays read-only.
   - 2b. **Sonnet model presentation owns:** `scripts/civilian_body_builder.gd`,
     `scripts/geometry_lod_state.gd`, `scripts/view_occlusion.gd`,
     `scripts/head_mark*.gd`, `scripts/vital_bar.gd`,
     `scripts/scene_damage_geometry.gd`, `scripts/mobile_damage_geometry.gd`,
     `scripts/damage_fx*.gd`, `scripts/retired_body.gd`,
     `scripts/dissolve_binding.gd`, `scripts/missile_body.gd` and
     `scripts/missile_view_ray.gd`.
   Decorative world scenery belongs to the Sonnet presentation lane.
3. **Sonnet view lane owns the bounded UI allowlist:** `scripts/native_ui.gd`,
   `scripts/*_settings.gd`, `scripts/room_player_editor.gd`,
   `scripts/room_bot_editor.gd`, `scripts/campaign_ui.gd`,
   `scripts/boss_hud.gd`, `scripts/battle_feed.gd`,
   `scripts/combat_feed_state.gd`, `scripts/status_icon*.gd` and
   `scripts/touch_controls.gd`. Event/command contracts stay with their producers.
4. **Opus owns authority and difficult shared semantics:** remaining
   `scripts/*_rules.gd` except `audio_rules.gd`/`audio_scene_rules.gd`,
   `scripts/*_math.gd`, `scripts/room_*.gd` except
   `room_world_resources.gd`/`room_world_prebuild.gd`,
   `scripts/actor_snapshot.gd`, `scripts/match_recipe.gd`,
   `scripts/fatal_watchdog.gd`, `scripts/bot_brain.gd`,
   `scripts/projectile_motion.gd`, `scripts/missile_motion.gd`,
   `scripts/lob_fire_control.gd`, `scripts/recoil_state.gd`,
   `scripts/shot_history.gd`, `scripts/hurt_bearing_log.gd`,
   `scripts/blast_feedback.gd`, `scripts/ability_charge_state.gd`,
   `scripts/source_*.gd`, `scripts/structure_layers.gd`,
   `scripts/lane_surface_profile.gd`, `scripts/climb_index.gd`,
   `scripts/climb_state.gd`, `scripts/balance_*.gd`,
   `scripts/campaign_progress.gd`, `scripts/audio_music_envelope.gd`,
   `scripts/outline_rules.gd`, `shaders/`,
   `tools/audio_music_gain_capture.mjs` and `tools/outline_*.mjs`,
   `tools/cel_*.mjs`, `tools/texture_*.mjs`.
5. **Sonnet view lane owns the bounded visual-consumer allowlist:**
   `scripts/camera_pose.gd`, `scripts/player_view_state.gd`,
   `scripts/view_lock_state.gd`, `scripts/scope_*.gd`,
   `scripts/spectator_*.gd`, `scripts/lock_glow_presentation.gd`,
   `scripts/minimap*.gd`, `scripts/pip_*.gd`, `scripts/campaign_*.gd` and
   `scripts/dialogue_*.gd`. Earlier rules retain `campaign_ui.gd` in this lane
   and `campaign_rules.gd`/`campaign_progress.gd` with Opus.
   Dedicated captures/importers for these consumers follow this lane, including
   `tools/import_campaign_hold.gd`/`.tscn` and
   `tools/import_dialogue_fonts.gd`/`.tscn`; shared importers remain Opus-owned.
6. **Sonnet presentation lane owns other presentation scripts** under `scripts/`, plus native
   world/audio importers, world capture/storage/selection tools,
   `tools/migrate_worlds.ps1` and `tools/import_audio_source.mjs`.
7. A dedicated test scene, fixture adapter or reference generator follows the
   owner of its production target. A file covering multiple owners, an unmatched
   tool, or a shared generated registry belongs to Opus. Shared graphics helpers
   remain Opus-owned even when consumed by Sonnet lanes.

Do not edit another owner's or lane's file to finish a local task. Add an exact
handoff to your own backlog, naming the producer/consumer contract and the acceptance case.
The target owner pulls that request only when integrating that contract. New
ownership exceptions must be settled before concurrent edits begin; ordinary
progress never rewrites this router. Concurrent runs of publishers that overwrite
the same generated output are also prohibited, even if their source edits differ.

## Claude Sonnet leases

A lease beats rules 1-7 while its ID remains in `migration/sonnet/MIGRATION.md`.
Before editing a listed file, search that backlog for the ID; do not load it whole.
Deleting the task returns the file to its rule owner without editing this router.
Leases are disjoint, so tasks with different IDs never edit the same file.

| Task | Exclusive files | Rule owner |
| --- | --- | --- |
| SN1 | `scripts/multimesh_copy.gd`, `scripts/{scenery,climb,aquatic,wildlife,petal}_presentation.gd`, `scripts/view_occlusion.gd` | Presentation, model presentation; helper returns to Opus |
| SN2 | `scripts/control_preferences.gd`, `scripts/audio_preferences.gd`, `scripts/skill_field_presentation.gd` | Presentation |
| SN3 | `tests/{body,burst,camera,cockpit,death,footprint,mobile,projectile_visual,tps,view}_network.gd` | Their production owners |
| SN4 | `tests/body_suite.gd`, `tests/civilian_body_suite.gd`, `tests/burst_suite.gd`, `scripts/civilian_body_builder.gd` | Opus lane F, model presentation |
| SN5 | `tools/import_cockpits.gd`/`.tscn`, `assets/companions/` | Opus lane F |
| SN6 | `scripts/combat_effects.gd` | Presentation |
| SN7 | `tools/fixture_json.mjs`, `tests/{aquatic_render,death_render,minimap_fog_render,splat_render}.gd`, `tests/campaign_suite.gd`, `tests/death_sequence_suite.gd`, `tests/raster_compare.gd` | Opus, presentation, view |
| SN8 | `tools/source_world_meshes.gd`, `tools/import_worlds.gd`/`.tscn`, `scripts/world.gd`, `scripts/room_world_resources.gd`, the selected bundles' `data/worlds/` and `assets/worlds/` outputs | Presentation |

SN9 edits no production file. Opus accepts contracts in its own lanes; a Sonnet
task never edits an Opus-owned file outside this table.

## Lane concurrency contract

- Sonnet: presentation owns S1-S11, S15-S19 and S21; view owns S12-S14, S20 and
  F4; model presentation owns M3 and M12-M15. Opus lanes A-E own the O tasks and
  lane F owns M1, M2 and M4-M11. Existing task IDs stay stable.
- Lanes with disjoint files may run concurrently in separate worktrees; tasks
  inside one lane run one at a time.
- Consumers use existing producer APIs read-only. Freeze payload shape, clock,
  lifecycle and resource ownership before separate changes; an API change is a
  handoff naming the target file, contract and acceptance case. The producer's
  owner implements it separately. Neither lane edits the other's backlog.
- Dedicated tests, fixture captures and generated resources follow their single
  production target, including `.uid` companions. Mixed-owner files, shared
  registries and publication helpers stay with Opus. Imported originals remain
  read-only. New files require an unambiguous owner before concurrent edits.
- Use `artifacts/sonnet/` and `build/sonnet-*` (or the path a lane backlog
  names) for new lane-local diagnostics, preferences and caches. Existing
  `artifacts/{sol,terra,flash}/` and `build/{sol,terra,flash}-*` evidence paths
  remain valid and read-only to other lanes. Use distinct output
  arguments for captures/tests that support them; fixed-output generators,
  shared `.godot` imports and publishers must run serially. Independent code
  editing does not authorize concurrent writes to common generated outputs.

## Completion policy

Each backlog contains only unresolved work and constraints required to finish it.
Delete completed items with no remaining dependency; do not add dated checkpoints,
completed checklists, superseded failures, copied logs or migration history.
Keep live blockers and unsupported behavior explicit. Evidence may be inspected
from its existing test/artifact location without copying it into shared prompts.

No historical partial test result certifies the current build. Runtime acceptance
uses `tests/run.tscn`, the runtime smoke test and relevant ENet/WebSocket cases;
world/model/render/export checks are added by the selected task. Missing content
or an unrun check remains an open item, never a passing result.
