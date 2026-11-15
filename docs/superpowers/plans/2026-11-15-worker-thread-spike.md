# Worker Thread Spike Implementation Plan

**Status:** drafted 2026-11-15 against `main` before the preparation commit (read-only; no Godot, suite or benchmark run while writing). All 7 Questions decided (user, 2026-11-15; section "Questions"); readiness review, night-settings check and handoff pending (`docs/night-run.md` Prepare steps 5-7). Resume record: [verification file](../../reference/worker-thread-spike-verification.md).

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: `docs/night-run.md` (Coordinator rules) and `docs/milestone-prompt.md` (session start, stop conditions). Every task subagent also reads "Global Constraints", "Arms and loads", "Thread rules" and "Commands the run needs" (`rg -n '^## ' <plan>`).

**Goal:** night lane item 5, "Worker thread spike" ([packages](../../packages.md#night-lane), package note; [design answers](../../reference/design-answers-2026-11-08.md#worker-thread-experiment-preparation-user-2026-11-14), all three rounds). Evidence only, thin scope: (1) a scratch worker driver that the real match scene (`match_screen.gd`) runs through its one swappable `driver`; (2) a headless digest check, inline against worker, same command stream, digest every 30 ticks over a 900-tick bot case and a later-mechanics workload, event and command-result order and contents compared too; (3) one fault probe: a script error in the worker job fails loudly, no hang, under an external watchdog; (4) the hand-over cost per unit; (5) one threaded export choosing the arm by URL and one no-threads export, ready to serve; (6) Steam Deck Firefox rows, report-only; (7) `results.md` with a short attended Mac A/B procedure for the morning. The go / park / drop decision is the morning's, not tonight's.

**Architecture:** `WorkerDriver` (`game/scripts/match/worker_driver.gd`) has OfflineDriver's surface (`create`, `start`, `step`, `step_results`, `submit`, `notice`, `pauses_sim`, `confirm_leave`, `can_restart`, `over`, `leave`, `detach`, `match_log`) and runs one bench load (`BenchLoads`, `game/scripts/debug/bench_loads.gd`). Mode `inline`: `driver.sim` is the live `Simulation`, stepped in the physics frame exactly as OfflineDriver does today. Mode `worker`: one persistent `Thread` owns the live simulation; the physics frame drains finished results, then posts at most one job (queue cap 2); `driver.sim` is a `PublishedSim` (`game/scripts/match/published_sim.gd`) that answers the screen's reads from the newest drained result (view state, copied events and command results, match status, the last hash-tick snapshot). The bench scene `worker_bench.tscn` runs one or several arms in sequence, each in a fresh instance of the real match scene (an inherited scene of `skirmish.tscn` whose root script extends `match_screen.gd` only to time frames), and posts one result file per page. No production file changes: `match_screen.gd`, `presentation_clock.gd`, `orders.gd`, `hud.gd` and everything under `game/scripts/simulation/` stay as on `main`.

**Tech stack:** typed GDScript (Godot 4.7.2), POSIX `sh` on the Deck, Python 3 (scratch extractor outside the repository).

**Written against** `main` as of 2026-11-15 (before the preparation commit; Task 0 records the base). Anchors verified on that tree: the screen builds its driver at `match_screen.gd:60` (`if driver == null: driver = OfflineDriver.new(local_player)`), calls `driver.create` in `_create_world` (`:127`), `driver.start()` last in `_ready` (`:102`), `driver.detach()` in `_exit_tree` (`:105`), steps in `_step_frame` (`:179-188`, `driver.step(_collect_sound)` at `:142`), refreshes through `driver.sim.view_state()` (`:241`), reads `driver.sim.combat_events()` and `command_results()` per tick in `_collect_sound` (`:279-282`), and assigns `_clock = PresentationClock.new()` in `_ready` (`:87`). `orders.gd` reads `driver.sim.snapshot()` on input (`:151`, `:232`, `:247`, `:259`, `:291`, `:322`, `:332`, `:339`, `:359`, `:364`), `match_over()` (`:31`), `tick()` and `preview_build` (`:283-286`); `hud.gd:163` reads `team_of`. Grok's reader inventory (`~/projects/wargrid-overnight-work/worker-threads/reader-inventory-grok.md`, `86dca0e`) matches these rows; its rows for the online driver, lockstep, recorder and headless client are outside tonight's scope (offline bench only).

## Global Constraints

- Notation only: `$W`, `$O`, `$L`, `$E`, `$D` and `~` stand for absolute paths; in every command type the absolute path (`/Users/<user>/…`, from the night handoff), never `~` or a shell variable (denied at night, 2026-11-13). `$W` = `~/projects/wargrid-wt-worker` (worktree, branch `spike-worker-threads`, Task 0 creates both); `$O` = `~/projects/wargrid-overnight-work/worker-threads`; `$L` = `$O/logs` (every log and scratch script); `$E` = `$O/exports` (served root, `threads/` and `nothreads/` below it); `$D` = `$O/deck`. Start every command with `cd <abs $W> && `, except Task 0 Step 1, which runs from `~/projects/wargrid` before `$W` exists. Never write logs into the repository.
- Every suite, lint, warnings, checks, scene, script and export call: Bash `timeout: 600000` (the fault probe: `timeout: 300000`, its outer watchdog), output to a file in `$L`, judged by exit code plus marker (`TESTS PASSED`, `CHECKS PASSED 5`, `WORKER BENCH DONE`, `WORKER BENCH FAILED`, `HANDOFF DONE`, `UNITS DONE`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`. A Godot `--script` run is judged by its marker, never by exit code (Godot exits 0 when a script fails to parse).
- Static gates: `sh tools/run_checks.sh` (lint, warnings, Python, shell, public). New code is typed; warnings are errors (`project.godot` `[debug]`). The suite fails on any `ERROR:` line (`tools/run_tests.sh:41`), so no `push_error` may fire in a test.
- Iterating: `WARGRID_TEST_ONLY=test_worker_driver sh tools/run_tests.sh`; the full suite is the gate before GREEN.
- Headless benchmarks, if any task runs one: `PERF_RECORD=0`. No budget, ceiling, ledger row, `perf-history.csv` or README status edit: the spike is evidence, not a package gate.
- **Don't touch** (production stays as on `main`): `game/scripts/simulation/`, `game/scripts/match/match_screen.gd`, `offline_driver.gd`, `online_driver.gd`, `orders.gd`, `hud.gd`, `game/scripts/presentation/`, `game/scripts/net/`, `game/scripts/playtest/`, `game/scripts/launcher*.gd`, `game/scenes/skirmish.tscn`, `game/benchmarks/bench_runner.gd`, `relay/`, `protocol/`, `game/data/`, `.github/`, `docs/guide/`, every budget. Branch-only edits allowed exactly where a task's `Owns` names them. `.claude/` and the night settings file are the user's: never edit them.
- Not allowed at night: `git push`, `git merge`, `gh pr`, deploys, `fly`, `sh tools/run_game.sh`, any visible window on the Mac (headless Godot only), launching Zero Hour, `git rev-parse` (not in the allow list; use `git log -1 --format=%h`), `kill`/`pkill` on the Mac. The one window allowed tonight is Firefox on the Deck screen in Task D7. A refused command goes to the ledger with its exact text; the task uses an allowed form or parks.
- **The Deck** is written `deck@<deck>`: the coordinator types the address from the night handoff (private; never in a repository file, log name or commit). Deck commands are single `ssh -o BatchMode=yes` / `scp` calls with no `$`, `~` or `$(…)` on the Mac side; anything needing a shell runs in `wargrid-worker/deck-job.sh` on the Deck.
- Mac exports, the hand-over measurement and the headless scene rows run alone (no other Godot of this run at the same time; `pgrep -fl 'godot|generalszh'` first, other sessions' processes listed, never killed). Deck jobs never block Mac tasks.
- Subagents never commit. The coordinator makes one local commit per GREEN task on `spike-worker-threads` (short subject, at most 2-3 lines of why); never on `main`, never pushed, never merged.
- Edit repository files with the Edit tool; new files and scratch files with the Write tool. Scratch Godot scripts live in `$L`, `quit()` on every path and end with a `<NAME> DONE` marker.
- Comments: why only, one line. A known limit gets `# shortcut: <limit>, <when to upgrade>`.
- Parking: Task 1 parks every later task except Task 8 (which then writes what exists). Task 2 parks Tasks 3, 6, D7. Task 3 parks nothing (its result is recorded either way unless the probe hangs past the outer watchdog: then Task 6 still runs, the morning summary names the hang). Task 4 parks nothing. Task 6 parks D7. D7 parks nothing (report-only; failure becomes a morning item).
- Production guide and docs stay unchanged (the branch is never merged without a go). At a go, the integration plan updates guide chapters 1 (frame loop), 4 (the tick), 5 (presentation), 11 (multiplayer), 12 (performance and platforms) and 13 (testing and tooling) (codebase guide rule, `AGENTS.md`).

## Arms and loads

URL / command-line contract of the bench (same names in both):

| Parameter | Values | Default |
|---|---|---|
| `driver` (`--driver=`) | comma list of `inline`, `worker`, run in that order in one page | `inline` |
| `load` (`--load=`) | `skirmish3v3`, `team`, `hordes300`, `late` | `skirmish3v3` |
| `fault` (`--fault-tick=`) | tick at which the worker job raises a script error | none |
| `deadline` (`--deadline-s=`) | inner watchdog, seconds, whole page | `3000` |

- `inline`: `main` as it is: step and bots in the physics frame, hand-off (`view_state`) at refresh through the unchanged `PresentationClock`. That clock **is lever A1** (performance-next lever A1, on `main` since 2026-11-11, `presentation_clock.gd`: refresh in the next idle frame, fallback to the same frame for 150 ticks when no idle frame came), so no separate A1 arm exists (Question 1, decided).
- `worker`: as Architecture. On a `nothreads` build the driver refuses with `failed = "no threads in this build"`.
- No-threads tax row: the `nothreads` export with `driver=inline`.
- Loads (`BenchLoads`): `skirmish3v3` and `hordes300` = `CombatWorkload.create(<name>)`, advanced by `sim.step()` (as `run_combat.gd` and `bench_runner.gd`); `team` = `TeamMatch.create()` advanced by `TeamMatch.step` (six bot seats) from `TEAM_START_TICK` (Task 0's rule, Question 4); `late` = `CombatWorkload.create("late_game_3v3")` advanced by `TeamMatch.step` (the late-game canary, `run_late_game.gd`). Window per run: 300 warm-up ticks, then 1800 sampled ticks (the benchmarks' window), counted from the load's start tick.
- Decide: `skirmish3v3`, `team`. Stress (park signal): `hordes300`, `late` (design answers, third round).
- Every arm hashes on ticks divisible by 30 (`StateHash.digest(snapshot())`; inline on the main thread after the step, worker inside the job), mirroring what online `finish_tick` does, so all arms pay it (Question 6). `DIGEST tick=<t> <digest>` lines are printed every 300 ticks.

Result line per run (`WORKER RUN {json}`), keys: `arm`, `load`, `run`, `export` (`threads` or `nothreads`, from `OS.has_feature("threads")`), `web`, `isolated` (`bool(JavaScriptBridge.eval("crossOriginIsolated"))` on the web, false elsewhere), `start_tick`, `end_tick`, `wall_s`, `build`, `window_ticks` (ticks actually included, Task 2 Step 1), `tick_rate` (`window_ticks` ÷ window wall seconds), `mechanics` (the per-load counters), `views_shown`, `frames` (count), `frame_ms` (interval summary p50/p95/p99/max, report-only: browser rAF bins intervals at about 16.7 ms), `missed_share` (share of frame intervals above 25 ms), `cpu_ms` (main-thread CPU per rendered frame over **all** frames of the timed window, no tick-frame classification; per-frame formula as `movement_benchmark.gd:244-257`: script time of the screen's `_physics_process` + `_process` plus `WorldView.draw_usec`, with the `_script_ms` carry pairing (a frame's draw is paired with the previous frame's tick, `performance.md:482`), plus `RenderingServer.viewport_get_measured_render_time_cpu` + `get_frame_setup_time_cpu`; nearest-rank `TimingStats.summary`, `timing_stats.gd:9-16`; `cpu_ms.p95` is the go metric `main_p95`), `main_per_tick` (sum of `cpu_ms` samples ÷ window ticks, frame-mix cross-check), `refresh_ms` (summary of `_refresh` time), `split_share`, `units_median`, worker only: `job_ms`, `handoff_ms` (view state + event copies + hash-tick snapshot inside the job), `age_ms` (publish to drain), `backlog_max`, `stall_max_ms`; `failed`. Header line: `WORKER BENCH engine=… os=… web=… export=threads|nothreads cross_origin_isolated=… load=… arms=…`. End line: `WORKER BENCH DONE` or `WORKER BENCH FAILED <reason>` or `WORKER BENCH TIMEOUT`. On the web the page POSTs all lines plus `UA <userAgent>` to `/result` (as `bench_runner.gd` `_post`), then shows `WORKER BENCH POSTED`.

## Thread rules

- Exactly one thread calls into the live simulation at a time: the main thread before `start()` (create, fast-forward, the first published result) and after a `detach()` that returned true (the join succeeded); the worker in between. After a failed detach nobody touches the simulation again and the bench ends. The main thread reads only drained results.
- A published result holds `view_state()` (fresh dictionaries, packed view rows, the `map` entry is the navigation snapshot that `grid_navigation.gd:134-140` makes read-only and replaces rather than edits), `combat_events().duplicate(true)` and `command_results().duplicate(true)` (live arrays cleared by the next step, `simulation.gd` `step`), `match_over()`, the tick, and on hash ticks `snapshot()` plus its digest. Nothing writes a result after it is appended to the queue.
- Static caches written lazily (`definitions.gd:15-19` `_unit_cache`, `_building_cache`, `_profile_cache`, `radius_cache`, `_extra`; `combat.gd:80` `_reach_by_kind`): before the worker starts, the driver warms them for every kind in `Usa.KINDS`, `China.KINDS` and `Frc.KINDS` (`unit_view`, `building_view`, `profile_view`, `CombatDefinitions.radius`, `Combat._reach` for kinds with a weapon profile). The bench scene (not the suite) then calls `make_read_only()` on those dictionaries, so a missed key is a loud error instead of a race (Question 5, decided). `DestinationAllocation.last_cells_examined` is an int written only on the worker, read by no main-thread code.
- `Profiler` statics are not thread-safe: `WorkerDriver.start()` in worker mode sets `failed` if `Profiler.enabled` is true; nothing in the bench enables it.
- No `Node`, scene tree or `Resource` access on the worker.
- The main thread never blocks on the worker: no `lock()` held across a job, no unbounded `wait_to_finish()`. Failure detection on the main thread, checked every physics frame: the thread is no longer alive while not stopping, or a job has been in flight longer than `STALL_MSEC` (5000), or a drained result lacks its completion sentinel (`done`, set as the job's last statement). Any of them sets `failed` and stops posting. Every main-thread read of a field the worker writes (`_jobs`, `_results`, `_busy_since_usec`) happens under `_mutex`.

## Same-frame and interaction cases

No new simulation command. Driver cases:

| Case | Expected | Test |
|---|---|---|
| Two results drained in one physics frame | `after_tick` runs once per result, in tick order, with that tick's events and results; `step_results()` holds both ticks' command results; the view is the newer one | WD3 |
| An earlier published view kept while later ticks run | its `tick`, unit columns and buildings unchanged | WD3 |
| Match over in the newest result | no further job posted; `over()` true | not tested (no bench load ends inside a suite-sized window; Task 1 Step 4) |
| Teardown with a job in flight | `detach()` returns within `STOP_WAIT_MSEC`, thread not alive, no engine error | WD5 |
| Screen input in worker mode | `submit` returns `{ok: false, error: "worker bench takes no orders"}`; `snapshot()` is the last hash-tick snapshot; `preview_build` returns `ok: false` (Question 7) | not tested (the bench takes no input) |
| Script error in a worker job | `failed` set within `STALL_MSEC`, bench ends `WORKER BENCH FAILED`, no hang | Task 3 probe |
| Worker mode on a no-threads build | `failed = "no threads in this build"`, page ends FAILED | Task 6 file check only (morning NT page runs `inline` only) |

## Risks and model routing

Riskiest first: (1) Godot's behaviour after a script error on a non-main thread is not known (thread ends, or the loop continues without a result): the driver detects both (liveness and stall), the probe says which happened; release (web) builds are not probed tonight; (2) a missed main-thread reader of the live simulation: in worker mode `driver.sim` is a `PublishedSim`, so any unlisted method is a loud script error in WS1 or the headless scene rows, not a race; (3) the lazy static caches racing (warm plus freeze); (4) the team fast-forward to `TEAM_START_TICK` blocking the browser page (done in chunks of 30 ticks per frame); (5) the threaded export on the Deck Firefox not cross-origin isolated (record, Firefox rows become a morning item); (6) the worker arm running fewer ticks per second than inline (the result line's `tick_rate` and `backlog_max`; the morning rule's pace guard reads them).

| Task | What | Model |
|---|---|---|
| 0 | Baseline: worktree, import, suite, checks, templates, anchors, team unit curve and `TEAM_START_TICK` | Sonnet |
| 1 | Bench loads, worker driver, published sim, digest check WD1-WD3, WD5 | Sonnet |
| 2 | Bench scene in the real match scene, WS1, presets, headless scene rows and cross-arm digests | Sonnet |
| 3 | Fault probe with watchdog, red by mutation | Sonnet |
| 4 | Hand-over cost per unit | Sonnet |
| 5 | Fresh-context branch review, one fix round, `/ponytail-review` | **Opus (high)** |
| 6 | Threaded and no-threads exports (alone) | Sonnet |
| D7 | Steam Deck Firefox rows, all arms, report-only (start; fetch, tabulate, clean up when done) | Sonnet |
| 8 | `worker_ab.py`, `results.md`, morning A/B procedure | Sonnet |

The review (Task 5) runs before the exports so a review fix never leaves the exports or Deck rows a commit stale. Diagnosis of any unexpected red, digest difference or hang goes to an Opus (high) agent first. Haiku is not used (every task has a judgement step).

---

### Task 0: Baseline

```text
Task: record the untouched tree, its suite and checks, the installed web templates, the anchors this plan names, and the team match's unit curve with TEAM_START_TICK.
Owns: the verification file only; $L/t0_units.gd (scratch).
Invariant: no repository file changes.
Boundary: none.
Red: n/a (measurement).
Green: suite exit 0 with TESTS PASSED; CHECKS PASSED 5; both web_release.zip and web_nothreads_release.zip present; UNITS DONE.
Stop: suite red on the untouched tree; a template missing; an anchor that no longer matches by symbol.
```

- [ ] **Step 1:** `ls <abs $L>` (the preparation creates it; missing: park the run, morning item, no `mkdir` without the rule). In `~/projects/wargrid`: `git worktree add ~/projects/wargrid-wt-worker -b spike-worker-threads main`. In `$W`: `git status --short` empty; `git log -1 --format=%h` recorded as the base; `godot --version` recorded (`4.7.2.stable…`); `pgrep -fl 'godot|generalszh'` (list, kill nothing).
- [ ] **Step 2:** `godot --headless --path <abs $W>/game --import > <abs $L>/t0-import.log 2>&1; echo "exit=$?"`.
- [ ] **Step 3:** `uptime`; `sh tools/run_tests.sh > <abs $L>/t0-suite.log 2>&1; echo "exit=$?"` and `sh tools/run_checks.sh > <abs $L>/t0-checks.log 2>&1; echo "exit=$?"`. Record CASES, CHECKS, wall seconds.
- [ ] **Step 4 (templates):** `ls "/Users/<user>/Library/Application Support/Godot/export_templates/4.7.2.stable"` (absolute, typed from the handoff; no `~`) lists `web_release.zip` and `web_nothreads_release.zip` (present at planning).
- [ ] **Step 5 (anchors, by symbol):** `rg -n 'driver = OfflineDriver.new|func _create_world|driver.start\(\)|driver.detach\(\)|func _step_frame|func _refresh|func _collect_sound|_clock = PresentationClock.new|func _start_auto_pick|func _physics_process|func _process' game/scripts/match/match_screen.gd`; `rg -n 'driver\.sim\.' game/scripts/match/orders.gd game/scripts/match/hud.gd`; `rg -n 'func stepped|_immediate_until' game/scripts/presentation/presentation_clock.gd`; `rg -n 'static var' game/scripts/simulation/definitions/definitions.gd game/scripts/simulation/combat.gd`; `rg -n 'func collect_step' game/scripts/presentation/sound_player.gd game/scripts/presentation/visual_director.gd` (both take `Array[Dictionary]`). Any `driver.sim.<method>` outside `tick view_state snapshot map_data combat_events command_results match_over team_of preview_build` is a new reader: record it and add it to `PublishedSim` in Task 1 (Question 7's rule: input-only readers get the stale-snapshot or refusal answer).
- [ ] **Step 6 (team unit curve):** write `<abs $L>/t0_units.gd` (Write tool):

  ```gdscript
  extends SceneTree

  const TeamMatch = preload("res://scripts/debug/team_match.gd")

  func _initialize() -> void:
  	var sim: RefCounted = TeamMatch.create()
  	while sim.tick() < TeamMatch.TEAM_TICK_CAP and not sim.match_over():
  		TeamMatch.step(sim)
  		if sim.tick() % 300 == 0: print("UNITS tick=%d n=%d" % [sim.tick(), sim.view_state().units.id.size()])
  	print("UNITS end tick=%d" % sim.tick())
  	print("UNITS DONE")
  	quit(0)
  ```

  Run `godot --headless --path <abs $W>/game --script <abs $L>/t0_units.gd > <abs $L>/t0-units.log 2>&1` (judge by `UNITS DONE`). Rule (Question 4): `TEAM_START_TICK` = the first `UNITS` tick with `n >= 210` (the goal row); if none, the `UNITS` tick with the largest `n`, minus 2100 (so the window ends at the peak), floored to a multiple of 300 and at least 0. Also check the window fits: `TEAM_START_TICK + 2100 <` the end tick; else use `end tick - 2100` floored to 300. Record the curve (every 3000 ticks), the rule's result and the units at the window's start and end. Also add to the script a `late` check: `CombatWorkload.create("late_game_3v3")` advanced by `TeamMatch.step` to tick 2100, printing `LATE tick=2100 match_over=<bool>`; if it ended early, `late` becomes report-only (no PARK signal from it, a morning item), not a blocker.
- [ ] **Step 7:** fill the verification file's Baseline section; Task 0 GREEN.

---

### Task 1: Bench loads, worker driver, published sim, digest check

```text
Task: WorkerDriver runs a bench load inline or on one worker thread with identical simulation outcomes; PublishedSim answers the screen's reads in worker mode.
Owns: game/scripts/debug/bench_loads.gd (new), game/scripts/match/worker_driver.gd (new), game/scripts/match/published_sim.gd (new), game/tests/test_worker_driver.gd (new), game/tests/run_tests.gd (SUITES entry and CASE_SECONDS entries only).
Invariant: no production file changes; every existing check unchanged.
Boundary: two results in one drain; a kept old view; teardown in flight; match over.
Red: WD1, WD2, WD3, WD5 written first against a WorkerDriver whose worker mode posts nothing (step returns without draining): WD1 "worker produced 900 ticks" fails.
Green: WARGRID_TEST_ONLY=test_worker_driver; full suite; run_checks CHECKS PASSED 5 (it runs tools/test_sim_boundary.py; the new test calls only the driver and the simulation interface).
Stop: any per-tick event, command-result or digest difference between inline and worker (Opus diagnosis, park).
```

- [ ] **Step 1 (`bench_loads.gd`):** `extends RefCounted`; preloads `CombatWorkload`, `TeamMatch`, `Simulation`. `const LOADS: Array[String] = ["skirmish3v3", "team", "hordes300", "late"]`; `const TEAM_START_TICK: int = <Task 0>` with the comment `# Task 0 rule: first 300-tick mark with at least 210 units (the goal row).`; `const WARMUP: int = 300`, `const WINDOW: int = 1800`. `static func create(load: String) -> Simulation` (`team` → `TeamMatch.create()`, `late` → `CombatWorkload.create("late_game_3v3")`, else `CombatWorkload.create(load)`; `assert(LOADS.has(load))`); `static func advance(load: String, sim: Simulation) -> void` (`TeamMatch.step(sim)` for `team` and `late`, else `sim.step()`); `static func start_tick(load: String) -> int` (`TEAM_START_TICK` for `team`, else 0). Fast-forwarding is the caller's loop (`while sim.tick() < start_tick(load): advance(load, sim)`), so the bench can chunk it across frames.
- [ ] **Step 2 (`published_sim.gd`):** `extends RefCounted`. `var current: Dictionary` (setter keeps `_snapshot = value.snapshot` when the result has one), `var _snapshot: Dictionary`, `var _map: Dictionary`; `_init(map: Dictionary, first: Dictionary)`. Methods with the live simulation's return types: `tick() -> int`, `view_state() -> Dictionary`, `combat_events() -> Array[Dictionary]`, `command_results() -> Array[Dictionary]`, `match_over() -> bool`, `team_of(player: int) -> int` (from `current.view.players`), `snapshot() -> Dictionary` (last hash-tick snapshot, `# shortcut: up to 29 ticks stale; input readers only, the bench takes no input; replace with view rows at a go.`), `map_data() -> Dictionary` (create-time `map_data()`), `preview_build(_player: int, _builder_id: int, _kind: String, _origin: Vector2i) -> Dictionary` returning `{"ok": false, "error": "worker bench: no placement"}`. No other method: an unlisted read is a loud script error (Thread rules).
- [ ] **Step 3 (`worker_driver.gd`):** `extends RefCounted`; constants `MAX_QUEUED := 2`, `HASH_TICKS := 30`, `STALL_MSEC := 5000`, `STOP_WAIT_MSEC := 2000`. Public: `var sim: RefCounted`, `var failed: String = ""`, `var fault_tick: int = -1`, `var stop_tick: int = -1`, `var sampling: bool = false`, `var digests := PackedStringArray()` (`"<tick> <digest>"` on hash ticks), `var stats: Dictionary` (packed arrays `job_usec`, `handoff_usec`, `age_usec`, `units`; ints `backlog_max`, `stall_max_usec`). `_init(mode: String, load: String, live: Simulation)` takes an already fast-forwarded simulation (the caller owns the fast-forward). Shape (fill in typed; names are the contract):

  ```gdscript
  func create(_map_path: String, _starts: Array[int], _factions: Dictionary, _match_seed: int) -> void:
  	if _mode == "inline":
  		sim = _live
  		return
  	sim = PublishedSim.new(_live.map_data(), _publish(0))

  func start() -> void:
  	if _mode == "inline": return
  	if Profiler.enabled: failed = "profiler is not thread-safe"
  	elif not OS.has_feature("threads") and OS.has_feature("web"): failed = "no threads in this build"
  	if not failed.is_empty(): return
  	_warm_caches()
  	_thread = Thread.new()
  	_thread.start(_loop)

  func step(after_tick: Callable) -> PackedStringArray:
  	_step_results = []
  	if _mode == "inline":
  		BenchLoads.advance(_load, _live)
  		after_tick.call()
  		_step_results = _live.command_results().duplicate(true)
  		if _live.tick() % HASH_TICKS == 0: digests.append("%d %s" % [_live.tick(), StateHash.digest(_live.snapshot())])
  		return PackedStringArray()
  	if failed.is_empty(): _drain(after_tick)
  	if failed.is_empty(): _check_alive()
  	if not failed.is_empty(): return PackedStringArray([failed])
  	if not sim.match_over(): _post()
  	return PackedStringArray()
  ```

  `_loop()`: `while true`: `_semaphore.wait()`; under `_mutex` read `_quit` (return if set) and set `_busy_since_usec = Time.get_ticks_usec()`; `var result: Dictionary = _run_job()` outside the lock; under `_mutex` `_jobs -= 1`, `_busy_since_usec = 0`, `_results.append(result)`. `_run_job()`: `var started := Time.get_ticks_usec()`; `var result: Dictionary = {}`; `if _live.tick() == fault_tick and not _fault(): return result` (empty result: the job's completion sentinel is missing); `BenchLoads.advance(_load, _live)`; `result = _publish(started)`; `result.done = true` as the **last** statement (completion sentinel: a job whose body was cut short by a script error, with the caller continuing, never sets it). `_fault() -> bool`: a deliberate runtime error (`var missing: Dictionary = {}` then `var value: int = missing.no_such_key`), then `return true`; with `# Fault probe only (Task 3); never set outside it.` If GDScript aborts `_fault` and the caller continues, `_fault()` returns null, the `not` check is true and the job returns an empty result; if the caller aborts too, the thread ends or stalls. All three outcomes are detected below. `_publish(started: int) -> Dictionary`: `var handoff := Time.get_ticks_usec()`; `{"tick", "view": _live.view_state(), "events": _live.combat_events().duplicate(true), "results": _live.command_results().duplicate(true), "over": _live.match_over()}`, plus `snapshot` and `digest` on hash ticks and always on the create-time call (the screen's `_reset_camera` reads `snapshot().map.size` before any job; start ticks are multiples of 300, so they are hash ticks anyway); then `units` (`view.units.id.size()`), `handoff_usec`, `job_usec` (0 when `started == 0`), `published_usec`. `_drain(after_tick)`: under `_mutex` take and clear `_results` (shallow copy); for each result in order: `if not result.get("done", false)`: `failed = "worker job did not complete"`, stop; record `age_usec`, `job_usec`, `handoff_usec`, `units` only while `sampling` is true (the screen sets `driver.sampling` at the window start, after calling `driver.reset_stats()`, and clears it at the end, Task 2 Step 1); `sim.current = result`; append `digest` to `digests` on hash ticks; `after_tick.call()`; `_step_results.append_array(result.results)`. `_check_alive()`: copy `_busy_since_usec` and `_jobs` under `_mutex` first (every read of a field the worker writes goes through the lock); `failed` = `"worker stopped at tick %d"` if `not _thread.is_alive()`, or `"worker stalled at tick %d"` if the copied `busy_since > 0` and older than `STALL_MSEC`; record `stall_max_usec`; `push_error(failed)` once. `_post()`: under `_mutex` `if _jobs < MAX_QUEUED: _jobs += 1` and post the semaphore after unlocking; record `backlog_max`; `step` posts nothing once `stop_tick >= 0` and the newest published tick has reached it (the screen sets `stop_tick` to the window end). `detach() -> bool`: no thread → true; set `_quit` under the lock, `_semaphore.post()`, poll `is_alive()` with `OS.delay_msec(1)` up to `STOP_WAIT_MSEC`; still alive → `failed = "worker did not stop"`, `push_error`, return false (`# shortcut: leaks a stuck thread instead of hanging the frame; a go needs a real cancel.`); else `wait_to_finish()`, `_thread = null`, return true. Ownership of the live simulation returns to the main thread only after `detach()` returned true; after false nothing may touch `_live` again, and the bench ends the page or process (Task 2 Step 3). Test helpers: `thread_alive() -> bool` (false when `_thread` is null); `pending_results() -> int` (under `_mutex`); `post_jobs_for_test(n: int) -> void` (calls `_post()` n times without draining; `n <= MAX_QUEUED`); `reset_stats() -> void`. `_warm_caches()` as Thread rules (no freeze here). Surface copied from OfflineDriver: `step_results() -> Array` returns `_step_results`; `submit(_payload: Dictionary) -> Dictionary` returns `{"ok": false, "error": "worker bench takes no orders"}`; `notice()` returns `failed`; `pauses_sim()` false; `confirm_leave()` false; `can_restart()` false; `over()` `sim.match_over()`; `leave()` pass; `match_log()` `{"mode": "bench", "factions": [], "commands": PackedStringArray()}`.
- [ ] **Step 4 (`test_worker_driver.gd`, red first):** `cases()` returns `[test_team_inline_equals_worker, test_late_inline_equals_worker, test_two_results_one_drain, test_detach_in_flight]`, appended to `SUITES` in `run_tests.gd`. Helpers: `_record(driver) -> Callable` appends, per `after_tick` call, `JSON.stringify([driver.sim.tick(), driver.sim.combat_events(), driver.sim.command_results()])` to a list; `_run(mode, load, ticks) -> Dictionary` builds `BenchLoads.create(load)`, fast-forwards to `start_tick`, makes the driver, `create("", [], {}, 0)`, `start()`, then calls `step(record)` until the published tick reaches start + ticks, `OS.delay_msec(1)` between calls in worker mode, with a deadline of 30 s (`runner.check(false, "WD deadline")` and stop, never an endless loop), then `detach()`; returns `{"ticks": records, "digests": driver.digests, "failed": driver.failed}`.
  - **WD1** team, 900 ticks from tick 0 (`_run` with a `from_zero` flag that skips the fast-forward, so the case stays a few seconds; the 900-tick bot case of the 2026-11-12 design): checks "WD1 worker produced 900 ticks" (`records.size() == 900`, ticks consecutive), "WD1 per-tick events and command results equal inline" (the two record lists `==`), "WD1 digests every 30 ticks equal inline" (30 entries, equal), "WD1 no failure".
  - **WD2** `late`, 900 ticks from 0 (shots, deaths and bot commands happen inside it: `run_late_game.gd` `FIRST_SHOT_LIMIT` 60): the same four checks with WD2, plus "WD2 the window had shots and deaths" (count `"shot"` and `"death"` in the inline records > 0).
  - **WD3** skirmish3v3: an inline driver and a worker driver from the same start. Worker: `post_jobs_for_test(2)`, then wait (`OS.delay_msec(1)`, deadline 10 s; on timeout `runner.check(false, "WD3 deadline")`, `detach()`, return) until `pending_results() == 2`; one `step(record)` drains both (and posts one more). Inline: two `step(record)` calls. Checks: "WD3 two drained results call after_tick twice in tick order" (record ticks start + 1, start + 2), "WD3 step_results holds both ticks", "WD3 the view is the newer tick". Then keep the **post-job** view `var kept: Dictionary = driver.sim.view_state()` (tick start + 2) and `var kept_text := _projection(kept)`, run 30 more ticks on both drivers: "WD3 a kept published view does not change" (`_projection(kept) == kept_text`). Projection check, at every tick of those 30 on both drivers: "WD3 published view equals the inline view" (`_projection(worker.sim.view_state()) == _projection(inline.sim.view_state())`), where `_projection(view)` is `JSON.stringify` of `tick`, `players`, `buildings`, `sources`, `match`, `command_results` and every `units` column (`id`, `owner`, `kind`, `x`, `y`, `hp`, `max_hp`, `status`, `mode`, `phase`, `flags`, `target`, `queue`, `tier`, `heading_x`, `heading_y`, `order_x`, `order_y`; read `view_rows.gd` for the exact column names), each packed column copied into an `Array` first (`Array(column)`) so JSON sees its values. Mutation (red, reverted): `_publish` stores `"view": _live.view_state()` taken **before** `advance` (one tick stale) → "WD3 published view equals the inline view" fails.
  - No match-over case: `late` starts a real match (`combat_workload.gd:294` `TeamMatch.create()` calls `start_match`), but no bench load ends inside a suite-sized window (team ends near tick 38786). The `if not sim.match_over()` guard stays untested; a load that ends before its window ends makes the run FAILED ("match ended before the window end", Task 2 Step 1), never a wait for the deadline.
  - **WD5** team worker from 0: post one job and immediately `detach()`: "WD5 detach returns true within STOP_WAIT_MSEC" (`Time.get_ticks_msec` delta), "WD5 thread stopped" (`not driver.thread_alive()`), "WD5 no failure".
  Red: with `step`'s worker branch returning before `_drain`, WD1, WD2 and WD3 fail on their named checks (record the failing lines). Then implement Step 3.
- [ ] **Step 5:** `WARGRID_TEST_ONLY=test_worker_driver sh tools/run_tests.sh > <abs $L>/t1-only.log 2>&1; echo "exit=$?"`; WD1-WD3 and WD5 green; record case seconds and put the measured seconds (rounded up) for WD1, WD2 into `CASE_SECONDS` in `run_tests.gd`. Full suite `> <abs $L>/t1-suite.log`; `sh tools/run_checks.sh > <abs $L>/t1-checks.log`. Record the inline / worker wall time of WD1 and WD2 (report only).

---

### Task 2: Bench scene in the real match scene

```text
Task: worker_bench.tscn runs each requested arm in a fresh instance of the real match scene, times frames and posts one result per page; two export presets build it.
Owns: game/scripts/debug/worker_bench.gd (new), game/scripts/debug/worker_bench_screen.gd (new), game/scenes/worker_bench.tscn (new), game/scenes/worker_bench_screen.tscn (new), game/project.godot (one run/main_scene.wargrid_worker_bench line), game/export_presets.cfg (presets 11 and 12 appended), game/tests/test_worker_driver.gd (WS1), game/tests/run_tests.gd (CASE_SECONDS only).
Invariant: production files unchanged (`git diff --stat main -- game/scripts/simulation game/scripts/match/match_screen.gd game/scripts/match/offline_driver.gd game/scripts/match/online_driver.gd game/scripts/match/orders.gd game/scripts/match/hud.gd game/scripts/presentation game/scripts/net game/scenes/skirmish.tscn` empty).
Boundary: several arms in one page; worker and inline give equal DIGEST lines in the real scene.
Red: WS1 "the screen's view tick follows the worker", run with the driver's drain skipped (scratch Edit, reverted), fails on that named check.
Green: WS1; full suite; checks; headless scene rows with WORKER BENCH DONE for every arm and load; DIGEST lines cmp-equal across arms per load.
Stop: DIGEST lines differ across arms (Opus diagnosis, park Tasks 3, 6, D7); a script error from a PublishedSim method the screen calls that is not in Thread rules' list (add only if it is a read; a write or a sync need is a stop).
```

- [ ] **Step 1 (`worker_bench_screen.gd`):** `extends "res://scripts/match/match_screen.gd"`. `signal finished(result: Dictionary)`. Vars set by the root before `add_child`: `bench_driver: RefCounted`, `arm: String`, `load_name: String`, `run_index: int`, `freeze: bool`. `_ready()`: `driver = bench_driver` before `super._ready()`; after it: `_start_auto_pick(false)` (a fresh browser profile has no stored quality, `match_screen.gd:93`, and the auto pick would change quality mid-run), `_view.set_quality(GraphicsSettings.HIGH)`, `_view.time_draws = true`, `_camera.zoom = Vector2.ONE * 0.5`, `_view.set_zoom(0.5)` (the render bench's zoom); `RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)` (as `movement_benchmark.gd:72`; without it the render CPU getters return 0); desktop non-headless only: vsync off (not used tonight). Overrides `_physics_process(delta)` and `_process(delta)`: each adds its `super(delta)` time to `_script_usec` with `+=` (as `movement_benchmark.gd:179`, `:208`), never `=`; `_refresh()` override times `super()` into `refresh_ms` (and counts `views_shown`, plus `view_ticks_shown` = the `tick` of the state `_view` received, read back through the `set_view` argument by overriding `_show(state)` to record `state.tick` before `super(state)`). Window, by published tick `t` (`driver.sim.tick()`): `S = start + 300`, `E = start + 2100`. At the first `_process` with `t >= S`: reset every accumulator (frame lists, `_script_usec`, `_carried_tick_usec`, `_view.draw_usec`, `refresh_ms`, mechanics counters, `missed` count), `driver.reset_stats()`, `driver.sampling = true`, `driver.stop_tick = E`, record `t_first = t` and the wall time, set `_last_frame` to now (so the first interval starts at the open, as `movement_benchmark.gd:205-211`); this frame is not sampled (it only opens the window, as `movement_benchmark.gd:205-211`). Every later `_process` while `t < E`: append the frame interval (count it in `missed_share` when above 25 ms) and the frame's CPU by the `movement_benchmark.gd:244-257` formula with its `_script_ms` carry (a frame's draw paired with the previous frame's tick). At the first `_process` with `t >= E`: sample this frame too (it flushes the carried tick), then close: `driver.sampling = false`; `window_ticks = t - t_first`; `tick_rate = window_ticks ÷ (wall seconds since open)`; mechanics and render checks (below); build the `WORKER RUN` dictionary, `finished.emit(result)` once. Ticks drained past `E` in that last frame count in `window_ticks` (reported `end_tick = t`); the worker posts nothing past `E` (`stop_tick`). Mechanics per load, counted from `combat_events` and `command_results` in `_collect_sound` (override: count, then `super()`) while sampling: `skirmish3v3`, `hordes300`: shots > 0 and deaths > 0; `team`: ok bot command results > 0; `late`: shots, deaths and ok bot commands > 0 (the `run_late_game.gd:39-58` counters). A row whose counter is 0, whose `views_shown` is 0, or whose last `view_ticks_shown` is not within 2 ticks of `t` is `failed` ("mechanics missing: <name>", "screen received no view"). Render check (web only, where a renderer exists): sum of render CPU over the window > 0, else `failed = "render timing unavailable"`. `match_over()` before `E`: `failed = "match ended before the window end"`. `driver.failed` non-empty: finish at once with it. No other override.
- [ ] **Step 2 (`worker_bench_screen.tscn`):** inherited scene, exactly:

  ```text
  [gd_scene load_steps=3 format=3]

  [ext_resource type="PackedScene" path="res://scenes/skirmish.tscn" id="1"]
  [ext_resource type="Script" path="res://scripts/debug/worker_bench_screen.gd" id="2"]

  [node name="Skirmish" instance=ExtResource("1")]
  script = ExtResource("2")
  ```
- [ ] **Step 3 (`worker_bench.gd` + `worker_bench.tscn`, one `Node` with this script):** parse parameters (web: `JavaScriptBridge.eval("location.search")`, split on `&` and `=`, as `launcher.gd:103-104` reads the page; desktop: `OS.get_cmdline_user_args()` `--driver=`, `--load=`, `--fault-tick=`, `--deadline-s=`); print the header line (adds `build=<contents of res://build_commit.txt, or "none">` and `window=300+1800`); start the inner watchdog (`get_tree().create_timer(deadline).timeout` → `_finish("WORKER BENCH TIMEOUT", 3)`). One terminal guard: `_finish(line: String, code: int)` returns at once if `_terminal` is already set, else sets it, prints `line`, posts on the web (then `WORKER BENCH POSTED`) or `quit(code)` on desktop; DONE, FAILED and TIMEOUT all go through it, and the per-arm loop checks `_terminal` after every `await` and stops, so a late timer can never post a second, contradictory result. Per arm in order: `var live := BenchLoads.create(load)`; fast-forward to `start_tick` with `await get_tree().process_frame` every 30 ticks (the page stays responsive, as `bench_runner.gd` `TICKS_PER_FRAME`); `WorkerDriver.new(<"worker" if arm == "worker" else "inline">, load, live)`, set `fault_tick`; instantiate `worker_bench_screen.tscn`, set its vars, `add_child`; if `freeze` (true on every arm here; never in tests) call the freeze once after the first worker `start()` (Thread rules); `var result: Dictionary = await screen.finished`; print `RUN <i> arm=<arm>`, the run's `DIGEST tick=<t> <digest>` lines (every 300 ticks, from `driver.digests`), `WORKER RUN <json>`; `screen.queue_free()` and `await get_tree().process_frame` twice (its `_exit_tree` calls `driver.detach()`); then, if `driver.failed` is `"worker did not stop"` or `result.failed` is non-empty, `_finish("WORKER BENCH FAILED <reason>", 1)` and no further arm runs. End: `_finish("WORKER BENCH DONE", 0)`; the web POST is `bench_runner.gd` `_post` (`:91-99`). Every path ends in `_finish`.
- [ ] **Step 4 (`project.godot`, `export_presets.cfg`):** after `run/main_scene.wargrid_render_bench="res://scenes/movement_benchmark.tscn"` add `run/main_scene.wargrid_worker_bench="res://scenes/worker_bench.tscn"`. Append to `export_presets.cfg` two presets copied from preset 10 (`Web Render Bench`, `:242-262`) with these differences only: `[preset.11]` `name="Web Worker Bench"`, `custom_features="wargrid_worker_bench"`, `export_path="../build/web-worker-bench/index.html"`, options `variant/thread_support=true`; `[preset.12]` `name="Web Worker Bench NT"`, same feature, `export_path="../build/web-worker-bench-nt/index.html"`, `variant/thread_support=false`. Check: `rg -c 'thread_support=true' game/export_presets.cfg` = 1, `rg -n 'wargrid_worker_bench' game/export_presets.cfg game/project.godot` = 3 lines.
- [ ] **Step 5 (WS1, red first):** in `test_worker_driver.gd`, case `test_bench_screen_worker` (appended to `cases()`): build skirmish3v3, a worker `WorkerDriver`, instantiate `worker_bench_screen.tscn` with `bench_driver`, `arm = "worker"`, `freeze = false`; `runner.root.add_child`, `set_physics_process(false)`, `set_process(false)`, `await runner.process_frame` (pattern of `test_skirmish_scene.gd:21-27`); loop `main._physics_process(0.0)`, `main._refresh()` and `OS.delay_msec(1)` until `driver.sim.tick() >= 31` or 10 s: "WS1 WorldView received the published tick" (the screen's recorded `view_ticks_shown` last value == `driver.sim.tick()` and >= 31; this is the state handed to `_view.set_view`, not the accessor), "WS1 the shown state is the inline state" (an inline driver stepped to the same tick in the same case: `_projection` of the last state passed to `_show` equals `_projection(inline.sim.view_state())`, `_projection` as WD3), "WS1 a hash-tick snapshot reached the screen" (`main.driver.sim.snapshot().tick == 30`); `main.free()`: "WS1 freeing the screen stops the worker" (`not driver.thread_alive()`). Red by mutation (reverted): in `PublishedSim`, `current`'s setter ignores later results after the first (the screen keeps the create-time view) → "WS1 WorldView received the published tick" fails. Full suite, checks.
- [ ] **Step 6 (headless scene rows and cross-arm digests, alone):** `pgrep -fl 'godot|generalszh'`; `uptime > <abs $L>/t2-uptime.txt`. For each load in `skirmish3v3 team hordes300 late` and each arm in `inline worker`, one process: `godot --headless --path <abs $W>/game res://scenes/worker_bench.tscn -- --driver=<arm> --load=<load> > <abs $L>/t2-<load>-<arm>.log 2>&1; echo "exit=$?"` (judge by `WORKER BENCH DONE`, exit 0 and no `SCRIPT ERROR` or `ERROR:` line; `failed` empty and the mechanics counters non-zero in `WORKER RUN`). Then `rg '^DIGEST' <abs $L>/t2-<load>-<arm>.log > <abs $L>/t2-<load>-<arm>.digest` and `cmp` the two files per load (silent). `uptime >> <abs $L>/t2-uptime.txt`. Record per row from `WORKER RUN`: `tick_rate`, `cpu_ms` p95/p99, `missed_share`, `main_per_tick`, `refresh_ms` p50/p95, worker `job_ms` p50/p95/p99, `handoff_ms` p50/p95, `age_ms` p50/p95/max, `backlog_max`, `units_median`. Labelled "headless, no rendering, one run: not timing evidence" (the go rule is browser-only). About 8 runs of 70-110 s.

---

### Task 3: Fault probe

```text
Task: a script error inside a worker job ends the bench loudly within the stall bound; an external watchdog bounds the whole run.
Owns: the verification file; scratch Edit of worker_driver.gd for the mutation only (reverted).
Invariant: worker_driver.gd identical to its Task 1/2 commit afterwards (git diff --stat empty).
Boundary: three possible Godot outcomes after the error: (a) the callee aborts and the caller continues (expected first: GDScript returns null from the failed call), (b) the whole job aborts and the loop continues without a result, (c) the thread ends. Each must end FAILED.
Red: mutations, each reverted: (1) the completion-sentinel check in _drain removed → outcome (a) must not end DONE: the probe judges any SCRIPT ERROR line plus DONE as a failure; (2) _check_alive returns at once → outcomes (b)/(c) end WORKER BENCH TIMEOUT, not FAILED.
Green: WORKER BENCH FAILED with "worker job did not complete", "worker stopped" or "worker stalled", exit 1, detection within 6 s of the fault tick, exactly the one expected SCRIPT ERROR (naming `_fault`), no leftover process. A log with any other SCRIPT ERROR, or with DONE together with a SCRIPT ERROR, is red.
Stop: the probe hangs past the outer watchdog (Bash timeout) — record, morning item; or the run needs a watchdog command the night settings deny.
```

- [ ] **Step 1 (probe):** `pgrep -fl 'godot|generalszh'`. Bash call with `timeout: 300000` (the external watchdog: the harness ends the command at the bound): `godot --headless --path <abs $W>/game res://scenes/worker_bench.tscn -- --driver=worker --load=skirmish3v3 --fault-tick=45 --deadline-s=120 > <abs $L>/t3-probe.log 2>&1; echo "exit=$?"`. Expected: one `SCRIPT ERROR` naming `_fault` (`rg -c 'SCRIPT ERROR' <log>` = 1), `WORKER BENCH FAILED worker job did not complete` (outcome a) or `… stopped at tick 45` / `… stalled at tick 45` (b, c), exit 1, no `WORKER BENCH DONE`. Record which outcome Godot produced (the open fact of Risk 1), the wall time from the header to the FAILED line, and `pgrep -fl godot` afterwards (nothing of this run; a leftover is a morning item, never killed with `kill`).
- [ ] **Step 2 (red by mutation):** run only the mutation that matches Step 1's outcome. Outcome (a): Edit out the `done` check in `_drain`; rerun into `t3-mutant.log`; expected: the run continues (DONE or a later FAILED) with the SCRIPT ERROR still in the log, which the probe's rule judges red; record it. Outcome (b) or (c): Edit `_check_alive` to return at once; rerun into `t3-mutant.log`: expected `WORKER BENCH TIMEOUT`, exit 3, after about 120 s. Revert with Edit; `git diff --stat` empty. If the mutant still ends FAILED, another check caught it: record which; GREEN still needs Step 1.
- [ ] **Step 3:** record both in "Fault probe"; not probed: release (web) builds, an infinite loop in a job (the stall check covers it by design, unmeasured), shutdown while waiting (WD5 covers detach in flight only).

---

### Task 4: Hand-over cost per unit

```text
Task: measure what handing a tick to the main thread costs (view state, event and result copies, hash-tick snapshot and digest) against unit count, at each bench load's unit count and on a unit sweep.
Owns: game/benchmarks/run_handoff.gd (new, report-only), the verification file.
Invariant: no production change; the script asserts its mechanics ran inside the window.
Boundary: run alone; three runs.
Red: the output check: with the event copy replaced by an empty array (mutation, code still runs), the script exits 1 ("handoff copied nothing").
Green: HANDOFF DONE in three runs; table filled.
Stop: none (report-only).
```

- [ ] **Step 1 (`run_handoff.gd`, `extends SceneTree`):** for each load in `BenchLoads.LOADS`: create, fast-forward to `start_tick`, advance 300 warm-up ticks, then 1800 ticks: `advance`, then time (`Time.get_ticks_usec`) `view_state()` (`view`), `combat_events().duplicate(true)` + `command_results().duplicate(true)` (`copy`), and on ticks divisible by 30 `snapshot()` + `StateHash.digest` (`hash`); units = `view.units.id.size()`. Print `HANDOFF load=<l> units_median=<n> units_min=<n> units_max=<n> view_ms=<summary> copy_ms=<summary> hash_ms=<summary> per_unit_us=<median view µs ÷ median units>` (`TimingStats.summary`). Sweep: `CombatWorkload.create("open", per_side)` for `per_side` in `[50, 105, 150, 200, 300]` (units 100, 210, 300, 400, 600 at start), 300 warm-up and 600 measured ticks, print `HANDOFF_SWEEP units_median=<n> view_ms_p50=… view_ms_p95=… copy_ms_p50=… hash_ms_p50=…`. Output check per row, counted inside the timed block: `view` samples = 1800 (sweep 600), every `view.units.id.size()` equal to the live `snapshot`'s entity count on hash ticks, the copied events summed over the window equal the live `combat_events().size()` summed (and > 0 on every combat row), copied command results summed > 0 on `team` and `late`, `hash` samples = window ÷ 30 with 16-character digests; any miss → `push_error("handoff copied nothing: <row> <check>")` and `quit(1)`; last line `HANDOFF DONE`, `quit(0)`.
- [ ] **Step 2:** red by mutation (replace `combat_events().duplicate(true)` in the timed block with `[] as Array[Dictionary]`: the script runs and exits 1 with "handoff copied nothing: <row> events"); revert; lint, warnings, full suite unchanged.
- [ ] **Step 3 (alone, three runs):** `uptime`; `godot --headless --path <abs $W>/game --script res://benchmarks/run_handoff.gd > <abs $L>/t4-handoff-<n>.log 2>&1` for n = 1, 2, 3; `uptime`. Record per row median of 3 [range]: `view_ms` p50/p95, `copy_ms` p50, `hash_ms` p50, `per_unit_us`; the sweep's least-squares line `view_ms_p50 = a + b × units` (b in µs per unit) and its value at 210 units (derived, labelled). Mac native headless numbers; the browser hand-off comes from the worker arm's `handoff_ms` in Task D7 and the morning.

---

### Task 5: Fresh-context branch review (Opus, high)

- [ ] One fresh Opus (high) reviewer gets `git diff main...HEAD` in `$W`, the changed paths, this plan's "Thread rules", "Same-frame and interaction cases" and "Arms and loads", the verification file, and the instruction to name, per test (WD1, WD2, WD3, WD5, WS1, the Task 3 probe and mutant, the Task 4 mechanics check), the production change that would make it fail. Focus: a main-thread read of the live simulation while the worker runs; a result written after publish; a lock held across a job; an unbounded wait; a cache write on two threads; the frame CPU sample matching `movement_benchmark.gd:244-257` (carry pairing). No repo-wide search.
- [ ] Fix critical and important findings in one round, test-first, by a Sonnet subagent; rerun WD/WS, full suite, checks and, if `worker_driver.gd` or the bench scripts changed, Task 2 Step 6 for `skirmish3v3` and `team` (both arms) and Task 3 Step 1. Minor findings go to the morning summary. Then one `/ponytail-review` pass on the diff (over-engineering only); apply cuts, re-verify the same way.

---

### Task 6: Exports (alone)

```text
Task: one threaded export (both arms by URL) and one no-threads export of the reviewed head, ready to serve.
Owns: $E only.
Invariant: no repository file changes; the tree is clean so build_commit.txt carries no -dirty.
Boundary: runs alone on the Mac.
Red: n/a.
Green: both exports exit 0; index.html, index.wasm, index.pck present; GODOT_THREADS_ENABLED true in threads/, false in nothreads/.
Stop: export fails twice (record; D7 is skipped, the morning procedure says "export first").
```

- [ ] **Step 1:** `git status --short` empty; `git log -1 --format=%h` recorded as the export tree. `pgrep -fl 'godot|generalszh'`.
- [ ] **Step 2:** `sh tools/export_build.sh "Web Worker Bench" <abs $E>/threads/index.html > <abs $L>/t6-export-threads.log 2>&1; echo "exit=$?"`; `sh tools/export_build.sh "Web Worker Bench NT" <abs $E>/nothreads/index.html > <abs $L>/t6-export-nothreads.log 2>&1; echo "exit=$?"` (the script makes the folders).
- [ ] **Step 3:** `ls <abs $E>/threads <abs $E>/nothreads`; `rg -o 'GODOT_THREADS_ENABLED = (true|false)' <abs $E>/threads/index.html <abs $E>/nothreads/index.html` (true, false; the archived threaded export `~/projects/wargrid-perf-work/threads/export/B-T/index.html` reads `true`); `wc -c` of both `index.wasm`. No browser on the Mac at night.

---

### Task D7: Steam Deck Firefox rows (report-only)

```text
Task: Deck Firefox 160 rows for inline and worker (threaded export) and inline on the no-threads export, on skirmish3v3, team and hordes300, each arm twice (the A/A pair), served on the Deck itself.
Owns: files under $D only; the verification file "Deck rows".
Invariant: no repository file changes; nothing on the Deck outside ~/wargrid-worker, the run's Firefox profiles and its systemd units.
Boundary: one systemd-run --user unit at a time; the Deck job overlaps Task 8.
Red: n/a.
Green: STARTED or SKIPPED with the reason; later FETCHED, table filled, Deck folder removed.
Stop: none. Every failure is recorded and becomes a morning item (user, 2026-11-15).
```

Runs after Task 6 is GREEN. Method as the Flatter worst ticks Deck tasks (`docs/superpowers/plans/2026-11-14-flatter-worst-ticks.md` Tasks D0, D7): Desktop Mode, ACAD and load at every edge, one `systemd-run --user` unit under `systemd-inhibit --what=sleep:idle`, Firefox on fresh profiles, the folder removed at the end. Served on the Deck (localhost is a secure context, so cross-origin isolation can hold). No native Deck rows tonight.

- [ ] **Step 1 (preflight):** `sh ~/projects/wargrid-native-work/deck-preflight.sh <deck>`; `RESULT: FAIL` → record, SKIPPED, morning item. No other benchmark job on the Deck: `ssh -o BatchMode=yes deck@<deck> systemctl --user list-units --all --no-legend 'wargrid*'` prints nothing (any project unit, not only this run's), `ssh -o BatchMode=yes deck@<deck> pgrep -fl 'Godot_v|firefox'` prints nothing, and `ssh -o BatchMode=yes deck@<deck> ls wargrid-worker` fails; else record what runs, SKIPPED, morning item.
- [ ] **Step 2 (job script):** write `<abs $D>/deck-job.sh` with the Write tool, exactly:

  ```sh
  #!/bin/sh
  # Runs on the Deck in one systemd-run --user unit under systemd-inhibit: sh wargrid-worker/deck-job.sh
  B=$HOME/wargrid-worker
  L=$B/logs
  FF=$HOME/.var/app/org.mozilla.firefox
  PORT=8064
  mkdir -p "$L"
  status=failed
  failed_pages=0
  cleanup() {
  	systemctl --user stop 'wargrid-worker-ff-*' 'wargrid-worker-srv-*' 2>/dev/null
  	pkill -f -- "$FF/wargrid-worker-profile-"
  	rm -rf "$FF"/wargrid-worker-profile-*
  	echo "JOB END $status $(date +%H:%M:%S)" >>"$L/edges.txt"
  }
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM
  edge() { echo "$1 $(date +%H:%M:%S) acad=$(cat /sys/class/power_supply/ACAD/online) load=$(cut -d' ' -f1-3 /proc/loadavg)" >>"$L/edges.txt"; }
  page() { # NAME PATH?QUERY: one Firefox page on a fresh profile; fails unless it posted a complete, isolated result
  	name=$1
  	profile=$FF/wargrid-worker-profile-$name
  	out=$L/$name
  	mkdir -p "$profile" "$out"
  	{
  		echo 'user_pref("browser.aboutwelcome.enabled", false);'
  		echo 'user_pref("browser.shell.checkDefaultBrowser", false);'
  		echo 'user_pref("browser.startup.homepage_override.mstone", "ignore");'
  		echo 'user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);'
  		echo 'user_pref("dom.max_script_run_time", 0);'
  		echo 'user_pref("termsofuse.acceptedVersion", 4);'
  		grep -h termsofuse "$FF"/config/mozilla/firefox/*/prefs.js "$FF"/.mozilla/firefox/*/prefs.js 2>/dev/null
  	} >"$profile/user.js"
  	edge "start $name"
  	systemd-run --user --quiet --collect --unit="wargrid-worker-srv-$name" python3 -I "$B/tools/serve_web_bench.py" "$B/web" "$out" "$PORT" || { edge "SERVER START FAILED $name"; return 1; }
  	n=0; until curl -s --max-time 2 -o /dev/null "http://127.0.0.1:$PORT/threads/index.html"; do n=$((n+1)); [ $n -gt 50 ] && { edge "SERVER NOT UP $name"; systemctl --user stop "wargrid-worker-srv-$name"; return 1; }; sleep 0.2; done
  	systemd-run --user --quiet --collect --unit="wargrid-worker-ff-$name" kde-inhibit --power --screenSaver flatpak run org.mozilla.firefox -no-remote -new-instance -profile "$profile" "http://127.0.0.1:$PORT/$2" || { edge "FIREFOX START FAILED $name"; systemctl --user stop "wargrid-worker-srv-$name"; return 1; }
  	t=0; until grep -Eqs 'WORKER BENCH (DONE|FAILED|TIMEOUT)' "$out"/web-*.log || [ $t -ge 3600 ]; do
  		systemctl --user is-active --quiet "wargrid-worker-ff-$name" || { edge "FIREFOX EXITED $name"; break; }
  		sleep 5; t=$((t+5))
  	done
  	edge "end $name"
  	systemctl --user stop "wargrid-worker-ff-$name" "wargrid-worker-srv-$name"
  	pkill -f -- "$profile"
  	rm -rf "$profile"
  	sleep 20
  	grep -qs 'WORKER BENCH DONE' "$out"/web-*.log && grep -Eqs 'cross_origin_isolated=(1|true)' "$out"/web-*.log
  }
  for load in skirmish3v3 team hordes300; do
  	page "$load-threads" "threads/index.html?load=$load&driver=inline,worker,inline,worker" || { edge "PAGE FAILED $load-threads"; failed_pages=1; }
  	page "$load-nothreads" "nothreads/index.html?load=$load&driver=inline,inline" || { edge "PAGE FAILED $load-nothreads"; failed_pages=1; }
  done
  [ "$failed_pages" = 0 ] && status=ok
  echo DONE >>"$L/edges.txt"
  ```

  (`cross_origin_isolated` prints `1` in Godot 4.7.2 web builds, `safari-check/web-20261114-124514.log:1`; the grep takes both spellings, the bug that stopped last night's base job after one run. `dom.max_script_run_time` 0 keeps Firefox's slow-script prompt away during the team fast-forward. The `EXIT` trap stops this run's units, removes its profiles and writes the terminal `JOB END ok|failed` line on every exit, including the parent unit's runtime bound below.)
- [ ] **Step 3 (push):** `ssh -o BatchMode=yes deck@<deck> mkdir -p wargrid-worker/tools wargrid-worker/web`; `scp <abs $D>/deck-job.sh deck@<deck>:wargrid-worker/`; `scp <abs $W>/tools/serve_web_bench.py deck@<deck>:wargrid-worker/tools/`; `scp -r <abs $E>/threads <abs $E>/nothreads deck@<deck>:wargrid-worker/web/`; check `ssh -o BatchMode=yes deck@<deck> ls wargrid-worker/web/threads/index.html wargrid-worker/web/nothreads/index.html wargrid-worker/tools/serve_web_bench.py`.
- [ ] **Step 4 (start):** `ssh -o BatchMode=yes deck@<deck> systemd-run --user --collect --same-dir --unit=wargrid-worker-job -p RuntimeMaxSec=12600 systemd-inhibit --what=sleep:idle --who=wargrid --why=benchmark sh wargrid-worker/deck-job.sh`; `ssh -o BatchMode=yes deck@<deck> systemctl --user is-active wargrid-worker-job` prints `active`. Return `STARTED`. Expected length: six pages, 18 runs of about 75 s plus the team fast-forward per team run (Deck team tick time not measured in the scene; under 2 h in all).
- [ ] **Step 5 (wait, coordinator, bounded, never blocking):** after Task 8's GREEN or BLOCKED and then at most every 20 minutes via a Monitor until-loop, `ssh -o BatchMode=yes deck@<deck> tail -n 1 wargrid-worker/logs/edges.txt` and `ssh -o BatchMode=yes deck@<deck> systemctl --user is-active wargrid-worker-job`. Fetch (Step 6) when the last line starts `JOB END`, or when the unit is no longer `active` (job died: fetch what exists, mark FAILED), or 3.5 h after STARTED (the unit's `RuntimeMaxSec` has then ended it). Never wait past that bound.
- [ ] **Step 6 (fetch, tabulate, clean up):** `scp -r deck@<deck>:wargrid-worker/logs <abs $D>/logs`; `python3 -I <abs $L>/worker_ab.py report <abs $D>/logs/skirmish3v3-threads <abs $D>/logs/skirmish3v3-nothreads <abs $D>/logs/team-threads <abs $D>/logs/team-nothreads <abs $D>/logs/hordes300-threads <abs $D>/logs/hordes300-nothreads > <abs $D>/deck-ab.txt 2>&1` (Task 8 writes the script; if Task 8 is not done, tabulate by reading the `WORKER RUN` lines). Fill "Deck rows": edges (ACAD, load range, any `PAGE FAILED`), per page isolation, `UA` Firefox version, DIGEST equality across arms and against the Mac headless rows (Task 2), per load and arm median [range] of `cpu_ms` p95 (`main_p95`) and p99/max, `missed_share`, `main_per_tick`, `frame_ms` p50/p95/p99/max, `tick_rate`, `backlog_max`, worker `job_ms` p95, `handoff_ms` p50/p95, `age_ms` p95, and the A/A range per arm. Report-only: no go/park/drop verdict from Deck rows. Then `ssh -o BatchMode=yes deck@<deck> rm -rf wargrid-worker`; `ssh -o BatchMode=yes deck@<deck> systemctl --user list-units --all --no-legend 'wargrid-worker*'` prints nothing; `ssh -o BatchMode=yes deck@<deck> ls .var/app/org.mozilla.firefox` lists no `wargrid-worker-profile-*`. `~/.local/share/godot` on the Deck is never touched. Fallback (export, launch or isolation failed): record, Firefox rows become a morning item, cleanup still runs.

---

### Task 8: Results and the morning A/B procedure

```text
Task: one extractor that applies the go / park / drop rule to result files; results.md with tonight's evidence and a short attended Mac A/B procedure.
Owns: $L/worker_ab.py, $O/results.md, the verification file.
Invariant: no repository file changes.
Boundary: works on Task 2's headless logs (stdout files), Deck result files and the morning's POSTed files.
Red: worker_ab.py on a hand-made fixture in $O/ab-fixture/ (outside every evidence folder the script is ever given; both goal loads; threaded inline, worker and no-threads inline; two runs each; all isolated; worker main_p95 better by 10× the spread against both baselines, every guard met) prints GO. Three variants must not print GO: (a) the worker's team cpu_ms.p99 above baseline median + range; (b) only the worker's team missed_share worse than baseline + range, everything else as the GO fixture; (c) one run not isolated (prints NO VERDICT); (d) one worker run with a differing DIGEST line (NO VERDICT); (e) one run ending `WORKER BENCH TIMEOUT` (NO VERDICT); (f) two `build` values in one load (NO VERDICT); (g) a goal load with 2 runs per arm (NO VERDICT); (h) a missing DIGEST tick (NO VERDICT); (i) a non-empty `failed` (NO VERDICT); (j) a window under 1800 ticks (NO VERDICT); (k) zero frame samples (NO VERDICT). Every hard NO VERDICT condition has its own fixture.
Green: all four fixture verdicts as expected; Task 2 logs and (if fetched) Deck logs tabulate without error.
Stop: none.
```

- [ ] **Step 1 (`worker_ab.py`, stdlib only, `python3 -I`):** usage `worker_ab.py decide|report <file or folder>…`; it reads only the paths it is given (folders: their `web-*.log` and `t2-*.log` files, not recursive), never a default root, so fixtures, fault-probe and mutant logs never enter a group unless named; a file is a sequence of `WORKER BENCH` header, `RUN i arm=…`, `DIGEST …`, `WORKER RUN {json}` and an end line; the export is the header's `export=` value. Each `WORKER RUN` row carries `build` and `window` from its page header. Hard `NO VERDICT` (with the reason), checked before any arithmetic: a missing or incomplete DIGEST sequence (every run of a load must print the same ticks from start + 300 to its end, every 300) or any digest mismatch across runs, arms and exports; any `WORKER BENCH FAILED` or `TIMEOUT` page, or a non-empty `failed`; a window shorter than 1800 ticks; zero frame samples; more than one `build` or `window` value per load; not isolated; fewer runs than the mode requires (`decide`: 3 per arm on each goal load, `skirmish3v3` and `team`, and any goal load with fewer than 3 is `NO VERDICT`; 2 per arm on `hordes300` and `late`; `report`: 1). `decide` is for the morning browser files only and prints the verdict; `report` (headless Task 2 rows, Deck rows) prints the tables with `REPORT ONLY` and never a verdict. Groups by (load, export, arm). Per group: run count, median and range (max − min over runs) of `cpu_ms.p95` (primary, `main_p95`), `cpu_ms.p99`, `cpu_ms.max`, `missed_share`, `main_per_tick`, `tick_rate`, `backlog_max`; report-only `frame_ms` p50/p95/p99/max; worker `job_ms.p95`, `handoff_ms.p50`, `age_ms` p50/p95 (flag `AGE HIGH` when p95 > 50 ms); W1 report-only: worker `job_ms.p95` against the design's 3.40 ms proposal, also shown ÷ 1.42 and ÷ 1.60 (the native-to-browser range). Digest check: every run of a load prints the same DIGEST lines (`DIGESTS EQUAL <load>` or the first differing tick). Rule (Question 2, decided), per goal load (`skirmish3v3`, `team`), worker (threaded) against **each** baseline, threaded `inline` and no-threads `inline` (the no-threads runs are not interleaved with the threaded page; say so beside the verdict): spread = max(range_baseline, range_worker) of `cpu_ms.p95`; gain = median_baseline − median_worker; guards: worker median `cpu_ms.p99` ≤ baseline median + the larger run range of `cpu_ms.p99`; worker median `missed_share` ≤ baseline median + its larger run range; pace: worker median `tick_rate` ≥ baseline median − its range and ≥ 29.7, worker `backlog_max` ≤ 1 in every run. Validity: every run of the load `isolated` true, else `NO VERDICT (not isolated)`; fewer than two runs in a group: `NO VERDICT (needs two runs per arm)`. Verdict: `GO` if gain > 2 × spread against both baselines with every guard met on both goal loads; else `PARK` if the worker's gain against threaded `inline` > 2 × spread on `hordes300` or `late` (design answers, third round); else `DROP`. Print the ranges, gains and each guard's numbers beside the verdict, plus `main_per_tick` per arm as the frame-mix cross-check and the tax (no-threads inline ÷ threaded inline, median `cpu_ms.p95`). Last line `AB DONE`.
- [ ] **Step 2:** fixture red and green as in the contract (`decide <abs $O>/ab-fixture/<case>`); then `report <abs $L>/t2-skirmish3v3-inline.log …` naming the eight Task 2 row logs explicitly, and, if fetched, `report` with the six Deck page directories named explicitly (`<abs $D>/logs/skirmish3v3-threads`, `…-nothreads`, `team-threads`, `team-nothreads`, `hordes300-threads`, `hordes300-nothreads`).
- [ ] **Step 3 (`results.md`):** sections, measured separated from derived: Tree and environment (base, branch head, export tree, Godot, host load); Digest check (WD1, WD2 counts; Task 2 cmp per load; Deck digests); Fault probe (which detection path, time to detect, mutant); Hand-over cost per unit (Task 4 table, the line fit, the 210-unit value labelled derived, and what it predicts for the tax toward the 210-unit target); Headless scene rows (Task 2, labelled not timing evidence); Deck rows (or why missing); What the morning decides; **Morning A/B procedure (attended, Mac)**, step by step:
  1. Quiet host: `uptime` 1-minute load under 2.5; no game or other Godot (`pgrep -fl 'godot|generalszh'`); display at 60 Hz; Firefox the only foreground window, not covered, not minimised, tab visible for the whole page (a hidden or covered window slows ticks about 5×, `performance.md` noise check).
  2. In `$W`: `python3 -I tools/serve_web_bench.py ~/projects/wargrid-overnight-work/worker-threads/exports ~/projects/wargrid-overnight-work/worker-threads/morning 8060` (leave it running; it serves both exports under one origin with cross-origin isolation and writes each page's result into `morning/`).
  3. Open each URL in Firefox, one page at a time, in this order (each page interleaves its arms itself); do not click inside the page (no input; a click would also start audio); wait for `WORKER BENCH POSTED` on the page before the next: (a) `http://127.0.0.1:8060/threads/index.html?load=skirmish3v3&driver=inline,worker,inline,worker,inline,worker`; (b) `http://127.0.0.1:8060/nothreads/index.html?load=skirmish3v3&driver=inline,inline,inline`; (c) `…/threads/index.html?load=team&driver=inline,worker,inline,worker,inline,worker`; (d) `…/nothreads/index.html?load=team&driver=inline,inline,inline`; (e) `…/threads/index.html?load=hordes300&driver=inline,worker,inline,worker`; (f) `…/threads/index.html?load=late&driver=inline,worker,inline,worker`. Runs (user, 2026-11-15): 3 per arm on the goal loads, 2 on hordes300; the late canary, which the park rule also reads, gets 2 like hordes300 (the answer did not name it). The repeated runs are the A/A pairs. Time: about 75 s per skirmish3v3, hordes300 and late run and 75 s plus the fast-forward per team run (the page prints the fast-forward time; Task 2's headless team rows give the Mac estimate), about 35-45 minutes in all.
  4. Record by hand: `uptime` before (a) and after (f), the Firefox version (also in each file's `UA` line), anything that covered the window.
  5. Stop the server (Ctrl-C), then `python3 -I ~/projects/wargrid-overnight-work/worker-threads/logs/worker_ab.py decide ~/projects/wargrid-overnight-work/worker-threads/morning`: the last verdict line is GO, PARK, DROP or NO VERDICT (with its reason) and the numbers; digests must be equal across all runs and against the Mac headless rows.
  6. Optional (production go only, not the rule): one page (a) in Safari or Vivaldi to confirm the threaded scene boots there; the 2026-11-14 kill check covered the compute-only bench, not the scene.
- [ ] **Step 4:** resume record names the morning items: the A/B itself; Deck rows if D7 failed; scratch worktree removal (`git worktree remove ~/projects/wargrid-wt-worker` only after the decision; not in the night allow list); a release-build fault probe if the morning wants one; any denied command with its text.

## Commands the run needs

Checked against `~/projects/wargrid-overnight-work/night-settings.json` on 2026-11-15 after the preparation added the worktree, worker-threads Python, `mkdir` and `zh_ini.py` rules (read-only check). All present:

| Class | Exact forms | Status |
|---|---|---|
| Worktree folder | `additionalDirectories` `~/projects/wargrid-wt-worker`; `Edit(//Users/<user>/projects/wargrid-wt-worker/**)` | present (added in the preparation) |
| git | `git worktree add`, `git status`, `git diff`, `git log`, `git add`, `git commit` | present (`git log -1 --format=%h` replaces `git rev-parse`, which is not listed) |
| Godot | `godot --version`; `godot --headless --path <abs> --import`; `godot --headless --path <abs>/game --script <abs or res://>`; `godot --headless --path <abs>/game res://scenes/worker_bench.tscn -- …` | present (`godot:*`) |
| Repository wrappers | `sh tools/run_tests.sh` (also with a leading `WARGRID_TEST_ONLY=…`), `sh tools/run_checks.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/export_build.sh` | present |
| Scratch Python | `python3 -I ~/projects/wargrid-overnight-work/worker-threads/logs/worker_ab.py …` | present (added in the preparation) |
| Folders | `$L` and `$D` exist (created in the preparation); `mkdir -p ~/projects/wargrid-overnight-work/worker-threads*` | present; `export_build.sh` makes `$E/threads` and `$E/nothreads` itself; `scp -r` makes `$D/logs` |
| Host checks | `uptime`, `pgrep -fl`, `cmp`, `wc`, `tail`, `ls`, `rg` | present (`ls`, `rg` read-only) |
| Deck | `sh ~/projects/wargrid-native-work/deck-preflight.sh <deck>`, `ssh -o BatchMode=yes deck@<deck> …`, `scp <files> deck@<deck>:…`, `scp -r <dirs> deck@<deck>:…`, `scp -r deck@<deck>:… <abs>` | present |
| Watchdog | the Bash tool's `timeout` parameter (outer bound) plus the bench's `--deadline-s` timer (inner); no `kill`, `pkill`, `timeout` or `perl` on the Mac | nothing to add |
| Never needed | `git push`, `git merge`, `gh pr`, `fly`, `sh tools/deploy_web.sh`, `sh tools/run_game.sh`, `open -a …` (morning only, attended), `git worktree remove` (morning) | — |

## Questions

All decided (user, 2026-11-15); the plan follows each answer.

1. **The `a1` arm.** Lever A1 (step and hand-off in separate frames) is already on `main` (`presentation_clock.gd`, performance-next lever A1, 2026-11-11). **Decided: dropped.** Arms are `inline` (`main` unchanged) and `worker` on the threaded export, plus `inline` on the no-threads export; the freed runs go to A/A pairs (each page interleaves `inline,worker,inline,worker…`). The go rule compares the worker against threaded `inline` and against no-threads `inline`.
2. **Go-rule metric.** **Decided** (from a separate Opus research pass, adopted): primary `main_p95` = `cpu_ms.p95`, the p95 of main-thread CPU per rendered frame over all frames of the timed window, per-frame formula of `movement_benchmark.gd:244-257` with the `_script_ms` carry pairing (`performance.md:482`), nearest-rank `TimingStats.summary` (`timing_stats.gd:9-16`); `cpu_tick_frame_mean` dropped (it misses the refresh frame under `presentation_clock.gd:14-31` and favours the worker). Guards per goal load: `cpu_ms.p99` and `missed_share` (intervals > 25 ms) not above baseline median + larger run range; `frame_ms` report-only (rAF bins at about 16.7 ms); pace: `tick_rate` ≥ baseline − range and ≥ 29.7, `backlog_max` ≤ 1; `age_ms` p50/p95 reported, p95 > 50 ms flagged; W1 report-only (`job_ms.p95` ÷ 1.42-1.60 against 3.40 ms); validity: every run isolated, else no verdict. Spread = max(range_baseline, range_worker); gain = median_baseline − median_worker; GO needs gain > 2 × spread on both goal loads against threaded `inline` and against no-threads `inline` (its range in the spread; not interleaved), plus every guard; PARK as the third round; ranges printed beside the verdict. `main_per_tick` reported as a frame-mix cross-check.
3. **Runs per arm.** **Decided:** morning 3 per arm on the goal loads, 2 on hordes300; Deck 2 per arm.
4. **Team-match window.** **Decided:** starts at the first 300-tick mark with at least 210 units (Task 0 measures it).
5. **Static caches.** **Decided:** warm every kind before the worker starts and freeze, in the bench scene only (not tests).
6. **Hashing in every arm.** **Decided:** a digest every 30 ticks in all arms.
7. **Input in worker mode.** **Decided:** no input; `submit` and `preview_build` refuse, `snapshot()` is the last hash-tick snapshot.

Plan choices that are not questions (recorded so the review can challenge them): drain only in the physics frame (one-tick pipeline, result age reported; an extra drain in `_process` would need a `match_screen.gd` edit); several arms per page, each in a fresh scene instance (fewer page loads attended and on the Deck); the benchmarks' 300 + 1800-tick window; zoom 0.5 and quality High fixed, auto quality pick off; no native Deck rows tonight.

## Decisions this plan relies on

- Scratch experiment, not a production `SimPump`; base `main` after One controller; headless overnight, rendered and browser measurement attended (user, 2026-11-14, first round).
- Thin scope: scratch worker driver in the real match scene, headless digest check, threaded exports built overnight, one fault probe; full reader audit and other fault probes after a go; A1 a third A/B arm (later dropped, below); go rule on skirmish3v3 and team match against the better of `main` and A1, no worse frame tails, hordes300 as stress (user, 2026-11-14, second round).
- Park outcome on hordes300 or the late-game canary; hand-over cost per unit; reader inventory kept as plan input (user, 2026-11-15, third round).
- Tonight (user, 2026-11-15): branch `spike-worker-threads` from `main` in `~/projects/wargrid-wt-worker`, one local commit per GREEN task, never merged without a go; arms inline and worker plus the no-threads tax row; one threaded export choosing the arm by URL plus one no-threads export; Deck Firefox rows for all arms on skirmish3v3, team match and hordes300 with an A/A pair, served on the Deck, report-only, fallback as night 4; `PERF_RECORD=0`, no budgets, no ledger row; no visible Mac window; final review Opus (high); the morning A/B is the decision.
- Plan Questions 1-7 (user, 2026-11-15): A1 arm dropped (already on `main`), freed runs to A/A, worker judged against threaded and no-threads `inline`; go metric `main_p95` with the `cpu_ms.p99`, `missed_share`, pace, age, W1 and isolation rules of Question 2; runs 3 per arm on goal loads, 2 on hordes300, Deck 2; team window from the first 300-tick mark with at least 210 units; caches warmed and frozen in the bench scene only; a digest every 30 ticks in all arms; no input in worker mode.
