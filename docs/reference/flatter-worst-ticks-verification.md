# Flatter worst ticks verification

```text
Resume record (updated 2026-11-14 at the refresh onto 4c21d1a; no task run yet)
Branch / base commit / working-tree state: flatter-worst-ticks (not created; Task 0 creates it and ~/projects/wargrid-wt-flatter from main) / main 4c21d1a / n/a
Last green task / next incomplete task: none / Task 0
Changed paths since last commit: none on the branch (this file and the plan are new in ~/projects/wargrid, uncommitted)
Last command / cases / checks / failures / exit / marker: none on the branch (the review's measurements ran on scratch copies of 74950e5; evidence rows below)
Known red case or blocker: plan approval pending (external readiness review applied 2026-11-14, evidence row below). All 21 Questions decided (user, 2026-11-14). Night settings re-checked at the refresh: worktree folder and Edit rule, compare_replays.py, python3 -I for $L scripts, mkdir -p under flatter-worst-ticks, ssh/scp to the Deck present; $L exists; git status, diff, log, add, commit and archive not named (the handoff's proposed copy adds them; scp fallback in Task D0 Step 4)
Approved decisions, pre-authorizations used, deferred gates: package note "Flatter worst ticks" (user, 2026-11-13); local commits per GREEN task only if the night handoff grants them; benchmark only if the handoff pre-approves it; no budget, ceiling or ASSUMED_SLOWDOWN touched; budget 384 route cells (user, 2026-11-14, round 1); X2 built, erase-and-append kept under the Task 4 Step 6 criterion, worst ticks measured then gated where deterministic (user, 2026-11-14, round 2); Steam Deck rows D0 and D7 report-only, a window on the Deck approved for tonight, Firefox fallback to native rows only (user, 2026-11-14 evening)
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 0 Step 1 (worktree from main 4c21d1a), then Task D0 before Task 1
```

Plan: [Flatter worst ticks plan](../superpowers/plans/2026-11-14-flatter-worst-ticks.md) (refreshed onto `4c21d1a`). Spec: `docs/packages.md` night lane item 4 and package note "Flatter worst ticks"; `docs/reference/simulation-reference-review.md` §5.2, §5.8, "Review 2026-11-13"; `docs/reference/hordes300-combat-fire.md`. Logs: `~/projects/wargrid-overnight-work/flatter-worst-ticks/logs/` (outside the repository). Deck logs: `$L/deck/`.

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins and R census, profile, benchmark, team match, netplay match | Sonnet | not started |
| D0 | Steam Deck rows on the base (start; fetch when done), report-only | Sonnet | not started |
| 1 | Retaliators sent home through one reservation map (RS1-RS3), hordes300 benchmark mechanics check | Sonnet | not started |
| 2 | Bot state, old gate (BS1, BS2), cost probe | Sonnet | not started |
| 3 | Bot seats on their own tick (BT1), test edits T1-T4 | Sonnet | not started |
| 4 | Path budget by route cells (PB1-PB4, X2), movement benchmark mechanics check, queue-place criterion (Question 8) | Sonnet | not started |
| 5 | The one re-pin | Sonnet | not started |
| 6 | Worst ticks after the changes: count lines, five measured runs | Sonnet | not started |
| 7 | Count gates from Task 6's numbers, red by mutation | Sonnet | not started |
| D7 | Steam Deck rows on the branch head (start; fetch and clean up when done), report-only | Sonnet | not started |
| 8 | Docs and package gate (ledger row) | Sonnet | not started |
| 9 | Fresh-context branch review, one fix round, `/ponytail-review` | Opus (high) | not started |

## Baseline (Task 0)

| Item | Value |
|---|---|
| Tree | |
| `uptime` at start / end (suite, profile, benchmark) | |
| Full suite: wall seconds, CASES, CHECKS, exit | |
| Trace files (`replay`, `economy`, `combat`, `team` `-before.tsv`), line counts | |
| Anchor drift against the plan | |
| `issue_opponent(s)` callers (count, files) | |
| Profile: team match `step` mean / max | |
| Profile: team match `opponent.decide` max, calls per tick; `snapshot` mean / max | |
| Profile: team match `step.service_paths` max, `route` max; top `PROFILE_SLOW` lines | |
| Profile: hordes300 `step.combat_fire` max, `assign_move.unavailable` max, `allocation.assign` max, `step` max | |
| Benchmark: `WORST TICK` lines; combat p95 / p99 per row | |
| Benchmark: movement open / dense `queue_peak`, `queue_drain_ticks` (Task 7's drain ceiling = 2 × these) | |
| Benchmark: hordes300 `allocation_calls` max (every allocation a full scan before Task 1; Task 7 mutation (e) reference) | |
| `run_team_match.sh` line; `TEAM TIMING` max and p99; `team_match` profile `opponent.decide`, `step.service_paths`, `step` max (one run) | |
| `run_netplay.sh match` terminal tick | |

## Pinned values and Re-pin list

Final R (Task 0 Step 4; fixed afterwards):

| # | Pin | Expected (on `4c21d1a`, same as on `74950e5`) | Task 0 | In R | Task 1 | Task 2 | Task 3 | Task 4 | Task 5 new value | Tasks 6-8 |
|---|---|---|---|---|---|---|---|---|---|---|
| V1 | `FINAL_DIGEST` | `3958ceaab11986af` | | yes | | | | | | |
| V2 | `TEAM_CORE_SERIES` | `8513092129969516499` | | yes | | | | | | |
| V3 | `S1_CORE_SERIES`, `TERMINAL_TICK`, `WINNER` | `4004499097874677431`, `8753`, `1` | | yes | | | | | | |
| V4 | `CHINA_TERMINAL_TICK`, `CHINA_WINNER`; `FRC_TERMINAL_TICK`, `FRC_WINNER` | `11578`, `2`; `48321`, `1` | | yes | | | | | | |
| V5 | `test_state_hash.gd` `PINNED` | `01e256834bdd4dfb` | | yes | | | | | | |
| V6 | `test_view_rows.gd` `EXPECTED_DIGEST` | `7c7fbc8d…48a9e7` | | yes | | | | | | |
| V7 | `SS6_PINNED` | unchanged | | **no** | | | | | | |
| V8 | four traces | `*-before.tsv` through Task 2; `*-t5.tsv` from Task 5 | | yes | | | | | | |
| V9 | netplay match terminal tick | `9129` | | yes | | | | | | |
| V10 | `run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | | yes | | | | | | |
| V11 | `git diff … -- game/tests \| rg '^-\s*const'` | empty before Task 5; R lines only after | | — | | | | | | |
| V12 | `test_skirmish_scene.gd` `HUD_TEXTS` (HUD1, `:646`) | as on the base | | yes (moves with the stagger, review) | | | | | | |
| V13 | `input_script_rows.gd` `IC1_ROWS`, `IC2_ROWS` | as on the base | | yes by the census rule (expected not to move, derived) | | | | | | |
| (census) | pins added by the Task 0 rule (`test_dock_lock.gd` `COMMAND_ROWS` is a command-name list, outside R) | | | | | | | | | |

Bounds that never move (checked at Task 5): `CHINA_TICK_CAP` 45000, `FRC_TICK_CAP` 50000, S1 window 7000-17999, team match cap 45000. Any winner inside them (plan Questions 11, 20).

Non-pin checks that go red and their allowed edit (review, measured on `74950e5`): 21 bot cases in `test_skirmish.gd`, `test_skirmish_waves.gd`, `test_factions.gd`, `test_playtest_replay.gd` (T1-T3); K2 `test_skirmish_scene.gd:48` on `4c21d1a` (`:45` on `74950e5`) (T4); G7, G8, BM5 per-unit (P1). A2 stays green (rewritten anyway). Converted by census although green: `test_skirmish.gd:195`, `:258` (checks; calls `:194`, `:257`), `test_factions.gd:248` (vacuous under the stagger).

## Reservation map (Task 1)

| Item | Value |
|---|---|
| Red (stub counters) | |
| Green: `test_combat` cases / checks / failures | |
| RS1 checks / mismatches; RS3 checks / mismatches and seconds | |
| Mutations (a)-(c) | |
| Combat benchmark red with the fix reverted (`no retaliator was sent home through the reservation map inside the timed window`, exit 1) | |
| Combat benchmark green: `COMBAT BENCHMARK PASSED 10`, hordes300 `reserved_window` | |
| hordes300 `step.combat_fire` max before / after (probe: 5.403 → 1.067 ms) | |
| hordes300 `allocation.reserved` max and calls; `assign_move.unavailable` max; `step` max | |
| Digest script (`$L/t1-digest.gd`) `main` against branch | |
| Suite and traces | |

## Bot state (Task 2)

| Item | Value |
|---|---|
| Field census (fields `skirmish.gd` reads from the state) | |
| Red on the stub | |
| BS1 comparisons per world; contained and hole rows seen | |
| Cost probe: µs per `snapshot()` / per `bot_state()` at team match tick 6000 (best of three rounds of 100), ratio, entities; `PROBE DONE` seen | |
| Gate (ratio at most 0.5; review measured 0.25): met / not met | |
| Mutations | |
| Suite, traces `cmp` against `*-before.tsv`, team match and netplay match lines | |

## Stagger (Task 3)

| Item | Value |
|---|---|
| BT1 red on Task 2 code; green | |
| Allowed test edits applied (file:line, kind T1 / T2 / T3 / T4); T1 census count | |
| `decide` no-op mutation: O1, A3, B1 positive checks red | |
| Red checks after the edits (must all be R; value reported) | |
| Team match line (exit 1 expected on the pin; `won` below 45000) | |
| team match `opponent.decide` max and calls per tick; `bot_state` mean / max; `step` mean / max | |

## Route cells (Task 4)

Expected from the review (today's cap; `verify-copy/logs/p-*-b0.tsv`): team match 14726 requests, route 7 / 185 / 280, searched 20 / 3759 / 16397, searched ÷ route 20.3, per-tick searched max 102413, max queue 153; movement searched ÷ route 3.00 (open), 4.54 (dense).

| Scenario | requests | route cells per request p50 / p95 / max | searched cells per request p50 / p95 / max | searched ÷ route | per-tick route sum p99 / max | per-tick searched max | ticks with more than 8 requests | max queue length |
|---|---|---|---|---|---|---|---|---|
| team match (V10 line unchanged by the probe: yes / no) | | | | | | | | |
| movement open (one leg) | | | | | | | | |
| movement dense (one leg) | | | | | | | | |
| combat open | | | | | | | | |
| combat dense | | | | | | | | |
| combat hordes300 | | | | | | | | |

| Item | Value |
|---|---|
| PB1-PB4 red on today's cap (stub `path_cells`) | |
| Rewritten checks (G7 → PB1, G8, A2, snapshot ceiling step: drain step, totals, busiest unit) | |
| Mutations (a)-(c) | |
| Movement benchmark red on the stub (`path budget never bound`, exit 1); green `path_capped_window` open / dense | |
| `PROFILE_PATHS team_match` (capped ticks, max cells; review: 847 at 384) | |
| team match `step.service_paths` max, `route` max, `step` max, `opponent.decide` max | |
| Movement `queue_peak` / `queue_drain_ticks` open, dense (Task 0 → Task 4; stop if more than double; review: dense 38 → 60 at 384) | |
| Combat p95 / p99 per row; `WORST TICK` lines | |
| Red checks in the suite (must all be R; value reported) | |
| Team match line | |

X2 (derived expectation, plan "Expected values": today 23 ticks; at 384 about 90, between 89 and 132; at least about 34200 route cells):

| Item | Today (Step 2, 8-request cap) | Task 4 (384) |
|---|---|---|
| `X2 ashfall` `drain_ticks` / `route_cells` / `max_queue` / `capped_ticks` / `searches` | | |
| X2 checks red on today's code (only the per-tick budget rule expected) | | — |
| X2r / X2m checks | | |
| Mutation (d) `PATH_CELLS_PER_TICK` 1000000: "X2 the budget bound" red | — | |
| Case seconds (both X2 cases; `CASE_SECONDS` entries added) | | |
| Drain ratio against today (morning feel item) | — | |

## Queue place (Task 4, Question 8)

| Scenario | requests | drain | max_queue | max_wait | p99_wait | max_reappends | units_reappended |
|---|---|---|---|---|---|---|---|
| team match, probe tree (today's cap) | | — | | | | | |
| team match, `$W` | | — | | | | | |
| movement open (one leg) | | | | | | | |
| movement dense (one leg) | | | | | | | |
| X2 | | | | | | | |

| Criterion | Value | Met |
|---|---|---|
| (a) movement and X2: `max_reappends == 0`, `max_wait == drain` | | |
| (b) team: `max_reappends <= max(2, today's)` | | |
| (c) team: `max_wait <= 3 × X2 drain_ticks` | | |
| Fallback (keep the chaser's slot): not needed / applied (PB5 red first, then green; suite red only on R and P1) / reverted and Task 4 parked (why) | | |

## Re-pin (Task 5)

| Pin | Old | New | Read from |
|---|---|---|---|
| | | | |

Sanity row (review, measured on scratch copies with stagger plus budget; a different number means the change differs from the review's model, for example a field missing from `bot_state`): at 384: S1 8626 / 1, China 24757 / **1**, FRC 37178 / 1, team `won` 38786 / 2 (`units_peak` 268), netplay match not run, HUD1 not recorded; at 256: S1 9685 / 1, China 12085 / 2, FRC 17372 / 1, team 34412 / 2, netplay 8782.

| Item | Value |
|---|---|
| Bounds (China, FRC, S1 window, team cap) | |
| `SUITE(t5)` and `SUITE(t5b)`: cases / checks / failures; trace `cmp` t5 against t5b | |
| Netplay probe on the old literal: terminal tick N; `compare_replays.py` s1 against s2 (`REPLAYS MATCHED`, or refused) | |
| Team match; netplay `match` (seats and oracle agree), `perturb`, `relay-down`, `relay-term`; conformance | |
| `git diff --stat <Task 4 commit>`; V11 | |
| Re-pin commit hash | |

## Worst ticks after the changes (Task 6)

Tree: . Runs alone; `uptime` at start / end per run; tagged runs ("host under load") rerun once.

| Run | benchmark load start / end, exit | team match load, exit | profile load, exit |
|---|---|---|---|
| 1 | | | |
| 2 | | | — (3 runs only) |
| 3 | | | |
| 4 | | | — |
| 5 | | | — |

Deterministic counts (must be identical in every run; a difference is a stop):

| Count | Row | Value (all runs) |
|---|---|---|
| movement open / dense `queue_drain_ticks` | `run_movement.gd` | |
| movement open / dense `path_cells_peak_window`, `path_capped_window` | `run_movement.gd` | |
| hordes300 `full_scans_peak_window`, `reserved_window` | `run_combat.gd` | |
| team `capped_ticks`, `max_cells`, `max_queue`, `max_decisions` | `run_team_match.gd` | |
| `X2 ashfall` line (SUITE(t6)) | `test_groups.gd` | |

Wall-clock (untagged runs; report-only):

| Figure | Task 0 | min / median / max | spread | proposed ceiling (worst + 5 %, not installed) |
|---|---|---|---|---|
| `WORST TICK` movement open / dense | | | | |
| `WORST TICK` combat hordes300, contact (and the other 9 lines) | | | | |
| `TEAM TIMING` max / p99 | | | | |
| team `opponent.decide` max | | | | |
| team `step.service_paths` max | | | | |
| team `step` max | | | | |
| hordes300 `step.combat_fire` max (`run_profile.sh`) | | | | |

## Count gates (Task 7)

| Figure | Row and file | Task 6 value | Threshold (rule) | Mutation | Red seen | Installed |
|---|---|---|---|---|---|---|
| `queue_drain_ticks` open / dense | `run_movement.gd` | | 2 × Task 0 | (a) budget 128 | | |
| `path_cells_peak_window` open / dense | `run_movement.gd` | | ceil(1.25 ×) | (b) budget 768 | | |
| `max_decisions` | `run_team_match.gd` | | exactly 1 | (c) shared tick | | |
| `max_cells` | `run_team_match.gd` | | ceil(1.25 ×) | (b) budget 768 | | |
| `capped_ticks` | `run_team_match.gd` | | > 0 | (d) budget 1000000 | | |
| `full_scans_peak_window` | `run_combat.gd` | | max(ceil(1.25 ×), +1) | (e) Task 1 Step 5 reverted | | |
| Green: `SUITE(t7)` `cmp` against `*-t5.tsv`; benchmark; team match `TEAM PATHS PASS`; static gates | | | | | | |

## Deck rows (Tasks D0 and D7, report-only)

Never a gate (user, 2026-11-14). Deck address: night handoff only. Logs: `$L/deck/logs-base/`, `$L/deck/logs-after/`.

| Item | Base (Task D0) | After (Task D7) |
|---|---|---|
| Tree | `4c21d1a` | |
| Preflight (ACAD, Desktop Mode, Firefox version, load) | | |
| Godot install: SHA-256 checked (`install.log`) | | (reused or installed) |
| ACAD at every edge; Deck load range (`edges.txt`) | | |
| `FAILED` / `SKIPPED` edge lines | | |
| Native profile x3: `PROFILE COMPLETE 10` each; hand-off sum per tick per workload, median [range] | | |
| Native combat x3: ten `COMBAT` lines each; p95 median [range] / p99 per layout | | |
| Web Bench export (exit, files); `hordes300` added in the scratch copy | | |
| Firefox runs: `cross_origin_isolated=true`, `BENCH DONE`, UA version | | |
| Firefox: team match (end tick) p50 / p95 [range] / p99 / max | | |
| Firefox: combat open, dense, hordes300 p50 / p95 [range] / p99 | | |
| After ÷ base per row | — | |
| Deck cleaned up (folder, units, profiles, no Godot process) | — | |

## Task 8 gates

| Gate | Result |
|---|---|
| Docs (chapters and references changed, footers) | |
| `roadmap.py` and `--check`; `check_public.sh`; link check | |
| `SUITE(final)`, `cmp` against `*-t5.tsv` | |
| `run_checks.sh`; conformance; netplay four scenarios; team match; profile | |
| `git diff --stat main -- game/scripts/presentation game/scenes relay protocol game/data .github` | |
| Benchmark `PERF_LABEL="Flatter worst ticks"`, alone, `uptime` | |
| Deck History rows (native, Firefox 160): written by Task 8 / by Task D7 Step 4 | |

| Worst tick (single runs; Task 6 holds the spread) | Task 0 | Task 8 |
|---|---|---|
| team match `step` max (profile) | | |
| team match `opponent.decide` max | | |
| team match `step.service_paths` max | | |
| hordes300 `step.combat_fire` max (profile) | | |
| combat hordes300 `WORST TICK` (benchmark) | | |

## Unverifiable at night (for the morning)

- CI on Linux and Windows with the re-pinned values and traces (`godot-replays`), and `sh tools/compare_local_traces.sh <run id>` for macOS: need a pushed branch (push needs approval). A re-pin makes this the most important morning check.
- Browser: digests of the stagger and path budget on wasm against native (no new float maths, so expected equal; unmeasured). Deck Firefox timing is Task D0 / D7's report-only row; if either fell back to native only, the Firefox rows are a morning item (user, 2026-11-14).
- Rendered benchmark: not needed (presentation unchanged); confirm Task 8 Step 3's diff is empty.
- Bot play after the stagger: the bots act two to eight ticks later than before; no attended match is required by the package, one short offline match is optional.
- X2: cross-map group starts on Ashfall drain about 3.9× slower than today (derived; measured value in "Route cells"): one short attended check whether a large cross-map order feels late; Question 15's 2× rule covers only the 64 × 64 rows.
- Wall-clock worst-tick ceilings: Task 6's proposals (worst + 5 %) are the user's decision; none installed at night.
- If Task 4 parked on Question 8: back of the queue with the measured starvation, or keep-slot with its fallout (the user's call).
- Remove the scratch worktrees `$L/probe-tree` (Task 4), `$L/deck/web-tree-base` and `$L/deck/web-tree-after` (Tasks D0, D7) with `git worktree remove`; not in the night allow list.
- If Task D7 did not run its Step 4: remove `~/wargrid-flatter` on the Deck and check no `wargrid-flatter*` unit or Firefox profile is left.
- Proposed night allow rule `Bash(git archive:*)` (Tasks D0, D7 have a fallback without it).
- Task 9 fixes that change `game/` after Task D7 make the Deck after rows one commit stale.
- Commands the night permissions refused, each with its exact text (filled in by the run).

## Evidence rows (append-only)

- 2026-11-14, plan writing (backup 1 of the One controller night run), tree `~/projects/wargrid` `main` `74950e5` clean, read-only (no suite, no benchmark, no profile, no Godot run). Read: `AGENTS.md`; `docs/packages.md` night lane and package note; simulation review §5.2, §5.8, "Review 2026-11-13"; `docs/reference/hordes300-combat-fire.md` and its probe diffs and digest script in `~/projects/wargrid-overnight-work/tighter-gates/`; design answers "Simulation reference review" and "Package review, second pass"; `docs/reference/performance.md` status table and budgets; `docs/reference/perf-history.csv` (last rows `ae09473`: combat open 1.834 / 2.113, dense 1.806 / 2.117, hordes300 2.884 / 3.372 ms p95 / p99); `docs/reference/determinism-rules.md`; `docs/reference/sim-interface.md`; the Sim quick wins plan and verification file (format); the One controller plan's pins (V8-V11). Code anchors on `74950e5`: `simulation.gd` `PATH_REQUESTS_PER_TICK` `:21`, `_allocation_calls` `:46`, `_unavailable_cells` `:322-335`, `_assign_move` `:422-450`, `_stop_unit` `:461-466`, `_service_paths` `:468-473`, `step` `:507-585` (`_service_paths` call `:550`), `_assign_route` `:627-638`, `_snapshot` `:707-724` (`last_sequences` `:715-719`), `_sorted_copies` `:784`, `issue_command` `:159-171`, `remove_object` `:827-847`; `combat.gd` `object_removed` `:612-622`, `_go_home` `:674-679`, `_plan_retaliate` `:681-696`, `_approach` `:207-229`; `destination_allocation.gd` `assign` `:5-50` (`has` at `:69`); `grid_navigation.gd` `route` `:108-127`; `skirmish.gd` `DECISION_TICKS` `:11`, `issue_opponents` `:67-72`, `_decide` `:74-89`, `_bot` `:161-164`; `team_match.gd` `SEATS` (1, 2, 8, 4, 5, 6) and `step`; `run_profile.gd` `_fixed` `:84-95`, `_team_match` `:129-141`; `test_groups.gd` `:149-234`; `test_combat_navigation.gd` A2 `:112-129`; `test_benchmark.gd` `:103-112`; `test_playtest_replay.gd` RP2 `:40-46`. Findings: (1) the tests that assume 8 requests per tick are G7, G8, A2 and the fixed step 38 of the snapshot ceiling test, so Task 4 rewrites them by rule; (2) about 25 bot test call sites assume a decision on `tick % 30 == 0`, hence the ungated `decide()` and the Allowed test edits; (3) pins beyond the Sim quick wins list move: the three skirmish match outcomes (`TERMINAL_TICK`, `CHINA_TERMINAL_TICK`, `FRC_TERMINAL_TICK` with winners) and `test_state_hash.gd` `PINNED` (12 requests on tick 0 of the replay world); `FRC_TERMINAL_TICK` 48321 sits 1679 ticks under its 50000 cap; (4) a per-seat bot state on the same tick decides exactly as the shared snapshot, because `issue_command` changes only `_pending` and that seat's `_last_sequences` entry; (5) the hordes300 probe diff applies to today's `_assign_move` and `object_removed` (the hash ring and `advance` split did not touch them); (6) Zero Hour sources at `0a05454`: `PATHFIND_CELLS_PER_FRAME=5000` (`AIPathfind.cpp:1103`), reset and loop (`:5923`, `:5927`), cells counted in `cleanOpenAndClosedLists` (`:4812-4822`), queued requests keep their slot (`:5663-5667`), `LOGICFRAMES_PER_SECOND = 30` (`GameCommon.h:72`), `PATHFIND_CELL_SIZE 10` (`AIPathfind.h:439`); AI players read live objects (`AIPlayer.cpp:2195`, `:3039`) and keep per-player countdowns (`:2916-2922`), with no shared decision tick found (corrected by the review row below: the countdowns all start at 0 and only drift apart; no deliberate stagger). Not verified: the route-cell to searched-cell ratio behind the 256 value (assumed 3); the bot state's cost (Task 2 probe); which tests break beyond the census; whether the budget binds in the team match (expected, Task 4 profile check); the new pinned values and whether the FRC match stays under its cap; the pins One controller adds (`IC1_ROWS`, `IC2_ROWS`, HUD summaries) and whether their scripts run a bot; Zero Hour's AI cadence beyond the two timers read.
- 2026-11-14, plan revision after the fresh-context review (Opus), docs only; nothing re-measured in this revision. Source: `~/projects/wargrid-overnight-work/one-controller/flatter-worst-ticks/review.md` (tree `main` `74950e5` exported into scratch copies under `verify-copy/`; host under load, load average 1.8 to 5.7, so its µs numbers are ratios; logs in `verify-copy/logs/`: `p-<scenario>-b<budget>.tsv` and `.log` from `scripts/path_probe.gd` and `analyze.py`, `budget-suite.log`, `stagger-suite.log`, `both-suite.log`, `both-team.log`, `both384-team.log`, `both384-skirmish-match.log`, `both-netplay.log` and `both-netplay/`, `botprobe-1.log`, `ceiling-tree.log`, `ceiling-budget.log`). Applied: (1) budget 256 → 384 route cells: searched ÷ route 20.3 on Ashfall (per-request p95 28.6) against about 3 on the synthetic maps; 256 binds on 1653 of 6220 team-match service ticks and drains movement dense in 81 ticks against 38 (Question 15 fires); 384 drains in 60, worst per-tick search 102413 → 31739 cells; (2) winners: China flips to 1 at 384, FRC flips with the 256 budget alone, so "any winner" covers all three skirmish pins and the team match (Questions 11, 20); (3) HUD1 `HUD_TEXTS` added to R as V12 (red under the stagger; the census regex missed it); K2 `test_skirmish_scene.gd:45` red under the stagger with no allowed edit: new T4 (Question 18); A2 green before and after (rewritten anyway); P1's snapshot-ceiling failure is BM5 per-unit (342 > 336 at step 38); 21 bot cases red under the stagger listed in Task 3; three negative checks vacuous under the stagger, so T1 converts by census; (4) Zero Hour Question 3: `m_teamDelay` starts at 0 for every AI player (`AIPlayer.cpp:80`, `:120`) and is reset by events, so players start in step and drift apart, no deliberate stagger (`0a05454`, read in the fork, content identical); (5) night settings lack `wargrid-wt-flatter` (folder and Edit), `mkdir` for `$L` and `python3` for `compare_replays.py` and `$L` scripts: plan "Night-run preparation" with the proposed rules and the user's `! cp` line; (6) mechanics checks moved from `run_profile.gd` (report-only, `docs/development.md:85`) to `run_combat.gd` hordes300 (`reserved_allocations` counter) and `run_movement.gd` (`path_cells`), profile prints only (Question 19); (7) same-tick rows for map-change re-queues (PB4) and collector, transport and chaser re-queues (G8 plus queue-length measurement); (8) Questions 17-21; (9) Task 2 probe gated on the ratio, best of three rounds (measured 0.25 at tick 6000); scratch scripts judged by marker (Godot exits 0 on a `--script` parse error); Task 4 probe counts searched cells with the review's `_estimate_cost` grid in a scratch worktree; Task 5 compares netplay seats by hand because `run_netplay.sh` checks the pin (`:91`) before `same_hashes` (`:92`). Added beyond the review: PB1 runs on the 64 × 64 variant because twenty routes of about 20 cells nearly fit one 384 budget on the 16 × 16 default (derived from `DIAGONAL_MODE_NEVER`, not measured). Not verified: movement open drain at 384; snapshot ceilings at the drain step at 384; netplay terminal tick at 384; `reserved_window` and `path_capped_window` > 0 inside the benchmark windows (derived); HUD1's new value; RS3's "checks ≥ 20"; the stagger-only team match line; One controller's `IC1_ROWS` / `IC2_ROWS`.
- 2026-11-14, plan revision after the user's round-2 answers (attended), docs only; nothing run (a package-gate benchmark was running on the host, so no Godot, suite, benchmark or profile run). Read: `AGENTS.md`, the plan, `review.md`, the night settings and the user-wide and repository settings, and on `~/projects/wargrid` `main` `74950e5`: `tools/run_benchmark.sh`, `tools/run_team_match.sh`, `game/benchmarks/run_movement.gd`, `run_combat.gd` (`:60-200`), `run_team_match.gd`, `run_profile.gd` `_team_match`, `game/scripts/debug/team_match.gd`, `movement_workload.gd`, `combat_workload.gd` `_building`, `simulation.gd` (`spawn`, `_validate`, `_assign_move`, `_service_paths`, `_assign_route`, `replace_blocked_cells`, `_replace_union`, `remove_object`, `_remove_building`), `combat.gd` (`:125-146`, `_approach` `:207-229`, `object_removed`), `map_data.gd`, `grid_navigation.gd` (`component_at`, `snapshot`), `test_groups.gd` (`:140-230`), `test_combat_navigation.gd` A2, `run_tests.gd` runner, `tools/perf_record.py` `auto_label`, `game/data/maps/ashfall.json` (194 × 187, start cells, 12 sources), guide ch. 12 gate table, `performance.md` gate proposals. Applied: Questions decided (round 1 and round 2, user, 2026-11-14); Q13 X2 and X2r / X2m in Task 4 with the work bound ceil(route cells ÷ budget) (2× cannot hold for cross-map routes: derived about 90 ticks against 23 today); Q8 criterion (re-appends per unit, max wait, max queue; thresholds from `REPATH_TICKS` 8 × 384 and X2's drain) with the pre-written keep-the-slot fallback in `combat.gd` `_approach` and PB5; Q14 as Task 6 (count lines, five runs) and Task 7 (gates by rule C or a requirement, red by mutation, wall-clock report-only with proposed ceilings), docs task now 8, review 9; ch. 13 added to the guide list. Double-check fixes: the Task 4 probe tree (at Task 3's commit) was checked against V10, which Task 3 already moves; PB tests named `PATH_CELLS_PER_TICK` before it existed (parse failure, not named failures); the movement red step used a stub Step 3 had already replaced; `cp` (not allowed at night) for the digest script and probe copies; PB4's untyped array argument; a Task 4 step that used a later step's output; park scope of Tasks 3-5 left Tasks 6-9 undefined; the review gate lacked a mechanics floor for bot decisions. Not verified: every X2, PB5, Q8 and Task 6 / 7 number (derived, nothing run); that `CountingNavigation` built from `_union_cells()` equals the Ashfall navigation (the case checks it); that PB5's setup triggers a re-request while queued (the case checks it); X2's runtime; that rule C's 25 % sits below each mutation's effect (Task 7 Step 3 checks it).
- 2026-11-14, plan refresh onto `main` `4c21d1a` (docs only; no suite, benchmark, profile or Godot run; nothing committed). Read: `AGENTS.md`, `docs/night-run.md`, `docs/milestone-prompt.md`, the draft plan, this file's draft and `review.md`; `git log 74950e5..main` (74 commits: One controller, P2.1 launcher, release 0.12.0) and `git diff 74950e5..main` on `game/scripts/simulation`, `game/scripts/debug`, `game/benchmarks`, the pinned test files, `tools/run_team_match.sh` and `tools/run_netplay.sh`. Findings: simulation drift is the builder-in-transport rejection (`simulation.gd:242`, `construction.gd:72-74`), so `simulation.gd` anchors from `:242` moved by one and `construction.gd` ones after `:71` by three; `combat.gd`, `skirmish.gd`, `destination_allocation.gd`, every benchmark script, `test_groups.gd`, `test_combat_navigation.gd`, `test_benchmark.gd`, `test_factions.gd`, `test_skirmish_waves.gd` and every pinned value are unchanged; `test_skirmish.gd` moved up one line (the `OnlineMain` / `SkirmishMain` preloads became `OnlineDriver`); K2 now reads `main.driver.sim` at `test_skirmish_scene.gd:46-51` and the scene's bot call is `offline_driver.gd:32`; HUD1 at `:646` / `:676`; `IC1_ROWS` / `IC2_ROWS` (`input_script_rows.gd:3`, `:27`) added to R by the census rule as V13 (derived: expected not to move); guide anchors re-read (ch. 1 `:103`, ch. 12 rows `:47-50`, ch. 13 `:82`, ch. 4 `:104` and ch. 6 `:14`, `:39`, `:84` also name the 8-request cap); `performance.md` "Mechanics inside the window" `:161`; `docs/development.md:86`. Night settings re-checked (folder, Edit, `compare_replays.py`, `python3 -I` for `$L`, `mkdir -p` for the run folder, `ssh` / `scp` to the Deck, `godot`, `export_build.sh`, `git worktree add`; `git archive` not named). Steam Deck probed read-only over ssh: Desktop Mode, ACAD 1, load 0.0, Firefox flatpak 160.0, the user manager's environment has `DISPLAY=:0` and `WAYLAND_DISPLAY=wayland-0`, `systemd-inhibit`, `kde-inhibit`, `python3` and `curl` present. Added Tasks D0 and D7 (user, 2026-11-14 evening). Not verified: the Deck job script (never run), Deck profile length, the Firefox flow on 160, the expected values on `4c21d1a` (carried over from `74950e5`).
- 2026-11-14, external readiness review applied (fresh context, a different model family; docs only, nothing run, tree `main` `4c21d1a`). 9 findings checked against the code: 7 applied, 2 rejected. Applied: (1) Task 7 mutation (e) also deletes the `window_reserved == 0` return for its run, which otherwise returns before the full-scan check; Task 1 Step 6's "the script stops at the first failing row" corrected (`run_combat.gd:14-36` measures every row; only hordes300's own stress ceiling, checked first in its block, can hide the line); (2) the new cases are appended to `cases()` (PB2-PB4, X2, X2r in `test_groups.gd`; PB5 in `test_combat_navigation.gd`; also BT1 in `test_skirmish.gd`, found while checking), since `run_tests.gd:82` runs only `cases()`; (3) Task 5 Step 1: a differing in-bound value returns `BLOCKED`, the coordinator dispatches the Opus diagnosis and continues the task by `SendMessage` (`docs/night-run.md` Coordinator rules); (4) RS1 checks `_reservation_opens == 1`, with mutation (d), because `_end_reservations` inside the loop kept every other check green; (5) the Deck `user.js` seeds `termsofuse.acceptedVersion` 4 before the copied lines and also reads `.mozilla/firefox` (hardening: `deck.sh:46` found the pref under `config/mozilla/firefox`, so the path claim itself did not hold); `bench_runner.gd` combat loop cited as `:29`; (6) Global Constraints and the preparation section name the git commands the night file lacks and the proposed copy adds; (7) the `combat.splash_index` record moved into Task 0 Step 6. Rejected: Task 6's `deciding` placement (the plan already puts it before `var started`, inside the loop, and only `paths` next to `units_peak`; `TeamMatch.SEATS` is `Array[Dictionary]` with a `seat` key, `game/scripts/debug/team_match.gd:9-11`, so the plan's lambda is right); the typed `[]` for `MapData.create` (an untyped literal there already runs in every movement benchmark, `movement_workload.gd:31`).
