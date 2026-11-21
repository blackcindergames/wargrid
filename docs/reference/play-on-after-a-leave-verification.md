# Play on after a leave: verification

Evidence file and resume record for night 8, [Play on after a leave](../superpowers/plans/2026-11-21-play-on-after-a-leave.md). Run rules: [milestone prompt](../milestone-prompt.md), [night run](../night-run.md). The resume record is overwritten at every checkpoint; the evidence rows below it are append-only.

## Resume record

```text
Resume record (updated 2026-11-21, prep; not started)
Branch / base commit / working-tree state: play-on-after-a-leave in ~/projects/wargrid-wt-playon, base main 6bd58ff3; the next commit on the branch is the prep commit adding the plan and this file (hash: <prep commit, filled by the prep session>), the only commit on top of 6bd58ff3; tree clean. Task 1 matches git log --oneline -3 against this line
Last green task / next incomplete task: none / Task 1 (Base and line map)
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: none on this branch
Known red case or blocker: none; Task 2 adds test_pal_two_leaves_never_hang red by design until Task 4a: a baseline with exactly one FAIL:, "PAL two leaves never hang", is expected until then; any other failure is a blocker
Approved decisions, pre-authorizations used, deferred gates: owner answers Q2 a, Q3 a, Q4 a, Q5 a, Q6 a, Q7 b, Q8 a, Q9 a, Q10 b, Q11 b, Q12 a, Q20 a (user, 2026-11-21); Q19 a (user, 2026-11-19); Q1, Q13-Q18 moot; backup B1 F42 spike only (user, 2026-11-21). Pre-authorized: one local commit per GREEN task on play-on-after-a-leave (handoff); none used yet. Deferred: merge decision, rendered rerun after a merge (game/scripts/match/ changes), CI wall times of the four new netplay scenarios (need the owner's push).
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: Task 1 Step 1 (branch, base and Pump hardening ancestor checks, uptime), then Step 2 base runs with tag base
```

Ledger, rulings and morning summary: `ledger.md`, `morning-summary.md` in the run's work folder `~/projects/wargrid-overnight-work/play-on/` (private). Logs: `logs/` there.

## Base counts

Filled by Task 1 Step 2, on `6bd58ff3` plus the prep commit.

| Check | Command form | Exit | Marker / count | Terminal tick or pin |
|---|---|---|---|---|
| Full suite | `SUITE(base)` | | `CASES … CHECKS … FAILURES …` | four traces written |
| `test_lockstep` | `ONLY(base-lock, test_lockstep)` | | | |
| `test_online_scene` | `ONLY(base-online, test_online_scene)` | | | |
| `test_sim_pump` | `ONLY(base-pump, test_sim_pump)` | | | |
| Netplay `match` | `NET(base, match)` | | `NETPLAY PASSED` | 9013 |
| Netplay `rematch` | `NET(base, rematch)` | | `NETPLAY PASSED` | 9013 |
| Netplay `left-mid`, `kill`, `perturb` | `NET(base, s)` | | `NETPLAY PASSED` | |
| Team match | `TEAM(base)` | | `TEAM MATCH won tick=38786 winner=2 units_peak=268` | |
| Lint, warnings, Python tests | `STATIC(base)` | | | |
| `PUMP_COUNTS` | `tools/test_sim_boundary.py` | | expected offline 10, online 9 | |

## Line map

Filled by Task 1 Step 3 (`rg -n '^(static )?(func|var|const|class) <name>\b' <file>`), on the branch base. Expected at `6bd58ff3` in brackets; a missing symbol is a stop.

| File | Symbol: line |
|---|---|
| `game/scripts/net/lockstep.gd` | `_left_seat` [32], `_left_after` [33], `take` [108], `advance` [138], `can_step` [95], `waiting_for_tick` [101], `_verify_hashes` [271], `_receive_left` [264], `left_seat` [201], `left_before_start` [195] |
| `game/scripts/match/online_driver.gd` | `step` [110], `_room_gone` [181], `rematch_line` [240], `notice` [332], `_finish` [274], `CATCH_UP_STEPS` [10] |
| `game/scripts/match/sim_pump.gd` | `Note` [23], `run_job` [142] |
| `game/scripts/simulation/simulation.gd` | `_survives` [178], `match_over` [192]; `survivors` absent |
| `game/scripts/simulation/skirmish.gd` | `create` [53] |
| `game/scripts/match_settings.gd` | `starts` [30] |
| `game/scripts/net/headless_client.gd` | `_start` [113], `_match_sim` [141], `_test_hooks` [195], `_run_steps` [151], `_parse` [320] |

## Task state

| Task | What | Status | Commit |
|---|---|---|---|
| 1 | Base and line map | not started | |
| 2 | Reproduce the overwrite (red by design) | not started | |
| 3 | `Simulation.survivors()`, `Note.survivors` | not started | |
| 4a | Lockstep left-seat set and decision (incl. P7 shape, Q20) | not started | |
| 4b | Command and removal rows | not started | |
| 4c | Three-seat `Skirmish.create` and starts | not started | |
| 5 | Online driver passes the note | not started | |
| 6a | Headless client: three seats, `--defeat` | not started | |
| 6b | Headless client: `--pump` with the credit clamp | not started | |
| 7 | Netplay scenarios (trio x3, `left-mid-pump`) | not started | |
| 8 | Docs | not started | |
| 9 | Gate (checks, netplay, benchmark, reviews) | not started | |
| 10 | Review fixes, stop gate | not started | |
| B1 | F42 spike (evidence only, private note) | not started | none (no repo change) |

## Recorded limits

- The online oracle stays two-seat; three-seat netplay scenarios skip it (Task 6a).
- `--pump` runs the driver's `_finish`, which overwrites `user://netplay-latency.txt` on the machine (Task 6b).
- The `--pump` credit clamp acts only on `--defeat` hook ticks (Task 6b).
- The driver's `_last.tick == _next_tick` guard cannot be observed on the inline pump; kept for SB5a (Task 5).

## Evidence

Append-only rows: date and time, tree (commit), task, command form, exit, marker, counts, `uptime` load, note.

| When | Tree | Task | Check | Exit | Marker / counts | Load | Note |
|---|---|---|---|---|---|---|---|
