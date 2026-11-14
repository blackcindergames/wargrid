# Flatter Worst Ticks Implementation Plan

**Status:** refreshed 2026-11-14 onto `4c21d1a`; all 21 Questions decided (user, 2026-11-14); external readiness review applied the same day (verification file evidence row); approval pending. History: drafted 2026-11-14 against `74950e5` as backup 1 of the One controller night run (docs only, nothing run), revised the same day with a fresh-context review that measured the open claims on scratch copies of `74950e5` (`~/projects/wargrid-overnight-work/one-controller/flatter-worst-ticks/review.md`, logs in its `verify-copy/logs/`; host under load, so its microsecond numbers are ratios, not budgets); round 2 of the Questions added the X2 check (Question 13), the queue-place criterion (Question 8) and measured worst-tick gates (Question 14, Tasks 6 and 7); the Steam Deck rows (Tasks D0 and D7, report-only) were added the same evening (user, 2026-11-14). Resume record: [verification file](../../reference/flatter-worst-ticks-verification.md).

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: `docs/night-run.md` (Coordinator rules) and `docs/milestone-prompt.md` (session start, stop conditions). Resume record: the verification file. Every task subagent also reads "Global Constraints", "Pinned values", "Re-pin list", "Determinism notes" and "Allowed test edits" (`rg -n '^## ' <plan>`).

**Goal:** night package 4 "Flatter worst ticks" ([packages](../../packages.md#night-lane), package note; [simulation review](../../reference/simulation-reference-review.md#review-2026-11-13) §5.8, §5.2 "Smaller alternative"; [hordes300 combat_fire](../../reference/hordes300-combat-fire.md); [design answers](../../reference/design-answers-2026-11-08.md#simulation-reference-review-user-2026-11-13)). Three tail-tick fixes: (1) retaliators sent home by one death share one cell map instead of one full entity scan each (no behaviour change); (2) bot seats decide on their own tick (`tick % 30 == seat % 30`), each from a light bot state instead of one shared `snapshot()`; (3) the path service stops starting searches once a tick's route cells reach a budget (384, Question 4), instead of after 8 requests. **One trace re-pin** for (2) and (3) together. Then the worst ticks are measured on the final tree with repeat runs and gated where the figure is a deterministic count (Question 14).

**Architecture:** (1) `Combat.object_removed` opens a refcounted reservation map on its first retaliator and `_assign_move` reads it while it is open (the probe diff of the hordes300 note, adapted to today's tree, plus the cross-check test that note asks for). (2) `Simulation.bot_state()` returns the fields the bot reads (entity rows with id, owner, kind, position, combat mode and target, hole and container ids; buildings; players; `last_sequences`; tick); `Skirmish.issue_opponents` calls the ungated `Skirmish.decide` for each seat whose tick it is. Task 2 lands the state with the old 30-tick gate and proves it changes nothing (every pin and trace unchanged); Task 3 moves the gate. (3) `PATH_CELLS_PER_TICK` replaces `PATH_REQUESTS_PER_TICK`; `_assign_route` returns the cells it charges; X2 (three seats order 60 units each across Ashfall on one tick) checks the budget on the real map. Task 5 re-pins once. (4) Task 6 adds report lines with per-tick counts to the benchmark rows and measures five runs; Task 7 turns the deterministic counts into gates in those rows by a stated rule; wall-clock worst ticks stay report-only with proposed ceilings. (5) Steam Deck rows, report-only, never gating and never blocking a task (user, 2026-11-14): Task D0 measures the base and Task D7 the branch head after Task 7, three runs each of the native headless profile and combat rows and of the Deck Firefox `Web Bench`; Task 8 puts both into the ledger History.

**Tech stack:** typed GDScript (Godot 4.7.2), POSIX `sh`.

**Written against** `main` `4c21d1a` (read-only; anchors below are `file:line` on that tree, re-read with `rg -n` at the refresh). Since the first draft's `74950e5`: One controller merged (the screen code lives in `game/scripts/match/`, the offline bot call is `offline_driver.gd:32`, `skirmish_main.gd` and `online_main.gd` are gone, `IC1_ROWS` and `IC2_ROWS` are pinned in `game/tests/input_script_rows.gd`), and P2.1 added the launcher. Simulation drift is two validation lines for builders inside a transport (`simulation.gd:242`, `construction.gd:72-74`), so `simulation.gd` anchors from `:242` on moved by one; no pin value of the table moved. Task 0 re-reads every anchor and the pin census on the real base; every task re-anchors by symbol on drift.

## Global Constraints

- Worktree `$W` = `~/projects/wargrid-wt-flatter`, branch `flatter-worst-ticks` from `main` (Task 0 creates both). `$L` = `~/projects/wargrid-overnight-work/flatter-worst-ticks/logs`. `$W`, `$L` and `~` are notation only: in every command type the absolute path; never `~` or a shell variable in a command (denied at night, 2026-11-13). Agent shells reset their working directory: start every command with `cd <absolute $W> && `. `$L` holds every log and scratch file; never write logs into the repository.
- Every suite, benchmark, profile, team match, netplay, conformance, lint, warnings and checks call: Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker (`TESTS PASSED`, `CHECKS PASSED 5`, `PROFILE COMPLETE 10`, `TEAM MATCH won`, `NETPLAY PASSED`, `CONFORMANCE PASSED`, `BENCHMARK PASSED 2` / `COMBAT BENCHMARK PASSED 10` / `LOCKSTEP BENCHMARK PASSED 1`; from Task 6 also a `TEAM PATHS` line). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`. Anything that may run past 10 minutes runs with `run_in_background` and is waited on by its completion notice.
- Static gates: `sh tools/run_checks.sh` (lint, warnings, Python, shell, public). New code is typed.
- While iterating: `WARGRID_TEST_ONLY=<suite file or case substring> sh tools/run_tests.sh`. The full suite is the gate before GREEN.
- Suite with traces (written `SUITE(<tag>)` below): `WARGRID_REPLAY_TRACE=$L/replay-<tag>.tsv WARGRID_ECONOMY_REPLAY_TRACE=$L/economy-<tag>.tsv WARGRID_COMBAT_REPLAY_TRACE=$L/combat-<tag>.tsv WARGRID_TEAM_REPLAY_TRACE=$L/team-<tag>.tsv sh tools/run_tests.sh > $L/<tag>-suite.log 2>&1; echo "exit=$?"`.
- Allowed at night (preparation record below): `sh tools/run_*.sh`, `sh tools/check_public.sh`, `sh tools/export_build.sh`, `godot --headless …`, `python3 tools/roadmap.py`, `python3 tools/compare_replays.py` and `python3 -I <abs $L>/<script>`, `mkdir -p <abs $L>/…`, `git worktree add`, `sh <abs ~/projects/wargrid-native-work>/deck-preflight.sh`, `ssh -o BatchMode=yes deck@…`, `scp … deck@…` and `scp -r deck@… …`, Edit and Write in `$W` and under `~/projects/wargrid-overnight-work/`. The night file itself names no `git status`, `git diff`, `git log`, `git add`, `git commit` or `git archive`; the handoff's proposed settings copy (the user's `! cp`, never an edit in place) adds `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git add:*)`, `Bash(git commit:*)` and `Bash(git archive:*)`, so they are allowed once that copy is in place; if `git archive` is refused anyway, Task D0 / D7 use the scp fallback named there. Other `python3` scripts, other `mkdir` and `cp` are not in the night allow list: copy a file by reading it and writing the copy with the Write tool. Denied: `git push`, `git merge`, `gh pr`, `fly`, `sh tools/deploy_web.sh`, `sh tools/run_game.sh`, any visible window on the Mac, any Zero Hour launch. The one window allowed tonight is Firefox on the Deck screen in Tasks D0 and D7 (user, 2026-11-14). A refused command goes to the morning list with its exact text; the task uses an allowed form or parks.
- **The Deck** is written `deck@<deck>`: the coordinator types the address from the night handoff (private; never in a repository file, a log name or a commit). Deck commands are single `ssh` / `scp` calls from the Mac with no `$`, `~` or `$(…)` on the Mac side; everything that needs a shell runs in `wargrid-flatter/deck-job.sh` on the Deck (Task D0 Step 3). Mac exports run alone like Mac benchmarks and profiles; Deck jobs may overlap every other Mac step.
- New tests use only the simulation interface (`docs/reference/sim-interface.md`; `tools/test_sim_boundary.py`). Tests that poke private state go into files already on that tool's allowlist: `test_combat.gd`, `test_groups.gd`, `test_combat_navigation.gd`, `test_skirmish.gd`, as named per task.
- Subagents never commit. The coordinator makes one local commit per GREEN task (pre-authorized by the night run handoff); never push. Tasks 3 and 4 count as GREEN when the only red checks are the Re-pin list's, and Task 5 is the one re-pin commit (Question 10, user, 2026-11-14).
- Edit repository files with the Edit tool only; scratch files in `$L` are written with the Write tool. Scratch Godot scripts live in `$L`, run with `godot --headless --path <abs $W>/game --script <abs script path>`, `quit()` on every path, and end with a `<NAME> DONE` marker line; judge them by that marker, never by exit code (Godot exits 0 when a `--script` fails to parse, seen twice in the review). Scratch mutations (red-by-mutation steps) are reverted with Edit and checked with `git diff --stat`.
- Comments: why only, one line, no diff narration.
- A parked task parks the tasks that build on it: Task 2 parks 3-9; Task 3 or 4 parks 5-9 ("one re-pin for both": no single-change re-pin at night); Task 5 parks 6-9; Task 6 parks 7. A parked Task 6 or 7 leaves Tasks 8 and 9 to run on the tree before it, and the docs say the count gates are not installed. Tasks D0 and D7 park nothing: a Deck failure is recorded and becomes a morning item; if the main line parks before Task 7, Task D7 runs on the last GREEN commit and the ledger row names that tree.
- **Don't touch:** `game/scripts/presentation/`, `game/scenes/`, `game/scripts/match/` (`offline_driver.gd:32` calls the bot; the bot entry `Skirmish.issue_opponent(s)` keeps its signature, so callers need no edit), `game/scripts/launcher.gd`, `game/scripts/launcher_settings.gd`, `game/scripts/net/` (`headless_client.gd:172` calls the bot), `relay/`, `protocol/`, `game/data/`, `.github/`, `tools/zh_map/`, `game/export_presets.cfg` and `game/benchmarks/bench_runner.gd` (Tasks D0 and D7 edit only their scratch copies under `$L`), every budget, regression ceiling and `ASSUMED_SLOWDOWN`. Simulation files only where a task names them: `combat.gd` and `destination_allocation.gd` (Task 1; `combat.gd` `_approach` also in Task 4, only for the Question 8 fallback), `simulation.gd` (Tasks 1, 2, 4), `skirmish.gd` (Tasks 2, 3). Benchmark scripts only for their timed-window mechanics checks, count lines and count gates (`run_combat.gd` Tasks 1, 6, 7; `run_movement.gd` Tasks 4, 6, 7; `run_team_match.gd` Tasks 6, 7); `run_profile.gd` stays report-only (`docs/development.md:86`), Task 4 adds one print line. `tools/run_team_match.sh`: the pinned line in Task 5, one `TEAM PATHS` grep line in Task 7. Pinned values only in Task 5; the count-gate constants only in Task 7. `.claude/` and the night settings file are the user's: never edit them, at night or in the preparation.

## Night-run preparation (done, checked)

Re-checked 2026-11-14 at the refresh against `~/projects/wargrid-overnight-work/night-settings.json`: `additionalDirectories` holds `~/projects/wargrid-wt-flatter` (the worktree, created by Task 0) and the allow list holds its `Edit(//…/wargrid-wt-flatter/**)` rule, `python3 tools/compare_replays.py`, `python3 -I` for scripts in `$L` and `mkdir -p` under `~/projects/wargrid-overnight-work/flatter-worst-ticks`; `$L` = `~/projects/wargrid-overnight-work/flatter-worst-ticks/logs` exists (empty). For the Deck: `ssh deck@*`, `ssh -o BatchMode=yes deck@*`, `scp * deck@*`, `scp deck@*`, the Deck preflight script, `godot`, `sh tools/export_build.sh` and `git worktree add` are allowed; `git status`, `git diff`, `git log`, `git add`, `git commit` and `git archive` are not named (the handoff's proposed copy adds them, Global Constraints; Tasks D0 and D7 keep the scp fallback). The night file has no `ask` list; the `ask` rules of `~/.claude/settings.json` (`git push`) and the repository's `.claude/settings.json` (`gh pr`, `git merge`, `sh tools/deploy_web.sh`, `fly`, `flyctl`, `sh tools/run_game.sh`) are denied at night, and no task uses them. Task 0 Step 1 still checks the folder rule. The handoff records the user's answers to all 21 Questions ("Decisions this plan relies on") and the Deck address (private).

## Pinned values

Values on `4c21d1a` (unchanged since `74950e5`, where the review measured them); Task 0 reads them on the base tree and records them (a value that already differs is recorded, not a stop; from then on the recorded value is the pin).

| # | Where | Value | Through Task 2 | Task 5 |
|---|---|---|---|---|
| V1 | `game/tests/test_team_match.gd` `FINAL_DIGEST` | `3958ceaab11986af` | unchanged | re-pin (R) |
| V2 | same file `TEAM_CORE_SERIES` | `8513092129969516499` | unchanged | R |
| V3 | `game/tests/test_skirmish_match.gd` `S1_CORE_SERIES`, `TERMINAL_TICK`, `WINNER` | `4004499097874677431`, `8753`, `1` | unchanged | R |
| V4 | same file `CHINA_TERMINAL_TICK`, `CHINA_WINNER`; `FRC_TERMINAL_TICK`, `FRC_WINNER` | `11578`, `2`; `48321`, `1` | unchanged | R, any winner (Questions 11, 20); caps `CHINA_TICK_CAP` 45000, `FRC_TICK_CAP` 50000 and the S1 window (7000 to 17999) never change |
| V5 | `game/tests/test_state_hash.gd` `PINNED` | `01e256834bdd4dfb` | unchanged | R (12 requests on tick 0 of the replay world) |
| V6 | `game/tests/test_view_rows.gd` `EXPECTED_DIGEST` | `7c7fbc8d…48a9e7` | unchanged | R (bots run in its fixture) |
| V7 | `game/tests/test_start_spots.gd` `SS6_PINNED` | unchanged | unchanged | **never changes** (setup only) |
| V8 | the four suite traces | byte-identical to Task 0's `*-before.tsv` | `cmp` silent at Tasks 1, 2 | new reference `*-t5.tsv`; later tasks `cmp` against it |
| V9 | `tools/run_netplay.sh` match terminal tick | `9129` | unchanged (Task 1, 2) | R |
| V10 | `tools/run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | unchanged (Task 2) | R; must still be `won` inside the 45000 cap |
| V12 | `game/tests/test_skirmish_scene.gd` `HUD_TEXTS` (HUD1, `:646`, checked `:676`) | as on the base | unchanged | R (moves with the stagger, measured in the review; stays green with the budget alone) |
| V13 | `game/tests/input_script_rows.gd` `IC1_ROWS` (`:3`, checked `test_skirmish_scene.gd:820`), `IC2_ROWS` (`:27`, checked `test_online_scene.gd:980`) | as on the base | unchanged | in R by the census rule (move orders, and IC1 steps the offline driver's bot once); expected not to move (their rows hold player 1's commands, selection and HUD text from tick 0 to 1, no position or bot output; derived, not measured) |
| V11 | no pinned line changes in tests outside Task 5 | `git diff <Task 4 commit> -- game/tests \| rg '^-\s*const'` empty before Task 5; after it, exactly the Re-pin list's lines | Tasks 1-4 | Task 5 |

Budgets: `docs/reference/performance.md`. The accepted line is `BUDGET EXCEEDED open dense hordes300 (regression ceilings held)` (open and hordes300 user 2026-11-07, dense user 2026-11-14); any other exceeded row or a broken regression ceiling (`run_benchmark.sh` exit 1) is a stop. Never loosen a budget, a ceiling or `ASSUMED_SLOWDOWN`.

Expected values measured by the review on scratch copies of `74950e5`; not re-measured on `4c21d1a`, whose only simulation change rejects builds by passengers and left every pin value in the test files unchanged (`git diff 74950e5..4c21d1a`), so they are expected to hold (tick counts and cell counts, so load does not move them; a different number means the change differs from the review's model, for example a field missing from `bot_state`):

- Movement `queue_drain_ticks` (one leg): today 38 (open and dense); 384 route cells: dense 60 (1.58×; open at 384 not measured, open drained like dense at 256); 256: 81 (2.13×, Question 15 fires).
- Team match per-tick searched cells max: today 102413; 384: 31739; 256: 26805. Max path queue length: today 153; 384: 153; 256: 224. Ticks the budget left requests waiting: 384: 847 of 6319 service ticks.
- Combined outcomes at 384 (stagger plus budget): S1 8626 / winner 1, China 24757 / winner **1** (flips), FRC 37178 / 1, team `won` 38786 / winner 2, `units_peak` 268; netplay match at 384 not run (at 256: 8782).
- X2 (Task 4, not measured, derived from the start cells and the review): 180 requests whose Manhattan route lengths are 155 (seat 1 to seat 4), 214 (seat 4 to seat 8) and 201 (seat 6 to seat 2), so at least about 34200 route cells: drain at 384 about 90 ticks, between 89 (Manhattan sum ÷ 384) and 132 (180 × 280 ÷ 384, 280 being the longest route the review saw on Ashfall); today's 8-request cap drains it in 23. About 3.9× today's group start, beyond Question 15's 2× rule, which was set on the 64 × 64 rows; the X2 check gates the work bound instead (Question 13), and the ratio is a morning item.

## Re-pin list

R = V1-V6, V9, V10, V12, V13, plus every pin Task 0's census adds by rule: a `const` in `game/tests/*.gd` whose name ends in `DIGEST`, `SERIES`, `PINNED`, `TERMINAL_TICK`, `WINNER` or `_ROWS`, or is `HUD_TEXTS`, or a literal pinned in a `tools/*.sh` gate, **and** whose test or script drives a bot (`Skirmish.issue_opponent`, `issue_opponents`, `TeamMatch.step`, `ScriptedHuman`, the headless client's `opponent` behaviour, the skirmish scene's opponent) or moves units through the path service. The census regex also hits `test_dock_lock.gd:29` `COMMAND_ROWS` on `4c21d1a`: a list of command names, not a pinned outcome, so outside R. Measured fallout on `74950e5` (review, full suites): budget alone 26 failures, stagger alone 41, both 59; V5 moves with the budget only, V12 with the stagger only, V1-V4 and V6 with each; V9 and V10 measured only with both (V10 also with the budget alone). Task 0 records the final R; it never grows afterwards. A pin outside R that changes is a stop (Opus diagnosis, park). A pin in R that does not change is recorded, not a stop. The Question 8 fallback in Task 4 (if applied) moves the same R pins and adds none: a pin outside R that it moves is a stop (Task 4 Step 6). Task 7's count-gate constants are ceilings, not pins: never in R, never re-pinned, set once by Task 7's rule.

## Allowed test edits (Tasks 3 and 4)

Behaviour moves in Tasks 3 and 4, so some tests that are not pins go red. Only these edits are allowed; every other red check (a changed count, id, kind, position, tick literal or digest outside R) is a stop: list it, Opus diagnosis, park.

- **T1 (Task 3):** **every** single-shot `Skirmish.issue_opponent(s)` call site in Task 0's census (a call not inside a per-tick loop, including a helper such as `test_skirmish_waves.gd` `_decide` `:32-34`) becomes `Skirmish.decide(sim, player[, attack_tick])` with the same player and attack tick, whether its checks go red or not (Question 3). Converted by census, not by failure: the negative checks `test_skirmish.gd:195` "O1 unaffordable site changes nothing" (call `:194`), `:258` "A3 an eliminated opponent submits nothing" (call `:257`) and `test_factions.gd:248` "B1 a bot with a builder trains none" stay green under the stagger only because the bot no longer runs at all (measured), so without the conversion the AI rule they guard goes untested.
- **T2 (Task 3):** decision-tick arithmetic for the seat under test (`t + Skirmish.DECISION_TICKS - t % Skirmish.DECISION_TICKS`, `(t / 30 + 1) * 30`, `tick % 30 == 0` before a bot call) becomes `Skirmish.next_decision(t, player)` or `Skirmish.decides(t, player)`.
- **T3 (Task 3):** a loop bound that waits for a decision (for example `Skirmish.ATTACK_TICK + Skirmish.WAVE_TIMEOUT - Skirmish.DECISION_TICKS` in `test_skirmish_waves.gd`) adds the seat's offset `player % Skirmish.DECISION_TICKS`.
- **T4 (Task 3, Question 18):** `test_skirmish_scene.gd` `test_skirmish_ready_and_tick` (K2, `:41-58`). Today one `_physics_process` steps tick 0, on which the scene's opponent (seat 2) decides (`offline_driver.gd:32`, `Skirmish.issue_opponent(_recording())` before `sim.step()`); staggered, seat 2 first decides at tick 2, so the check at `:48` goes red (measured on `74950e5`, where it was `:45`) and no other rule covers it (the screen scripts are don't-touch). Before (`:46-51`):

  ```gdscript
  	main._physics_process(0.0)
  	var state: Dictionary = main.driver.sim.snapshot()
  	runner.check(state.tick == 1 and state.buildings.size() == 3 and state.buildings[2].owner == 2 and state.buildings[2].kind == "usa_power_plant", "K2 one physics callback is one tick and the opponent command is due on the pre-step tick")
  	main._process(0.1)
  	main._refresh()
  	runner.check(main.driver.sim.snapshot().tick == 1, "K2 _process and _refresh never step")
  ```

  After:

  ```gdscript
  	main._physics_process(0.0)
  	runner.check(main.driver.sim.snapshot().tick == 1, "K2 one physics callback is one tick")
  	main._process(0.1)
  	main._refresh()
  	runner.check(main.driver.sim.snapshot().tick == 1, "K2 _process and _refresh never step")
  	while main.driver.sim.snapshot().tick <= Skirmish.next_decision(0, 2) and main.driver.sim.snapshot().tick < 40: main._physics_process(0.0)
  	var state: Dictionary = main.driver.sim.snapshot()
  	runner.check(state.tick == Skirmish.next_decision(0, 2) + 1 and state.buildings.size() == 3 and state.buildings[2].owner == 2 and state.buildings[2].kind == "usa_power_plant", "K2 the opponent's first command lands on its seat's decision tick")
  ```

  (`Skirmish` is already preloaded, `:5`; the rest of the case, from the building removal on (`:52`), unchanged.) If the opponent call moves again, Task 0 re-anchors; the rule stays "the opponent's first command lands on its seat's decision tick".
- **P1 (Task 4):** the path-budget checks named in Task 4: G7 and G8 (`test_groups.gd`), A2 (`test_combat_navigation.gd:123`; green before and after, measured, but it pins the dead 8-request rule, so it is rewritten), and the fixed step 38 of `test_snapshot_size_ceiling` (`test_benchmark.gd:103-112`; its red check is BM5 **per-unit**, busiest unit 342 > 336 at step 38 at 256; the total check stays green; both ceilings hold at the drain step at 256: 82112 / 83003 nodes, busiest 330; at 384 not measured). Their ceilings and limits stay.
- **P2 (Task 4, only with the Question 8 fallback):** no edit of an existing test; the fallback adds the new case PB5 only. An existing chase, collector or transport check that goes red under the fallback is a stop (Task 4 Step 6).

## Determinism notes (`docs/reference/determinism-rules.md`)

- **Reservation map is not state.** Lives only inside one `Combat.object_removed` call, never in the snapshot. `Allocation` reads `excluded` only through `has` (`destination_allocation.gd:69`), so the map's insertion order never reaches behaviour; zero counts are erased so `has` equals "count > 0". Exactness needs that nothing else writes a ground unit's position or destination while the map is open: today only `_go_home → _assign_move` and `_stop_unit` run there; the cross-check (RS1, RS3) guards it. A nested `object_removed` inside the loop would clear the outer map: not reachable today (nothing in the loop removes an object).
- **Bot state is not state.** Built per decision, from live dictionaries, entities in id order (as `_snapshot` sorts them), buildings and players through `_sorted_copies`, `last_sequences` sorted by player, so every bot loop sees the order it sees today. Not in the snapshot, not hashed, not on the wire. Copies: the bot reads only, but a later bot edit that writes must not reach the simulation (BS2).
- **Decision tick** depends only on `tick` and the seat number. In netplay each client runs only its own seat's bot, and replays replay commands, not bots, so moving a seat's decision tick changes command ticks, not agreement. Commands keep `tick = state.tick`, which equals `sim.tick()` because the state is built on the decision tick.
- **Path budget.** The per-tick count is a local of `_service_paths` plus a diagnostic counter reset by it; nothing carries over between ticks, so the snapshot's `path_queue` stays the whole path-service state. Route size comes from `AStarGrid2D` (`grid_navigation.gd:108-127`), whose tie-breaks are an existing coupling: equal paths give equal counts on every platform, as today.

## Same-tick and interaction cases

No new command. Every changed rule:

| Rule | Case | Expected | Test |
|---|---|---|---|
| Reservations | a death with 4 ground retaliators, two with the same home cell | each allocation sees the full scan's cells; the second does not get the first's new destination | RS1 |
| | attack-mode units before and after the first retaliator in `_entities` order | their cleared destinations leave the map | RS1 |
| | a retaliator whose home has no free cell (allocation returns null) | status `blocked`, destination kept, map stays exact | RS1 (one home on a blocked cell) |
| | one death sends retaliators home | no per-order full scan | RS2 |
| | deaths inside `fire` in a real fight | map equals the full scan at every batched call | RS3 (hordes300); the hordes300 benchmark fails if no batched call ran in its timed window (Task 1 Step 6) |
| | `_go_home` from `_plan_retaliate` (leash, timeout) | old full-scan path; map closed | RS2 second half |
| Bot state | same tick as a snapshot | every field the bot reads equal; a contained unit and a rebuild hole present | BS1 |
| | bot code writes into the state | simulation unchanged | BS2 |
| Stagger | seats 1, 2, 4, 5, 6, 8 (team match) | seat k issues commands only on ticks with `tick % 30 == k % 30`, the first at tick k | BT1 |
| | a seat without objects | silent | TB2 (existing) |
| | seat wrapper (netplay) and recorder | memory and state from the wrapped simulation | `test_bot_state_survives_seat_wrapper`, RP2 (existing) |
| | two seats with the same `seat % 30` | both decide that tick, each with its own state | structural (no seat ≥ 30 today) |
| | the skirmish screen's opponent (seat 2) | first decides at tick 2; its command lands on step 2 | `"K2 the opponent's first command lands on its seat's decision tick"` (T4) |
| | single-shot bot calls in tests (T1) | `decide` runs the bot ungated, so negative checks ("changes nothing", "submits nothing", "trains none") see a real decision | O1 `test_skirmish.gd:195`, A3 `:258`, B1 `test_factions.gd:248` (converted by census) |
| Path budget | requests served first in, first out until the tick's route cells reach the budget; the crossing one finishes | FIFO kept; waiting units stand still | PB1 (G7 rewritten); the movement benchmark fails if the budget never bound in its timed window (Task 4 Step 4) |
| | one route longer than the budget | served alone; the next request waits one tick | PB2 |
| | a search that finds no route | charges the whole budget; nothing else starts that tick | PB3 |
| | next tick after a capped tick | starts from 0 | PB1 phases |
| | unit re-ordered, stopped or removed while queued | stale entry removed, final appended once | G8 (rewritten), A2 stop (kept), RP2 removal (`test_repath.gd`, kept) |
| | map change mid-move (`replace_blocked_cells`, a building placed or destroyed: `_replace_union`, `simulation.gd:754-783`, called from `construction.gd:111`, `:136`) | the queue is cleared and every moving or pending ground unit re-queued once, in id order (the biggest burst); the budget serves it first in, first out over several ticks; no unit served twice; waiting units stand still | PB4 (new) |
| | collectors, transports and chasers re-queue (`supply_collection.gd:114`, `containers.gd:61`, `combat.gd:140-143`, `:219-229`) behind a group order | appended at the back once (chasers erase first) and served in their turn; behind a 300-unit order they wait up to the group's drain (dense: 38 ticks today, 60 at 384, measured) | G8 (rewritten: the same erase-and-append rule) plus the Question 8 criterion (Task 4 Step 6: max queue length, max wait, re-appends per unit; team match max queue today 153, 384: 153, 256: 224); existing collector, transport and chase tests stay green |
| | a chaser re-requested while it waits, if Task 4 Step 6 applies the fallback | keeps its queue place (Zero Hour's rule) | PB5 (fallback only) |
| | three seats order 60 units each across Ashfall on one tick (X2) | each tick starts no search after its route cells reach the budget; a tick leaves requests waiting only after charging the full budget; drains within ceil(route cells ÷ budget) ticks; every unit searched once and moving | X2 `test_group_order_across_ashfall`; its budget-bound check is the mechanics-run assertion |
| | a unit removed on its order's tick, after the order | never queued, never searched | X2r (`test_ashfall_burst_against_removal_and_map_change`) |
| | a queued unit removed mid-drain | leaves the queue; the rest keep their order | X2r |
| | a moving unit removed and a building destroyed (map change) on the same tick, mid-drain | the queue is every remaining moving or waiting unit, in id order, never a removed one; each searched once; drains within the work bound | X2m (same case) |
| | unreachable allocation | never searched | G7 second half (kept) |
| | air unit | never queued | E8, E9 (kept) |

## Review focus

1. Reservation map exactness: every write to a ground unit's position or destination inside the `object_removed` loop is mirrored; the map is closed after the loop on every path.
2. Bot state completeness: every field `skirmish.gd` reads from the state is in it, with the snapshot's value; order of every list as in the snapshot.
3. Path budget: a started search finishes; the failed-search charge; no carry-over; the counter reset.
4. Test rewrites: no weakened check outside the Allowed test edits; R complete and unchanged after Task 0.
5. Count gates (Task 7): each threshold follows its stated rule from Task 6's numbers, each was red by its mutation, none touches a budget or `STRESS_CEILING`, wall-clock figures stay report-only.

## Risks and model routing

Riskiest first: (1) Task 3 and 4 test fallout larger than the Allowed test edits (park, do not widen; the review measured the fallout on `74950e5`, listed in Task 3 Step 3 and P1); (2) the path budget slowing group starts (movement `queue_drain_ticks`, Task 4 stop rule: 256 trips it at 81 against 38, 384 is expected at 60) or starving re-requested chasers (Question 8 criterion, Task 4 Step 6, with a pre-written fallback); (3) cross-map group starts on Ashfall about 3.9× slower than today (X2, derived; the budget's work bound, not a 2× rule, is what X2 can hold; a morning feel item); (4) an outcome past a match cap after the re-pin (stop, Question 12); (5) the bot state missing a field, which shows only as a pin change in Task 2 (that is why Task 2 runs before the gate moves); (6) a count gate that its mutation does not trip (Task 7 then leaves that figure report-only and says so). (7) the Deck asleep, unreachable or its Firefox run failing (report-only: recorded, native rows only, Firefox a morning item; nothing parks).

| Task | What | Model |
|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins and R census, profile, benchmark, team match, netplay match | Sonnet |
| D0 | Steam Deck rows on the base (start; fetch when done), report-only | Sonnet |
| 1 | Retaliators sent home through one reservation map (RS1-RS3), hordes300 benchmark mechanics check | Sonnet |
| 2 | Bot state, old gate (BS1, BS2), cost probe | Sonnet |
| 3 | Bot seats on their own tick (BT1), test edits T1-T4 | Sonnet |
| 4 | Path budget by route cells (PB1-PB4, X2), movement benchmark mechanics check, queue-place criterion (Question 8) | Sonnet |
| 5 | The one re-pin | Sonnet |
| 6 | Worst ticks after the changes: count lines, five measured runs | Sonnet |
| 7 | Count gates from Task 6's numbers, red by mutation | Sonnet |
| D7 | Steam Deck rows on the branch head (start; fetch and clean up when done), report-only | Sonnet |
| 8 | Docs and package gate (ledger row) | Sonnet |
| 9 | Fresh-context branch review, one fix round, `/ponytail-review` | **Opus (high)** |

Diagnosis of any unexpected red, trace difference or pin change goes to an Opus (high) agent before anything else. Haiku is not used: every task has an anchor or load judgement.

---

### Task 0: Baseline

```text
Task: record the untouched tree's suite, traces, pins, the final Re-pin list, profile zones, benchmark, team match and netplay match.
Owns: the verification file only.
Invariant: no repository file changes.
Boundary: the import is not inside timed runs; load average above 2.5 delays the benchmark.
Red: n/a (measurement).
Green: suite exit 0 with TESTS PASSED; four trace files; PROFILE COMPLETE 10; benchmark exit 0; TEAM MATCH line; NETPLAY PASSED match.
Stop: suite red on the untouched tree; a pin of the table missing from its file.
```

- [ ] **Step 1:** `ls <abs $L>` (the preparation created it, checked at the refresh; missing: park the run with the morning item "create `$L`", no `mkdir` at night); in `~/projects/wargrid`: `git worktree add <abs $W> -b flatter-worst-ticks main`; `rg -n 'wargrid-wt-flatter' <abs path of the night settings>` lists the folder and its Edit rule (present at the refresh; no hit: park the run, morning item "add the `wargrid-wt-flatter` folder and Edit rule to the night settings"). In `$W`: `git status --short` empty, `git log --oneline -1` recorded; `pgrep -fl 'godot|generalszh'` (list others, kill nothing).
- [ ] **Step 2 (import):** `godot --headless --path game --import > $L/t0-import.log 2>&1; echo "exit=$?"`.
- [ ] **Step 3:** `uptime > $L/t0-uptime.txt`; `SUITE(before)`; `uptime >> $L/t0-uptime.txt`. Record CASES, CHECKS, wall seconds, `wc -l $L/*-before.tsv`.
- [ ] **Step 4 (pins and R):** `rg -n '^const [A-Z0-9_]*(DIGEST|SERIES|PINNED|TERMINAL_TICK|WINNER|_ROWS|HUD_TEXTS)\b' game/tests/*.gd`; `rg -n '9129' tools/run_netplay.sh`; `rg -n 'won tick' tools/run_team_match.sh`; `rg -n 'test_hud_summaries_are_pinned|test_skirmish_ready_and_tick|IC1_ROWS|IC2_ROWS' game/tests`. Apply the Re-pin list rule to each hit (read the test body: does it step a simulation with a bot or a move order?) and write the final R into the verification file.
- [ ] **Step 5 (anchors):** by symbol: `combat.gd` `static func object_removed`, `_go_home`, `_plan_retaliate`; `simulation.gd` `PATH_REQUESTS_PER_TICK`, `func _unavailable_cells`, `func _assign_move`, `func _service_paths`, `func _assign_route`, `func _snapshot`, `func _sorted_copies`, `func allocation_calls`; `destination_allocation.gd` `static func assign`; `skirmish.gd` `DECISION_TICKS`, `issue_opponents`, `_decide`, `_bot`; `run_profile.gd` `func _team_match`; `run_combat.gd` `if layout == "hordes300":`, `window_retaliations += sim.retaliations()`; `run_movement.gd` `samples.append(elapsed)`, `print("HEADLESS "`; `test_skirmish_scene.gd` `"K2 one physics callback`, `IC1_ROWS`; `test_online_scene.gd` `IC2_ROWS`; `offline_driver.gd` `Skirmish.issue_opponent(_recording())`; `test_skirmish_waves.gd` `func _decide`; `test_groups.gd` `test_path_budget`, `test_queued_retarget`, `_twenty`; `test_combat_navigation.gd` `"A2 at most 8`; `test_benchmark.gd` `range(38)`; for Tasks 4, 6 and 7: `combat.gd` `static func _approach`, `const REPATH_TICKS`; `map_data.gd` `static func start_cell`, `static func slot`; `combat_workload.gd` `static func _building`; `simulation.gd` `func _replace_union`, `func replace_blocked_cells`; `run_team_match.gd` `func _play`; `tools/run_team_match.sh` `^grep -Eq '\^TEAM MATCH`; `run_combat.gd` `const STRESS_CEILING`; callers `rg -n 'issue_opponents?\(' game` (record the count and every file). Record drift.
- [ ] **Step 6 (profile before):** `sh tools/run_profile.sh > $L/t0-profile.log 2>&1` (background if long). Record from `PROFILE` lines: `team_match` `step` mean / max, `opponent.decide` max and calls per tick, `snapshot` mean / max, `step.service_paths` max, `route` max; `combat_hordes300` `step.combat_fire` max, `assign_move.unavailable` max, `allocation.assign` max, `step` max; the `PROFILE_SLOW team_match` top lines. From the same `PROFILE` lines, record calls and mean zone time of `combat.splash_index` per workload size, and whether calls or per-call cost grow ("Added after planning"; evidence only, no fix).
- [ ] **Step 7 (benchmark before, alone):** `uptime`; if the 1-minute load is above 2.5, wait with a Monitor until-loop on `uptime` (at most 15 minutes). `sh tools/run_benchmark.sh > $L/t0-bench.log 2>&1` (on the branch it does not record). Record `WORST TICK` lines, combat p95 / p99 per row, the movement `HEADLESS` lines' `queue_peak` and `queue_drain_ticks` for open and dense (Task 7's drain ceiling is twice these), and the hordes300 `allocation_calls` max from its `COMBAT hordes300` line (before the fix every allocation is a full scan; Task 7's mutation check compares against it).
- [ ] **Step 8:** `sh tools/run_team_match.sh > $L/t0-team.log 2>&1`; `NETPLAY_OUT=$L/t0-netplay sh tools/run_netplay.sh match > $L/t0-netplay.log 2>&1`. Record both lines, plus from `t0-team.log` the `TEAM TIMING` max and the `team_match` profile lines' `opponent.decide`, `step.service_paths` and `step` max (wall-clock baseline for Task 6; one run, so no variance).
- [ ] **Step 9:** fill the verification file's Baseline section; Task 0 GREEN.

---

### Task D0: Steam Deck rows on the base (report-only)

```text
Task: start three runs each of the Deck native headless profile and combat rows and of the Deck Firefox 160 Web Bench on the base tree; fetch and tabulate them when the Deck job ends.
Owns: files under $L/deck/ only (scratch worktree, archive, job script, export, fetched logs), the verification file "Deck rows".
Invariant: no repository file changes; nothing on the Deck outside ~/wargrid-flatter and the run's own Firefox profiles and systemd units.
Boundary: the Mac export runs alone (no Mac benchmark, profile or other export at the same time); the Deck job overlaps Tasks 1 onwards.
Red: n/a (measurement).
Green: STARTED (unit wargrid-flatter-base running) or SKIPPED with the reason; later FETCHED with the table filled.
Stop: none. Every failure is recorded and becomes a morning item; it never parks a task (user, 2026-11-14).
```

Runs after Task 0 is GREEN and before Task 1 is dispatched (so the export runs alone). Rows (user, 2026-11-14 evening, decided): the native rows of 2026-11-14 (`docs/reference/performance.md:137`, `run_profile.gd` hand-off sums; and the combat p95 / p99 of the Sim quick wins Deck rerun, `~/projects/wargrid-overnight-work/sim-quick-wins/deck-rerun.md`), and the Firefox row (`performance.md:138`: team match to its end tick, combat open, dense, hordes300). The earlier Firefox rows ran Firefox 159; the Deck now has 160.0 (probed 2026-11-14), so this run is the like-for-like baseline for Task D7. Method as `deck-rerun.md`: Godot 4.7.2 Linux through `tools/install_godot.py` against the CI SHA-256 (`.github/workflows/ci.yml:34`), everything in `~/wargrid-flatter` on the Deck with the XDG folders redirected into it, one `systemd-run --user` unit under `systemd-inhibit --what=sleep:idle`, ACAD and load at every job edge, the folder removed after Task D7. Probed 2026-11-14 (read-only): Desktop Mode (`plasmashell`), ACAD 1, the user manager's environment carries `DISPLAY=:0` and `WAYLAND_DISPLAY=wayland-0`, so a `systemd-run --user` unit can open Firefox on the Deck screen (as `deck.sh` did for the 2026-11-10 and 2026-11-14 rows); `systemd-inhibit`, `kde-inhibit`, `python3` and `curl` are present.

- [ ] **Step 1 (preflight):** `sh <abs ~/projects/wargrid-native-work>/deck-preflight.sh <deck>`. `RESULT: FAIL`: record the failing lines, Task D0 SKIPPED (morning item "Deck rows on the base not run: <reason>"), dispatch Task 1. Then `ssh -o BatchMode=yes deck@<deck> systemctl --user list-units --all --no-legend 'wargrid-flatter*'` prints nothing and `ssh -o BatchMode=yes deck@<deck> ls wargrid-flatter` fails (no leftover of an earlier run; if one exists, record it, SKIPPED, morning item).
- [ ] **Step 2 (trees, Mac):** `mkdir -p <abs $L>/deck`; `cd <abs ~/projects/wargrid> && git worktree add --detach <abs $L>/deck/web-tree-base 4c21d1a`; `cd <abs ~/projects/wargrid> && git archive --format=tar -o <abs $L>/deck/base.tar 4c21d1a`. If `git archive` is refused: record the exact command for the morning list and use the fallback in Step 4.
- [ ] **Step 3 (job script):** write `<abs $L>/deck/deck-job.sh` with the Write tool, exactly:

  ```sh
  #!/bin/sh
  # Runs on the Deck in one systemd-run --user unit under systemd-inhibit: sh wargrid-flatter/deck-job.sh <base|after>
  tree=$1
  B=$HOME/wargrid-flatter
  L=$B/logs-$tree
  G=$B/godot/Godot_v4.7.2-stable_linux.x86_64
  FF=$HOME/.var/app/org.mozilla.firefox
  PORT=8062
  export XDG_DATA_HOME=$B/xdg/data XDG_CONFIG_HOME=$B/xdg/config XDG_CACHE_HOME=$B/xdg/cache
  mkdir -p "$L" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
  edge() { echo "$1 $(date +%H:%M:%S) acad=$(cat /sys/class/power_supply/ACAD/online) load=$(cut -d' ' -f1-3 /proc/loadavg)" >>"$L/edges.txt"; }
  job() { # NAME ARGS...
  	name=$1; shift
  	edge "start $name"
  	"$G" --headless --path "$B/$tree/game" "$@" >"$L/$name.log" 2>&1
  	echo "exit=$?" >>"$L/$name.log"
  	edge "end $name"
  	sleep 20
  }
  web() { # N: one Firefox run on a fresh profile; fails unless the result is complete and cross-origin isolated
  	profile=$FF/wargrid-flatter-profile-$tree-$1
  	out=$L/web-$1
  	mkdir -p "$profile" "$out"
  	{
  		echo 'user_pref("browser.aboutwelcome.enabled", false);'
  		echo 'user_pref("browser.shell.checkDefaultBrowser", false);'
  		echo 'user_pref("browser.startup.homepage_override.mstone", "ignore");'
  		echo 'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);'
  		echo 'user_pref("termsofuse.acceptedVersion", 4);'
  		grep -h termsofuse "$FF"/config/mozilla/firefox/*/prefs.js "$FF"/.mozilla/firefox/*/prefs.js 2>/dev/null
  	} >"$profile/user.js"
  	edge "start web-$1"
  	systemd-run --user --quiet --collect --unit="wargrid-flatter-srv-$tree-$1" python3 -I "$B/$tree/tools/serve_web_bench.py" "$B/web-$tree" "$out" "$PORT"
  	n=0; until curl -s -o /dev/null "http://127.0.0.1:$PORT/index.html"; do n=$((n+1)); [ $n -gt 50 ] && break; sleep 0.2; done
  	systemd-run --user --quiet --collect --unit="wargrid-flatter-ff-$tree-$1" kde-inhibit --power --screenSaver flatpak run org.mozilla.firefox -no-remote -new-instance -profile "$profile" "http://127.0.0.1:$PORT/index.html"
  	t=0; until grep -qs 'BENCH DONE' "$out"/web-*.log || [ $t -ge 1500 ]; do sleep 5; t=$((t+5)); done
  	edge "end web-$1"
  	systemctl --user stop "wargrid-flatter-ff-$tree-$1" "wargrid-flatter-srv-$tree-$1"
  	pkill -f -- "$profile"
  	rm -rf "$profile"
  	sleep 20
  	grep -qs 'BENCH DONE' "$out"/web-*.log && grep -qs 'cross_origin_isolated=true' "$out"/web-*.log
  }
  if [ ! -x "$G" ]; then
  	edge "start install"
  	RUNNER_TEMP=$B GITHUB_ENV=$B/godot-env GODOT_VERSION=4.7.2-stable GODOT_ZIP=Godot_v4.7.2-stable_linux.x86_64.zip GODOT_SHA256=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4 GODOT_EXECUTABLE=Godot_v4.7.2-stable_linux.x86_64 python3 -I "$B/$tree/tools/install_godot.py" >"$L/install.log" 2>&1 || { edge "INSTALL FAILED"; echo DONE >>"$L/edges.txt"; exit 1; }
  	edge "end install"
  fi
  job import --import
  for i in 1 2 3; do job "profile-$i" --script res://benchmarks/run_profile.gd; done
  for i in 1 2 3; do job "combat-$i" --script res://benchmarks/run_combat.gd; done
  if [ -f "$B/web-$tree/index.html" ]; then
  	for i in 1 2 3; do web "$i" || { edge "WEB FAILED run $i"; break; }; done
  else
  	edge "WEB SKIPPED (no export)"
  fi
  echo DONE >>"$L/edges.txt"
  ```

  (`install_godot.py` exits non-zero on a checksum mismatch; the SHA-256 is the CI Linux one, check `rg -n cadd3204 .github/workflows/ci.yml` before writing. `serve_web_bench.py` sends the cross-origin isolation headers and writes each POSTed result as `web-<time>.log` into its results folder; `bench_runner.gd` prints `cross_origin_isolated=<value>` in its first line and posts after `BENCH DONE`. The `termsofuse` default line comes first so a value read from the Deck's own profile, which `deck.sh` found under `config/mozilla/firefox`, overrides it; version 4 is what the 2026-11-08 runs seeded, `perf-spike-verification.md:701`.)
- [ ] **Step 4 (push the tree):** `ssh -o BatchMode=yes deck@<deck> mkdir -p wargrid-flatter/base`; `scp <abs $L>/deck/base.tar <abs $L>/deck/deck-job.sh deck@<deck>:wargrid-flatter/`; `ssh -o BatchMode=yes deck@<deck> tar -xf wargrid-flatter/base.tar -C wargrid-flatter/base`. Fallback without `base.tar`: `scp <abs $L>/deck/deck-job.sh deck@<deck>:wargrid-flatter/` and `scp -r <abs $L>/deck/web-tree-base/game <abs $L>/deck/web-tree-base/tools deck@<deck>:wargrid-flatter/base/`, before Step 5 edits or imports that tree. Check: `ssh -o BatchMode=yes deck@<deck> ls wargrid-flatter/base/game/project.godot wargrid-flatter/base/tools/install_godot.py`.
- [ ] **Step 5 (Web Bench export, Mac, alone):** in `<abs $L>/deck/web-tree-base/game/benchmarks/bench_runner.gd` (scratch copy only; never in `$W`), Edit `for layout: String in ["open", "dense", "contact", "skirmish3v3"]: await _combat(layout)` (`:29`) to `for layout: String in ["open", "dense", "contact", "skirmish3v3", "hordes300"]: await _combat(layout)`. Then `cd <abs $L>/deck/web-tree-base && godot --headless --path <abs $L>/deck/web-tree-base/game --import > <abs $L>/deck/web-base-import.log 2>&1; echo "exit=$?"` and `cd <abs $L>/deck/web-tree-base && sh tools/export_build.sh "Web Bench" <abs $L>/deck/web-base/index.html > <abs $L>/deck/web-base-export.log 2>&1; echo "exit=$?"` (the `Web Bench` preset is single-threaded, `game/export_presets.cfg:147-166`; templates 4.7.2.stable are installed on the Mac). Green: both exit 0, `ls <abs $L>/deck/web-base` shows `index.html`, `index.wasm` and `index.pck`. Then `scp -r <abs $L>/deck/web-base deck@<deck>:wargrid-flatter/web-base`. Export or copy failed: record it and go on without it (the job then logs `WEB SKIPPED`; Firefox becomes a morning item, native rows only; user, 2026-11-14).
- [ ] **Step 6 (start):** `ssh -o BatchMode=yes deck@<deck> systemd-run --user --collect --same-dir --unit=wargrid-flatter-base systemd-inhibit --what=sleep:idle --who=wargrid --why=benchmark sh wargrid-flatter/deck-job.sh base`; then `ssh -o BatchMode=yes deck@<deck> systemctl --user is-active wargrid-flatter-base` prints `active`. Return `STARTED`; the coordinator dispatches Task 1.
- [ ] **Step 7 (wait, coordinator, never blocking):** after each later task's GREEN or BLOCKED, the coordinator runs `ssh -o BatchMode=yes deck@<deck> tail -n 1 wargrid-flatter/logs-base/edges.txt` (one line, no log reading). When it prints `DONE`, it dispatches the fetch (Step 8) as a short Sonnet task between two main tasks. Expected length: three profiles, three combat runs and three Firefox runs of about 8 minutes each, a few hours in all (Deck profile length not measured).
- [ ] **Step 8 (fetch and tabulate):** `scp -r deck@<deck>:wargrid-flatter/logs-base <abs $L>/deck/logs-base`; read `<abs ~/projects/wargrid-overnight-work/sim-quick-wins/budget-logs/extract.py>` and write it as `<abs $L>/deck/extract.py` with the Write tool. Into the verification file "Deck rows", per row the median of 3 [range]:
  - edges: `<abs $L>/deck/logs-base/edges.txt` (ACAD at every edge, load range, any `FAILED` or `SKIPPED` line);
  - native profile: each `profile-<n>.log` ends with `PROFILE COMPLETE 10` and `exit=0`; the hand-off sum per tick per workload (the means of `view_state`, `view.copy`, `view.sort`, `view.batch`, `rg -n 'view_state|view\.copy|view\.sort|view\.batch' <abs $L>/deck/logs-base/profile-1.log` and likewise for 2 and 3), method of `performance.md:137`;
  - native combat: `python3 -I <abs $L>/deck/extract.py <abs $L>/deck/logs-base/combat-1.log <abs $L>/deck/logs-base/combat-2.log <abs $L>/deck/logs-base/combat-3.log > <abs $L>/deck/base-combat.txt 2>&1` (p95 median [range], p99, max per layout); each log has ten `COMBAT <layout> tick_ms=` lines; `exit=1` is expected (the Deck breaks the Mac-derived regression ceilings, `deck-rerun.md`), so judge by the ten lines;
  - Firefox: per `web-<n>`, the result file shows `cross_origin_isolated=true`, `BENCH DONE` and the Firefox version in its `UA` line; `python3 -I <abs $L>/deck/extract.py <abs $L>/deck/logs-base/web-1/*.log <abs $L>/deck/logs-base/web-2/*.log <abs $L>/deck/logs-base/web-3/*.log > <abs $L>/deck/base-web.txt 2>&1` (combat and `TEAM TIMING` p95 [range], p99, max); p50 per row and the `TEAM MATCH` line read from the result files. A missing or non-isolated run is recorded as such, never replaced.
  Leave `~/wargrid-flatter` on the Deck for Task D7 (the Godot install is reused). Return `FETCHED` with the row count.

---

### Task 1: Retaliators sent home through one reservation map

```text
Task: one death with retaliators builds one cell map; every _go_home inside that Combat.object_removed call allocates against it instead of a full entity scan.
Owns: game/scripts/simulation/combat.gd (object_removed), game/scripts/simulation/simulation.gd (vars, _begin_reservations, _end_reservations, _reserve, _cross_check, _assign_move, reserved_allocations, step's counter reset), game/scripts/simulation/destination_allocation.gd (assign, assign_excluding), game/tests/test_combat.gd (RS1-RS3), game/tests/run_tests.gd (CASE_SECONDS entry only), game/benchmarks/run_combat.gd (hordes300 timed-window check), docs/reference/sim-interface.md (diagnostic counter list).
Invariant: V1-V12 and V8 byte-identical; non-batched _go_home callers (_plan_retaliate) keep the full scan.
Boundary: the same-tick table's Reservations rows.
Red: RS1-RS3 written against stub vars (counters stay 0, so named checks fail); the combat benchmark's hordes300 check red with Step 5 reverted.
Green: WARGRID_TEST_ONLY=test_combat; full suite; traces cmp silent; combat benchmark script exit 0 with COMBAT BENCHMARK PASSED 10; PROFILE COMPLETE 10 (report only).
Stop: any trace, digest or core series differs.
```

- [ ] **Step 1 (stub):** `simulation.gd`, after `var _allocation_calls: int = 0` (`:46`):

  ```gdscript
  # Cell -> ground positions plus destinations there; open only while Combat.object_removed sends retaliators home.
  var _reserved: Dictionary = {}
  var _reserving: bool = false
  # Tests only: the check pays the full scan the map saves.
  var _check_reservations: bool = false
  var _reservation_checks: int = 0
  var _reservation_mismatches: int = 0
  var _reservation_opens: int = 0
  var _reserved_allocations: int = 0
  ```

  Diagnostic counter like `allocation_calls()`: `func reserved_allocations() -> int: return _reserved_allocations` next to `allocation_calls()` (`:505`), and `_reserved_allocations = 0` next to `_allocation_calls = 0` in `step` (`:517`).
- [ ] **Step 2 (tests, `test_combat.gd`, add to `cases()`):**
  - **RS1 `test_retaliators_home_against_full_scan_cells`:** `Fixture.world()` (32 × 32), `add_player(1, 0)`, `add_player(2, 0)`; enemy E = `usa_tank` of player 2 at (20.5, 10.5); player 1, spawned after E in this order: an attack-mode `usa_tank` A1 (lowest player 1 id; `combat.mode = "attack"`, `combat.target_id = E`, `destination = [18.5, 10.5]`, `status = "moving"`), then four `usa_tank` retaliators at (10.5, 10.5) … (13.5, 10.5) (`combat.mode = "retaliate"`, `target_id = E`, `goal`: two at `[5.5, 5.5]`, one at `[8.5, 5.5]`, one whose goal `[3.5, 5.5]` lies in a one-cell pocket: before the spawns `sim.replace_blocked_cells(...)` with the eight cells around `Vector2i(3, 5)`, so the allocation finds no cell in the unit's component), then a second attack-mode tank A2 (highest id, same fields as A1 with destination `[18.5, 12.5]`). `sim._check_reservations = true`; `sim.remove_object(E)`. Checks: `"RS1 each retaliator sent home allocates against the full scan's cells (%d checks, %d mismatches)"` with checks == 4 and mismatches == 0; the two `[5.5, 5.5]` retaliators have different destination cells; the pocket-home one has status `blocked`; A1 and A2 idle with `destination == null`; `sim._reservation_opens == 1` (`"RS1 one death opens the map once"`); `sim._reserving == false and sim._reserved.is_empty()` (`"RS1 the map is closed after the removal"`).
  - **RS2 `test_one_death_skips_per_order_scans`:** same world without A1, A2. `Profiler.reset()`, `Profiler.enabled = true`; `remove_object(E)`; `Profiler.calls(&"assign_move.unavailable") == 0 and Profiler.calls(&"allocation.reserved") == 4` (`"RS2 retaliators sent home by one death skip the per-order full scan"`). Second half: a fresh world with one retaliator whose `combat.until = sim.tick()` and a live E far away; `Profiler.reset()`; one `step()`; `Profiler.calls(&"allocation.reserved") == 0 and Profiler.calls(&"assign_move.unavailable") >= 1` (`"RS2 a retaliator sent home by its timer keeps the full scan"`). Profiler off and reset at the end.
  - **RS3 `test_hordes300_home_allocations_match_full_scan`:** `const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")` if absent; `var sim = CombatWorkload.create("hordes300")`; `sim._check_reservations = true`; step 800 ticks (the note's spike is at tick 776). `"RS3 over 800 hordes300 ticks every batched home allocation matches the full scan (%d checks, %d mismatches)"`: checks ≥ 20, mismatches 0. Time it; add `"test_hordes300_home_allocations_match_full_scan": <seconds>` to `CASE_SECONDS` in `game/tests/run_tests.gd` if over 1 s.
  Run `WARGRID_TEST_ONLY=test_combat sh tools/run_tests.sh > $L/t1-red.log 2>&1`: RS1, RS2 first half and RS3 fail by name (checks 0; opens 0; `allocation.reserved` 0). Record.
- [ ] **Step 3 (`destination_allocation.gd`):** before (`:5-22`, excerpt):

  ```gdscript
  static func assign(navigation: RefCounted, units: Array[Dictionary], target: Vector2, unavailable: Array[Vector2i]) -> Dictionary:
  	var ordered: Array[Dictionary] = units.duplicate()
  	…
  	var component: int = navigation.component_at(target)
  	if component < 0:
  		return goals
  	var excluded: Dictionary = {}
  	for cell in unavailable:
  		excluded[cell] = true
  	var target_cell := Vector2i(target.floor())
  ```

  After:

  ```gdscript
  static func assign(navigation: RefCounted, units: Array[Dictionary], target: Vector2, unavailable: Array[Vector2i]) -> Dictionary:
  	var excluded: Dictionary = {}
  	for cell in unavailable:
  		excluded[cell] = true
  	return assign_excluding(navigation, units, target, excluded)

  # Reads `excluded` only through `has`, so a cell -> count map works while zero counts are erased.
  static func assign_excluding(navigation: RefCounted, units: Array[Dictionary], target: Vector2, excluded: Dictionary) -> Dictionary:
  	var ordered: Array[Dictionary] = units.duplicate()
  	…
  	var component: int = navigation.component_at(target)
  	if component < 0:
  		return goals
  	var target_cell := Vector2i(target.floor())
  ```
- [ ] **Step 4 (`simulation.gd`):** after `_unavailable_cells` (`:323-336`) add:

  ```gdscript
  func _begin_reservations() -> void:
  	_reservation_opens += 1
  	_reserved = {}
  	for unit: Dictionary in _entities.values():
  		_reserve(unit, "position", 1)
  		_reserve(unit, "destination", 1)
  	_reserving = true

  func _end_reservations() -> void:
  	_reserving = false
  	_reserved = {}

  func _reserve(unit: Dictionary, key: String, delta: int) -> void:
  	if Registry.air_kinds.has(unit.kind) or unit.has("container_id") or unit[key] == null: return
  	var cell := _cell(unit[key])
  	var count: int = _reserved.get(cell, 0) + delta
  	if count == 0: _reserved.erase(cell)
  	else: _reserved[cell] = count

  func _cross_check(ground: Array[Dictionary]) -> void:
  	var cells: Array[Vector2i] = _unavailable_cells(ground)
  	_reservation_checks += 1
  	if cells.size() != _reserved.size() or not cells.all(func(cell: Vector2i) -> bool: return _reserved.has(cell)): _reservation_mismatches += 1
  ```

  `_assign_move` (`:423-451`), the six lines from `_allocation_calls += 1` to `Profiler.end(&"allocation.assign", zone)` become:

  ```gdscript
  	_allocation_calls += 1
  	var goals: Dictionary
  	if _reserving:
  		_reserved_allocations += 1
  		var zone: int = Profiler.begin()
  		for unit in ground: _reserve(unit, "position", -1)
  		if _check_reservations: _cross_check(ground)
  		goals = Allocation.assign_excluding(_navigation, ground, point, _reserved)
  		for unit in ground:
  			_reserve(unit, "position", 1)
  			_reserve(unit, "destination", -1)
  		Profiler.end(&"allocation.reserved", zone)
  	else:
  		var zone: int = Profiler.begin()
  		var unavailable: Array[Vector2i] = _unavailable_cells(ground)
  		Profiler.end(&"assign_move.unavailable", zone)
  		zone = Profiler.begin()
  		goals = Allocation.assign(_navigation, ground, point, unavailable)
  		Profiler.end(&"allocation.assign", zone)
  ```

  and after the existing `for unit in members:` loop (end of the function) add:

  ```gdscript
  	if _reserving:
  		for unit in ground: _reserve(unit, "destination", 1)
  ```

  The members loop itself is unchanged (a `blocked` unit keeps its old destination, so its −1 and +1 cancel).
- [ ] **Step 5 (`combat.gd` `object_removed`, `:612-622`):** before:

  ```gdscript
  		if unit.combat.mode == "retaliate":
  			_go_home(sim, unit)
  		if unit.combat.mode == "attack":
  			unit.combat.mode = "guard"
  			sim._stop_unit(unit)
  ```

  After:

  ```gdscript
  		if unit.combat.mode == "retaliate":
  			if not sim._reserving: sim._begin_reservations()
  			_go_home(sim, unit)
  		if unit.combat.mode == "attack":
  			unit.combat.mode = "guard"
  			if sim._reserving: sim._reserve(unit, "destination", -1)
  			sim._stop_unit(unit)
  	sim._end_reservations()
  ```

  `sim._end_reservations()` sits at one tab, after the `for unit` loop (inside the loop every retaliator would open its own map; RS1's "opens the map once" check catches that).
- [ ] **Step 6 (benchmark mechanics check, `run_combat.gd` `_measure`; the profile stays report-only, Question 19):** next to `var ramp_shots: int = 0` add `var window_reserved: int = 0`; in the timed `else:` branch, after `window_retaliations += sim.retaliations()`, add `window_reserved += sim.reserved_allocations()`. The hordes300 block, before:

  ```gdscript
  	if layout == "hordes300":
  		print("COMBAT ", layout.to_upper(), " checks_window=", horde_checks, " level2_peak_window=", horde_peak)
  		if not _stress_ok(layout, summary):
  			return false
  		if horde_checks == 0 or horde_peak == 0:
  			push_error("Combat benchmark: no horde checks or no horde of five inside the timed window")
  			return false
  		return true
  ```

  After:

  ```gdscript
  	if layout == "hordes300":
  		print("COMBAT ", layout.to_upper(), " checks_window=", horde_checks, " level2_peak_window=", horde_peak, " reserved_window=", window_reserved)
  		if not _stress_ok(layout, summary):
  			return false
  		if horde_checks == 0 or horde_peak == 0:
  			push_error("Combat benchmark: no horde checks or no horde of five inside the timed window")
  			return false
  		if window_reserved == 0:
  			push_error("Combat benchmark: no retaliator was sent home through the reservation map inside the timed window")
  			return false
  		return true
  ```

  (`tools/perf_record.py` reads only `COMBAT <lowercase layout> tick_ms=`, `:39`, so the uppercase line's new field is not parsed; `tools/test_perf_charts.py:26` keeps its old fixture line.) Expected `reserved_window` > 0: the hordes300 note's spike is at tick 776, inside the 300-2100 window; not measured. Red first: with Step 5 reverted (scratch), `godot --headless --path game --script res://benchmarks/run_combat.gd > $L/t1-combat-red.log 2>&1; echo "exit=$?"`: exit 1 and `rg -n 'reservation map inside the timed window' $L/t1-combat-red.log` hits (judge by that line: a host-load ceiling failure is not this check; `_run` measures hordes300 even after another row fails, `run_combat.gd:14-36`, but the hordes300 block checks its own stress ceiling first, so if that ceiling failed and the line is missing, rerun once when the load is below 2.5, else record "red not shown" as a morning item); restore Step 5.
- [ ] **Step 7 (red by mutation, scratch, revert each):** (a) drop `if sim._reserving: sim._reserve(unit, "destination", -1)` in `object_removed`: RS1 mismatches > 0 (A2 follows the first retaliator); (b) drop the trailing destination `+1` loop in `_assign_move`: RS1 or RS3 mismatches > 0; (c) drop `sim._end_reservations()`: RS1 "map is closed" fails; (d) indent `sim._end_reservations()` one tab, into the `for unit` loop: `"RS1 one death opens the map once"` fails. `git diff --stat` after the reverts shows only the Owns paths.
- [ ] **Step 8:** `WARGRID_TEST_ONLY=test_combat` green; `SUITE(t1)`, `cmp` each against `*-before.tsv` silent; static gates; `godot --headless --path game --script res://benchmarks/run_combat.gd > $L/t1-combat.log 2>&1` (exit 0, `COMBAT BENCHMARK PASSED 10`, record `reserved_window`; under host load a stress-ceiling failure is rerun once when the load is below 2.5, then reported); `sh tools/run_profile.sh > $L/t1-profile.log 2>&1` (PROFILE COMPLETE 10). `docs/reference/sim-interface.md` "Not interface", diagnostic counters: add `reserved_allocations` (allocations the last step served from the reservation map). Record `combat_hordes300` `step.combat_fire` max, `allocation.reserved` max and calls, `assign_move.unavailable` max, `step` max against Task 0 (note: 5.40 → 1.07 ms `combat_fire` max on the probe). Scratch digest check: read `~/projects/wargrid-overnight-work/tighter-gates/logs/cf-digest.gd` and write it as `$L/t1-digest.gd` with the Write tool (no `cp`), run it on `main` (`~/projects/wargrid`) and on `$W`, `diff` the `DIGEST` lines: identical (105 lines; the script prints no `DONE` marker, so 105 `DIGEST` lines in each log stand in for it).

---

### Task 2: Bot state, old gate

```text
Task: the bot reads Simulation.bot_state(), built per seat, instead of one shared snapshot(); still every 30th tick.
Owns: game/scripts/simulation/simulation.gd (_sequence_rows, bot_state, _snapshot one key), game/scripts/simulation/skirmish.gd (issue_opponents, _real, _bot), game/tests/test_skirmish.gd (BS1, BS2), docs/reference/sim-interface.md (one line).
Invariant: V1-V12 and V8 byte-identical (the strongest equivalence check: every bot match pin unchanged).
Boundary: Bot state rows of the same-tick table.
Red: BS1 and BS2 fail by name against a stub bot_state() that returns {} .
Green: WARGRID_TEST_ONLY=test_skirmish; full suite; traces cmp silent; team match and netplay match lines unchanged.
Stop: any pin or trace differs (a field is missing: Opus diagnosis, park); the cost probe fails its gate (park Tasks 3-9, Question 2).
```

- [ ] **Step 1 (field census):** `rg -n 'state\.|unit\.|building\.|entry\.|enemy\.|mine\[' game/scripts/simulation/skirmish.gd` plus the helpers it calls (`Combat.distance_squared`, `Combat.masked`, `Registry.*`). Record every state field read. Expected on `74950e5`: `tick`, `last_sequences[].player/sequence`, `players[].id/credits/team/faction`, `buildings[]` (whole copies), `entities[].id/owner/kind/position/combat.mode/combat.target_id` and `has("hole_id")`, `has("container_id")`, `has("origin")` (absent on entities in both, so equal; the review checked this census on `74950e5` and found nothing missing). Any other entity field: add it to the rows in Step 3 and record.
- [ ] **Step 2 (stub and tests):** stub `func bot_state() -> Dictionary: return {}` in `simulation.gd`. `test_skirmish.gd`, add to `cases()`:
  - **BS1 `test_bot_state_carries_what_the_bot_reads`:** (a) `TeamMatch.create()` (`const TeamMatch = preload("res://scripts/debug/team_match.gd")`), `TeamMatch.step` to tick 1500, comparing every 150 ticks; (b) the world of `test_bot_ignores_contained_units` (`:381`) at its check tick (a contained unit); (c) the world of `test_bot_leaves_rebuild_alone` (`:110`) once a hole exists (a unit or building with `hole_id`). Per comparison `var b = sim.bot_state()`, `var s = sim.snapshot()`: `b.tick == s.tick`, `b.last_sequences == s.last_sequences`, `b.buildings == s.buildings`; per player row the keys `id`, `credits`, `team` and `get("faction")` equal; `b.entities.size() == s.entities.size()` and per index: keys ⊆ {`id`, `owner`, `kind`, `position`, `combat`, `hole_id`, `container_id`}, the four scalar fields equal, `combat == null` iff the snapshot's is, else `mode` and `target_id` equal, `hole_id` and `container_id` present iff present and equal. One check per world: `"BS1 the bot state carries every field the bot reads, equal to the snapshot (%s, %d comparisons)"`; plus `"BS1 a contained row and a hole row were compared"`.
  - **BS2 `test_bot_state_is_a_copy`:** a `Skirmish.create()` world after 300 ticks with bots; `var before = sim.snapshot()`; take `bot_state()`, write `entities[0].position[0] += 1.0`, the first combat row's `mode = "x"`, `buildings[0].hp -= 1`, `players[0].credits += 1`; `sim.snapshot() == before` (`"BS2 changing the bot state changes nothing in the simulation"`). On the stub it fails by name (guard `b.has("entities")` first).
  Run `WARGRID_TEST_ONLY=test_bot_state` against the stub: named failures. Record.
- [ ] **Step 3 (`simulation.gd`):** in `_snapshot` (`:716-720`) the `sequences` loop moves into

  ```gdscript
  func _sequence_rows() -> Array:
  	var sequences: Array = []
  	var players: Array = _last_sequences.keys()
  	players.sort()
  	for player: Variant in players:
  		sequences.append({"player": player, "sequence": _last_sequences[player]})
  	return sequences
  ```

  and `_snapshot` uses `"last_sequences": _sequence_rows()` (value unchanged). Replace the stub:

  ```gdscript
  # Only what the bots read: a full snapshot per staggered seat would add about 0.1 ms to the mean tick (simulation review §5.8).
  func bot_state() -> Dictionary:
  	var zone: int = Profiler.begin()
  	var ids: Array = _entities.keys()
  	ids.sort()
  	var entities: Array = []
  	for id: Variant in ids:
  		var unit: Dictionary = _entities[id]
  		var row := {"id": unit.id, "owner": unit.owner, "kind": unit.kind, "position": unit.position.duplicate(), "combat": null}
  		if unit.combat != null: row.combat = {"mode": unit.combat.mode, "target_id": unit.combat.target_id}
  		if unit.has("hole_id"): row.hole_id = unit.hole_id
  		if unit.has("container_id"): row.container_id = unit.container_id
  		entities.append(row)
  	var result := {"tick": _tick, "entities": entities, "buildings": _sorted_copies(_buildings), "players": _sorted_copies(_players), "last_sequences": _sequence_rows()}
  	Profiler.end(&"bot_state", zone)
  	return result
  ```
- [ ] **Step 4 (`skirmish.gd`):** before (`:67-72`):

  ```gdscript
  static func issue_opponents(sim: RefCounted, players: Array[int], attack_tick: int = ATTACK_TICK) -> void:
  	if sim.tick() % DECISION_TICKS != 0: return
  	var zone: int = Profiler.begin()
  	var state: Dictionary = sim.snapshot()
  	for player in players: _decide(sim, player, attack_tick, state)
  	Profiler.end(&"opponent.decide", zone)
  ```

  After:

  ```gdscript
  static func issue_opponents(sim: RefCounted, players: Array[int], attack_tick: int = ATTACK_TICK) -> void:
  	if sim.tick() % DECISION_TICKS != 0: return
  	var zone: int = Profiler.begin()
  	for player in players: _decide(sim, player, attack_tick, _real(sim).bot_state())
  	Profiler.end(&"opponent.decide", zone)

  # A seat wrapper or command recorder is rebuilt every decision; memory and state live on the simulation.
  static func _real(seat_or_sim: RefCounted) -> RefCounted:
  	return seat_or_sim.simulation() if seat_or_sim.has_method("simulation") else seat_or_sim
  ```

  `_bot` (`:161-164`): its first line becomes `var sim: RefCounted = _real(seat_or_sim)` (the old trailing comment moves to `_real`). A state per seat on the same tick decides exactly as the shared one: `issue_command` changes only `_pending` and that seat's own `_last_sequences` entry (`simulation.gd:159-171`), and the bot reads neither for other seats.
- [ ] **Step 5 (cost probe, scratch `$L/t2-probe.gd`):** `TeamMatch.create()`, `TeamMatch.step` to tick 6000, then three rounds of 100 calls of `snapshot()` and 100 of `bot_state()` (`Time.get_ticks_usec`), keep the best round of each, print µs per call, their ratio and the entity count, end with `PROBE DONE`. **Gate (Question 2), on the ratio (load-robust):** `bot_state` at most half of `snapshot`; expected about 0.25 (review, 2026-11-14: 235.6 against 926.6 µs at tick 6000, 205 entities, loaded host). Over: park Tasks 3-9 with the numbers (morning decision); Tasks 1-2 stand.
- [ ] **Step 6:** BS1, BS2 green; red by mutation (scratch, revert each): drop the `container_id` line → BS1 (b) fails; `_buildings.values()` instead of `_sorted_copies(_buildings)` → BS2 fails (the building write reaches the simulation). `SUITE(t2)`, `cmp` silent against `*-before.tsv`; `sh tools/run_team_match.sh > $L/t2-team.log 2>&1` (V10 unchanged); `NETPLAY_OUT=$L/t2-netplay sh tools/run_netplay.sh match > $L/t2-netplay.log 2>&1` (V9); static gates. `docs/reference/sim-interface.md` "State out": `bot_state() -> Dictionary`: what the skirmish bot reads (entity rows with `id`, `owner`, `kind`, `position`, `combat` `{mode, target_id}` or null, `hole_id` and `container_id` when present; `buildings`, `players`, `last_sequences`, `tick`), copies, id order as in the snapshot; built per call, not state, never hashed. `simulation.gd`.

---

### Task 3: Bot seats on their own tick (§5.8)

```text
Task: bot seat k decides on ticks with tick % 30 == k % 30, each from its own bot state; single-shot callers get an ungated decide().
Owns: game/scripts/simulation/skirmish.gd (issue_opponents, decides, next_decision, decide), game/tests/test_skirmish.gd (BT1), test files touched only by the Allowed test edits T1-T4 (test_skirmish.gd, test_skirmish_waves.gd, test_factions.gd, test_playtest_replay.gd, test_skirmish_scene.gd).
Invariant: Skirmish.issue_opponent(s) signatures unchanged; no pin edited (R stays red until Task 5).
Boundary: Stagger rows of the same-tick table.
Red: BT1 fails on Task 2's code (every seat at tick 0).
Green: BT1; full suite red only on R checks; PROFILE COMPLETE 10 (report only).
Stop: a red check outside R after the Allowed test edits; the team match no longer ends won inside its cap.
```

- [ ] **Step 1 (test, `test_skirmish.gd`):** **BT1 `test_bot_seats_decide_on_their_own_ticks`:** `TeamMatch.create()`; for 90 ticks, inline `TeamMatch.step`: `Skirmish.issue_opponents(sim, seats)` (seats from `TeamMatch.SEATS`), then collect each new (player, sequence) of `sim.snapshot().pending_commands` with its `tick` (moves leave no command result, so read pending before the step), then `sim.step()`. Checks: every command's `tick % Skirmish.DECISION_TICKS == player % Skirmish.DECISION_TICKS` (`"BT1 bot seat k issues commands only on ticks where tick mod 30 equals k mod 30 (%d commands, %d off)"`); every seat of `TeamMatch.SEATS` issued at least one; each seat's first command tick equals its seat number (`"BT1 seat %d first decides at tick %d"`). Append it to `test_skirmish.gd` `cases()` (`:22`). Run on Task 2's code: fails (all at tick 0). Record.
- [ ] **Step 2 (`skirmish.gd`):** `issue_opponents` becomes:

  ```gdscript
  static func issue_opponents(sim: RefCounted, players: Array[int], attack_tick: int = ATTACK_TICK) -> void:
  	for player in players:
  		if not decides(sim.tick(), player): continue
  		var zone: int = Profiler.begin()
  		decide(sim, player, attack_tick)
  		Profiler.end(&"opponent.decide", zone)

  # Seat k decides on ticks k, k + 30, …: six seats on one tick made the team match's worst tick.
  static func decides(tick: int, player: int) -> bool:
  	return tick % DECISION_TICKS == player % DECISION_TICKS

  static func next_decision(tick: int, player: int) -> int:
  	return tick + 1 + posmod(player - tick - 1, DECISION_TICKS)

  static func decide(sim: RefCounted, player: int, attack_tick: int = ATTACK_TICK) -> void:
  	_decide(sim, player, attack_tick, _real(sim).bot_state())
  ```

  `issue_opponent` (`:64-65`) unchanged. `opponent.decide` is now one zone per seat decision, so its max is the per-seat cost and its calls count seat decisions (Task 0's count was shared decisions: compare calls ÷ 6).
- [ ] **Step 3 (fallout):** first apply T1 by census to every single-shot call site from Task 0 Step 5's caller list, then T4, then `SUITE(t3)`. List every failing check (`rg -n 'FAIL|SCRIPT ERROR' $L/t3-suite.log`). Each is either an R check (record its new value from the message, do not edit) or fixed by T1-T4 only. Measured on `74950e5` under the stagger alone (review; lines below are on `4c21d1a`, where `test_skirmish.gd` moved up one line and K2 moved to `:48`): 21 red bot cases in 4 files plus K2, outside R:
  - `test_skirmish.gd`: O1 `test_opponent_pays_and_retries` (`:169`, then a script error, so the case ends incomplete), B4 (`:101`, `:107`), A3 (`:252`), W2 (`:293`), W3 march (`:309`), D1 (`:353`), D2 (`:369`), D3 (`:405`), SK-S3 rally (`:665`, call at `:662`).
  - `test_skirmish_waves.gd`: W1 (`:55`), W3 shares (`:78`, then a script error, incomplete), W4 (`:96`), T1-T5 target scores (`:116-145`, through the `_decide` helper `:32-34` after `_run` to `ATTACK_TICK`), W10 (`:168`).
  - `test_factions.gd`: B1 (`:244`, `:246`), B2 (`:259`).
  - `test_playtest_replay.gd`: RP2 (`:44`, `:46`).
  - `test_skirmish_scene.gd`: K2 (`:48`, T4).

  T1 sites (single-shot calls; all, whether red or not): `test_skirmish.gd` around `:98`, `:104`, `:166`, `:194`, `:257`, `:338`, `:662`; `test_skirmish_waves.gd` `:33` (the `_decide` helper); `test_factions.gd` `:243`, `:248`, `:257`; `test_playtest_replay.gd` `:43` (`Skirmish.decide(recorder, 2, 0)`). T2/T3 candidates: `test_skirmish.gd` `:78`, `:244`, `:249`, `:290`, `:306`, `:312`, `:337` (`_decide_now` `:336-339` steps to the next multiple of 30); `test_skirmish_waves.gd` `:50`, `:66`, `:80`, `:94`, `:97`, `:169`. Every case decides on `tick % 30 == 0` today (single shots at tick 0, at `ATTACK_TICK`, or helpers that step to the next multiple of 30). Rerun until the only red checks are R's (HUD1 is R). Anything else: stop. Then red by mutation for the converted negative checks (scratch, revert): make `decide` a no-op; the positive checks of O1, A3 and B1 go red (the decision runs in those cases), then restore.
- [ ] **Step 4:** `sh tools/run_team_match.sh > $L/t3-team.log 2>&1`: exit 1 is expected (V10 line), but the log's `TEAM MATCH` line must say `won` with a tick below 45000 (record it). `sh tools/run_profile.sh > $L/t3-profile.log 2>&1`: PROFILE COMPLETE 10; record `team_match` `opponent.decide` max and calls per tick, `bot_state` mean / max, `step` mean / max against Task 0 (derived expectation: about 0.24 ms of state per seat decision instead of about 0.93 ms of shared snapshot, review claim 3; decide max about 1.4 ms, derived). Static gates. Record the suite's R lines in the verification file.

---

### Task 4: Path budget by route cells (§5.2 smaller alternative)

```text
Task: the path service starts no new search once the tick's route cells reach PATH_CELLS_PER_TICK (384, Question 4); a started search finishes; a search that finds no route charges the whole budget.
Owns: game/scripts/simulation/simulation.gd (PATH_CELLS_PER_TICK, _path_cells, path_cells, _service_paths, _assign_route), game/tests/test_groups.gd (CountingNavigation, FailingNavigation, _twenty, G7 as PB1, G8, PB2, PB3, PB4, _ashfall_groups, X2, X2r/X2m), game/tests/test_combat_navigation.gd (A2 check; PB5 only with the fallback), game/tests/test_benchmark.gd (snapshot ceiling step), game/tests/run_tests.gd (CASE_SECONDS entries only), game/benchmarks/run_movement.gd (timed-window path budget check), game/benchmarks/run_profile.gd (_team_match PROFILE_PATHS print, report only), game/scripts/simulation/combat.gd (_approach, only for the Question 8 fallback), docs/reference/sim-interface.md (diagnostic counter list).
Invariant: path_queue form and FIFO; air units never queued; unreachable allocations never searched; snapshot ceilings and every benchmark budget unchanged.
Boundary: Path budget rows of the same-tick table.
Red: PB1-PB4 and X2's per-tick budget rule fail on today's 8-request cap; the movement benchmark check fails with path_cells() mutated to 0.
Green: WARGRID_TEST_ONLY=test_groups, =test_combat_navigation, =test_benchmark; full suite red only on R checks; Question 8 criterion met (with or without the fallback); PROFILE COMPLETE 10; benchmark exit 0.
Stop: a red check outside R and P1; movement open or dense queue_drain_ticks more than twice Task 0's (Question 15; expected about 60 against 38 at 384, measured for dense; X2 is held to its work bound instead, Question 13); a budget newly exceeded; a snapshot ceiling broken at the drain step (not measured at 384); the Question 8 criterion failed and the fallback either moves a check outside R and P1 or does not meet it (revert the fallback, park, Step 6).
```

- [ ] **Step 1 (route-cell probe, scratch `$L/t4-probe.gd`, before any edit; evidence only, Question 21):** for `TeamMatch` (whole match), `MovementWorkload` open and dense (one leg each), `CombatWorkload` open, dense, hordes300 (2100 ticks). A runtime swap of the navigation does not survive map rebuilds (`_replace_union`, `construction.gd:111`), so the probe runs in a scratch tree: `cd <abs $W> && git worktree add --detach <abs $L>/probe-tree HEAD` (HEAD is Task 3's commit: staggered bots, today's 8-request cap, so the probe isolates the budget), `godot --headless --path <abs $L>/probe-tree/game --import`, then Edit only that tree's `grid_navigation.gd` and `simulation.gd` as the review's probe copy does (`~/projects/wargrid-overnight-work/one-controller/flatter-worst-ticks/verify-copy/probe/game/scripts/simulation/`: an inner `CountingGrid extends AStarGrid2D` whose `_estimate_cost(from_id, end_id)` records each `from_id` and returns `float(absi(from_id.x - end_id.x) + absi(from_id.y - end_id.y))`, the default Manhattan value, so behaviour is unchanged; `route` stores the count as `last_searched`; `_service_paths` logs tick, queue length, route size and searched cells per request). Never Edit `$W` for the probe. Behaviour check first: the instrumented team match still ends on Task 3 Step 4's recorded `TEAM MATCH` line (the stagger already moved V10, so V10's `won tick=39497` is no longer the reference); otherwise the probe's numbers are void. Script: adapt the review's `verify-copy/scripts/path_probe.gd` into `$L` (read it, write the adapted copy with the Write tool), ending `PROBE DONE`; for the team scenario it also runs the wait tracking that Step 6 defines (write it here first, as a function Step 6's `$L/t4-wait.gd` then copies) and prints its `WAIT team …` line, today's comparator for Question 8. Summarise with a copy of its `analyze.py` in `$L` (Read, then Write): `python3 -I <abs $L>/analyze.py <abs tsv> <budget>` (rule installed 2026-11-14; if refused anyway: print the summary from the Godot script instead). Per scenario: requests, route cells per request p50 / p95 / max, searched cells per request p50 / p95 / max, searched ÷ route over all requests, per-tick route sum p99 / max, per-tick searched max, ticks with more than 8 requests, max queue length. The probe tree stays until the morning (`git worktree remove` is not in the night list; morning item). Expected (review, today's cap, on `74950e5` without the stagger, so the team match numbers are approximate here and the bot-free movement and combat numbers should match): team match searched ÷ route 20.3, per-request p95 28.6, per-tick searched max 102413, max queue 153; movement 3.0 (open) and 4.54 (dense). Record in "Route cells". `PATH_CELLS_PER_TICK` stays 384 whatever the probe prints (Question 4).
- [ ] **Step 2 (stub, tests):** stub `func path_cells() -> int: return 0` in `simulation.gd`, and add `const PATH_CELLS_PER_TICK: int = 384` next to the still-live `PATH_REQUESTS_PER_TICK` (the new tests name it; without it `test_groups.gd` and `test_combat_navigation.gd` fail to parse and the suite reports "suite failed to load" instead of named failures; Step 3 removes the old constant and gives the new one its comment). `test_groups.gd`:
  - `CountingNavigation` (`:149-154`) also records sizes: `var sizes: Array[int] = []` and `sizes.append(result.size())` around `super.route`; a second inner class `FailingNavigation extends CountingNavigation` with `var fail_from: Dictionary = {}` returns `[]` (still counted, size 0) when `Vector2i(from.floor())` is in `fail_from`.
  - `_twenty(blocked: Array[Vector2i] = [], size := Vector2i(16, 16), target: Array = [13.5, 13.5])`; `Simulation.new(blocked, size)`; the command targets `target`. Default call sites unchanged.
  - **PB1 (replaces G7's first loop, `:168-183`, same case name `test_path_budget`):** on `_twenty([], Vector2i(64, 64), [60.5, 60.5])` (the grid never moves diagonally, `grid_navigation.gd:23`, so routes are about 115 cells and about four are served per tick at 384; on the 16 × 16 default the twenty routes of about 20 cells nearly all fit in one tick, derived, so the budget would barely bind), per tick until the queue is empty (at most 10 ticks) with `nav.sizes` cleared: served ids (units that went from `path_pending` to another status) are exactly the first `n = nav.calls` ids of the previous `path_queue`; `sum(sizes) - sizes.back() < Simulation.PATH_CELLS_PER_TICK`; and `sum(sizes) >= Simulation.PATH_CELLS_PER_TICK` or the queue is now empty (`"PB1 phase %d serves the queue front until the route cells reach the budget"`); waiting units stand still and keep empty routes; served units move at most 0.1 (the G7 checks kept). At least one tick left requests waiting (`"PB1 the budget bound on at least one tick"`), and within the 10 ticks every unit is served (`"PB1 the twenty requests drain"`). G7's unreachable half (`:184-194`) unchanged.
  - **PB2 `test_long_route_served_alone`:** `Simulation.new([], Vector2i(256, 256))`, unit A at (0.5, 0.5), unit B at (250.5, 200.5), one move command for [A, B] to (251.5, 201.5) (A's route is about 450 cells, B's a few; ids sorted, so A is first). Step 1: A `moving`, B `path_pending` (`"PB2 a route longer than the budget is served alone"`); step 2: B `moving` (`"PB2 the next request waits one tick"`).
  - **PB3 `test_failed_search_spends_the_tick`:** `_twenty()` with `FailingNavigation` whose `fail_from` holds unit 1's cell. Step 1: `nav.calls == 1`, unit 1 `blocked`, units 2-20 still `path_pending` (`"PB3 a search that finds no route spends the whole tick's budget"`); step 2: `nav.calls` ≥ 2 more.
  - **PB4 `test_map_change_requeues_under_budget`:** `_twenty([], Vector2i(64, 64), [60.5, 60.5])` with `CountingNavigation`; one `step()` (some units `moving`, the rest `path_pending`); `var corner: Array[Vector2i] = [Vector2i(63, 0)]`, `sim.replace_blocked_cells(corner)` (a corner no unit or route uses; check `.ok`; a typed variable as in A2's `none`, `test_combat_navigation.gd:97`; this map has no terrain cells, and `replace_blocked_cells` replaces the terrain set, `simulation.gd:749`, so never call it this way on a map with terrain). Then `path_queue` equals the ids of every `moving` or `path_pending` unit, sorted (`"PB4 a map change re-queues every moving unit once, in id order"`); step until it is empty (at most 10 ticks), per tick the PB1 budget rule holds (`"PB4 the re-queued burst is served first in, first out under the budget"`) and no id is served twice (`"PB4 no unit is served twice after a map change"`). `_replace_union` updates the same navigation object in place (`simulation.gd:759`), so the `CountingNavigation` keeps counting.
  - **G8 (`:197-217`):** run on `_twenty([], Vector2i(64, 64), [60.5, 60.5])` (routes about 115 cells, about four served per tick at 384). `waiting` = the first id of `path_queue` after the first step, as 9 is today (check the queue has at least four ids: `"G8 setup leaves requests waiting"`); every `9` in the case becomes `waiting` and the entity index `waiting - 1`. `"G8 stale queue entry removed, final appended once"` becomes: `path_queue.count(waiting) == 1`, `path_queue.back() == waiting`, and `path_queue` without `waiting` is a suffix of the previous queue without `waiting`. "Snapshot isolated" compares with the queue read just before. "Low-ID repeated orders do not starve older requests": re-order unit 1 every tick for up to 40 ticks; `waiting` and the queue's original last id both become `moving` before the loop ends (record the tick). "Current final order routed" unchanged.
  - **A2 (`test_combat_navigation.gd:112-123`):** preload `res://tests/test_groups.gd` as `Groups`, set `many._navigation = Groups.CountingNavigation.new(<many's blocked cells>, <many's map size>)` before the loop (the file is allowlisted); per tick `"A2 a tick starts no search after its route cells reach the budget"`: `sizes.is_empty() or sum(sizes) - sizes.back() < Simulation.PATH_CELLS_PER_TICK`. The stop check (`:125-129`) unchanged.
  - **Snapshot ceiling (`test_benchmark.gd:103-112`):** `for i in range(38): sim.step()` becomes "step until `sim.snapshot().path_queue.is_empty()`, at most 300 steps" (check it drained: `"BM snapshot ceiling measured once the queue drained"`), and the comment `# Step 38 is the peak (routes full, queue just drained).` becomes `# Measured when the path queue has just drained (routes full).` Ceilings unchanged.
  - **X2 setup (review X2 row, `docs/reference/simulation-reference-review.md:259`; Question 13), `test_groups.gd`:** add near the top `const MapData = preload("res://scripts/simulation/map_data.gd")` and `const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")`, then:

    ```gdscript
    # (seat, seat whose start cell is the target): three groups ordered across Ashfall.
    const X2_SEATS: Array[Vector2i] = [Vector2i(1, 4), Vector2i(4, 8), Vector2i(6, 2)]

    # Seat 1's power plant stands so that destroying it later changes the map.
    func _ashfall_groups() -> Dictionary:
    	var map: Dictionary = MapData.load("res://data/maps/ashfall.json")
    	var sim = MapData.create(map, [])
    	var plant: int = sim._next_entity_id
    	CombatWorkload._building(sim, "usa_power_plant", MapData.slot(map, 1, "usa_power_plant"))
    	var nav := CountingNavigation.new(sim._union_cells(), Vector2i(int(map.size[0]), int(map.size[1])))
    	var same: bool = nav.snapshot() == sim._navigation.snapshot()
    	sim._navigation = nav
    	var groups: Array = []
    	var commands: Array = []
    	for pair: Vector2i in X2_SEATS:
    		var target := Vector2(MapData.start_cell(map, pair.y)) + Vector2(0.5, 0.5)
    		var start: Vector2i = MapData.start_cell(map, pair.x)
    		var ids: Array = []
    		for y in range(start.y - 12, start.y + 13):
    			for x in range(start.x - 12, start.x + 13):
    				var point := Vector2(x + 0.5, y + 0.5)
    				if ids.size() == 60 or nav.component_at(point) != nav.component_at(target): continue
    				var id: int = sim.spawn(pair.x, point)
    				if id > 0:
    					sim._entities[id].combat = null
    					ids.append(id)
    		groups.append(ids)
    		commands.append(command(sim, ids, [target.x, target.y], 0, pair.x))
    	return {"sim": sim, "nav": nav, "plant": plant, "groups": groups, "commands": commands, "same_navigation": same}
    ```

    Map facts this rests on (`game/data/maps/ashfall.json`, 194 × 187): start cells seat 1 (21, 127), 2 (69, 168), 4 (174, 125), 6 (123, 21), 8 (18, 67), so every scan square stays inside the map; the 12 supply sources take entity ids first, so unit ids do not start at 1 (use the returned ids). `MapData.create(map, [])` adds no players: moves need none (`_validate`, `simulation.gd:192-275`, returns for a move at `:227`, before it asks for a player at `:237`), and the plant's removal refunds an empty queue (`production.gd:23-26`). Building the plant before the spawns keeps its cells free of units (`spawn` rejects unwalkable cells, `simulation.gd:85`). Units get `combat = null` as in `movement_workload.gd`, so nothing but these orders queues a path. If `same` is false only because the two blocked lists differ in order, compare them as sorted cell sets instead and record that.
  - **X2 `test_group_order_across_ashfall`:** `var world = _ashfall_groups()`; record `spawned[id] = position.duplicate()` for every id; check `world.same_navigation` and three groups of 60 (`"X2 three seats of 60 units on Ashfall, counted on a navigation equal to the map's"`); issue the three commands before the first step (`"X2 the three group orders are accepted on one tick"`). Then, with `budget = Simulation.PATH_CELLS_PER_TICK`, per tick up to 300: `nav.sizes.clear()`, `sim.step()`, `spent` = sum of `nav.sizes`, `cells += spent`, `rule_ok` stays true while `nav.sizes.is_empty() or spent - nav.sizes.back() < budget`, `max_queue = maxi(max_queue, sim._path_queue.size())`; stop when the queue is empty (`drain` = ticks stepped, the order tick included), otherwise `capped += 1` and `full_ok` stays true while `spent >= budget`. Checks:
    - `"X2 each tick starts no search after its route cells reach the budget"` (`rule_ok`);
    - `"X2 a tick leaves requests waiting only after charging the full budget"` (`full_ok`);
    - `"X2 the burst drains within ceil(route cells / budget) ticks (%d ticks, %d cells)"`: queue empty and `drain <= ceili(cells / float(budget))` (the Ashfall bound: every tick before the last charges at least the budget, so `(drain - 1) × budget < cells`; Question 15's 2× rule cannot hold here, see "Expected values");
    - `"X2 the budget bound on at least one tick (%d ticks)"`: `capped >= 1` (the mechanics-run assertion);
    - `"X2 every unit of the three orders is searched once and moving on a route to its destination (%d searches)"`: `nav.calls == 180` and every spawned unit `moving`, route not empty, the route's last point in its destination's cell;
    - then `Simulation.START_DELAY_TICKS + 20` more steps: `"X2 nothing is stuck: every unit has left its start point %d ticks after the drain"` (status not `blocked`, position differs from `spawned`).
    Then `print("X2 ashfall drain_ticks=", drain, " route_cells=", cells, " max_queue=", max_queue, " capped_ticks=", capped, " searches=", nav.calls)` (a report line like BM9's, `test_benchmark.gd:242`; it records the max queue length).
  - **X2r / X2m `test_ashfall_burst_against_removal_and_map_change`:** a fresh `_ashfall_groups()`; issue the three commands, then `remove_object(groups[0].back())` before the step (`gone`); one `step()`: `"X2r a unit removed on its order's tick is never queued"` (`gone` not in `_path_queue`, not in `_entities`; `_live_ids` drops it, `simulation.gd:303`, `:368`). Remove the unit at the middle of `_path_queue` (`waiting`; `@warning_ignore("integer_division")` on the index): `"X2r removing a queued unit leaves the rest of the queue in order"` (the queue equals the previous one without `waiting`). One `step()`; then on one tick, before stepping: remove the first `moving` unit of `groups[0]` (`mover`), then `remove_object(world.plant)` (`.ok`; `_remove_building` → `Construction.rebuild_navigation` → `_replace_union`, which updates the counting navigation in place, `simulation.gd:754-783`). `"X2m a map change re-queues every moving or waiting unit once, in id order, never a removed one"`: `mover > 0` and `_path_queue` equals the sorted ids of all `moving` or `path_pending` units and holds none of `gone`, `waiting`, `mover`. `nav.calls = 0`, then step until the queue is empty (at most 300), with the X2 per-tick rule: `"X2m the re-queued burst is served under the budget and drains within ceil(route cells / budget) ticks (%d ticks)"` and `"X2m every re-queued unit is searched exactly once after the map change (%d of %d)"` (`nav.calls` equals the re-queued count).
  Append the new cases to `test_groups.gd` `cases()` (`:8-9`; `run_tests.gd:82` runs only `cases()`, so an unlisted test never fails): `test_long_route_served_alone`, `test_failed_search_spends_the_tick`, `test_map_change_requeues_under_budget`, `test_group_order_across_ashfall`, `test_ashfall_burst_against_removal_and_map_change` (PB1 and G8 keep their listed names). Time both X2 cases; add each to `CASE_SECONDS` in `game/tests/run_tests.gd` if over 1 s.
  Run the three suites on today's code with the stub: PB1-PB4 fail by name (8 per tick, failure not charged); of the X2 cases only the per-tick budget rule fails (`"X2 each tick starts no search…"` and `"X2m the re-queued burst…"`: eight routes of about 200 cells a tick); every other X2 check passes on today's code, which proves the setup (any other X2 failure: fix the setup, never the assertion, and record). Record the `X2 ashfall` line: today's `drain_ticks` (expected 23 = ceil(180 ÷ 8)) and `route_cells`.
- [ ] **Step 3 (`simulation.gd`):** `const PATH_REQUESTS_PER_TICK: int = 8` (`:21`) and Step 2's bare `PATH_CELLS_PER_TICK` line become:

  ```gdscript
  # Route cells stand in for searched cells, which AStarGrid2D does not report; sized so a 300-unit order drains in under twice the 8-request time.
  const PATH_CELLS_PER_TICK: int = 384
  ```

  `var _path_cells: int = 0` next to `_allocation_calls`; replace the stub with `func path_cells() -> int: return _path_cells` next to `allocation_calls()`. `_service_paths` (`:469-474`) before:

  ```gdscript
  func _service_paths() -> void:
  	for i in range(mini(PATH_REQUESTS_PER_TICK, _path_queue.size())):
  		var id: int = _path_queue.pop_front()
  		var zone: int = Profiler.begin()
  		_assign_route(_entities[id])
  		Profiler.end(&"route", zone)
  ```

  After:

  ```gdscript
  func _service_paths() -> void:
  	_path_cells = 0
  	while _path_cells < PATH_CELLS_PER_TICK and not _path_queue.is_empty():
  		var id: int = _path_queue.pop_front()
  		var zone: int = Profiler.begin()
  		_path_cells += _assign_route(_entities[id])
  		Profiler.end(&"route", zone)
  ```

  `_assign_route` (`:628-639`) returns `int`: `var points: Array[Vector2] = _navigation.route(from, to)` before the loop, the loop iterates `points`, and the function ends with:

  ```gdscript
  	# A search that finds nothing may have searched its whole region, so nothing else starts this tick.
  	return points.size() if not points.is_empty() else PATH_CELLS_PER_TICK
  ```

  `rg -n 'PATH_REQUESTS_PER_TICK' game tools` prints nothing afterwards (docs follow in Task 8).
- [ ] **Step 4 (benchmark mechanics check, `run_movement.gd` `_measure`; Question 19):** add `var capped: int = 0` next to `var completed: int = 0`; the timed sample block, before:

  ```gdscript
  		if tick >= 300:
  			samples.append(elapsed)
  ```

  After (outside the timed span, which ends at `elapsed`):

  ```gdscript
  		if tick >= 300:
  			samples.append(elapsed)
  			if sim.path_cells() >= Simulation.PATH_CELLS_PER_TICK: capped += 1
  ```

  The `HEADLESS` print gains `" path_capped_window=", capped` at its end (`tools/perf_record.py:38` reads only `tick_ms`), and after the `"Benchmark incomplete workload"` check:

  ```gdscript
  	if capped == 0:
  		push_error("Benchmark: the path budget never bound inside the timed window for " + layout)
  		return false
  ```

  Expected `capped` > 0: main runs two legs in the timed window (`completed_legs=2`), each a 300-unit order whose per-tick route sum peaks at 738 cells (review); not measured on the branch. Red by scratch mutation (Step 3 already replaced the stub): make `path_cells()` return 0, `godot --headless --path game --script res://benchmarks/run_movement.gd > $L/t4-movement-red.log 2>&1; echo "exit=$?"`: exit 1 and `rg -n 'path budget never bound' $L/t4-movement-red.log` hits; restore `return _path_cells` with Edit. Report only, no failure: `run_profile.gd` `_team_match`, in the loop after `TeamMatch.step(sim)` when `sim.tick() > WARMUP`, counts `capped` and `max_cells` the same way and prints `PROFILE_PATHS team_match capped_ticks=<n> max_cells=<n> budget=<n>` after the loop (expected about 847 capped ticks at 384, review).
- [ ] **Step 5 (red by mutation, scratch, revert each):** (a) `return points.size()` also for an empty route: PB3 fails; (b) skip a search that would cross the budget (`if _path_cells + <Manhattan length> > PATH_CELLS_PER_TICK: break` before `pop_front`): PB2 fails (A never served on tick 1); (c) do not reset `_path_cells` (carry-over): PB1 phase 1 fails; (d) `PATH_CELLS_PER_TICK` 1000000: `"X2 the budget bound on at least one tick"` fails (the whole burst is served on the order tick), which proves X2's mechanics-run assertion can fail. `git diff --stat` shows only the Owns paths.
- [ ] **Step 6 (queue place, Question 8: keep erase-and-append unless this criterion fails):** scratch `$L/t4-wait.gd` (Write tool; `extends SceneTree`, `quit()` on every path, last line `WAIT DONE`), run on `$W` after Step 5: `godot --headless --path <abs $W>/game --script <abs $L>/t4-wait.gd > $L/t4-wait.log 2>&1` (judge by `WAIT DONE`). Scenarios: `MovementWorkload` open and dense, one leg each (`create`, `issue_leg(sim, 0)`, step until `settled`); X2 (`preload("res://tests/test_groups.gd").new()._ashfall_groups()`, issue its commands, step until the queue is empty, then 30 more ticks); `TeamMatch` whole match (`TeamMatch.step` until `match_over()` or `TEAM_TICK_CAP`). Tracking after every step, from `sim._path_queue` (private read, scratch only): an id first seen starts its wait at that tick; its index rising against the previous tick counts one re-append (erase-and-append moves it to the back; first in, first out alone only lowers indexes); when it leaves the queue with status `moving` or `blocked`, its wait (leaving tick − first-seen tick + 1) is recorded and its tracking resets; leaving any other way (stopped, removed) drops it unrecorded. Per scenario print `WAIT <scenario> requests=<n> drain=<n> max_queue=<n> max_wait=<n> p99_wait=<n> max_reappends=<n> units_reappended=<n>` (`drain` only for the one-order scenarios). Today's comparator: the probe tree's `WAIT team` line (Step 1).

  **Starvation counts as unlikely when all three hold** (record each in "Queue place (Task 4)"):
  - (a) movement open, dense and X2: `max_reappends == 0` and `max_wait` equals that scenario's drain, which the script also prints (`drain=<n>`: ticks from the order tick, included, until the queue is empty; for X2 it must equal the `X2 ashfall` line's `drain_ticks`, and Step 7 compares the movement ones with the benchmark's `queue_drain_ticks`). These units have no combat and one order each, so nothing can re-request; any other value is a bug: stop, Opus diagnosis.
  - (b) team match: `max_reappends <= max(2, today's max_reappends)`. Reasoning: a chaser re-requests at most once per `Combat.REPATH_TICKS` = 8 ticks (`combat.gd:11`, `_approach` `:207-229`) and only when its target has left its reach. First in, first out serves it once the work ahead of it is done, and 8 ticks at 384 route cells serve at least 3072 route cells (today's cap: 64 requests). One re-append means more than one repath period of work was ahead of it, two mean more than 16 ticks; three or more mean the queue ahead outgrows the budget period after period, the starvation pattern Zero Hour's keep-the-slot rule prevents. If today's code already shows more, the budget did not create it.
  - (c) team match: `max_wait <= 3 × X2's drain_ticks` on this tree. Reasoning: X2's 180-request cross-map burst is the largest measured burst (the team match's longest queue is 153, review), so a unit re-appended at most twice waits at most three such drains; longer means it was passed over beyond what (b) allows.

  **Fallback if (b) or (c) fails** (pre-written; Zero Hour keeps an already queued unit's slot, `AIPathfind.cpp:5663-5667` at `0a05454`). `combat.gd` `_approach` (`:218-229`), before:

  ```gdscript
  	if previous != null: held.cells.erase(previous)
  	sim._path_queue.erase(unit.id)
  	if goal == null:
  		sim._stop_unit(unit)
  		unit.status = "blocked"
  		return
  	held.cells[Vector2i(goal.floor())] = true
  	unit.destination = [goal.x, goal.y]
  	unit.order = {"type": "move", "target": [goal.x, goal.y]}
  	unit.route = []
  	unit.status = "path_pending"
  	sim._path_queue.append(unit.id)
  ```

  After (`_stop_unit` already erases the entry on the `null` path, `simulation.gd:467`):

  ```gdscript
  	if previous != null: held.cells.erase(previous)
  	if goal == null:
  		sim._stop_unit(unit)
  		unit.status = "blocked"
  		return
  	held.cells[Vector2i(goal.floor())] = true
  	unit.destination = [goal.x, goal.y]
  	unit.order = {"type": "move", "target": [goal.x, goal.y]}
  	unit.route = []
  	unit.status = "path_pending"
  	# A re-requested chaser keeps its queue place (Zero Hour AIPathfind.cpp:5663-5667), so a moving target cannot starve it.
  	if not sim._path_queue.has(unit.id): sim._path_queue.append(unit.id)
  ```

  Player commands keep erase-and-append (G8 pins it; a player's re-order is not periodic). Test first, before the edit: **PB5 `test_queued_chaser_keeps_its_place`** (`test_combat_navigation.gd`, allowlisted; P2): `Simulation.new([], Vector2i(64, 64))`; 40 player-1 `usa_rifle_infantry` in rows from (2.5, 2.5) ordered to (60.5, 30.5), then on the same tick 20 more ordered to attack a player-2 `usa_builder` at (60.5, 60.5) that is itself ordered to (60.5, 2.5), so the attackers' firing cells go stale while about 40 routes of about 85 cells (derived: more than 8 ticks of budget) wait ahead of them. Per tick while an attacker is `path_pending`: its `path_queue` index never rises (`"PB5 a chaser re-requested while it waits keeps its queue place"`), and at least one attacker's destination changed while it stayed queued (`"PB5 a chaser was re-requested while queued"`, the mechanics check). Append `test_queued_chaser_keeps_its_place` to `test_combat_navigation.gd` `cases()` (`:8-9`), and remove it again if the fallback is reverted. Red on erase-and-append by the first check; if the second fails instead, the setup triggers no re-request: add movers until it does, and record. Then rerun this step's script and `SUITE(t4)`. (a)-(c) hold and the only red checks are R's and P1's: keep the fallback, record "fallback applied". Any other check red (a pin or check outside R moved: changing queue order is then a stop), or (b) / (c) still failing: revert the fallback and PB5 with Edit (`git diff --stat` shows `combat.gd` and `test_combat_navigation.gd` back at Step 5's state) and park Task 4 with both `WAIT` measurements (morning item: back of the queue with the measured starvation, or keep-slot with its fallout; the user's call).
- [ ] **Step 7:** the three suites green; `SUITE(t4)`: red only on R checks (record the values and the `X2 ashfall` line: `drain_ticks`, `route_cells`, `max_queue`, `capped_ticks`, against Step 2's today line); `sh tools/run_profile.sh > $L/t4-profile.log 2>&1` (PROFILE COMPLETE 10; record `PROFILE_PATHS`, `team_match` `step.service_paths` max, `route` max, `step` max, `opponent.decide` max); benchmark alone as in Task 0 Step 7 into `$L/t4-bench.log` (exit 0, accepted line only; record movement `queue_peak`, `queue_drain_ticks` and `path_capped_window` against Task 0: `queue_drain_ticks` more than twice is the stop of Question 15, expected about 60 against 38; each is at least Step 6's one-leg `WAIT open` / `WAIT dense` `drain` (the benchmark keeps the max over its legs; the review's 38 and 60 are one-leg values); record combat p95 / p99 and `WORST TICK`); `sh tools/run_team_match.sh > $L/t4-team.log 2>&1` (`won` below 45000, record the line); static gates. `docs/reference/sim-interface.md` "Not interface", diagnostic counters: add `path_cells` (route cells the last step's path service charged).

---

### Task 5: The one re-pin

```text
Task: write the new values of every R pin, in one commit, after checking they are deterministic.
Owns: the R lines only (game/tests/*.gd consts, tools/run_netplay.sh one literal, tools/run_team_match.sh the pinned line and its comment), the verification file.
Invariant: V7 unchanged; no pin outside R; caps and windows unchanged; git diff of this task touches only R lines.
Boundary: an R value that did not move is recorded and left alone.
Red: Task 4's suite (R checks red).
Green: SUITE(t5) and SUITE(t5b) green; t5 and t5b traces byte-identical; team match, netplay match, perturb, relay-down, relay-term pass.
Stop: a new outcome past a cap or outside the S1 window; two runs disagree; any non-R check red.
```

- [ ] **Step 1:** from `$L/t4-suite.log` read each R check's reported value (`TB3 final digest … at tick`, `TB4 … got`, `S1 core series pinned, got`, `S1 pinned outcome, got`, `Cs1 pinned outcome, got`, the FRC outcome line, `H1 pinned digest`, `VR1 … got`, `HUD1 pinned summary texts, got`, and any census additions). Check the bounds first: China and FRC terminal ticks below their caps, S1 terminal inside 7000-17999, team match `won` below 45000; any winner is fine for all three skirmish pins and the team match (Questions 11, 20). A bound broken: stop (Question 12). Compare with the review's expected values at 384 (Pinned values, "Expected values"; if Task 4 kept the Question 8 fallback, the review's values do not apply: record that and go on to Step 2). A value inside the bounds that differs from them is not a stop by itself, but the subagent edits nothing and returns `BLOCKED` with each old value, its new value, the review's expected value and `bounds hold; recommend re-pin`. The coordinator then dispatches one Opus (high) diagnosis with those numbers and the "Expected values" list (`docs/night-run.md` Coordinator rules: "Diagnose before asking", "Opus work stays on Opus") and continues this task's subagent with `SendMessage`, passing the diagnosis; Steps 2-3 run only after that reply recommends the re-pin; otherwise Task 5 parks with the diagnosis (morning item). A broken bound stays a stop (Question 12): park, no re-pin.
- [ ] **Step 2:** edit each R `const` with the Edit tool (old → new into the verification file's Re-pin table). `tools/run_team_match.sh:13`: the pinned line takes `$L/t4-team.log`'s values; its comment becomes `# Pinned outcome: won inside the 45000 cap; re-pinned for staggered bots and the route-cell path budget (Flatter worst ticks).` `tools/run_netplay.sh:91`: run `NETPLAY_OUT=$L/t5-netplay-probe sh tools/run_netplay.sh match > $L/t5-netplay-probe.log 2>&1` first (it fails on the old literal and prints `terminal tick N, pinned 9129`); the script checks the pin (`:91`) before `same_hashes` (`:92`), so it never compares the seats on a moved pin: run `python3 tools/compare_replays.py --interval 30 --rows 0 <abs $L>/t5-netplay-probe/s1.tsv <abs $L>/t5-netplay-probe/s2.tsv > $L/t5-netplay-seats.log 2>&1` (expected `REPLAYS MATCHED`; if refused despite the installed rule: record it and rely on Step 3's rerun, whose `same_hashes` compares both seats and the oracle); then write N.
- [ ] **Step 3 (determinism):** `SUITE(t5)` and `SUITE(t5b)`: both TESTS PASSED, exit 0; `cmp` each `*-t5.tsv` with its `*-t5b.tsv` silent (the new trace reference). `sh tools/run_team_match.sh > $L/t5-team.log 2>&1` exit 0. `sh tools/run_netplay.sh` with `NETPLAY_OUT=$L/t5-<scenario>` for `match` (both seats and the oracle agree: the script's `same_hashes`), `perturb`, `relay-down`, `relay-term`: NETPLAY PASSED each. `sh tools/run_conformance.sh`. Static gates. `git diff --stat <Task 4 commit>` lists only R files; V11.

---

### Task 6: Worst ticks after the changes (Question 14, measure)

```text
Task: on the re-pinned tree, add per-tick count lines to the three benchmark rows (report only) and measure five runs of the benchmark and the team match and three of the profile, so Task 7 sets its gates from measured values.
Owns: game/benchmarks/run_movement.gd (HEADLESS line field), game/benchmarks/run_combat.gd (HORDES300 line field), game/benchmarks/run_team_match.gd (TEAM PATHS line), the verification file.
Invariant: no simulation or test file changes; traces equal *-t5.tsv; every pinned line, budget and ceiling unchanged; the new lines fail nothing yet.
Boundary: 1-minute load above 2.5 at a run's start or end.
Red: n/a (measurement; the lines stay report-only until Task 7).
Green: SUITE(t6) cmp silent against *-t5.tsv; static gates; five benchmark runs exit 0 with their markers; five team-match runs exit 0, each with one TEAM PATHS line; three PROFILE COMPLETE 10; every count identical in every run.
Stop: a count differs between two runs on the same tree (nondeterminism: Opus diagnosis, park); a run fails an existing gate.
```

- [ ] **Step 1 (count lines, report only):**
  - `run_movement.gd` `_measure`: `var cells_peak: int = 0` next to Task 4's `var capped`; in the timed block after Task 4's `capped` line, `cells_peak = maxi(cells_peak, sim.path_cells())`; the `HEADLESS` print gains `" path_cells_peak_window=", cells_peak` after `path_capped_window`.
  - `run_combat.gd` `_measure`: `var full_scans_peak: int = 0` next to Task 1's `var window_reserved`; in the timed `else:` branch after `window_reserved += sim.reserved_allocations()`, `full_scans_peak = maxi(full_scans_peak, sim.allocation_calls() - sim.reserved_allocations())` (each allocation outside the reservation map pays one full entity scan); the hordes300 print gains `" full_scans_peak_window=", full_scans_peak`.
  - `run_team_match.gd`: `const Skirmish = preload("res://scripts/simulation/skirmish.gd")`; `_play` (`:17-40`) keeps its timed span and its `TEAM MATCH` and `TEAM TIMING` lines unchanged (the first is pinned by `tools/run_team_match.sh:13`). Before `var started`, `var deciding: int = TeamMatch.SEATS.filter(func(entry: Dictionary) -> bool: return Skirmish.decides(sim.tick(), entry.seat)).size()`; next to `var units_peak`, `var paths := {"capped_ticks": 0, "max_cells": 0, "max_queue": 0, "max_decisions": 0}`; after `units_peak = maxi(…)`, `if sim.tick() > WARMUP: _count_paths(paths, sim, state, deciding)`; both `return true` become `return _paths_ok(paths)`. New functions:

    ```gdscript
    func _count_paths(paths: Dictionary, sim: Simulation, state: Dictionary, deciding: int) -> void:
    	if sim.path_cells() >= Simulation.PATH_CELLS_PER_TICK: paths.capped_ticks += 1
    	paths.max_cells = maxi(paths.max_cells, sim.path_cells())
    	paths.max_queue = maxi(paths.max_queue, state.path_queue.size())
    	paths.max_decisions = maxi(paths.max_decisions, deciding)

    func _paths_ok(paths: Dictionary) -> bool:
    	print("TEAM PATHS capped_ticks=", paths.capped_ticks, " max_cells=", paths.max_cells, " max_queue=", paths.max_queue, " max_decisions=", paths.max_decisions)
    	return true
    ```

  Static gates; `SUITE(t6)`, `cmp` against `*-t5.tsv` silent.
- [ ] **Step 2 (repeat runs, each alone, in the background, waited on by its notice):** one command per run with the run number typed out (no shell loop, no variable): `sh tools/run_benchmark.sh > $L/t6-bench-<n>.log 2>&1; echo "exit=$?"` for n = 1 to 5 (on the branch it does not record; it prints `uptime` at its start and end); `uptime > $L/t6-team-<n>.log && sh tools/run_team_match.sh >> $L/t6-team-<n>.log 2>&1; echo "exit=$?"; uptime >> $L/t6-team-<n>.log` for n = 1 to 5; `uptime > $L/t6-profile-<n>.log && sh tools/run_profile.sh >> $L/t6-profile-<n>.log 2>&1; echo "exit=$?"; uptime >> $L/t6-profile-<n>.log` for n = 1 to 3. **Loaded host:** before each run, if the 1-minute load is above 2.5, wait with a Monitor until-loop on `uptime` (at most 15 minutes); a run that starts or ends above 2.5 is tagged "host under load" and rerun once (`<n>b`); if the rerun is tagged too, keep both, and that run's wall-clock figures go to the morning list. The counts are kept either way: load cannot move them.
- [ ] **Step 3 (tabulate, verification file "Worst ticks after the changes (Task 6)"):**
  - Deterministic counts, per run: movement open / dense `queue_drain_ticks`, `path_cells_peak_window`, `path_capped_window`; hordes300 `full_scans_peak_window`, `reserved_window`; team `capped_ticks`, `max_cells`, `max_queue`, `max_decisions`; and SUITE(t6)'s `X2 ashfall` line. Identical in every run, else stop.
  - Wall-clock, per untagged run, then min / median / max and spread ((max − min) ÷ median): the 13 `WORST TICK` lines; `TEAM TIMING` max and p99; the `team_match` profile lines of `run_team_match.gd` (`opponent.decide`, `step.service_paths`, `step` max); hordes300 `step.combat_fire` max (`run_profile.sh`). Each against Task 0's single run.
  - Proposed wall-clock ceilings, **not installed** (a new wall-clock gate is a budget decision, the user's, like the G1 option in `performance.md` "Gate proposals"): worst untagged run + 5 % (the `STRESS_CEILING` rule, `run_combat.gd:9`); with fewer than three untagged runs, "no proposal (host under load)".

---

### Task 7: Count gates from Task 6's numbers (Question 14, gate)

```text
Task: turn the deterministic counts into gates in their benchmark rows by the rule below; wall-clock worst ticks stay report-only.
Owns: game/benchmarks/run_movement.gd, game/benchmarks/run_combat.gd, game/benchmarks/run_team_match.gd (gate constants and checks), tools/run_team_match.sh (one grep line), the verification file.
Invariant: no simulation or test file; traces equal *-t5.tsv; budgets, STRESS_CEILING, ASSUMED_SLOWDOWN and the pinned lines unchanged.
Boundary: every threshold is written into the verification file before any edit.
Red: each gate fails under its mutation (Step 3, scratch, reverted).
Green: sh tools/run_benchmark.sh exit 0 with its markers; sh tools/run_team_match.sh exit 0 with TEAM PATHS PASS; static gates; SUITE(t7) cmp silent against *-t5.tsv.
Stop: a gate fails on the unmutated tree (the rule or the measurement is wrong: Opus diagnosis, park; never raise a threshold to pass, AGENTS.md); Task 6's own value over a threshold.
```

- [ ] **Step 1 (thresholds, into the verification file "Count gates (Task 7)"):**

  | Figure | Row and file | Threshold | Rule |
  |---|---|---|---|
  | `queue_drain_ticks` open, dense | movement rows, `run_movement.gd` | 2 × Task 0's value | Question 15's requirement, now enforced by the row; Task 6's value must sit under it |
  | `path_cells_peak_window` open, dense | movement rows, `run_movement.gd` | `ceili(1.25 × Task 6 value)` | C |
  | `max_decisions` | team match row, `run_team_match.gd` | exactly 1 | §5.8's goal: the six seats (1, 2, 4, 5, 6, 8) are distinct mod 30, so no tick has two decisions, and at least one tick has one (the bots ran) |
  | `max_cells` | team match row, `run_team_match.gd` | `ceili(1.25 × Task 6 value)` | C |
  | `capped_ticks` | team match row, `run_team_match.gd` | > 0 | the budget's mechanics inside the timed ticks (after `WARMUP`) |
  | `full_scans_peak_window` | hordes300 row, `run_combat.gd` | `maxi(ceili(1.25 × Task 6 value), Task 6 value + 1)` | C |
  | X2 drain | `test_groups.gd` (Task 4) | work bound, already a test | structural |
  | every wall-clock worst tick | — | report-only; Task 6's proposal stands for the user | variance (Task 6 Step 3) |

  **Rule C:** the counts do not vary between runs (Task 6 proved it), so the 25 % is not for noise: it lets unrelated simulation changes, which move these chaotic workloads like any pin, pass, while the reversion each gate guards does not (Step 3 must show it). A gate its mutation does not trip is not installed: its count stays in the report line and the verification file says "report-only, mutation did not exceed".
- [ ] **Step 2 (edits):** each constant carries `# Deterministic counts measured on <tree> (Flatter worst ticks), rule in its plan: raise only with user approval and a ledger line.`
  - `run_movement.gd`: `const QUEUE_DRAIN_CEILING := {"open": <n>, "dense": <n>}` and `const PATH_CELLS_CEILING := {"open": <n>, "dense": <n>}`; after Task 4's `capped == 0` check:

    ```gdscript
    	if queue_drain > QUEUE_DRAIN_CEILING[layout] or cells_peak > PATH_CELLS_CEILING[layout]:
    		push_error("Benchmark: path queue drain or per-tick route cells over the ceiling for " + layout)
    		return false
    ```
  - `run_combat.gd`: `const HORDES_FULL_SCANS_CEILING: int = <n>` next to `STRESS_CEILING`; in the hordes300 block after Task 1's `window_reserved == 0` check:

    ```gdscript
    		if full_scans_peak > HORDES_FULL_SCANS_CEILING:
    			push_error("Combat benchmark: full-scan allocations in one tick over the ceiling for hordes300")
    			return false
    ```
  - `run_team_match.gd`: `const TEAM_PATH_CELLS_CEILING: int = <n>` and `const TEAM_DECISIONS_PER_TICK: int = 1`; `_paths_ok` becomes:

    ```gdscript
    func _paths_ok(paths: Dictionary) -> bool:
    	var ok: bool = paths.capped_ticks > 0 and paths.max_cells <= TEAM_PATH_CELLS_CEILING and paths.max_decisions == TEAM_DECISIONS_PER_TICK
    	print("TEAM PATHS ", "PASS" if ok else "FAIL", " capped_ticks=", paths.capped_ticks, " max_cells=", paths.max_cells, " ceiling=", TEAM_PATH_CELLS_CEILING, " max_queue=", paths.max_queue, " max_decisions=", paths.max_decisions)
    	if not ok: push_error("Team match: the path budget never bound, or per-tick route cells or bot decisions over the ceiling")
    	return ok
    ```
  - `tools/run_team_match.sh`, after the pinned `grep` (`:13`): `grep -Eq '^TEAM PATHS PASS ' "$log_dir/match.log" || exit 1`.
- [ ] **Step 3 (red by mutation, scratch, revert each with Edit, `git diff --stat` after):** judge each by its error line, not the exit code (a mutated match also fails the pinned line): (a) `PATH_CELLS_PER_TICK` 128: `godot --headless --path game --script res://benchmarks/run_movement.gd > $L/t7-red-a.log 2>&1`, `rg -n 'over the ceiling' $L/t7-red-a.log` hits (review: drain 150 at 128 against 2 × 38); (b) `PATH_CELLS_PER_TICK` 768: the same movement run (`t7-red-b.log`) and `sh tools/run_team_match.sh > $L/t7-red-b-team.log 2>&1`, both lines hit (derived: a tick may then charge up to 767 plus one route); (c) `Skirmish.decides` returns `tick % DECISION_TICKS == 0`: team match, `TEAM PATHS FAIL` with `max_decisions=6`; (d) `PATH_CELLS_PER_TICK` 1000000: team match, `capped_ticks=0`; (e) Task 1 Step 5 reverted and, for this run only, the `if window_reserved == 0:` block (its three lines) deleted, because with Step 5 reverted that check returns before the full-scan one: `godot --headless --path game --script res://benchmarks/run_combat.gd > $L/t7-red-e.log 2>&1`, `rg -n 'full-scan allocations' $L/t7-red-e.log` hits (Task 0's hordes300 `allocation_calls` max is the expected peak; `_run` measures hordes300 after any other row fails, but the block checks its own stress ceiling first: if that fails under load and the line is missing, rerun once); restore both edits. A mutation that does not trip its gate: Step 1's rule.
- [ ] **Step 4:** `SUITE(t7)`, `cmp` against `*-t5.tsv` silent; static gates (ShellCheck covers the `.sh` line); `sh tools/run_benchmark.sh > $L/t7-bench.log 2>&1` (exit 0, markers; loaded host as in Task 6 Step 2); `sh tools/run_team_match.sh > $L/t7-team.log 2>&1` (exit 0, `TEAM PATHS PASS`).

---

### Task D7: Steam Deck rows on the branch head (report-only)

```text
Task: the same rows as Task D0 on the branch head after Task 7; fetch, tabulate against Task D0, then remove everything the run put on the Deck.
Owns: files under $L/deck/ only, the verification file "Deck rows"; the ledger rows are Task 8's (or Step 4's follow-up).
Invariant: no repository file changes; the same job script, run count and Firefox flow as Task D0.
Boundary: the Mac export runs alone (Task 8's suite and benchmark wait for Step 2 to finish); the Deck job overlaps Tasks 8 and 9.
Red: n/a (measurement).
Green: STARTED or SKIPPED with the reason; later FETCHED, table filled, Deck folder removed.
Stop: none (as Task D0).
```

Runs after Task 7 is GREEN (or, if the main line parked earlier, after the last GREEN task) and before Task 8 is dispatched. It starts only when `ssh -o BatchMode=yes deck@<deck> systemctl --user list-units --all --no-legend 'wargrid-flatter*'` prints nothing (Task D0's job has ended); otherwise the coordinator dispatches Task 8 and retries this check after each later task. A Task 9 fix that changes `game/` makes these rows one commit stale: Task 9 records that in the morning summary, no rerun at night.

- [ ] **Step 1:** preflight as Task D0 Step 1 (leftover check skipped: `~/wargrid-flatter` is expected; it may lack `godot/` if Task D0 was skipped, then the job installs it). Record `cd <abs $W> && git rev-parse --short HEAD` as the after tree.
- [ ] **Step 2 (trees, export, push):** `cd <abs $W> && git worktree add --detach <abs $L>/deck/web-tree-after HEAD`; `cd <abs $W> && git archive --format=tar -o <abs $L>/deck/after.tar HEAD`; if Task D0 was skipped, write `<abs $L>/deck/deck-job.sh` as Task D0 Step 3. `ssh -o BatchMode=yes deck@<deck> mkdir -p wargrid-flatter/after`; `scp <abs $L>/deck/after.tar <abs $L>/deck/deck-job.sh deck@<deck>:wargrid-flatter/`; `ssh -o BatchMode=yes deck@<deck> tar -xf wargrid-flatter/after.tar -C wargrid-flatter/after` (fallback as Task D0 Step 4 with `web-tree-after` and `wargrid-flatter/after/`). Then Task D0 Step 5 with `web-tree-after`, `web-after-import.log`, `web-after-export.log`, `web-after` (the same one-line `hordes300` Edit in the scratch copy) and `scp -r <abs $L>/deck/web-after deck@<deck>:wargrid-flatter/web-after`.
- [ ] **Step 3 (start):** `ssh -o BatchMode=yes deck@<deck> systemd-run --user --collect --same-dir --unit=wargrid-flatter-after systemd-inhibit --what=sleep:idle --who=wargrid --why=benchmark sh wargrid-flatter/deck-job.sh after`; `ssh -o BatchMode=yes deck@<deck> systemctl --user is-active wargrid-flatter-after` prints `active`. Return `STARTED`; the coordinator dispatches Task 8 and waits as Task D0 Step 7 with `logs-after`.
- [ ] **Step 4 (fetch, tabulate, clean up):** `scp -r deck@<deck>:wargrid-flatter/logs-after <abs $L>/deck/logs-after`; tabulate as Task D0 Step 8 into `after-combat.txt`, `after-web.txt` and the "Deck rows" after column, with after ÷ base per row (the team match ends on Task 5's re-pinned tick on this tree, so its Firefox row is a different match length: say so next to the ratio). Then `ssh -o BatchMode=yes deck@<deck> rm -rf wargrid-flatter`; `ssh -o BatchMode=yes deck@<deck> systemctl --user list-units --all --no-legend 'wargrid-flatter*'` prints nothing; `ssh -o BatchMode=yes deck@<deck> ls .var/app/org.mozilla.firefox` lists no `wargrid-flatter-profile-*`; `ssh -o BatchMode=yes deck@<deck> pgrep -fl Godot_v4.7.2` prints nothing. `~/.local/share/godot` on the Deck is never touched (another project's data). If Task 8 has already passed its Step 2, this step also writes the two Deck History rows of Task 8 Step 2 (Edit in `$W`, docs only) and the coordinator commits them like a GREEN task.

---

### Task 8: Docs and package gate

```text
Task: docs describe the three changes and the count gates; the final tree passes every local gate; one ledger row plus the two Deck rows.
Owns: docs/guide/01-big-picture.md, 04-the-tick.md, 06-movement.md, 08-combat.md, 09-ai.md, 12-performance-and-platforms.md (tail sentence, gate table), 13-testing-and-tooling.md (performance paragraph), docs/guide/README.md (glossary line), docs/reference/determinism-rules.md (one clause), docs/reference/performance.md, docs/reference/simulation-reference-review.md, docs/reference/hordes300-combat-fire.md (status line), docs/STATUS.md, README.md (generated only), docs/reference/perf-history.csv (benchmark record only), the verification file.
Invariant: V7, V11; traces equal to *-t5.tsv.
Boundary: load average above 2.5 at the benchmark start (wait with a Monitor until-loop on uptime at most 15 minutes, else morning item).
Red: n/a.
Green: every command below on the final tree, each recorded with the tree it ran on.
Stop: a pin differs from Task 5; a budget or ceiling newly exceeded.
```

- [ ] **Step 1 (guide):** footers "Checked against" = `git rev-parse --short HEAD` at the start of this task; simple-to-complex order kept (`AGENTS.md`, codebase guide rule).
  - ch. 4: pipeline node 6 (`:17`) "answer route requests until PATH_CELLS_PER_TICK route cells"; step 9 (`:89`) and the group stagger arithmetic `(p-1)/8` (`:104`); the cap paragraph (`:134`): route cells per tick, a started search finishes, a failed search spends the tick, Zero Hour's searched-cell budget, P5's node budget replaces it later, measured before and after (`service_paths` max, `queue_drain_ticks`); `:138`: bot seats staggered by seat number, measured `opponent.decide` max before and after; tail ticks: the hordes300 `combat_fire` spike and its fix in one sentence; files list (`:156`): `PATH_CELLS_PER_TICK`, `path_cells`.
  - ch. 9: diagram node (`:10`) "a bot state per seat, on the seat's own tick"; steps 1-2 (`:33-35`): `decides`, `decide`, `bot_state`; Cost paragraph (`:132`) with the new measured max; files (`:144`).
  - ch. 8: the "Big splash fights" paragraph's speculation about `object_removed` (`:195`) becomes the measured cause and fix (link the hordes300 note); retaliate paragraph (`:111-112`) code trail gains `object_removed → _begin_reservations`; files list.
  - ch. 6 (diagram node `:14` "8 requests per tick", the six-tank example `:39`, the shortcut bullet `:84`, files `:98`) and ch. 1 (`:103`): the constant's new name and meaning; README glossary "Path request" (`:102`): "answered up to a budget of route cells per tick".
  - ch. 12 (`:91`): the tail sentence with the new team-match worst tick; the gate table's `run_benchmark.sh` row (`:47`): the movement rows fail if the path budget never bound or the queue drain or per-tick route cells pass their ceilings, and hordes300 fails if no retaliator went home through the reservation map inside the timed window or full-scan allocations in one tick pass their ceiling; `run_team_match.sh` row (`:50`): "pins the outcome line and the `TEAM PATHS` counts (the budget bound, per-tick route cells, one bot decision per tick), not the time"; `run_profile.sh` stays "no, reports only" (`:48`); one sentence that wall-clock worst ticks are reported, not gated, with the measured spread.
  - ch. 13 (`:82`): the performance paragraph names the `TEAM PATHS` line next to the `WORST TICK` lines (ch. 13 is outside Question 16's list, which predates the count gates; the guide rule in `AGENTS.md` asks for it).
- [ ] **Step 2 (references):** `determinism-rules.md` "Order": one clause that the retaliator reservation map is read only through `has`. `performance.md`: the watch-item paragraph (`:55`) gets the new team-match and hordes300 worst ticks; "Mechanics inside the window" (`:161`) gets the two new benchmark checks with their window counts and red-first evidence; a short "Count gates (Flatter worst ticks)" paragraph beside "Gate proposals": each Task 7 figure, its threshold, rule and mutation evidence, plus Task 6's wall-clock spread and proposed ceilings labelled "proposed, needs the user's decision"; one hand-written History row (team match `step` / `opponent.decide` / `service_paths` max, hordes300 `combat_fire` and benchmark `WORST TICK`, movement `queue_drain_ticks`, before and after, linking the verification file), plus two hand-written Deck History rows beside `:137-138`, report-only, each "before (base `4c21d1a`) / after (branch head of Task D7)", median of 3 [range]: (1) Deck native headless (Godot 4.7.2 Linux editor build checked against the CI SHA-256, one `systemd-run --user` unit under `systemd-inhibit`, ACAD and load range): hand-off sums per workload from `run_profile.gd` and combat p95 / p99 per layout from `run_combat.gd`; (2) Deck Firefox 160 (flatpak), `Web Bench` single-threaded export with `hordes300` added in the scratch copy only, `crossOriginIsolated` checked, fresh profile per run, window on the Deck approved by the user: team match to its end tick, combat open, dense and hordes300, p50 / p95 [range] / p99, against 10 / 20 ms on target, and a note that 160 replaces the 159 of the earlier rows. A row Task D0 or D7 could not fill says "not run: <reason>"; if Task D7 has not finished, Task 8 writes the base half and Task D7 Step 4 adds the after half. `simulation-reference-review.md` "Review 2026-11-13": one line that §5.8 and §5.2's smaller alternative are implemented on branch `flatter-worst-ticks`. `hordes300-combat-fire.md` status: "fix shipped on branch `flatter-worst-ticks` with the cross-check test (RS1, RS3)". `docs/STATUS.md` night 4 row (`:26`): "implemented on branch `flatter-worst-ticks` (local, not pushed); one trace re-pin; CI, Windows and browser unverified". Then `python3 tools/roadmap.py` and `python3 tools/roadmap.py --check` exit 0; `sh tools/check_public.sh` exit 0; relative links in changed docs resolve; `rg -n 'PATH_REQUESTS_PER_TICK' docs/guide docs/reference/sim-interface.md` prints nothing.
- [ ] **Step 3 (gates):** `SUITE(final)`, `cmp` against `*-t5.tsv` silent; static gates; `sh tools/run_conformance.sh`; `sh tools/run_netplay.sh` `match`, `perturb`, `relay-down`, `relay-term`; `sh tools/run_team_match.sh`; `sh tools/run_profile.sh` (PROFILE COMPLETE 10, record the package's numbers); `git diff --stat main -- game/scripts/presentation game/scenes game/scripts/match game/scripts/net game/benchmarks/bench_runner.gd game/export_presets.cfg relay protocol game/data .github` empty.
- [ ] **Step 4 (benchmark, alone, last):** `pgrep -fl 'godot|generalszh'` shows none of this run's processes; `uptime`; `PERF_LABEL="Flatter worst ticks" sh tools/run_benchmark.sh > $L/t8-bench.log 2>&1`. Expected `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, `recorded … rows`, and only the accepted `BUDGET EXCEEDED` line. No rendered rerun: presentation unchanged (Step 3's diff empty).
- [ ] **Step 5:** resume record names the morning items ("Unverifiable at night").

---

### Task 9: Fresh-context branch review (Opus, high)

- [ ] One fresh Opus (high) reviewer gets `git diff main...HEAD`, the changed paths, this plan's "Review focus", "Determinism notes", "Same-tick and interaction cases", "Allowed test edits" and "Re-pin list", the verification file, and the instruction to name, per new or rewritten test (RS1-RS3, BS1, BS2, BT1, PB1-PB4, X2, X2r / X2m, PB5 if the fallback stayed, G8, A2, K2 (T4), the T1 conversions of the negative checks, the snapshot ceiling change, the two benchmark mechanics checks, Task 7's count gates), the production change that would make it fail. No repo-wide search.
- [ ] Fix critical and important findings in one round, test-first, by a Sonnet subagent; rerun the affected checks and the full suite with trace `cmp` against `*-t5.tsv`; list minor findings in the morning summary. A fix that moves a pin is a stop (no second re-pin at night). Then one `/ponytail-review` pass on the diff (over-engineering only); apply cuts, re-verify.

## Questions

Zero Hour citations: `~/projects/CnC_Generals_Zero_Hour` at `0a05454`, `GeneralsMD/Code/GameEngine/`. Every question is decided (user, 2026-11-14, two rounds); the plan follows each decision.

1. **Bot state shape:** recommend dict rows with only the fields the bot reads (`bot_state()`, bot code unchanged, proven by every pin staying put in Task 2); alternatives: `view_state()` rows plus `last_sequences` (rewrites every bot reader), a full snapshot per seat (about +0.09 ms on the team-match mean, review §5.8), one snapshot reused across the 30-tick window (stale, and command ticks would need re-stamping); Zero Hour's AI reads live objects, no copy (`Source/GameLogic/AI/AIPlayer.cpp:2195`, `:3039`, `for( obj = TheGameLogic->getFirstObject(); obj; obj = obj->getNextObject() )`). **Decided:** as recommended (user, 2026-11-14).
2. **Bot state cost gate:** recommend `bot_state` at most half a `snapshot` at team-match tick 6000, else park Tasks 3-9 for the morning (no silent switch to a full snapshot per seat); no Zero Hour default. **Decided:** as recommended (user, 2026-11-14).
3. **Bot entry points:** recommend the staggered `issue_opponents`, a public ungated `decide(sim, player, attack_tick)` for single-shot callers, and `decides` / `next_decision` helpers, so tests keep their states; alternative: tests step to each seat's tick (changes the state they check); Zero Hour keeps a per-player countdown (`AIPlayer.cpp:2916-2922`, `m_teamDelay--; if (m_teamDelay<1) { queueUnits(); … m_teamDelay = 5*LOGICFRAMES_PER_SECOND; // check again in 5 seconds.`), all starting at 0 (`:80` `m_teamDelay(0),`; `:120` `m_teamDelay = 0; // Cause the update queues & selection to happen immediately.`) and reset to 0 by events (`:415`, `:1137`, `:1645`, `:2519`, `:2910`, `:3186`), so AI players start in step and only drift apart; no deliberate stagger found. Wargrid's seat stagger is its own choice. **Decided:** as recommended (user, 2026-11-14).
4. **Path budget value:** recommend 384 route cells per tick (review recommendation, measured 2026-11-14 on scratch copies of `74950e5`): the smallest measured value that keeps movement `queue_drain_ticks` under 2× today (dense 60 against 38; 256 gives 81, 320 gives 75, 512 gives 44); team match worst per-tick searched cells 102413 → 31739 (256: 26805). Searched ÷ route is about 3.0 on the synthetic maps but 20.3 on Ashfall (per-request p95 28.6), so 256 binds on 1653 of 6220 team-match service ticks and trips Question 15. Alternatives: 256 with Question 15's rule raised to 2.5×, or 512. Zero Hour: `PATHFIND_CELLS_PER_FRAME=5000` searched cells (`Source/GameLogic/AI/AIPathfind.cpp:1103`) at 30 logic frames a second (`Include/Common/GameCommon.h:72`) on 10-unit cells (`Include/GameLogic/AIPathfind.h:439`); a Wargrid cell is 25 units (`tools/zh_map/convert.py:18`), so about 800 Wargrid cells searched per tick, which at Ashfall's ratio is about 40 route cells, one long route a tick: not workable for group starts, so Zero Hour equivalence cannot set the value. **Decided:** as recommended (user, 2026-11-14, round 1).
5. **Failed search charge:** recommend the whole budget (nothing else starts that tick); alternatives one cell, or nothing; Zero Hour counts every cell on the open and closed lists of each search, found or not (`AIPathfind.cpp:4812-4822`, `m_cumulativeCellsAllocated += count;`). **Decided:** as recommended (user, 2026-11-14).
6. **Budget carry-over:** recommend none, each tick starts at zero; Zero Hour resets the count every frame (`AIPathfind.cpp:5923`, `m_cumulativeCellsAllocated = 0;`) and stops starting requests once it reaches the budget (`:5927`). **Decided:** as recommended (user, 2026-11-14).
7. **What counts as a route cell:** recommend the size of `grid_navigation.route`'s result; alternatives the stored route after the behind-pop, or a Manhattan estimate before the search (would allow skipping a long search but breaks "a started search finishes"); Zero Hour counts searched cells, which `AStarGrid2D` does not report. **Decided:** as recommended (user, 2026-11-14).
8. **Re-requested unit's queue place:** recommend keeping today's erase-and-append (Task 4 Step 6 measures starvation); alternative: keep its slot; Zero Hour keeps an already queued unit's slot (`AIPathfind.cpp:5663-5667`, "Check & see if we are already queued."). **Decided:** keep erase-and-append; the user accepts the back of the queue if starvation is judged unlikely (user, 2026-11-14). Task 4 Step 6 holds the falsifiable criterion (re-appends per unit, max wait, max queue, with the threshold derived from the 384 budget and X2's drain) and the pre-written keep-the-slot fallback; a fallback that moves a check outside R and P1 is reverted and Task 4 parks.
9. **Reservation cross-check form:** recommend a private `_check_reservations` flag with two counters in `simulation.gd`, off by default and set only by tests; alternatives `assert` (runs in every debug-build benchmark and pays the scan it saves) or a test-only subclass; no Zero Hour default. **Decided:** as recommended (user, 2026-11-14).
10. **Commits with red pin checks:** recommend Tasks 3 and 4 each committed with only R's checks red and Task 5 as the one re-pin commit; alternative one commit for Tasks 3-5 (not resumable); no Zero Hour default. **Decided:** as recommended (user, 2026-11-14).
11. **Outcomes after the re-pin:** recommend any deterministic `won` inside the 45000 cap, any winner, for the team match and for the S1, China and FRC pins (Question 20); alternative require today's winners (turns the re-pin into a balance gate); no Zero Hour default. **Decided:** as recommended (user, 2026-11-14, round 1).
12. **Match caps:** recommend a new outcome past `CHINA_TICK_CAP`, `FRC_TICK_CAP` (FRC sits at 48321 of 50000), the team cap or outside the S1 window is a stop; caps never raised; alternative raise the cap; no Zero Hour default. **Decided:** as recommended (user, 2026-11-14, round 1).
13. **Review X2 row "group order across Ashfall":** recommend skipping it (not in the package note; the review measured the budget binding on Ashfall, 847 of 6319 service ticks at 384, and the team-match `PROFILE_PATHS` line reports it); alternative build it (review §6); no Zero Hour default. **Decided:** build it (user, 2026-11-14): X2 and X2r / X2m in Task 4 (`test_groups.gd`), deterministic, the budget binding asserted, held to the work bound ceil(route cells ÷ budget) because Question 15's 2× rule cannot hold for cross-map routes (derived: about 3.9× today's group start; a morning feel item).
14. **Worst-tick targets:** recommend report only (worst tick is a watch item without a gate; derived expectations about 1.4 ms `opponent.decide`, at most about 3.3 ms `service_paths` (derived for 256; at 384 the worst per-tick search is 31739 cells against 26805, measured, so somewhat higher), about 1.1 ms hordes300 `combat_fire`); alternative gate them; no Zero Hour default. **Decided:** measure first, then gate (user, 2026-11-14): Task 6 measures five runs on the final tree, Task 7 gates the deterministic counts in their benchmark rows by its stated rule, wall-clock worst ticks stay report-only with proposed ceilings for the user.
15. **Group start stop rule:** recommend parking Task 4 if movement open or dense `queue_drain_ticks` more than doubles against Task 0 (then the budget is the user's call); measured: 384 gives 60 against 38 (1.58×), 256 gives 81 (2.13×, fires), so the rule and Question 4's value are settled together; alternative record only; no Zero Hour default. **Decided:** as recommended (user, 2026-11-14, round 1). It applies to the movement open and dense rows; X2 on Ashfall is held to the work bound instead (Question 13).
16. **Guide scope:** recommend chapters 1, 4, 6, 8, 9, 12 and the README glossary (each names the constant or the behaviour), beyond the package note's chapters 4 and 9; no Zero Hour default. **Decided:** as recommended (user, 2026-11-14). Task 8 also updates ch. 13 for the count gates, which the answer predates (guide rule, `AGENTS.md`).
17. **Budget value against group starts:** recommend 384 under Question 15's 2× rule (with the 8-request cap gone a 300-unit order drains in 60 ticks at 384, 81 at 256, today 38); alternative 256 with the rule raised to 2.5×; Zero Hour has no group-start number to follow (its 5,000 searched cells a frame, `AIPathfind.cpp:1103`, are about 40 route cells at Ashfall's measured search ratio). **Decided:** as recommended (user, 2026-11-14, round 1).
18. **K2 and the skirmish screen:** recommend the T4 test edit (the screen's opponent now first decides at tick 2, and the check asserts that); alternative let the screen script call `decide` on tick 0 (touches a don't-touch screen script, and the screen's bot would then differ from the netplay seat's); no Zero Hour default. **Decided:** as recommended (user, 2026-11-14).
19. **Where the mechanics assertions live:** recommend the benchmark rows (hordes300 fails without a batched home allocation in its timed window, movement fails if the path budget never bound), the profile staying report-only as `docs/development.md:86` says; alternative checks in the profile (then it stops being report-only and `docs/development.md` and guide ch. 12 change); no Zero Hour default. **Decided:** as recommended (user, 2026-11-14, round 1).
20. **Winners may flip:** recommend "any winner inside the cap" for all three skirmish pins (Question 11 extended): measured, the China winner flips to 1 at 384 and the FRC winner flips with the 256 budget alone; alternative keep today's winners as a gate; no Zero Hour default. **Decided:** as recommended (user, 2026-11-14, round 1).
21. **Counting searched cells for real:** recommend evidence only, in Task 4 Step 1's scratch tree: the `_estimate_cost` override counts searched cells exactly and deterministically but adds a script call per searched cell (cost unmeasured), and P5's node budget is the real fix (decided); alternative ship the override and budget searched cells; Zero Hour counts searched cells on its open and closed lists (`AIPathfind.cpp:4812-4822`, `m_cumulativeCellsAllocated += count;`). **Decided:** as recommended, evidence only (user, 2026-11-14).

## Decisions this plan relies on

- Package scope and "one trace re-pin for both" (user, 2026-11-13, package note "Flatter worst ticks").
- §5.8 with a light per-bot state and §5.2's smaller alternative in this package (user, 2026-11-13, review "Review 2026-11-13").
- The hordes300 retaliator fix here, with the cross-check test (user, 2026-11-13, Sim quick wins plan Question 6).
- Exceeded `open`, `dense` and `hordes300` rows accepted, never loosened (user, 2026-11-07 and 2026-11-14, performance ledger).
- P5's node budget and deferred delivery replace the route-cell cap later (user, 2026-11-13, design answers "Movement design inputs").
- Questions 4/15/17 (budget 384 route cells per tick), 11/20 (any winner inside the cap, for the team match and the three skirmish pins), 19 (mechanics assertions in the benchmark rows, profile stays report-only) and 12 (a match ending past its cap is a stop, caps never raised) answered as recommended (user, 2026-11-14, round 1).
- Questions 1-3, 5-7, 9, 10, 16 and 18 confirmed as recommended, Question 21 as recommended (evidence only) (user, 2026-11-14, round 2).
- Question 8: keep erase-and-append if starvation is judged unlikely, with the Task 4 Step 6 criterion and fallback; Question 13: build the X2 check; Question 14: measure first, then gate (user, 2026-11-14, round 2).
- Steam Deck rows before (base) and after (final branch tree), report-only, three runs each, never gating or blocking: native headless profile and combat rows and Deck Firefox 160 `Web Bench`; a window on the Deck screen is approved for tonight; if the export, the Firefox launch or isolation fails, record it, run the native rows only and make Firefox a morning item (user, 2026-11-14 evening).

## Added after planning (user, 2026-11-14)

- Sim quick wins review minor 12, moved here: `combat.splash_index` grows 3.1-3.9x per doubling of units (expected about 2x), cause unknown. In Task 0 Step 6 (profile before), from the same `PROFILE` lines, record `Profiler.calls(&"combat.splash_index")` and the mean zone time per workload size, and say whether calls or per-call cost grow. Evidence only: no fix in this package unless the user decides one.
