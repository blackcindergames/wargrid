# Play on after a leave: verification

Evidence file and resume record for night 8, [Play on after a leave](../superpowers/plans/2026-11-21-play-on-after-a-leave.md). Run rules: [milestone prompt](../milestone-prompt.md), [night run](../night-run.md). The resume record is overwritten at every checkpoint; the evidence rows below it are append-only.

## Resume record

```text
Resume record (updated 2026-11-21, Task 6a GREEN, uncommitted; Task 5 parked)
Branch / base commit / working-tree state: play-on-after-a-leave in ~/projects/wargrid-wt-playon, base main 6bd58ff3; HEAD eb2c3ffa (Task 4c committed); Task 6a changes uncommitted; Task 5 parked (stashed, never popped)
Last green task / next incomplete task: Task 6a (headless client three seats, --defeat) / Task 7 (6b parked with 5)
Changed paths since last commit: game/scripts/net/headless_client.gd, docs/reference/play-on-after-a-leave-verification.md
Last command / cases / checks / failures / exit / marker: SUITE(t6a) / 1272 / 152806 / 0 / 0 / TESTS PASSED 152806; STATIC(t6a) lint 0, warnings 0 (189 files), python 0; NET(t6a, match) and rematch NETPLAY PASSED at 9013, left-mid NETPLAY PASSED, NETEQ REPLAYS MATCHED 301 x2, cmp silent; --defeat hook not exercised yet (Task 7 trio scenarios)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: owner answers Q2 a, Q3 a, Q4 a, Q5 a, Q6 a, Q7 b, Q8 a, Q9 a, Q10 b, Q11 b, Q12 a, Q20 a (user, 2026-11-21); Q19 a (user, 2026-11-19); Q1, Q13-Q18 moot; backup B1 F42 spike only (user, 2026-11-21). Pre-authorized: one local commit per GREEN task (handoff). Deferred: merge decision, rendered rerun after a merge (game/scripts/match/ changes), CI wall times of the four new netplay scenarios (need the owner's push).
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: coordinator commits Task 6a, then Task 7 without its --pump parts
```

Ledger, rulings and morning summary: `ledger.md`, `morning-summary.md` in the run's work folder `~/projects/wargrid-overnight-work/play-on/` (private). Logs: `logs/` there.

## Base counts

Filled by Task 1 Step 2, on `6bd58ff3` plus the prep commit.

| Check | Command form | Exit | Marker / count | Terminal tick or pin |
|---|---|---|---|---|
| Full suite | `SUITE(base)` | 0 | `CASES 1250 CHECKS 152761 FAILURES 0`, `TESTS PASSED 152761` | four traces written |
| `test_lockstep` | `ONLY(base-lock, test_lockstep)` | 0 | `CASES 28 CHECKS 122 FAILURES 0` | |
| `test_online_scene` | `ONLY(base-online, test_online_scene)` | 0 | `CASES 85 CHECKS 3211 FAILURES 0` | |
| `test_sim_pump` | `ONLY(base-pump, test_sim_pump)` | 0 | `CASES 29 CHECKS 134 FAILURES 0` | |
| Netplay `match` | `NET(base, match)` | 0 | `NETPLAY PASSED` | 9013 |
| Netplay `rematch` | `NET(base, rematch)` | 0 | `NETPLAY PASSED` | 9013 |
| Netplay `left-mid`, `kill`, `perturb` | `NET(base, s)` | 0, 0, 0 | `NETPLAY PASSED` x3 | perturb ring diverges at tick 41 |
| Team match | `TEAM(base)` | 0 | `TEAM MATCH won tick=38786 winner=2 units_peak=268` | |
| Lint, warnings, Python tests | `STATIC(base)` | 0, 0, 0 | lint clean, `WARNINGS CHECKED 189 FILES`, `PYTHON TESTS PASSED` | |
| `PUMP_COUNTS` | `tools/test_sim_boundary.py` | n/a | offline 10, online 9 (read at `:101-105`) | |

## Line map

Filled by Task 1 Step 3 (`rg -n '^(static )?(func|var|const|class) <name>\b' <file>`), on the branch base. Expected at `6bd58ff3` in brackets; a missing symbol is a stop. Task 1 result: every line number equals its bracket; `survivors` absent (`rg` exit 1).

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
| 1 | Base and line map | GREEN | 7df5f4dd |
| 2 | Reproduce the overwrite (red by design) | GREEN (red as specified, reproduced) | 98882a3b |
| 3 | `Simulation.survivors()`, `Note.survivors` | GREEN | 14f831fc |
| 4a | Lockstep left-seat set and decision (incl. P7 shape, Q20) | GREEN | 9c5a5f77 |
| 4b | Command and removal rows | GREEN (tests only) | bb16b62b |
| 4c | Three-seat `Skirmish.create` and starts | GREEN | eb2c3ffa |
| 5 | Online driver passes the note | parked (stop: six test helpers outside Allowed test edits; patch logs/t5-parked.patch; stash SHA only in the private ledger) | |
| 6a | Headless client: three seats, `--defeat` | GREEN (uncommitted), review fix round done (P2-1: removal repeats until FRC rebuild holes are gone) | (coordinator commits) |
| 6b | Headless client: `--pump` with the credit clamp | parked (needs 5) | |
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
