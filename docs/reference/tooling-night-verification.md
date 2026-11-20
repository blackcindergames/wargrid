# Tooling night verification

Plan: [tooling night](../superpowers/plans/2026-11-20-tooling-night.md). Decisions: [design answers, Tooling night (user, 2026-11-20)](design-answers-2026-11-08.md#tooling-night-user-2026-11-20).

```text
Resume record (updated 2026-11-20, Task 3 green, not committed)
Branch / base commit / working-tree state: tooling-night in ~/projects/wargrid-wt-tooling at 33fff081 (Tasks 1 and 2 committed); Task 3 changes uncommitted
Last green task / next incomplete task: Task 3 (green, awaiting review and local commit) / Task 4
Changed paths since last commit: game/tests/run_tests.gd, game/tests/test_runner.gd, tools/case_times.py, tools/test_case_times.py, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 1246 / 152732 / 0 / 0 / TESTS PASSED 152732
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: F15 design and public tick_hash() approved (user, 2026-11-20); local commit per GREEN task pre-authorized for the night run; no push, no merge. Guide chapters 10 and 13 (incl. the case_times usage line) stay with Task 6
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: review Task 3 diff, commit locally, then Task 4 (plan heading "Task 4: Check-count drift (evidence only)")
```

## Evidence

| Date | Task | Command | Result | Tree |
|---|---|---|---|---|
| 2026-11-20 | 1 Red | `WARGRID_TEST_ONLY=<tick_hash, th_pump, offline_record_tick_hashes, two_match_session>` | TH1, TH2, TH3, pump check, PO12 fail as assertions (no `tick_hash` method, `tick_hashes` null, rows `[[], []]`); PO28 and N-PT1 are guards that pass before and after | tooling-night f1a8709d + test edits, uncommitted |
| 2026-11-20 | 1 Green | `sh tools/run_tests.sh` | CASES 1243 CHECKS 152722 FAILURES 0, TESTS PASSED, exit 0 (1239 + 4 new cases); end digests and pinned traces unchanged | tooling-night f1a8709d + Task 1 changes, uncommitted |
| 2026-11-20 | 1 Green | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `python3 tools/test_sim_boundary.py` | no problems; 187 files checked; 17 tests OK (PUMP_COUNTS unchanged, offline_driver.gd still 10) | same tree |
| 2026-11-20 | 1 TH5 | `godot --headless --path game --script ~/projects/wargrid-overnight-work/tooling-night/th5.gd` (hordes300, 300 warm-up ticks, 200 calls) | run 1: mean 76.6 us, p99 86 us; run 2: mean 76.5 us, p99 81 us; amortised mean/30 = 2.55 us per tick; limit 600 us; load average 2.1 (1 min) | same tree |
| 2026-11-20 | 1 review fixes | `WARGRID_TEST_ONLY=no_tick_hash_rows` with the drain filter removed, then restored | red: rows ["30", "60", "60"] at tick 60 (post-end duplicate); green with the filter (`note.tick > _last.tick`) | tooling-night f1a8709d + Task 1 changes, uncommitted |
| 2026-11-20 | 1 review fixes | `sh tools/run_tests.sh`; `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `python3 tools/test_sim_boundary.py` | CASES 1244 CHECKS 152724 FAILURES 0, TESTS PASSED, exit 0; lint, warnings, boundary exit 0 | same tree |
| 2026-11-20 | 2 Red | `python3 -m unittest discover -s tools -p test_playtest_session.py`; `WARGRID_TEST_ONLY=names_first_differing sh tools/run_tests.sh` | Python: 4 errors, 1 failure (no `--compare-hashes` flag, no `.hashes` file, wrapper has no hash compare); RH5 fails 2 of 4 checks as assertions (compare exits 2) | tooling-night 3d915a80 + test edits, uncommitted |
| 2026-11-20 | 2 Green | same two commands | Python 12 tests OK; RH5 CASES 1 CHECKS 4 FAILURES 0 (recorded rows equal the oracle ring rows on a clean replay; the dropped-move replay reports the expected tick) | tooling-night 3d915a80 + Task 2 changes, uncommitted |
| 2026-11-20 | 2 Green | `sh tools/run_tests.sh` | CASES 1245 CHECKS 152728 FAILURES 0, TESTS PASSED, exit 0 | same tree |
| 2026-11-20 | 2 Green | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `sh tools/run_shell_checks.sh`; `sh tools/run_python_checks.sh`; `python3 tools/test_sim_boundary.py` | all exit 0 (warnings: 187 files; python checks after `ruff format` of the two touched files) | same tree |
| 2026-11-20 | 2 review fixes | `sh tools/run_python_checks.sh`; `sh tools/run_shell_checks.sh`; `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `python3 tools/test_sim_boundary.py`; `sh tools/run_tests.sh` | all exit 0; CASES 1245 CHECKS 152728 FAILURES 0, TESTS PASSED 152728. Fixes: first-row message, OSError and UnicodeError give exit 2, file name in the malformed message, no-rows wrapper test, gap test; RH5 reads `PYTHON` and derives the repo root from `WARGRID_VECTORS` so the exported CI suite finds the script | tooling-night 3d915a80 + Task 2 changes, uncommitted |
| 2026-11-20 | 3 Red | `python3 tools/test_case_times.py` (stub `main` returning 0); `WARGRID_TEST_ONLY=test_case_stat_line sh tools/run_tests.sh` (stub `stat_line`/`stats_enabled`) | CT1, CT2 (3 tests), CT3 fail as assertions (5 of 5); R6 fails 3 of 4 checks as assertions | tooling-night 33fff081 + test edits, uncommitted |
| 2026-11-20 | 3 Green | `python3 tools/test_case_times.py`; `WARGRID_TEST_ONLY=test_runner sh tools/run_tests.sh` | 6 tests OK (CT4 added: wrapped cases print the shared name `<anonymous lambda>`, 10 of them, so they count toward the CASES total but get no table key); runner CASES 6 CHECKS 15 FAILURES 0 | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 Green | plain `sh tools/run_tests.sh` | CASES 1246 CHECKS 152732 FAILURES 0, TESTS PASSED, exit 0; `rg -c '^CASE_STAT'` on the log prints nothing (0 matches, rg exit 1); load average 1.61 (1 min) at start | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 Green | `WARGRID_CASE_STATS=1 sh tools/run_tests.sh` | CASES 1246 CHECKS 152732 FAILURES 0, TESTS PASSED, exit 0; `rg -c '^CASE_STAT'` prints 1246 (equals CASES); load average 2.15 at start, 2.85 at end (own 4 shards included) | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 Green | `python3 -I tools/case_times.py <stats log> --write game/tests/run_tests.gd`, then `sh tools/run_tests.sh` | write exit 0; table 15 -> 25 entries (cut at 1.0 s; team_match_prefix 44.8 -> 52.6). Suite wall time 63.4 s with the old table, 60.9 s with the new (load 2.5 to 3.4, noisy: not a benchmark); CASES 1246 CHECKS 152732 FAILURES 0, exit 0 | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 Green | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `sh tools/run_python_checks.sh`; `python3 tools/test_sim_boundary.py` | all exit 0 (warnings: 187 files; PYTHON TESTS PASSED). Shell checks not run: no shell file touched | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 review fixes | `python3 tools/test_case_times.py` before the fix | CT5 (filtered log), CT6 (no pass marker or FAIL line), CT7 (duplicate name, max in either order) fail as assertions; raw shard logs sum (CT1 raw) already passed | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 review fixes | `sh tools/run_python_checks.sh`; `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `sh tools/run_tests.sh` | all exit 0; 10 Python tests OK; CASES 1246 CHECKS 152732 FAILURES 0, TESTS PASSED 152732; load 1.87 at start. Fixes: `CASE_FILTER <only>` marker printed by a filtered stats run and refused by `--write`; `--write` also needs one TESTS PASSED per CASES line and no FAIL line; duplicate names keep the max; atomic rewrite (temp file, `os.replace`) | tooling-night 33fff081 + Task 3 changes, uncommitted |
| 2026-11-20 | 3 review fixes | filtered stats run (`WARGRID_CASE_STATS=1 WARGRID_TEST_ONLY=test_case_stat_line`), then `--write` on a copy of run_tests.gd; old full stats log `--write` on the copy | log has `CASE_FILTER` line; write exits 2 "filtered", copy unchanged; the full log rewrites the copy identical to the committed table (no regeneration needed) | tooling-night 33fff081 + Task 3 changes, uncommitted |
