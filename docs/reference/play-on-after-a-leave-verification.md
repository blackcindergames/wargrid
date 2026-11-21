# Play on after a leave: verification

Evidence file and resume record for night 8, [Play on after a leave](../superpowers/plans/2026-11-21-play-on-after-a-leave.md). Run rules: [milestone prompt](../milestone-prompt.md), [night run](../night-run.md). The resume record is overwritten at every checkpoint; the evidence rows below it are append-only.

## Resume record

```text
Resume record (updated 2026-11-21, Task 7 GREEN, uncommitted)
Branch / base commit / working-tree state: play-on-after-a-leave in ~/projects/wargrid-wt-playon, base main 6bd58ff3; HEAD 9b7816f3 (Task 6b committed); Task 7 tools/run_netplay.sh, .github/workflows/ci.yml, this file uncommitted
Last green task / next incomplete task: Task 7 (netplay scenarios) / Task 8
Changed paths since last commit: tools/run_netplay.sh, .github/workflows/ci.yml, docs/reference/play-on-after-a-leave-verification.md
Last command / cases / checks / failures / exit / marker: NET trio-play-on 2.7 s (5 more runs 5 of 5), trio-left-first 2.5 s, trio-result 3.1 s (3 more runs 3 of 3, both clients 1201), left-mid-pump 2.2 s, each NETPLAY PASSED; wall sum 10.5 s under load 6-8 (host under load); m1 (_defeated never true) red, s3 ended_left 325; m2 (take third argument null) red, ends 325-330; REVERT exit 0 each; run_shell_checks exit 0; actionlint exit 0; run_checks.sh CHECKS PASSED 5
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: owner answers Q2 a, Q3 a, Q4 a, Q5 a, Q6 a, Q7 b, Q8 a, Q9 a, Q10 b, Q11 b, Q12 a, Q20 a (user, 2026-11-21); Q19 a (user, 2026-11-19); test-only helpers used by new test_pal_* cases allowed (user, 2026-11-21); Q1, Q13-Q18 moot; backup B1 F42 spike only (user, 2026-11-21). Pre-authorized: one local commit per GREEN task (handoff). Deferred: merge decision, rendered rerun after a merge (game/scripts/match/ changes), CI wall times of the four new netplay scenarios (need the owner's push).
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: coordinator commits Task 7, then Task 8
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
| 5 | Online driver passes the note | GREEN (uncommitted), reapplied after the helper ruling; review fix round done (P3-1: closes-room case pins `notice() == ""`, killed by the `_close_room` relay-loss mutant; `_single_until` merged into `_trio_until`) | (coordinator commits) |
| 6a | Headless client: three seats, `--defeat` | GREEN, review fix round done (P2-1: removal repeats until FRC rebuild holes are gone) | ba4cc3ee |
| 6b | Headless client: `--pump` with the credit clamp | GREEN (uncommitted), review fix round done (P1-1/P2-1: one tick per call, only after that tick's hooks and script ran; pumped `match` back at 9013); `--pump` exercised by hand, scenarios in Task 7 | (coordinator commits) |
| 7 | Netplay scenarios (trio x3, `left-mid-pump`) | GREEN (uncommitted); each `NETPLAY PASSED`, m1 and m2 red near 325, `run_checks.sh` 5 of 5 | (coordinator commits) |
| 8 | Docs | not started | |
| 9 | Gate (checks, netplay, benchmark, reviews) | not started | |
| 10 | Review fixes, stop gate | not started | |
| B1 | F42 spike (evidence only, private note) | not started | none (no repo change) |

## Recorded limits

- The online oracle stays two-seat; three-seat netplay scenarios skip it (Task 6a).
- `--pump` runs the driver's `_finish`, which overwrites `user://netplay-latency.txt` on the machine (Task 6b).
- `--pump` takes one tick per driver call, so the headless client never runs the driver's two-tick catch-up (Task 6b).
- The driver's `_last.tick == _next_tick` guard cannot be observed on the inline pump; kept for SB5a (Task 5).

## Evidence

Append-only rows: date and time, tree (commit), task, command form, exit, marker, counts, `uptime` load, note.

| When | Tree | Task | Check | Exit | Marker / counts | Load | Note |
|---|---|---|---|---|---|---|---|
