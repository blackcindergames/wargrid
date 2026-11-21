# Honest speed report verification

Plan: [honest speed report](../superpowers/plans/2026-11-21-honest-speed-report.md). Decisions: [design answers, low-end report loose ends (user, 2026-11-20)](design-answers-2026-11-08.md#low-end-report-loose-ends-user-2026-11-20); owner rulings for the plan (user, 2026-11-21) in the plan header. Night lane item 14 in [packages](../packages.md#night-lane).

```text
Resume record (updated 2026-11-22, Task 3 green, uncommitted)
Branch / base commit / working-tree state: honest-speed-report in ~/projects/wargrid-wt-speed, HEAD 0e128cc0 (Tasks 1 and 2 committed), Task 3 changes uncommitted
Last green task / next incomplete task: Task 3 (awaiting the coordinator's commit) / Task 4
Changed paths since last commit: tools/perf_chart.py, tools/test_perf_charts.py, README.md and docs/reference/performance.md (generated blocks only), this file
Last command / cases / checks / failures / exit / marker: sh tools/run_python_checks.sh / 96 perf chart tests (4 new RB1-RB4) / 0 failures / exit 0 / PYTHON TESTS PASSED; perf_chart.py regenerated, roadmap --check 0, check_public PUBLIC CHECK PASSED; no GDScript touched, suite last passed on Task 1 tree (TESTS PASSED 152754)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: one local commit per green task (pre-authorized); no push, PR, merge or fly deploy; D3 and D4 at the SB6 plan; the plan's owner answers (user, 2026-11-21) all took the recommendations
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: coordinator commits Task 3, then starts Task 4 (Sonnet high)
```

## Tasks

| Task | What | Model | Status | Commit |
|---|---|---|---|---|
| 1 | Record the 3v3 profile rows (`step`, `team_tick`) | Sonnet high | green | fbd54a6f |
| 2 | The trend rule and the goal lines | Sonnet high | green | 3b94d9d1 |
| 3 | The README block (checked and tracked tables, Deck row) | Sonnet high | green, uncommitted | |
| 4 | Docs (ledger paragraph, guide 12 and 13, STATUS) | Sonnet high | not started | |
| 5 | War Room round page (`n14-speed-report`) | Sonnet high | not started | |
| 6 | Gate benchmark | Sonnet low | not started | |
| 7 | Gap 12, Mac half | Sonnet high | not started | |
| 8 | Gap 12, Wasm half on the Steam Deck | Sonnet high | not started | |
| Gate | Reviews, fix round, stop at the advisory round | Opus high and the gate set | not started | |

## Evidence

| Date | Task | Command | Result | Tree |
|---|---|---|---|---|
| 2026-11-22 | 1 | `tools/.venv/bin/python3 tools/test_perf_charts.py` before the change | Red: PR1 fails on `assertIn(("step", "team_match:profile"), s)`, PR3 on `len(rows)` 0 != 1; PR2 passes already (plumbing rows set the marker) | honest-speed-report d6141edf plus the two test edits |
| 2026-11-22 | 1 | same command after the change; `sh tools/run_python_checks.sh` | exit 0; ruff, mypy (52 files) clean; `PYTHON TESTS PASSED` | honest-speed-report d6141edf plus Task 1 changes |
| 2026-11-22 | 1 | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; `sh tools/run_tests.sh` (baseline on d6141edf clean, then again with changes) | lint exit 0; warnings exit 0, 189 files; suite exit 0, `TESTS PASSED 152754` both times | honest-speed-report d6141edf plus Task 1 changes |
| 2026-11-22 | 2 | `tools/.venv/bin/python3 tools/test_perf_charts.py` after the new tests, before `perf_chart.py` changed | Red: 7 errors (no `trend_text`, `TRENDS`) and TR7 fails (no `GOAL`); TR8 `test_limits_unchanged` passes (guard, as planned) | honest-speed-report fbd54a6f plus the test edits |
| 2026-11-22 | 2 | same command after the change; `sh tools/run_python_checks.sh` (after `ruff format` on the two files) | exit 0; 92 tests OK; ruff, mypy clean; `PYTHON TESTS PASSED`. Baseline suite skipped: passed on the Task 1 tree, no GDScript changed | honest-speed-report fbd54a6f plus Task 2 changes |
| 2026-11-22 | 3 | `tools/.venv/bin/python3 tools/test_perf_charts.py` after the new tests, before the change | Red: RB1 errors (no `PASS_FAIL`), RB2 and RB3 fail; RB4 passes (guard, ledger unchanged, as planned) | honest-speed-report 0e128cc0 plus the test edits |
| 2026-11-22 | 3 | same command after the change; `sh tools/run_python_checks.sh` (after `ruff format`) | 96 tests OK; exit 0; ruff, mypy clean; `PYTHON TESTS PASSED` | honest-speed-report 0e128cc0 plus Task 3 changes |
| 2026-11-22 | 3 | `tools/.venv/bin/python3 tools/perf_chart.py`; `python3 tools/roadmap.py --check`; `sh tools/check_public.sh` | exit 0 each; `PUBLIC CHECK PASSED`; diff touches only the two generated blocks (README 7 checked rows plus Deck row, 6 tracked rows; ledger 11 rows, 4 over) | honest-speed-report 0e128cc0 plus Task 3 changes |

## Rulings

| Date | Ruling | Why | Cost if wrong |
|---|---|---|---|
