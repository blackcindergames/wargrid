# Worker thread spike verification

This file is still the pre-run template and was not filled in. The run's result tables are private evidence (the spike's morning summary, private); the Deck rows are summarised in the [design answers](design-answers-2026-11-08.md#worker-thread-ab-and-the-sim-boundary-user-2026-11-15).

```text
Resume record (updated 2026-11-15, Questions decided)
Branch / base commit / working-tree state: not created (Task 0 cuts spike-worker-threads from main into ~/projects/wargrid-wt-worker) / base = main at the preparation commit (`git log -1` on main) / tree clean after that commit
Last green task / next incomplete task: none / Task 0
Changed paths since last commit: none on the branch
Last command / cases / checks / failures / exit / marker: none (plan written read-only; no Godot, suite or benchmark run)
Known red case or blocker: none known
Task 0 bootstrap: Task 0 Step 1 runs from ~/projects/wargrid (it creates $W); session-start checks on $W begin after it
Dispatch (in order; a parked task skips its dependants, the rest still run):
  0 -> 1 -> 2 -> 3 -> 4 -> 5 (Opus) -> 6 -> D7 start -> 8 -> D7 fetch
  0 or 1 parks: skip all but 8 (8 writes what exists)
  2 parks: skip 3, 6, D7; 3 and 4 park nothing
  6 parks: skip D7
  D7 is asynchronous: Step 4 returns STARTED, the coordinator dispatches 8 at once. Poll (coordinator): after each later task, then a Monitor until-loop every 20 min running `ssh -o BatchMode=yes deck@<deck> tail -n 1 wargrid-worker/logs/edges.txt` and `ssh -o BatchMode=yes deck@<deck> systemctl --user is-active wargrid-worker-job`; dispatch D7 Step 6 (fetch) when the line starts `JOB END`, or the unit is not active (fetch, FAILED), or 3.5 h after STARTED; never block on it
  Terminal statuses: GREEN, BLOCKED (question), PARKED (stop condition), SKIPPED (dependency or Deck preflight), STARTED/FETCHED (D7 only)
Approved decisions, pre-authorizations used, deferred gates: thin scope, A1 arm, go / park / drop rule, hand-over cost per unit (user, 2026-11-14 and 2026-11-15, design answers); tonight's run decisions and plan Questions 1-7 (user, 2026-11-15: A1 arm dropped, go metric main_p95 with its guards, runs 3/2/Deck 2, team window from 210 units, caches warmed and frozen in the bench only, hash every 30 ticks, no input; plan "Questions"); local commits per GREEN task on spike-worker-threads only if the night handoff grants them; PERF_RECORD=0, no ledger row, no budget touched; the go / park / drop decision is the attended morning A/B
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: Task 0 Step 1
```

Plan: [Worker thread spike plan](../superpowers/plans/2026-11-15-worker-thread-spike.md). Spec: `docs/packages.md` night lane item 5 and package note "Worker thread spike"; [design answers](design-answers-2026-11-08.md#worker-thread-experiment-preparation-user-2026-11-14) (three rounds); architecture reference (not a contract) [worker thread design](../superpowers/specs/2026-11-12-worker-thread-design.md). Logs: `~/projects/wargrid-overnight-work/worker-threads/logs/`; exports `…/worker-threads/exports/`; Deck files `…/worker-threads/deck/`; results `…/worker-threads/results.md` (all outside the repository).

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 0 | Baseline: worktree, import, suite, checks, templates, anchors, team unit curve and `TEAM_START_TICK` | Sonnet | not started |
| 1 | Bench loads, worker driver, published sim, digest check WD1-WD3, WD5 | Sonnet | not started |
| 2 | Bench scene in the real match scene, WS1, presets, headless scene rows and cross-arm digests | Sonnet | not started |
| 3 | Fault probe with watchdog, red by mutation | Sonnet | not started |
| 4 | Hand-over cost per unit | Sonnet | not started |
| 5 | Fresh-context branch review, one fix round, `/ponytail-review` | Opus (high) | not started |
| 6 | Threaded and no-threads exports (alone) | Sonnet | not started |
| D7 | Steam Deck Firefox rows, all arms, report-only | Sonnet | not started |
| 8 | `worker_ab.py`, `results.md`, morning A/B procedure | Sonnet | not started |

## Baseline (Task 0)

| Item | Value |
|---|---|
| Base tree (`git log -1 --format=%h`), Godot version | open |
| Import exit; suite CASES / CHECKS / exit / wall s; `run_checks` | open |
| Web templates `web_release.zip`, `web_nothreads_release.zip` | open (both present at planning) |
| Anchor drift (plan "Written against") | open |
| Team unit curve (every 3000 ticks), end tick | open |
| `TEAM_START_TICK` by the rule; units at window start and end | open |

## Digest check (Tasks 1 and 2)

| Check | Result |
|---|---|
| WD1 team 900 ticks: ticks, per-tick events and results, 30 digests equal | open |
| WD2 late 900 ticks: the same, shots and deaths in the window | open |
| WD3 two results one drain; old view unchanged | open |
| WD5 detach in flight | open |
| WS1 bench screen in worker mode | open |
| Red runs (named failing checks) | open |
| Task 2 headless scene: `cmp` of DIGEST lines inline / worker per load (skirmish3v3, team, hordes300, late) | open |

## Headless scene rows (Task 2, one run each, not timing evidence)

| Load | Arm | tick_rate | cpu_ms p95 / p99 | missed_share | main_per_tick | refresh_ms p50 / p95 | job_ms p50 / p95 / p99 | handoff_ms p50 / p95 | age_ms p50 / p95 / max | backlog_max | units_median |
|---|---|---|---|---|---|---|---|---|---|---|---|
| (filled by Task 2) | | | | | | | | | | | |

## Fault probe (Task 3)

| Item | Result |
|---|---|
| Probe: end line, exit, detection path (stopped or stalled), time to detect, SCRIPT ERROR line | open |
| Mutant (`_check_alive` returns at once): end line, exit | open |
| Leftover processes after each run | open |

## Hand-over cost per unit (Task 4)

| Row | units median [min-max] | view_ms p50 / p95 | copy_ms p50 | hash_ms p50 | per_unit_us |
|---|---|---|---|---|---|
| (filled by Task 4, median of 3 [range]) | | | | | |

Sweep line fit and the 210-unit value (derived): open.

## Review (Task 5)

Open.

## Exports (Task 6)

| Item | Result |
|---|---|
| Export tree; `threads/` exit, files, `GODOT_THREADS_ENABLED`; `nothreads/` the same; wasm sizes | open |

## Deck rows (Task D7, report-only)

Never a gate. Deck address: night handoff only.

| Item | Result |
|---|---|
| Preflight (ACAD, Desktop Mode, Firefox version, load, no leftover) | open |
| Edges: ACAD at every edge, load range, `PAGE FAILED` lines | open |
| Isolation and `WORKER BENCH DONE` per page | open |
| DIGEST equality across arms and against Task 2 | open |
| Per load and arm: cpu_ms p95 (main_p95) / p99 / max, missed_share, main_per_tick, frame p50 / p95 / p99 / max (report-only), tick_rate, backlog_max, job p95, handoff p50 / p95, age p95, A/A range | open |
| Cleanup (folder, units, profiles) | open |

## Unverifiable at night (for the morning)

- The go / park / drop decision: the attended Mac browser A/B (`results.md`, "Morning A/B procedure").
- Fault behaviour in a release (web) build; an infinite loop in a job; shutdown while waiting.
- Input, placement and feedback latency in worker mode (the bench takes no input, plan Question 7, decided).
- The match-over guard (no bench load ends inside a suite-sized window).
- Online (lockstep) worker mode and a mixed online match: outside the thin scope.
- Removing the worktree `~/projects/wargrid-wt-worker` (not in the night allow list; only after the decision).
- Commands the night permissions refused, each with its exact text (filled in by the run).

## Evidence rows (append-only)

- 2026-11-15, plan writing, tree `~/projects/wargrid` `main` `3369df9` (working tree: `docs/packages.md` modified by another session, untouched), read-only (no Godot, suite, benchmark or export run). Read: `AGENTS.md`, `docs/night-run.md`, `docs/milestone-prompt.md`, the private handoff `worker-thread-experiment-prompt.md`, the design answers heading (three rounds), `docs/packages.md` item 5 and package note, the 2026-11-12 worker thread design, Grok's reader inventory (`86dca0e`; rows for the offline match path spot-checked against `3369df9`: `match_screen.gd:60, 87, 102, 105, 127, 142, 179-188, 241, 279-282`, `orders.gd` snapshot readers, `hud.gd:163`, `definitions.gd:15-19`, `combat.gd:80`), `offline_driver.gd`, `online_driver.gd`, `command_recorder.gd`, `match_screen.gd`, `presentation_clock.gd`, `simulation.gd` (`tick`, `combat_events`, `command_results`, `step`, `snapshot`, `view_state`), `state_hash.gd`, `profiler.gd`, `combat_workload.gd`, `team_match.gd`, `bench_runner.gd`, `run_late_game.gd`, `movement_benchmark.gd`, `tools/serve_web_bench.py`, `tools/export_build.sh`, `game/export_presets.cfg` (presets 6 and 10 single-threaded), `game/project.godot`, `tools/run_tests.sh` (any `ERROR:` fails the suite), `tools/test_sim_boundary.py`, the Flatter worst ticks plan and verification file (format, Deck tasks; last night's base Deck job stopped after one Firefox run on a `cross_origin_isolated=true` grep while Godot prints `=1`), `~/projects/wargrid-perf-work/threads/threads-result.md`, `~/projects/wargrid-perf-work/split-ab/split_ab.gd` (frame CPU formula), the 2026-11-14 Safari and Vivaldi logs, and the night settings. Findings: lever A1 is already on `main` (`presentation_clock.gd`, performance-next lever A1, split A/B History row 2026-11-11), so the plan defines `a1` as A1 without its fallback (Question 1); the screen, orders and HUD read `driver.sim` directly in 16 places, so worker mode needs a `PublishedSim` stand-in rather than a driver swap alone; web templates with and without threads for 4.7.2 are installed; branch `spike-worker-threads` does not exist; the night settings lack the worktree folder, its Edit rule, `python3 -I` for this run's `$L` and `mkdir -p` under `worker-threads`.
- 2026-11-15, plan Questions 1-7 answered (user, 2026-11-15), docs only, nothing run: A1 arm dropped (lever A1 is on `main`), arms `inline` and `worker` plus no-threads `inline`, freed runs to A/A; go metric replaced by `main_p95` (`cpu_ms.p95` over all frames, `movement_benchmark.gd:244-257` formula with carry pairing) with `cpu_ms.p99`, `missed_share`, pace, age, W1 and isolation rules, and the worker judged against threaded and no-threads `inline`; runs 3 per arm on goal loads, 2 on hordes300 (late canary kept at 2, not named in the answer), Deck 2; team window, cache freeze, hashing and no-input answers as recommended. Plan's `ForcedSplitClock`, `a1` URLs, `cpu_tick_frame_mean` removed; `worker_ab.py` fixture gains a missed_share-only and a non-isolated case.
- 2026-11-15, external readiness review (fresh context, a different model family; NOT READY, 16 findings) applied, docs only, nothing run. Skipped 1 (permission patterns ran unchanged on night 4, user). Applied: two-job test helper with bounded wait (2); per-job completion sentinel, the callee-fails-caller-continues outcome probed first, any extra SCRIPT ERROR red (3); locked reads, ownership only after a successful join, failed detach ends the page (4); render-time measurement switched on and checked (5); exact window boundaries, accumulator reset, carry flush, stop posting at the end, tick rate from included ticks (6); per-load mechanics counters in the window (7); published-against-inline projection, kept post-job view, WorldView-received check, mutations (8); hard NO VERDICT conditions, build and window identity, decide and report modes (9); explicit evidence paths, fixtures outside them (10); runnable hand-over mutation with output checks (11); Deck preflight for every project job, bounded curl and parent runtime, unit-state checks, cleanup trap, terminal line, bounded fetch (12); dispatch table in the resume record (13); base, bootstrap and settings lines refreshed (14); `late` starts a real match, early end fails the run (15); one terminal guard for DONE, FAILED and TIMEOUT (16).
