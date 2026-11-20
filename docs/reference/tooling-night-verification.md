# Tooling night verification

Plan: [tooling night](../superpowers/plans/2026-11-20-tooling-night.md). Decisions: [design answers, Tooling night (user, 2026-11-20)](design-answers-2026-11-08.md#tooling-night-user-2026-11-20).

```text
Resume record (updated 2026-11-20, Task 2 green, not committed)
Branch / base commit / working-tree state: tooling-night in ~/projects/wargrid-wt-tooling at 3d915a80 (Task 1); Task 2 changes uncommitted
Last green task / next incomplete task: Task 2 (green, awaiting review and local commit) / Task 3
Changed paths since last commit: tools/playtest_session.py, tools/replay_session.sh, tools/test_playtest_session.py, game/tests/test_playtest_replay.gd, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 1245 / 152728 / 0 / 0 / TESTS PASSED 152728
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: F15 design and public tick_hash() approved (user, 2026-11-20); local commit per GREEN task pre-authorized for the night run; no push, no merge
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: review Task 2 diff, commit locally, then Task 3 (plan heading "Task 3: Measured case times")
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
