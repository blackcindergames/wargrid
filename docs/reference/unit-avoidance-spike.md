# Unit avoidance spike: evidence note (2026-11-09)

Status: **MEASURED, EVIDENCE ONLY. No design decision, nothing merged, nothing on main.** Branch `spike-avoidance`, base main `07c3ab6`. The spec is the [research prompt](../unit-avoidance-research-prompt.txt) ("Output" paragraph); the user's answers are in [design answers](design-answers-2026-11-08.md#unit-avoidance-scope) ([behaviour](design-answers-2026-11-08.md#unit-avoidance-behaviour), [spike](design-answers-2026-11-08.md#avoidance-spike-night-of-2026-11-08)); the milestone entry is in the [blueprint](../blueprint.md) (§7, "Unit avoidance milestone"). The prototypes are not production code and are not meant to be merged.

Neither approach meets the user's cost cap (about +0.5 ms p95 on the 300-unit benchmark) cleanly, and neither completes the packed 300-unit moves the way main does. Details, and what each would need, below.

## Where everything lives

Numbers in this note come only from the raw results and logs of the night, which are **outside the repo** (user rule: nothing from the night goes into the repo). `AW` = `~/projects/wargrid-overnight-work/avoidance`.

| What | Path |
|---|---|
| Experiment plan | `AW/plan.md` |
| Per-experiment results | `AW/results/E0.txt` (main baseline), `E1.txt` (A), `E2.txt` (B), `E3.txt` (harness), `E4.txt` (browser), `E5.txt` (screenshots) |
| Raw logs | `AW/logs/E0` to `E5` |
| Determinism traces | `AW/traces/` |
| Measured tree copies | `AW/trees/main`, `AW/trees/yield`, `AW/trees/reserve` |
| Browser runs | `AW/web/<label>-<n>/`, table `AW/logs/E4/web-table.txt` |
| Screenshots | `AW/shots/` |

Host for every number: Apple M6, macOS, Godot 4.7.2 (official, headless unless stated), 1-minute load 1.05 to 2.8 during timed runs, never above 3.0 there (the untimed E2 suite runs reached 3.10, v1 3.30; per-run values in the logs). Calibration run on main: p50 0.698, p95 0.718, p99 0.729 ms (`AW/logs/E0/calibration.log`). Cross-platform (Linux, Windows) determinism is **not verified** (no CI run without a push).

## What was built (shared)

Commits on `spike-avoidance`:

| Commit | Content |
|---|---|
| `e9f82ed` | Jam scenario harness: `game/scripts/debug/avoidance_scenarios.gd`, `game/benchmarks/run_avoidance.gd` |
| `344b1f3` | Approach A and the shared code |
| `d319b5a` | Approach B (small change to the shared code, see below) |

Shared code (`344b1f3`): `game/scripts/simulation/avoidance.gd` (mode switch, per-tick cell grids, pass-through rules, side-cell search, last resort, counters), a hook of 7 changed lines in `simulation.gd`, and `route_avoiding` (12 lines) in `grid_navigation.gd`. `git diff --stat 07c3ab6 HEAD` over `game/` shows 12 files and 1106 added lines in total, including the harness and the generated `.uid` files.

- **Mode switch.** `static var mode: String = ""` in `avoidance.gd` (committed value; `""` = today's movement, `"yield"` = A, `"reserve"` = B). The committed tree behaves as main. Measured copies set the mode with one asserted edit of that line.
- **Per-unit state** is `sim._avoid` (a Dictionary keyed by id, plus `stats` counters). It is **not snapshotted and not hashed**. A production version would have to be (see open questions).
- **Pass-through rules** (same in both approaches, so only the core rule differs): infantry through infantry; supply trucks on a supply run through everyone (others still treat them as solid, so the exact-position dock admission is untouched); crushers through enemy infantry (the kill itself is **not prototyped**, only the counter `would_crush`); units boarding a carrier, air, and units inside containers; a unit in the last-resort ghost state.
- **Last resort** (both): a unit blocked more than 150 consecutive ticks ignores all blockers for 60 ticks.
- **Side-cell search** (both): fixed order, four neighbours, then four straight cells at distance 2; no diagonals.
- **Local re-route**: `route_avoiding` marks a given set of cells solid in the shared `AStarGrid2D`, routes, and restores exactly those cells in the same call; at most 8 per tick, a failed one waits 30 ticks.

### Approach A: Zero Hour style yielding (`344b1f3`, `avoid_yield.gd`, 48 lines)

Wraps the unchanged `_advance`: if the unit would enter a cell held by a solid other, it restores position, route, status and order, sets `speed = 0.0` and runs the yielding rules, in this order: ignore the blocker within one cell of the destination (Zero Hour: `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/AIUpdate.cpp:1303-1311`, checked at 0a05454); vehicle vs idle friendly infantry (infantry sidesteps); a standing non-busy friend steps aside (its destination becomes the side cell); no side cell or enemy or busy blocker: re-route at once around the standing units within 2 cells; head-on: the lower right of way sidesteps (builder over non-builder, vehicle over infantry, then the unit in front, then id; Zero Hour's order: `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/AIUpdate.cpp:1215-1253`, checked at 0a05454); otherwise wait, re-route after 60 blocked ticks. Zero Hour's step-aside depth cap of 2 is `GeneralsMD/Code/GameEngine/Source/GameLogic/AI/AIPathfind.cpp:10125` (`m_moveAlliesDepth > 2`, checked at 0a05454); A resolves chains one hop per tick instead (E1.txt:255). The rule-by-rule Zero Hour pointers are in the overnight research (`wargrid-overnight-work/questions/avoidance-zh.md:9-49`), whose other cites were not all re-checked. A sidestepping unit resumes its saved order.

Bugs found and fixed during the build: re-sidestepping an already sidestepping unit every tick (counter 4184 in `dw_choke`, 66 after the fix) and re-route spam after 60 ticks (now only when `blocked % 60 == 0`).

### Approach B: OpenRA style reservation (`d319b5a`, `avoid_reserve.gd`, 167 lines)

`avoidance.gd` changed by +6/-1 lines (const `Reserve`, three record keys, the `Reserve.begin_tick` call, the dispatch at the top of `advance`); A's code is untouched. A moving unit must hold a claim on the cell of its next waypoint before it calls `_advance`; the claim is rebuilt each tick into per-class grids and dropped when the unit stops or re-routes. Blocked sequence: immovable blocker (standing enemy, busy friend, or a standing friend with no free side cell) means re-route at once; otherwise nudge a standing friend and wait 40 ticks; a moving blocker means wait 40 more, once; then re-route with every solid-to-me unit cell in a window of 10 cells solid (shortcut: a window, not the whole map); no route means sidestep if my cell is claimed by someone, else **give up** (order null, status `arrived`, destination left as is).

Two variants were built. v1 re-checked the held cell every tick (kept in `AW/logs/E2/avoid_reserve.v1.gd`); v2 (committed) skips the check while the claim on that cell is already held, which cut `cell_checks` from 222059 to 14669 in the `hordes300` window. All B numbers below are v2 unless marked v1.

## Method and gates

- **Cost**: interleaved main, X, main, X, main, X (3 runs each), median of 3, delta X minus main, main-vs-main spread = max minus min of the 3 main runs. The cap is the user's: delta p95 at most +0.5 ms on the 300-unit rows (movement open, movement dense, `hordes300`).
- **`sh tools/run_benchmark.sh` stops early on both approaches** (`run_movement.gd:82`, "Benchmark leg exceeded 3000 ticks", exit 1; main passes: E0 ran it 3 times, all gates passed). Per the plan the fallback is used: HEADLESS rows from `res://benchmarks/bench_runner.gd` and COMBAT rows from `res://benchmarks/run_combat.gd`, same workloads, no arrival check. Main medians from that path match E0 within the spread.
- **`hordes300` is all infantry**, so with infantry passing through infantry it measures the wrapper cost only, not blocking.
- **Activity inside the timed window** (harness counters, ticks 300 to 2099): in `move_open` and `move_dense` the mechanics ran under both A and B. In `docks` and `hordes300` only the wrapper ran (`cell_checks` only): A `docks` 264, `hordes300` 14122; B `docks` 262, `hordes300` 14669.
- **Budgets** are 1.82 ms p95 / 3.64 ms p99 (the 300-unit stress rows use `STRESS_CEILING` in `run_combat.gd:10`), see [performance ledger](performance.md#budgets). On this host main already exceeds the combat `open` p95 budget (E0: 1.853 against 1.82; known and accepted per the perf spike) and `hordes300` p95 (2.815, within its ceiling).
- **Main baseline** (E0, `AW/results/E0.txt`): movement open p95 0.681 / p99 0.849, dense 0.676 / 0.875, `hordes300` 2.815 / 3.311, docks 0.553 / 0.571.

## Approach A: results

### Cost, native (headless, ms)

| Row | main p95 | A p95 | delta p95 | main p99 | A p99 | delta p99 |
|---|---|---|---|---|---|---|
| HEADLESS open (300) | 0.690 | 1.560 | **+0.870** | 0.848 | 1.625 | +0.777 |
| HEADLESS dense (300) | 0.682 | 1.877 | **+1.195** | 0.887 | 1.971 | +1.084 |
| COMBAT hordes300 (300) | 2.834 | 3.220 | **+0.386** | 3.303 | 3.708 | +0.405 |
| COMBAT open | 1.864 | 2.487 | +0.623 | 2.197 | 2.720 | +0.523 |
| COMBAT dense | 1.790 | 2.566 | +0.776 | 2.094 | 2.819 | +0.725 |
| COMBAT contact | 1.152 | 1.284 | +0.132 | 1.604 | 1.915 | +0.311 |
| COMBAT skirmish3v3 | 1.298 | 1.534 | +0.236 | 1.464 | 1.709 | +0.245 |
| COMBAT transports | 1.073 | 1.188 | +0.115 | 1.163 | 1.273 | +0.110 |
| COMBAT defences | 0.785 | 0.871 | +0.086 | 2.081 | 2.203 | +0.122 |
| COMBAT docks | 0.558 | 0.608 | +0.050 | 0.577 | 0.625 | +0.048 |
| COMBAT ramp | 0.649 | 0.805 | +0.156 | 1.207 | 1.373 | +0.166 |
| COMBAT frc | 0.826 | 1.266 | +0.440 | 1.142 | 1.798 | +0.656 |

Main-vs-main p95 spread on the 300-unit rows: 0.014 (open), 0.004 (dense), 0.008 (`hordes300`); largest p95 spread on any row 0.020. Loads 1.5 to 2.5. Raw: `AW/logs/E1/cost-{main,yield}-{1,2,3}.log`.

- **Cap**: movement open FAIL (+0.870), movement dense FAIL (+1.195), `hordes300` PASS (+0.386).
- **Budget status**: movement open 1.560 / 1.625 within 1.82 / 3.64; movement dense p95 1.877 exceeds 1.82 (p99 1.971 within); `hordes300` p95 3.220 exceeds its ceiling 3.07 (p99 3.708 within 4.05); COMBAT open 2.487 / 2.72 exceeds its ceiling 2.10 / 2.59; COMBAT dense 2.566 / 2.819 within its ceiling 2.64 / 3.95; the other rows are within their budgets.
- **`run_combat.gd` exits 1 on A**: STRESS FAIL open, STRESS FAIL `hordes300`, and the validity check "never retaliated inside the timed window for skirmish3v3" fails (behaviour changed when units block each other).
- **Where the cost comes from** (E1's reading of the counters; the per-unit figure is the builder's arithmetic, not a separate measurement): `hordes300` has zero blocking (`blocked_ticks` 0, `cell_checks` 14122 in the window) and still costs +0.386 p95, so that is the fixed wrapper cost (grid fill in `begin_tick` for about 300 units plus the per-unit wrapper), about 1.3 microseconds per unit per tick. The movement rows add blocked retries: `blocked_ticks` 127185 (open) and 226653 (dense) over 1800 ticks, about 70 and 126 blocked units per tick, each re-running the step, the blocker lookup and the yielding rules every tick, plus `reroutes` 1263 / 2793 inside `step.advance`. **No optimisation pass was done.** E1 expects the fixed cost to be reducible and the blocked-retry cost less so; that is an expectation, not a measurement.

### Cost, browser (Mac Firefox 159.0.1, no-threads Web Bench export, `crossOriginIsolated` 1, 30 ticks/frame, release web export, median of 3)

A was outside the native cap (it failed it), measured because it cost only 3 extra runs. See the shared browser table below for all rows; A deltas p95: HEADLESS open +1.18, dense +1.66, `hordes300` +0.60.

### Jams (one run, deterministic; cap 6000 ticks)

| Scenario | completion main / A | blocked>150 units / episodes (near goal) | deadlocks | last resort veh / inf | overlap pair-ticks (peak), main / A | step_asides / sidesteps / reroutes / reroute_fail |
|---|---|---|---|---|---|---|
| move_open | 2331 / cap | 131 / 449 (28) | 60 | 449 / 0 | 94951 (123) / 120968 (70) | 214 / 265 / 3027 / 667 |
| move_dense | 2369 / cap | 252 / 1281 (27) | 50 | 1281 / 0 | 1639208 (1891) / 747081 (609) | 262 / 273 / 5436 / 301 |
| docks | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 380 (2) / 380 (2) | 0 / 0 / 0 / 0 |
| docks_traffic | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 16435 (25) / 1191 (4) | 12 / 1 / 44 / 0 |
| hordes300 | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 0 / 0 | 0 / 0 / 0 / 0 |
| dw_exits | 1095 / 1778 | 2 / 2 (0) | 0 | 2 / 0 | 1389 (8) / 171 (1) | 15 / 14 / 20 / 2 |
| dw_docks | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 9194 (18) / 841 (5) | 1 / 9 / 25 / 0 |
| dw_choke | 1220 / 1588 | 3 / 3 (0) | 0 | 3 / 0 | 908 (11) / 289 (3) | 7 / 66 / 54 / 0 |
| dw_group50 | 2823 / cap | 6 / 7 (1) | 2 | 5 / 2 | 14499 (19) / 1074 (3) | 27 / 59 / 125 / 27 |

On main every blocked and deadlock column is 0 (units pass through each other); overlap is the signal there. Main's `status_blocked_units` is 0 everywhere. Docks: credits 4500 / 900 (`dw_docks`) and waiting ticks identical to main in `docks`, `docks_traffic` and `dw_docks`. `off_goal` (ordered units more than 2.5 cells from their chosen destination at the end): `dw_exits` 1, `dw_group50` 4 (main 0). Builder last resorts and `would_crush`: 0 everywhere.

### Determinism

- Harness `--mode yield` twice in separate processes with `--trace`: `diff -r` identical (9 files) (`AW/traces/E1-yield-1`, `E1-yield-2`).
- Mode `""` (hook compiled in, `begin_tick` returns false) vs main: traces identical (`AW/traces/E1-off` vs the E3 main traces); suite on the committed tree: CASES 559, CHECKS 136844, FAILURES 0.
- **Float operations in the new code** (line numbers as in `d319b5a`): `avoid_yield.gd:43,46` (`*`, `+`, `-` and comparisons on heading and position in the right-of-way test), `avoid_yield.gd:47,48` (`== 0.0` and `< 0.0` compares); `avoidance.gd:69,76,82,85` (`floori` on the float64 position or destination), `avoidance.gd:218` (`cell + 0.5`), `avoidance.gd:144` (`unit.speed = 0.0`, assignment), `avoidance.gd:222` (`speed == 0.0`), `avoidance.gd:236,237` (`Vector2(...)` float32 cast before `navigation.route_avoiding`, the same cast `simulation._assign_route` does). No `sqrt`, `sin`, `cos`, `atan2` or `pow` in the new files. Decisions iterate the sorted ids or fixed orders (the four directions, a 5x5 scan y then x); Dictionaries are only read with `get`/`has`. The heading values come from the existing `Locomotion`. Cross-platform: **not verified**.

### Suite with A active (`AW/logs/E1/suite-yield.log`)

CASES 559, CHECKS 669307, FAILURES 17, exit 1. One of the 17 is an archive artifact (W3 vector files: the E1 tree copy had no `protocol/vectors`; it passes in the worktree), so 16 real. Failing: BM5 per-unit and snapshot node ceilings (open, dense), BM6 settled predicate, Cs1, Fm1, S1 (two lines), TB3 and TB4 pins, G3 arrives within 1800 ticks (two lines), P3 (two lines), S8 occupied toggle setup. Pins and traces are the expected re-pin scope. G3, P3, S8 and BM6 are behaviour tests (units now block each other) and need a look in a real milestone. Not fixed or re-pinned.

### Failure cases seen

- **Packed 300-unit moves do not finish.** `move_open` and `move_dense` hit the 6000-tick cap (main: 2331 and 2369). Destinations are 300 unique cells in one blob and the start is a full 20x15 block. Standing arrivals have no free side cell (every neighbour is occupied or reserved), so crossers re-route (the re-route fails), wait 150 ticks, then ghost through for 60 ticks. Numbers: 131 and 252 units reach more than 150 blocked ticks, 449 and 1281 vehicle last resorts (a pass-through storm), 60 and 50 deadlocks. Only 28 and 27 episodes are within 4 cells of the goal, so most of it is transit jam in the packed start and crossing, not arrival alone. In `move_open`, overlap pair-ticks are *higher* than main (120968 vs 94951): the last resort lets units through each other again. E1 saw 14 units still moving at tick 14000 in a scratch run.
- **`dw_group50` never finishes** (cap): one unit (id 35) circles the goal area for thousands of ticks re-routing around standing arrivals; `route_avoiding` only knows standing units within 2 cells of the mover, and `blocked` resets whenever the unit enters a new cell, so the 150-tick last resort never fires (counted as deadlocks = 2).
- **`run_benchmark.sh` fails** on `run_movement.gd:82` ("leg exceeded 3000 ticks"), so A cannot pass the real gate as is.
- Yielding costs wall time: `dw_exits` 1778 vs 1095 ticks (+683), `dw_choke` 1588 vs 1220 (+368).
- Step-aside from a packed block moves destinations (`off_goal` 1 and 4).
- Combat-mode validity changes (the skirmish3v3 retaliation check, above).

### Hard to implement, and why

- **"Units step aside a cell or two / go around"** with one-cell units and a fully packed benchmark destination: there is no free cell to step into. The design needs looser destination packing or a stronger crossing rule than Zero Hour's one-cell goal ignore (`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Update/AIUpdate.cpp:1303-1311`).
- **"Last resort after about 5 s"**: the timer counts continuous blocking and resets on any new cell, so a unit circling an obstacle never trips it.
- **"A fast unit behind a slower friend slows and follows"**: not prototyped (speed matching); stop-and-go keeps many units in the blocked state every tick, which is what drives the movement-row cost.

## Approach B: results

### Cost, native (headless, ms)

| Row | main p95 | B p95 | delta p95 | main p99 | B p99 | delta p99 |
|---|---|---|---|---|---|---|
| HEADLESS open (300) | 0.693 | 0.996 | **+0.303** | 0.847 | 1.079 | +0.232 |
| HEADLESS dense (300) | 0.685 | 0.577 | **-0.108** (artifact, below) | 0.881 | 0.763 | -0.118 |
| COMBAT hordes300 (300) | 2.836 | 3.475 | **+0.639** | 3.327 | 3.960 | +0.633 |
| COMBAT open | 1.869 | 2.464 | +0.595 | 2.206 | 2.715 | +0.509 |
| COMBAT dense | 1.801 | 2.520 | +0.719 | 2.109 | 2.976 | +0.867 |
| COMBAT contact | 1.157 | 1.316 | +0.159 | 1.604 | 1.744 | +0.140 |
| COMBAT skirmish3v3 | 1.299 | 1.568 | +0.269 | 1.461 | 1.715 | +0.254 |
| COMBAT transports | 1.070 | 1.252 | +0.182 | 1.161 | 1.336 | +0.175 |
| COMBAT defences | 0.785 | 0.931 | +0.146 | 2.081 | 2.301 | +0.220 |
| COMBAT docks | 0.558 | 0.628 | +0.070 | 0.576 | 0.646 | +0.070 |
| COMBAT ramp | 0.648 | 0.814 | +0.166 | 1.214 | 1.399 | +0.185 |
| COMBAT frc | 0.824 | 1.251 | +0.427 | 1.147 | 1.753 | +0.606 |

Main-vs-main p95 spread on the 300-unit rows: 0.004 (open), 0.003 (dense), 0.018 (`hordes300`); the largest p95 spread on any row is 0.047 (COMBAT dense). Raw: `AW/logs/E2/cost-{main,reserve}-{1,2,3}.log`, table `AW/logs/E2/cost-table.txt`. v1 deltas p95 for the cap rows: open +0.363, dense -0.088, `hordes300` +0.772.

- **Cap**: movement open PASS (+0.303), movement dense PASS (-0.108), `hordes300` **FAIL** (+0.639). **The two passes are not wins.** In the HEADLESS rows, B completes 1 leg in the timed window and main 2: units give up, leg 2 never starts, so B does less movement work. The dense row is cheaper than main because of that, not because the mechanics are cheap.
- **Budget status**: movement open 0.996 / 1.079 and dense 0.577 / 0.763 within 1.82 / 3.64; `hordes300` p95 3.475 exceeds its ceiling 3.07 (p99 3.960 within 4.05); COMBAT open 2.464 / 2.715 exceeds its ceiling 2.10 / 2.59; COMBAT dense 2.520 / 2.976 within its ceiling 2.64 / 3.95; the other rows are within their budgets.
- **`run_combat.gd` exits 1 on B**: STRESS FAIL open (p95 2.464) and `hordes300` (p95 3.475). The skirmish3v3 retaliation validity check does *not* fail on B (it failed on A).
- **Fixed wrapper cost** is higher than A's for infantry (`hordes300` +0.639 vs +0.386 p95): per-unit record lookup, the claim-rebuild loop over all ids, the per-cell holder test. Only wrapper work ran in the `hordes300` window (`cell_checks` 14669).

### Cost, browser (Mac Firefox 159.0.1, same export and method as above)

B deltas p95: HEADLESS open +0.42, dense -0.14, `hordes300` +0.94 (cap FAIL, +0.5); same shape as native, scaled up about 1.4 to 1.5x (E4's reading; web main is 1.4 to 1.5x the native main row, for example open 1.00 vs 0.681 and `hordes300` 4.00 vs 2.815). B still gives up in the browser (legs 1 vs main 2 on both movement rows), so the movement rows are cheaper or dearer than main for the wrong reason.

### Jams (v2, one run, deterministic; cap 6000 ticks)

| Scenario | completion main / B | blocked>150 units / episodes (near goal) | deadlocks | last resort veh / inf | overlap pair-ticks (peak), main / B | nudges / reroutes / reroute_fail = gave_up | off_goal |
|---|---|---|---|---|---|---|---|
| move_open | 2331 / cap | 19 / 20 (6) | 2 | 20 / 0 | 94951 (123) / 10287 (6) | 125 / 2009 / 168 | not recorded |
| move_dense | 2369 / 2601 | 5 / 5 (1) | 1 | 5 / 0 | 1639208 (1891) / 173 (1) | 102 / 343 / 245 | not recorded |
| docks | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 380 (2) / 380 (2) | 0 / 0 / 0 | n/a |
| docks_traffic | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 16435 (25) / 1477 (4) | 20 / 22 / 5 | n/a |
| hordes300 | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 0 / 0 | 0 / 0 / 0 | n/a |
| dw_exits | 1095 / 1331 | 0 / 0 | 0 | 0 / 0 | 1389 (8) / 0 (0) | 8 / 11 / 7 | 7 |
| dw_docks | fixed / fixed | 0 / 0 | 0 | 0 / 0 | 9194 (18) / 429 (4) | 4 / 19 / 2 | n/a |
| dw_choke | 1220 / 2041 | 5 / 5 (0) | 1 | 4 / 1 | 908 (11) / 50 (1) | 20 / 83 / 13 | 13 |
| dw_group50 | 2823 / cap | 0 / 0 (0) | 2 | 0 / 0 | 14499 (19) / 0 (0) | 11 / 281 / 25 | 29 |

Docks: credits and waiting ticks identical to main in `docks`, `docks_traffic` and `dw_docks`. `sidesteps` is 0 in every B scenario (the `UnblockDestination` sidestep never fired). `move_dense` completes at 2601 only because 245 units gave up (their orders ended); in v1 it hit the cap.

### Determinism

- Harness `--mode reserve` twice in separate processes with `--trace`: `diff -r` identical (9 files), for v1 (`AW/traces/v1-E2-reserve-1`, `-2`) and v2 (`AW/traces/E2-reserve-1`, `-2`).
- Shared code changed for B, so neutrality was re-checked: mode `""` traces identical to main (`AW/traces/E2-off`, `E2-off-v2`), suite in the worktree CASES 559, CHECKS 136844, FAILURES 0.
- **Float operations in `avoid_reserve.gd`**: `:88` and `:163` `unit.speed = 0.0` (assignment); `:122` and `:125` `Vector2(...)` float32 cast before `navigation.route_avoiding` (same as A and `simulation._assign_route`). No `+ - * / sqrt` on floats, no `sin`, `cos`, `atan2`, `pow` (the integer index arithmetic at `:14` and `:144` is not a float operation). Cells come from `floori` in `avoidance.gd` (lines above). Decisions iterate the sorted ids and a fixed y-then-x scan; no Dictionary iteration. Cross-platform: **not verified**.

### Suite with B active (`AW/logs/E2/suite-reserve.log`)

CASES 559, CHECKS 568890, FAILURES 17, exit 1 (v1: 17, same names). Failing: S8 (4 lines), Fm1, TB3, S1 (2 lines), TB4, P3, G3, BM5 (4 lines), Cs1, BM6. W3 passes (this copy had `protocol/`). E2 diagnosed the lines A left uninvestigated, and showed that the mode-off wrapper is not the cause (main copy and worktree with mode `""` both give 0 failures with identical counts):

- G3 (30 units to one point): after 1800 ticks 29 arrived and 1 still moving in the rectangle layout (11 gave up with status `arrived`); the test needs all 30.
- BM5: the tick-38 snapshot has more nodes with avoidance (scratch measurement: 84215 to 84980 open, 85079 to 85844 dense, busiest unit 339 to 342 against ceiling 336). Re-routes change route lengths: a pin, not a defect.
- BM6: 0 mismatches but 0 flips; the workload never settles in 1500 ticks per layout and the test needs at least one flip.
- P3 (reasoned from code, not run in isolation): the test allows 20 ticks for the first exit to free; B's nudge plus 40-tick wait is longer.
- S8 (reasoned from code, not reproduced headless): unit 1 must reach exactly (10.5, 5.5) within 250 physics ticks; under avoidance it does not.

### Failure cases seen

- **Units give up and never resume.** `gave_up` equals `reroute_fail` in every scenario: every failed re-route ends in a give-up. A given-up unit stands still with order null, status `arrived` and its destination left behind: `move_open` 168 units, `move_dense` 245, `docks_traffic` 5, `dw_exits` 7, `dw_docks` 2, `dw_choke` 13, `dw_group50` 25. With 300 unique destination cells packed in a blob (and a 50-unit group to a blob, and start blocks packed solid) some unit's destination is enclosed by standing units, so there is no route with all units solid and it gives up.
- **No 300-unit move completes in the sense `run_movement.gd` needs.** `move_open` hits the cap; `move_dense` ends at 2601 only because 245 units abandoned their orders. `run_benchmark.sh` fails on `run_movement.gd:82` (leg over 3000 ticks).
- **Livelock at the cap** in `move_open` and `dw_group50`: two infantry in the start cluster ping-pong between re-routes around given-up tanks that stand in the start block (an immovable-blocker re-route avoids only that one cell, the next given-up tank blocks again). `blocked150` never trips because `blocked` resets on every new cell (the same hole as A's circling unit).
- Slower than main in transit: `dw_exits` 1331 vs 1095 (+236), `dw_choke` 2041 vs 1220 (+821; A +368).
- v1 `move_dense` hit the cap; v2 ends at 2601 with 245 gave-ups.

### Hard to implement, and why

- **Units give way and keep their orders** (a consequence of the "Units step aside" and "re-route" answers in [design answers](design-answers-2026-11-08.md#unit-avoidance-behaviour), not a quoted answer; the answers contain no give-up rule): B's prototype gives up when no route exists (`avoid_reserve.gd`, E2.txt:113). OpenRA's own give-up is its "close enough" rule at the destination (`OpenRA.Mods.Common/Activities/Move/Move.cs:265-289`, spot-checked at OpenRA `9636b63eae`); whether OpenRA gives up when there is no route at all is unverified. With unique destination cells packed into a blob there is always a unit whose destination is enclosed. It needs looser packing, a "stop near enough" rule, or Zero Hour's goal-ignore rule (excluded from B by the plan to keep only the core rule different).
- **"Last resort after about 5 s"**: the blocked counter resets on each cell entered, so units cycling between cells never reach it (both approaches).
- **"Step aside a cell or two" for tanks**: the nudge fires only on standing blockers; moving blockers get no help (plan), so head-on convoys resolve only by waiting and re-routing.

## Browser numbers (Mac Firefox 159.0.1, Web Bench export, no threads, median of 3, interleaved main, A, B)

Same asserted edit in all three tree copies: `game/benchmarks/bench_runner.gd:29` combat list `["open","dense","contact","skirmish3v3"]` plus `"docks","hordes300"` (the committed tree does not have it). Engine 4.7.2, `crossOriginIsolated` 1. Main-vs-main p95 spread at most 0.02 on every row. Table: `AW/logs/E4/web-table.txt`.

| Row (p95 / p99 ms) | main | A | B | delta p95 A | delta p95 B |
|---|---|---|---|---|---|
| HEADLESS open | 1.00 / 1.22 | 2.18 / 2.26 | 1.42 / 1.54 | +1.18 | +0.42 |
| HEADLESS dense | 0.96 / 1.26 | 2.62 / 2.76 | 0.82 / 1.08 | +1.66 | -0.14 |
| COMBAT hordes300 | 4.00 / 4.76 | 4.60 / 5.32 | 4.94 / 5.66 | +0.60 | +0.94 |
| COMBAT open | 2.66 / 3.12 | 3.54 / 3.86 | 3.50 / 3.86 | +0.88 | +0.84 |
| COMBAT dense | 2.54 / 2.98 | 3.64 / 4.02 | 3.60 / 4.28 | +1.10 | +1.06 |
| COMBAT contact | 1.62 / 2.28 | 1.82 / 2.76 | 1.86 / 2.46 | +0.20 | +0.24 |
| COMBAT skirmish3v3 | 1.84 / 2.08 | 2.20 / 2.46 | 2.24 / 2.44 | +0.36 | +0.40 |
| COMBAT docks | 0.80 / 0.82 | 0.88 / 0.92 | 0.90 / 0.92 | +0.08 | +0.10 |
| TEAM MATCH (to the 45000-tick cap) | 1.86 / 4.08 | 2.20 / 4.20 | 2.34 / 4.50 | +0.34 | +0.48 |

Both A and B complete 1 movement leg vs main 2 in both movement rows (`legs=`), so those two rows measure a run that ends its work earlier. `bench_runner.gd` checks neither arrival nor any other validity, so a jam is invisible there except through `legs=`. The team match hit its cap (45000 ticks) on all three trees, so there is no differing end tick. Mac Firefox only: Chrome, Safari and the Deck are not measured. Each run left its Firefox tab open (9 tabs in the user's Firefox window; close by hand).

## Screenshots

Taken windowed on Dry Wells (`dw_choke`, `dw_docks`), 1280x720, fixed camera per scenario (`dw_choke` focus (40,44), `dw_docks` focus (26,7), zoom 1.5), at the tick of the highest blocked count (A, B) or the highest shared-cell count (main, which has no blocked counter) and 300 ticks later. Not copied into the repo. Each exists as `<name>.png` and `<name>_marked.png` (debug rings: yellow = blocked, magenta = last-resort ghost, red = gave up). All in `~/projects/wargrid-overnight-work/avoidance/shots/`:

| File (without `.png`) | What it shows |
|---|---|
| `main_dw_choke_t378` | Two 25-unit groups passing through each other in a blob of about 10 cells, rectangles drawn on top of one another; nobody stopped |
| `main_dw_choke_t678` | Groups have swapped sides, strung out; 4 units still overlapping |
| `yield_dw_choke_t578` | One tight mass of about 30 blocked units head-on in the middle, one ghost; almost no overlap; no give-ups |
| `yield_dw_choke_t878` | Jam fully dissolved, both groups past each other |
| `reserve_dw_choke_t701` | About 30 blocked units queueing in two arcs, one ghost, 8 given-up units standing short of their goals |
| `reserve_dw_choke_t1001` | Queues mostly dissolved, 7 given-up units frozen in place (5 of them from t701) |
| `main_dw_docks_t498` | The 10 shuttling tanks stacked in a clump of 4 to 5 cells south of the pile |
| `main_dw_docks_t798` | 5 trucks on the dock ring (docked 1, waiting 4), tanks passed |
| `yield_dw_docks_t597` | The tanks in a tight 2-cell blob of 8 blocked tanks east of the pile, waiting for each other |
| `yield_dw_docks_t897` | Trucks on the ring undisturbed; 4 tanks still waiting in a small cluster to the east |
| `reserve_dw_docks_t67` | Start-up congestion: 8 tanks queue in a row at the west waypoint cell right after spawning; not a dock jam |
| `reserve_dw_docks_t367` | Two given-up tanks at the west waypoint cell next to the ridge, one blocked tank on the ring's south corner; the pile label is drawn over a tank |

Caveats (E5): units are placeholder rectangles, all owner 1 and the same blue, so tanks vs infantry vs trucks differ only in size and the two head-on `dw_choke` groups cannot be told apart by colour; the pile label draws over units standing on it; vsync was not disabled (irrelevant for stills). Windowed Dry Wells rendering from a `SceneTree` script (a `WorldView` node plus a `Camera2D`) works with Dummy audio.

## Comparison

All figures p95 deltas against main, native unless stated; "cap" = +0.5 ms on the 300-unit rows.

| | A (yield) | B (reserve) |
|---|---|---|
| Cap, movement open | FAIL, +0.870 | pass, +0.303 (units give up; 1 leg vs 2) |
| Cap, movement dense | FAIL, +1.195 | pass, -0.108 (artifact of give-ups) |
| Cap, `hordes300` (wrapper only) | pass, +0.386 | FAIL, +0.639 |
| Browser, open / dense / `hordes300` | +1.18 / +1.66 / +0.60 | +0.42 / -0.14 / +0.94 |
| `run_benchmark.sh` | fails (leg over 3000 ticks) | fails (leg over 3000 ticks) |
| `run_combat.gd` | exit 1: open and `hordes300` over ceiling, skirmish3v3 validity fails | exit 1: open and `hordes300` over ceiling |
| Packed 300-unit move | cap (`move_open`, `move_dense`); 449 / 1281 vehicle last resorts | cap (`move_open`); `move_dense` 2601 with 245 units given up |
| Units abandon their orders | no (`gave_up` 0) | yes: `move_open` 168, `move_dense` 245, `docks_traffic` 5, `dw_exits` 7, `dw_docks` 2, `dw_choke` 13, `dw_group50` 25 |
| Overlap, non-packed scenarios (main to X) | `docks_traffic` 16435 to 1191, `dw_docks` 9194 to 841, `dw_exits` 1389 to 171, `dw_choke` 908 to 289, `dw_group50` 14499 to 1074 | `docks_traffic` 16435 to 1477, `dw_docks` 9194 to 429, `dw_exits` 1389 to 0, `dw_choke` 908 to 50, `dw_group50` 14499 to 0 (units given up stand still, so part of this is inactivity) |
| Overlap, packed moves | `move_open` worse than main (120968 vs 94951), `move_dense` 747081 (45 % of main) | `move_open` 10287, `move_dense` 173 |
| Transit time vs main | `dw_exits` +683, `dw_choke` +368 | `dw_exits` +236, `dw_choke` +821 |
| Docks credits / waiting | identical to main | identical to main |
| Determinism | identical across two runs; neutral at mode `""` | identical across two runs (v1, v2); neutral at mode `""` |
| Suite with the mode active | 17 failures (16 real) | 17 failures |
| Fixed wrapper cost (infantry pass-through, `hordes300`) | +0.386 | +0.639 |

What the numbers say:

- Both approaches remove most vehicle overlap where the scene is not a packed 300-unit move, and both leave docks credits untouched.
- Neither can move 300 units into a block of 300 unique destination cells. A fails by a deadlock/last-resort spiral; B fails by giving up. This is the user's "arrival spreading keeps today's reserved destination cells" scope answer meeting a benchmark that packs the destinations; see the open questions.
- B's apparent cap passes on the movement rows are an artifact of giving up, not of cheap mechanics.
- A is the more expensive on the rows where blocking happens; B is the more expensive where nothing blocks.

## Recommendation (a proposal; the user decides)

**Neither passes the cap cleanly, and neither is ready to become the milestone as built.**

- **A** is the one that matches the user's answers (right of way, standing friends step aside, head-on sidestep, last resort, re-route timing; they came from Zero Hour). It misses the cap on both movement rows by a wide margin (+0.870 and +1.195 against +0.5), keeps only about 0.11 ms of the 0.5 ms for any real work (inference: 0.5 minus the wrapper's +0.386 on `hordes300`, which assumes the infantry-only wrapper cost equals the vehicle-row wrapper cost), does not finish packed moves, and its failures are mechanical (a 150-tick timer that resets, a re-route that sees only 2 cells). To become a candidate it needs: (1) the wrapper and blocked-retry cost cut, for example no per-tick retry for blocked units and a cheaper infantry path (**untried**; E1's expectation is that the fixed cost is reducible and the blocked-retry cost less so); (2) a decision on arrival packing (open question 1); (3) a last-resort timer that counts no progress towards the goal, not consecutive blocked ticks; (4) the unprototyped pieces that change the cost profile (speed matching, column group moves) before the cost is trusted.
- **B** gives the cleanest result on overlap, but only by units that stop and never resume. It misses the cap on `hordes300` (+0.639), and its movement-row passes are not valid evidence. To become a candidate it needs: no give-up (Zero Hour's goal-ignore rule or an OpenRA "near enough" rule, both excluded from the prototype; given-up units must resume or be replaced by something else), a re-route that does not use a 10-cell window, and a wrapper cheap enough to get under the cap with room left for the blocking work. It is also not one of the user's answers (the answers are Zero Hour rules).
- **If one is to continue**, my reading (inference, not tested) is A's rule set as the base with B's idea of claiming the next cell tried only where A's retry cost shows up. A hybrid is a hypothesis; nothing in the results tests it.
- **The cap itself** is only meaningful if it is clear which rows it applies to: `hordes300` is all infantry and measures pure wrapper cost, while the two movement rows are where blocking happens. I applied it to all three rows as the plan says; this is for the user to confirm (open question 2).

### Steam Deck estimate (UNMEASURED, inferred)

Not measured on the Deck. Inference only: the ledger's browser factor F = 5.5 ([ledger](performance.md#target-factor-measurement-2026-11-06), Deck Firefox p95 against the Mac editor build, 4.9 to 5.45 across the rows then) applied to the native p95 deltas above:

| Row | A (native delta x 5.5) | B (native delta x 5.5) |
|---|---|---|
| movement open | about +4.8 ms | about +1.7 ms |
| movement dense | about +6.6 ms | about -0.6 ms (give-up artifact) |
| `hordes300` | about +2.1 ms | about +3.5 ms |

Compare with the 10 ms target-device budget (1.82 x 5.5). The web-on-Mac deltas measured in E4 are 1.3 to 1.55x the native ones on the three cap rows, so the Deck figure cannot be reconstructed from the Mac web numbers alone; this table is arithmetic on one factor and nothing else. A real Deck run needs the user (Deck, Desktop Mode, plugged in, per the ledger's Steam Deck section in [performance.md](performance.md)).

## What was NOT prototyped

- Crushing kills (only the pass-through and the counter `would_crush`; it stayed 0 in every scenario because no scenario has mixed owners, so the crush path was never exercised).
- Column group moves (infantry 3 wide, vehicles 2 wide, one shared route), the factory-exit special case (the generic step-aside stands in for it), the building-placement move-away, multi-cell vehicle footprints (one cell per unit).
- Speed matching ("a fast unit behind a slow friend follows"); it is stop-and-go in A, and B has no equivalent.
- Step-aside depth cap 2 (in A chains resolve one hop per tick); A's shortcut that units sharing a cell are invisible to the per-tick grids (first writer wins); the grids' reserved map holds destinations only.
- B: OpenRA's near-enough / give-up-at-destination rule, nudge depth, notifying a moving blocker; a moving unit with order null that gets a sidestep would not resume (not exercised).
- Combat guard interaction (`combat.gd:101`) for stepped-aside or nudged units: reasoned from the code, not exercised in an armed fight.
- Snapshot and hash of `sim._avoid`; aircraft (unchanged); fog; the "keep formation" command.
- No optimisation pass on either approach.
- Not measured: Steam Deck, Chrome, Safari, Linux/Windows determinism, a rendered benchmark.

## Open questions for the brainstorm

1. **Arrival packing.** The scope answer keeps today's reserved destination cells, so 300 units are sent to 300 unique cells in one blob. Both prototypes fail on it (A spirals into last resorts, B gives up). Keep unique cells and relax something else (a larger goal-ignore radius, "stop near enough", fan-out slots), or change the benchmark's destinations? Which one is a design decision, not a tuning one.
2. **What the 0.5 ms cap covers.** It is about 28 % of the 1.82 ms budget on a row where main is at 0.69. Does it apply to `hordes300` (wrapper cost only, all infantry) as well as to the movement rows? With the current wrapper both approaches use 0.39 to 0.64 ms there before any blocking.
3. **`dw_choke` is not a bottleneck.** On the Dry Wells route the narrowest cross-section is 20 cells wide at (40,44), route index 21 of 62. The scenario is two 25-unit groups head-on in a 20-wide lane, so the screenshots show head-on mixing in open ground. Is there a real choke on Dry Wells or on a converted map (bridge, ramp) to use instead? I did not check which map has one.
4. **Per-unit state is not hashed.** `sim._avoid` is outside snapshot and state hash; the trace column only sums the counters. The determinism result above holds for two runs from the same start in one build. A production version must serialise it (late join, replays, rollback of any kind), which adds cost on top of the numbers here.
5. **Last-resort timer.** It resets on every new cell, so circling units escape it in both approaches. Count "no progress towards the goal for N ticks" instead? The user's "about 5 s" says nothing about this.
6. **Give-up policy.** Zero Hour's goal-ignore versus OpenRA's give-up; and what a unit that cannot reach its cell should do (stop, repath to a nearby cell, wait).
7. **Cost shape.** A's blocked units re-run the step every tick (about 70 to 126 per tick in the movement rows). Is stop-and-go acceptable, or does speed matching have to be part of the first version because of cost, not only feel?
8. **Crushing and mixed-owner scenarios.** The crush path never ran. Add a mixed-owner scenario before any decision on its cost.
9. **Pins and behaviour tests.** Besides the expected trace and pin re-pins, G3, P3, S8 and BM6 fail under an active mode because behaviour changed. Which of them should be rewritten and which reflect behaviour the user does not want?
10. **Screenshots.** Units are same-coloured placeholders; if the screenshots will be used to judge feel, should the shot script colour by group or role?
11. **Browser and Deck.** Only Mac Firefox was measured, and the Deck estimate above is unmeasured.

## Reproduce

All commands run from the worktree `~/projects/wargrid-wt-avoid` unless stated. One Godot process at a time (the night used a lock directory `AW/godot.lock`, taken with `mkdir` and released with `rmdir`). Every suite or benchmark call: output to a file, tool timeout 600000 ms. `AW=~/projects/wargrid-overnight-work/avoidance`.

**Trees.**

```sh
# main baseline (07c3ab6); copy the two harness files in for the jam baseline
mkdir -p $AW/trees/main && git archive 07c3ab6 game tools protocol | tar -x -C $AW/trees/main
cp game/scripts/debug/avoidance_scenarios.gd $AW/trees/main/game/scripts/debug/
cp game/benchmarks/run_avoidance.gd $AW/trees/main/game/benchmarks/

# A and B: archive the commit, set the mode with an asserted edit of one line
mkdir -p $AW/trees/yield && git archive 344b1f3 game tools protocol | tar -x -C $AW/trees/yield
mkdir -p $AW/trees/reserve && git archive d319b5a game tools protocol | tar -x -C $AW/trees/reserve
F=$AW/trees/yield/game/scripts/simulation/avoidance.gd   # same for reserve
grep -c 'static var mode: String = ""' $F                # must print 1
sed -i '' 's/static var mode: String = ""/static var mode: String = "yield"/' $F   # "reserve" for B
grep -c 'static var mode: String = "yield"' $F           # must print 1
```

The measured copies of the night were built from the working trees at the time and so differ from a plain archive in places (the E1 copy had no `protocol/`, which made W3 fail as an artifact; main's copy got `protocol/`). Neutral mode `""` on the committed tree gives identical traces to main.

**Jam harness** (headless; `--mode off|yield|reserve`, `--only a,b`, `--trace ABS_DIR`; prints one `AVOID <mode> <scenario> ...` line per scenario and `AVOID HARNESS COMPLETE`):

```sh
godot --headless --path <tree>/game --import
godot --headless --path <tree>/game --script res://benchmarks/run_avoidance.gd -- --mode yield --trace $AW/traces/mine-1 > $AW/logs/mine-1.log 2>&1
godot --headless --path <tree>/game --script res://benchmarks/run_avoidance.gd -- --mode yield --trace $AW/traces/mine-2 > $AW/logs/mine-2.log 2>&1
diff -r $AW/traces/mine-1 $AW/traces/mine-2        # determinism: no output
```

**Cost** (per tree, three interleaved rounds over main and the approach; the night's script is `AW/logs/E1/cost.sh`):

```sh
godot --headless --path <tree>/game --script res://benchmarks/bench_runner.gd  > cost-<tree>-<n>.log 2>&1   # HEADLESS rows
godot --headless --path <tree>/game --script res://benchmarks/run_combat.gd   >> cost-<tree>-<n>.log 2>&1   # COMBAT rows
godot --headless --path <tree>/game --script res://benchmarks/run_movement.gd > movement-gate-<tree>.log 2>&1   # real gate: fails on A and B
sh <tree>/tools/run_benchmark.sh > bench-<tree>.log 2>&1                        # full gate: passes on main only
```

**Suite** (once per tree; mode `""` passes, A and B fail 17 lines each as above):

```sh
(cd <tree> && sh tools/run_tests.sh > suite.log 2>&1; echo "exit=$?" >> suite.log)
```

**Browser** (per tree, after the asserted `bench_runner.gd:29` edit):

```sh
cd <tree>
sed -n 29p game/benchmarks/bench_runner.gd                                          # the combat layout list: open, dense, contact, skirmish3v3
# edit game/benchmarks/bench_runner.gd:29 so the list also holds "docks", "hordes300"
sh tools/export_build.sh "Web Bench" build/web-bench/index.html
python3 -I tools/serve_web_bench.py build/web-bench <result-dir> &     # the night used AW/web/serve_once.py, a copy that exits after the first POST /result
open -a Firefox http://127.0.0.1:8060/                                  # tab in front; wait for the result log
```

The night's driver scripts are `AW/web/run1.sh <label> <n>` and `AW/web/driver.sh`; the table script is `AW/web/table.py`.

**Screenshots** (windowed; the scratch scripts `avoid_shot.gd` and `avoid_shot_overlay.gd` are kept in `~/projects/wargrid-overnight-work/avoidance/logs/E5/`: copy them into `game/`, run, then delete them and their `.uid` files). `--ticks peak,peak+300` makes the script search ticks 0 to 2099 for the peak itself; `--mode ""` is main:

```sh
sh tools/run_game.sh --audio-driver Dummy --script res://avoid_shot.gd -- --mode yield --scenario dw_choke --focus 40,44 --zoom 1.5 --ticks peak,peak+300
sh tools/run_game.sh --audio-driver Dummy --script res://avoid_shot.gd -- --mode reserve --scenario dw_docks --focus 26,7 --zoom 1.5 --ticks peak,peak+300
```

The peaks found on the night: `dw_choke` main 378, A 578, B 701; `dw_docks` main 498, A 597, B 67 (the script writes to its `OUT` constant, the night's `AW/shots/`; change it to avoid overwriting).

**Lint** before handing back GDScript: `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` (both passed on the E1 and E2 trees; `run_warnings.sh` skips untracked files, so `--check-only` was also run on the new files).
