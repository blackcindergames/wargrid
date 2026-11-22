# Play on after a leave: verification

Evidence file and resume record for night 8, [Play on after a leave](../superpowers/plans/2026-11-21-play-on-after-a-leave.md). Run rules: [milestone prompt](../milestone-prompt.md), [night run](../night-run.md). The resume record is overwritten at every checkpoint; the evidence rows below it are append-only.

## Resume record

```text
Resume record (updated 2026-11-22, 9c benchmark rerun done)
Branch / base commit / working-tree state: play-on-after-a-leave in ~/projects/wargrid-wt-playon, base main 6bd58ff3; HEAD c6af4507 (benchmark rows); clean once this edit is committed
Last green task / next incomplete task: 9c benchmark rerun on 6c329a01 (rows c6af4507) / Task 10 stop gate: owner merge decision
Changed paths since last commit: this file only
Last command / cases / checks / failures / exit / marker: 9c `PERF_LABEL="night 8 play on after a leave" sh tools/run_benchmark.sh` on 6c329a01 (night 14, 2026-11-21 23:36): exit 0, LOCKSTEP BUDGET PASS p99 0.067 ms, PAIR GATE PASSED 3, PROFILE COMPLETE 11, recorded 24 rows
Known red case or blocker: none; BUDGET EXCEEDED open dense hordes300 are report-only stress rows (pair ratios against the reference 0.99 to 1.01), no CEILING ALARM
Approved decisions, pre-authorizations used, deferred gates: owner answers Q2 a, Q3 a, Q4 a, Q5 a, Q6 a, Q7 b, Q8 a, Q9 a, Q10 b, Q11 b, Q12 a, Q20 a (user, 2026-11-21); Q19 a (user, 2026-11-19); test-only helpers used by new test_pal_* cases allowed (user, 2026-11-21); take(tick, quiet, survivors) signature in sim-interface and the blueprint _left_seat sentence replaced (user, 2026-11-21); gate 9d uses Fable 5.2 high instead of Grok 4.7 (user, 2026-11-21); survivors() returns every match player during setup, option A (user, 2026-11-21); benchmark rerun waits until the p7 session finishes (user, 2026-11-21); Q1, Q13-Q18 moot; backup B1 F42 spike only (user, 2026-11-21). Pre-authorized: one local commit per GREEN task (handoff). Deferred: merge decision, rendered rerun after a merge (game/scripts/match/ changes), CI wall times of the four new netplay scenarios (need the owner's push).
Usage so far (python3 tools/session_usage.py <session files>): none recorded
Next exact action: owner merge decision; after the merge the rendered rerun and the CI wall times below
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
| 5 | Online driver passes the note | GREEN, reapplied after the helper ruling; review fix round done (P3-1: closes-room case pins `notice() == ""`, killed by the `_close_room` relay-loss mutant; `_single_until` merged into `_trio_until`) | 25fb4721 |
| 6a | Headless client: three seats, `--defeat` | GREEN, review fix round done (P2-1: removal repeats until FRC rebuild holes are gone) | ba4cc3ee |
| 6b | Headless client: `--pump` with the credit clamp | GREEN, review fix round done (P1-1/P2-1: one tick per call, only after that tick's hooks and script ran; pumped `match` back at 9013); `--pump` exercised by hand, scenarios in Task 7 | 9b7816f3 |
| 7 | Netplay scenarios (trio x3, `left-mid-pump`) | GREEN; each `NETPLAY PASSED`, m1 and m2 red near 325, `run_checks.sh` 5 of 5 | a939ae22 |
| 8 | Docs | GREEN; guide chapters 01, 03, 04, 11, 13, development notes, sim-interface, STATUS row; Opus docs review 1 P1, 5 P2, fix round done; owner rulings applied (take signature, blueprint sentence) | e620dbe8, 2ad0c9a4 |
| 9a | Gate: static checks, suite, traces, conformance | GREEN | none (checks only) |
| 9b | Gate: netplay scenarios | GREEN | none (checks only) |
| 9c | Gate: benchmark | GREEN on 6c329a01: LOCKSTEP BUDGET PASS, PROFILE COMPLETE 11, 24 rows recorded | c6af4507 |
| 9d | Gate: reviews | done: five reviewers (Opus whole-branch, Fable, silent-failure-hunter, pr-test-analyzer, ponytail-review), 0 P1 | none (reports private) |
| 10 | Review fixes, stop gate | fix rounds done: part 1 (two surviving mutations killed, `--defeat` validated), part 2 (`survivors()` in setup, option A), footers and comment at the final code tip; stop gate waits for the 9c rerun | ff76b309, 0404c2fe, e4852145 |
| B1 | F42 spike (evidence only, private note) | not started | none (no repo change) |

## Recorded limits

- The two-seat online product is unchanged: only tests (the in-process lockstep and driver cases and the three-seat netplay scenarios) reach play-on.
- The online oracle and `--replay-log` ignore `--defeat`; three-seat netplay scenarios skip the oracle (Tasks 6a, 8).
- `--pump` runs the driver's `_finish`, which overwrites `user://netplay-latency.txt` on the machine, and takes one tick per driver call, so the headless client never runs the driver's two-tick catch-up (Task 6b).
- `--pump --rematch` is unsupported; a `--defeat` hook landing on a seat's decision tick gives a pumped seat a stale survivors list (Task 6b, 9d).
- `--defeat` does not check the seat against the match's seats (Task 10).
- The driver's `_last.tick == _next_tick` guard cannot be observed on the inline pump; kept for SB5a (Task 5).
- Pump cost (9c rerun): PROFILE_PUMP extra 0.0228 ms over the direct tick (1.24 %); `team_match_pump:profile` mean 1.1167 ms, over the 0.91 ms plumbing budget, recorded and not loosened.
- Unfixed P3 findings are listed in the private ledger.
- Not checked, waiting for the owner's push: CI wall times of the four new netplay scenarios, Windows CI.

## Evidence

Append-only rows: date and time, tree (commit), task, command form, exit, marker, counts, `uptime` load, note.
Rows give the commit that carries the task's change; each check ran on that change before its commit. Load is `uptime` as noted in the ledger, "n/r" where not recorded.

| When | Tree | Task | Check | Exit | Marker / counts | Load | Note |
|---|---|---|---|---|---|---|---|
| 2026-11-21 12:48 | 7df5f4dd | 1 | base suite, three suites, netplay, team, static | 0 | 1250 cases 152761 checks 0 failures; match, rematch 9013; team 38786 | 5.9-6.6 | line map equals brackets |
| 2026-11-21 12:50 | 98882a3b | 2 | `test_pal_two_leaves` | 1 | CASES 1 CHECKS 1 FAILURES 1 (waiting, seat 3, tick 21) | 5.2 | red by design, reproduced |
| 2026-11-21 12:58 | 14f831fc | 3 | suite; mutation m1 | 1 (by design) | 1253 cases 152768 checks 1 failure (Task 2 case); traces x4 matched; m1 killed | 5.4-6.1 | suite green after Task 4a |
| 2026-11-21 13:02 | 9c5a5f77 | 4a | suite; netplay; NETEQ; mutations m1-m5 | 0 | 1262 cases 152783 checks 0 failures; traces x4, netplay five, NETEQ 301 matched; m1-m5 killed | 2.9-3.0 | review fix round: test_lockstep 38/140/0, desync variant kills the hash-skip mutation |
| 2026-11-21 13:15 | bb16b62b | 4b | suite; mutations A-C | 0 | 1269 cases 152802 checks 0 failures; traces x4 matched; A, B, C killed | 1.9-3.3 | tests only |
| 2026-11-21 13:21 | eb2c3ffa | 4c | suite; netplay; NETEQ | 0 | 1272 cases 152806 checks 0 failures; traces x4 matched; match, rematch 9013; NETEQ 301 | 1.0-3.5 | |
| 2026-11-21 13:45 | 25fb4721 | 5 | suite; mutations a, b, c | 0 | 1275 cases 152821 checks 0 failures; traces x4 matched; PUMP_COUNTS 10/9; a, b, c killed | 2.9-4.3 | six helpers allowed (user, 2026-11-21) |
| 2026-11-21 13:41 | ba4cc3ee | 6a | suite; netplay; scratch FRC check | 0 | 1272 cases 152806 checks 0 failures; match 9013, left-mid passed; FRC removal 1 to 0 in 2 passes | 2.4-6.6 | `--defeat` first exercised in Task 7 |
| 2026-11-21 14:01 | 9b7816f3 | 6b | suite; netplay; pumped runs | 0 | 1275 cases 152814 checks 0 failures (rerun 152821); match 9013, left-mid passed; pumped defeat 2@300 5/5, ends 301; pumped human-script match 9013 | 6-7 | review P1 fixed, not reproduced before the fix |
| 2026-11-21 14:10 | a939ae22 | 7 | four scenarios; mutations m1, m2; run_checks | 0 | trio-play-on 2.7 s, trio-left-first 2.5 s, trio-result 3.1 s (1201 both), left-mid-pump 2.2 s; m1, m2 red near 325; CHECKS PASSED 5 | 6-8 | CI wall times wait for the owner's push |
| 2026-11-21 14:18 | e620dbe8 | 8 | check_public; Opus docs review | 0 | check_public exit 0; review 1 P1, 5 P2, 12 P3, fixed | n/r | owner rulings applied in 2ad0c9a4 |
| 2026-11-21 14:26 | 2ad0c9a4 | 9a | checks, suite, team, traces, conformance | 0 | CHECKS PASSED 5; 1275 cases 0 failures; team unchanged; traces x4 matched; CONFORMANCE PASSED 69 | 6.21 to 1.91 | |
| 2026-11-21 14:26 | 2ad0c9a4 | 9b | 20 netplay scenarios, NETEQ | 0 | NETPLAY PASSED x20; match, rematch 9013; NETEQ 301 matched, cmp silent; four new scenarios 10 s | 2-5 | relay-term skipped as at SB4 |
| 2026-11-21 14:27 | 2ad0c9a4 | 9c | `sh tools/run_benchmark.sh` | 1 | COMBAT BUDGET FAIL contact (p95 2.072, p99 3.284), skirmish3v3, transports; no PROFILE_PUMP | 5.62 to 7.14 | simulation-only rows, host load, not loosened; rerun owed |
| 2026-11-21 14:42 | 2ad0c9a4 | 9d | five reviews | n/a | 0 P1 each; P2: 1 (Opus), 2 (Fable), 2 (silent-failure), 2 (tests), ponytail Ship | n/r | all P2s handled in Task 10 or recorded |
| 2026-11-21 14:50 | ff76b309 | 10 part 1 | suite; mutations MA, MB; `--defeat` validation | 0 | 1276 cases 152826 checks 0 failures; test_pal_ 26/65/0; traces x4 matched; PUMP_COUNTS 10/9; MA, MB red | 12-26 | netplay trio-play-on, trio-result, left-mid-pump, match 9013, left-mid passed |
| 2026-11-21 15:18 | 0404c2fe | 10 part 2 | suite; setup-leave test; mutation | 0 | 1277 cases 152828 checks 0 failures; test_pal_ 27/67/0; traces x4 matched; setup mutation red (2 FAILs); match 9013, left-mid, trio-play-on passed | 5.6 | red repro first (harness targets 11 to 12) |
| 2026-11-21 | 453c2812 + working tree | owner follow-ups | suite; test_pal_; trio-result, trio-left-first, trio-play-on, left-mid-pump; run_checks; two mutations | 0 | 1277 cases 152821 checks 0 failures (count varies by 7 between runs); test_pal_ 27/67/0; four scenarios passed; run_checks 5/5. Changes: `--pump` on trio-result seat 1 (still ends 1201); `lead bound` check in trio-left-first; `NETPLAY LATENCY` assert in trio-play-on; shared `game/tests/seat_fixture.gd` plus `_trio_net` and `_send_left` in test_lockstep (-209/+66 lines in the two suites, +24 fixture; every test and check kept). Mutations: relay logs `lead bound` at tick 100 without refusing, trio-left-first exit 1; `--pump` removed from trio-play-on seat 1, exit 1 (both restored) | trio-result 4 s before, 4 s after (3.5 s, 4.0 s inside) | owner rulings (user, 2026-11-21); logs `followups-*` |
| 2026-11-21 | 453c2812 + working tree | follow-up review fixes | fresh Opus review (0 P1, 3 P2, 4 P3; `followups-review.md` in the private run folder): `trio-result` asserts the pump marker, guide 11 and 13 passages and footers, comment dropped from `seat_fixture.gd`; `trio-result` NETPLAY PASSED 3.9 s, `run_checks.sh` CHECKS PASSED 5, `WARGRID_TEST_ONLY=pal` 32 / 156 / 0; check-count wobble (152814 / 152821 / 152828, steps of 7, only under host load) pre-existing, not located |

| 2026-11-21 23:36 | 6c329a01 | 9c | `PERF_LABEL="night 8 play on after a leave" sh tools/run_benchmark.sh` | 0 | BENCHMARK PASSED 2, COMBAT BENCHMARK PASSED 10, PAIR GATE PASSED 3, LOCKSTEP BUDGET PASS p99 0.067, PROFILE COMPLETE 11, PROFILE_PUMP extra_pct 1.24; BUDGET EXCEEDED open dense hordes300 (stress rows, report only); 24 rows recorded in c6af4507 | 1.25 to 1.64 | night 14 run; log `logs/gate-bench.log` in the private run folder |
