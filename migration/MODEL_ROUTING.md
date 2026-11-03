# Model routing rationale

Optional planning reference. Do not inject this research into routine workstream
prompts. It explains the current routing decision; it is not a status ledger.

## Difficulty and execution model

| Work | Reasoning demand | Default | Escalation boundary |
| --- | --- | --- | --- |
| Sonnet presentation lane | World/resource pipelines, audio, input and combat presentation against source fixtures | Claude Sonnet 5.5 at `medium` | Shared shader/numeric contract, authority/lifecycle change or unresolved source semantics |
| Sonnet view lane | View/scope, minimap, PiP, campaign and bounded UI consumers with explicit fixtures | Claude Sonnet 5.5 at `medium` | Shared shader/font/numeric semantics or producer API change |
| Sonnet model presentation | Civilian assembly, markers/LOD/occlusion, damage and missile geometry | Claude Sonnet 5.5 at `high` | Pose composition, rig or packer change |
| Sonnet leases | Named files, explicit contracts and runnable acceptance | Claude Sonnet 5.5 at `medium` | Ambiguous semantics, authority, privacy or lifecycle |
| Opus lanes A-E | Publication, render/numeric contracts, simulation, session/rooms and integration | Claude Opus 5.5 | Resolve from original source and independent evidence; unavailable if semantics remain absent |
| Opus lane F | Mech rigs, pose order, transforms and actor packing | Claude Opus 5.5 | Same as A-E; packing stays on a real renderer |

This is a project-specific routing inference, not measured intelligence or a
claim that one model always wins. The project uses only Claude Sonnet and Opus.
Work formerly routed to Gemini Flash (bounded UI), ChatGPT Sol 6.1 (presentation
pipelines) and ChatGPT Terra 6.1 (visual consumers) now runs on Sonnet, because
each task already carries named files, a source oracle and runnable acceptance.
Opus keeps authority, shared contracts and the pose-composition half of the
former Models workstream, where aliasing and composition order decide fidelity.
Ownership follows the file, not the model: an escalated Sonnet task keeps its
files in the Sonnet lane while Opus settles the shared contract in its own files.

## Claude Sonnet/Opus evidence and routing decision

Checked on 2026-10-31 (Asia/Taipei). Anthropic assigns complex agentic coding and
large-scale refactoring to Opus 5.5, and everyday coding and agent work to Sonnet
5.5. Sonnet lists at half of Opus's token price.
[Official model selection](https://platform.claude.com/docs/en/about-claude/models/choosing-a-model),
[models overview](https://platform.claude.com/docs/en/about-claude/models/overview).
Its launch page places Sonnet at well-scoped tasks and bug fixing and keeps Opus
ahead on complex, open-ended work. At `max`, Sonnet more often started a
multi-subagent review skill; two examined cases timed out or edited out of scope.
[Sonnet 5.5 launch](https://www.anthropic.com/claude-sonnet-5-5).
The effort guide starts Sonnet at `medium` for well-specified agentic coding,
moves to `high` for harder or longer tasks and reserves `xhigh`/`max` for measured
gains. [Official effort guide](https://platform.claude.com/docs/en/build-with-claude/effort).

Anthropic's multi-model measurements found delegation saved money for routine work
with a long cost tail or work larger than one context window. One dependent chain
did better on one model at lower effort. Its only Sonnet-with-Opus-advisor result,
on a non-coding benchmark, was within noise at 25% more cost.
[Official cost and intelligence guide](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence).
Secondary reporting says Sonnet used more output tokens and cost more per task than
Opus at max effort, and found 6 of 13 known issues against Opus's 8 of 13 in a small
code-review set. [Codersera summary](https://codersera.com/blog/claude-sonnet-5-5-vs-opus-5-5-2026/).

Community evidence is thin and conflicting. Reddit could not be retrieved, so this
sample is Hacker News comments from 2026-10-21 through 2026-10-26, not a survey:

- One developer reports Sonnet as cheaper per task and faster for personal work.
  [Sonnet report](https://news.ycombinator.com/item?id=50243939).
- Another reports Opus as more token-efficient and cheaper per run on a
  reverse-engineering benchmark. [Opus report](https://news.ycombinator.com/item?id=50220395).
- A third reports Sonnet implementation exhausting a team limit about two hours
  into a session. [Usage report](https://news.ycombinator.com/item?id=50178757).

Project inference: price per token alone does not justify Sonnet. Use it where a
narrow contract limits exploration and retries; keep open-ended authority work on
Opus. Run independent lane sessions rather than an Opus orchestrator or advisor.
Compare completed, accepted tasks and retries before widening Sonnet's scope.

## Progressive disclosure and cache isolation

Load root `AGENTS.md` and the stable root migration router, then exactly one
workstream's stable `AGENTS.md`, its index, one lane backlog and task evidence.
Sibling backlogs are never part of the routine prefix. Progress changes only
the selected backlog; completed tasks disappear without a shared changelog.

This is a file/context design, not an API cache implementation. Prefix matching
also depends on model, request boundaries, tool schemas, settings, cache length
and expiry. Sonnet and Opus do not share a cache. A local edit cannot guarantee a
cache hit in any client.

- Claude caches the prefix through an enabled breakpoint, including tools,
  system and messages. Its API caching configuration and invalidation rules are
  separate from this repository's Markdown layout.
  [Claude prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching).

Claude Code reads `AGENTS.md` directly only from v2.1.277, and a root `CLAUDE.md`
takes precedence over it. The installed CLI is 2.1.208, so root `CLAUDE.md` imports
`AGENTS.md`. Imports load in every session, so workstream files stay explicit reads.
[Official Claude memory guide](https://code.claude.com/docs/en/memory).
