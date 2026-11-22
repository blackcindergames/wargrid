# Project instructions

## What this is

Wargrid is a Godot isometric RTS with geometric 2.5D art, inspired by Zero Hour's game design: its own game that feels close to it, not mathematical parity ([Zero Hour verification](docs/reference/zero-hour-verification.md)). Names in code and UI are Wargrid's own (`usa`, `china`, `frc`); faction differences are capability data, not simulation branches.

- Package state and what waits for the owner: [status](docs/STATUS.md), the only place for it. Other documents link to it and never repeat it.
- Setup and commands: [development notes](docs/development.md). Scope: [blueprint](docs/blueprint.md). Next work: [packages](docs/packages.md); the owner starts each package.
- Before changing maps, art, sound, performance, release tooling, `relay/`, `protocol/` or `warroom/`, read that area's entry in the [agent map](docs/agent-map.md).
- Working files (handoffs, session notes) live in `~/projects/wargrid-private/docs/`, never in this repository.

## Hard limits

- No commit, push, PR, merge or fly deploy without explicit approval. Only the owner pre-authorizes local commits for a run; its handoff records that.
- Ordinary CI must work without sibling projects or retail game data.
- Never loosen a budget, tolerance, assertion or pinned outcome to make something pass. Report it as exceeded and ask.
- Never invent approvals, playtests or measurements. Say what is unverified.
- Simulation is typed GDScript, advanced by ticks, separate from scenes, rendering, wall-clock time and networking. It follows the [determinism rules](docs/reference/determinism-rules.md). New tests use only the [simulation interface](docs/reference/sim-interface.md).
- Ask before any visible window and batch such checks. Tests, replays and simulation benchmarks stay headless. The reference game always runs `-headless -noaudio`. A UI round may take one batch of offscreen screenshots per screen (rendered to files, no window, no sound) and have a reviewer compare them with the mock-ups before the owner's look.
- Reference engines (`~/projects/CnC_Generals_Zero_Hour`, `GeneralsGameCode`, `OpenRA`, `RecoilEngine`, `permafrost-engine`) are read-only. Read them for behaviour and values, then write Wargrid's own code. Port only a small algorithm where our own version would be clearly worse, rewritten in typed GDScript with a comment naming repo, revision and path; ported EA code keeps EA's copyright line and a pointer to EA's additional terms.
- Never copy EA assets, INI or map data, art, audio, text or trademarks. Exception: maps from EA's GPL-released `CnC_Modding_Support`, converted by a repo tool, with EA's copyright line, the source revision and a Wargrid map name. Query Zero Hour data only through `python3 tools/zh_ini.py dump` and `python3 tools/zh_w3d.py dump`; the dumps are never committed.
- The repository is public. No personal detail, hostnames, LAN addresses, session ids or scratch paths in tracked files; paths are home-relative. `sh tools/check_public.sh` must pass; fix a hit by rewording.
- Performance targets a low-end device, not this machine ([ledger](docs/reference/performance.md)). A package that touches `game/` is not done without a passing `PERF_LABEL="<package>" sh tools/run_benchmark.sh` and its ledger row.
- The art direction stays. Over budget means a performance fix or an explicit budget change by the owner.

## How a package runs

1. **One page first.** What the player will notice, the observation that would refute it, the first playable slice, what is out. Look for the refuting observation in data that already exists before running anything new.
2. **Build the smallest playable slice,** test-first for simulation rules. Then the owner plays it for ten minutes. Measuring and polishing come after that match and aim at what it showed.
3. **Decide details yourself.** Bar definitions, probe sizes, constants and implementation choices are the coordinator's; list them under "Decided for you" in the report, reversible on the owner's word. Ask the owner only for taste, play results, scope and approvals, with the selector tool and a recommendation. Look decisions run as a [War Room](warroom/README.md) round.
4. **Harden once, at the end:** pins and traces, one fresh Opus review of the whole branch, the benchmark row, one status line, the affected [guide](docs/guide/README.md) chapter.
5. **Player experience.** Design specs, plans, playtest cards, mock-ups and diffs touching UI, HUD, controls, art or player-facing text also get the [player-experience reviewer](.claude/agents/player-experience-reviewer.md), beside the correctness reviewer. It runs unasked, before the work is reported done or shown to the owner; not on simulation, relay or tooling-only diffs; typo, rename and comment-only diffs are exempt. The [game director](.claude/agents/game-director.md) runs only when the owner asks.
6. **Night runs** take only work whose acceptance a headless check can decide; follow [night run](docs/night-run.md).
7. Build only the requested package and stop at its gate. Writing, editing or approving a plan, or preparing a branch, never starts implementation on its own. No scaffolding for later systems.

## Commands and environment facts

- Before reporting done: `sh tools/run_checks.sh` (lint, warnings, Python, shell, public) and the full suite. Report counts, exit status and the tree each check ran on.
- Suite and benchmark output goes to a file; read the summary lines, and on failure only the failing lines. `WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh` while iterating.
- Pass `timeout: 600000` on every suite, benchmark, netplay, lint and parity call.
- Wait on long jobs with `run_in_background` or a Monitor until-loop, never `sleep` polling; CI with `gh run watch --exit-status`.
- Edit with the Edit tool or asserted replacements only. Scratch Godot scripts `quit()` on every path.
- The Godot project is `game/` (`res://`); repository tools live outside it. Terminal-first: no routine editor clicking.
- Rendered benchmarks open a window: ask first.
- The README roadmap block is generated (`python3 tools/roadmap.py`); never edit it in the README.

## Git

- Merge a branch into `main` with `git merge --squash` as one to three commits. First tag its tip: `git tag -m "<branch> branch tip" <branch>-tip <sha>`, pushed with `main`.
- After a merge to `main`, follow [After a merge](docs/development.md#after-a-merge).
- Preserve user changes. Keep caches, build output and local environment files untracked.
