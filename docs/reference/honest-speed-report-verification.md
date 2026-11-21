# Honest speed report verification

Plan: [honest speed report](../superpowers/plans/2026-11-21-honest-speed-report.md). Decisions: [design answers, low-end report loose ends (user, 2026-11-20)](design-answers-2026-11-08.md#low-end-report-loose-ends-user-2026-11-20); owner rulings for the plan (user, 2026-11-21) in the plan header. Night lane item 14 in [packages](../packages.md#night-lane).

```text
Resume record (updated 2026-11-22, Task 6 green, uncommitted)
Branch / base commit / working-tree state: honest-speed-report in ~/projects/wargrid-wt-speed, HEAD 1afd6416 (Tasks 1 to 4 committed), Task 5 changes uncommitted
Last green task / next incomplete task: Task 6 (awaiting the coordinator's commit) / Task 7
Changed paths since last commit: README.md, docs/reference/perf-history.csv, docs/reference/performance.md, docs/images/speed-report/readme-blocks.html (rerun; Task 5 files still uncommitted), warroom/rounds/index.yaml, warroom/rounds/n14-speed-report/round.yaml (h 1000 to 1100 for Task 6's two extra rows), warroom/internal/rounds/rounds_test.go, this file
Last command / cases / checks / failures / exit / marker: sh warroom/tools/quality.sh / exit 0; sh tools/check_public.sh / exit 0, PUBLIC CHECK PASSED; go test ./internal/rounds/ ./internal/web/ / exit 0; baseline skipped (no GDScript changed since the Task 1 suite pass TESTS PASSED 152754)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: one local commit per green task (pre-authorized); no push, PR, merge or fly deploy; D3 and D4 at the SB6 plan; the plan's owner answers (user, 2026-11-21) all took the recommendations
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: coordinator commits Tasks 5 and 6, then starts Task 7
```

## Tasks

| Task | What | Model | Status | Commit |
|---|---|---|---|---|
| 1 | Record the 3v3 profile rows (`step`, `team_tick`) | Sonnet high | green | fbd54a6f |
| 2 | The trend rule and the goal lines | Sonnet high | green | 3b94d9d1 |
| 3 | The README block (checked and tracked tables, Deck row) | Sonnet high | green | 4363cba3 |
| 4 | Docs (ledger paragraph, guide 12 and 13, STATUS) | Sonnet high | green | 1afd6416 |
| 5 | War Room round page (`n14-speed-report`) | Sonnet high | green, uncommitted | |
| 6 | Gate benchmark | Sonnet low | green, uncommitted | |
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
| 2026-11-22 | 4 | `python3 tools/roadmap.py --check`; `sh tools/check_public.sh`; link targets of the added lines checked by hand | exit 0 each; `PUBLIC CHECK PASSED`; every linked file exists and `#rule-per-milestone` is a heading in the ledger; claims checked against `tools/perf_chart.py` (`PASS_FAIL` 7 rows, `TRENDS` 8, `NOISE_PCT` unchanged) | honest-speed-report 4363cba3 plus Task 4 changes |
| 2026-11-22 | 5 | `python3 -I ~/projects/wargrid-overnight-work/night-14/round/blocks_page.py docs/images/speed-report/readme-blocks.html`; headless Firefox screenshots of `#shot=old` and `#shot=new` (needs `--profile <empty dir>`; without it Firefox exits 1) | exit 0; 1280 x 1000 shots, the new state ends at about 950 px with both tables whole; no absolute path in the page. Task 6 adds two tracked rows (about 1025 px), so `h` is 1100 | honest-speed-report 1afd6416 plus Task 5 changes |
| 2026-11-22 | 5 | `go test ./internal/rounds/` with the index entry, before the count change | Red: `index 4, rounds 4, want 3 and 3` | honest-speed-report 1afd6416 plus the index entry |
| 2026-11-22 | 5 | `go test ./internal/rounds/ ./internal/web/`; `go run . open`; built option texts compared with `TREND_INTRO`, `DECK_ROW` and the headline, labels and row names in `tools/perf_chart.py` | exit 0; `n14-speed-report 0 of 6 answered, advisory: answer when you like`, no `warning: n14-speed-report/` line (the 16 warnings are p2-3b-dock's, as before); texts equal | honest-speed-report 1afd6416 plus Task 5 changes |
| 2026-11-22 | 5 | `sh warroom/tools/quality.sh`; `sh tools/check_public.sh` | exit 0 (all steps incl. network ones); `PUBLIC CHECK PASSED` | honest-speed-report 1afd6416 plus Task 5 changes |
| 2026-11-22 | 6 | `sh tools/run_checks.sh`; `sh tools/run_tests.sh` | both exit 0; `TESTS PASSED 152754` | honest-speed-report 990ac6f5 |
| 2026-11-22 | 6 | `wait-quiet.sh` then `PERF_LABEL="night 14 honest speed report" sh tools/run_benchmark.sh` alone; `tools/.venv/bin/python3 tools/perf_chart.py` | exit 0; `LOCKSTEP BUDGET PASS`, `PROFILE COMPLETE 11`, `BUDGET EXCEEDED open dense hordes300`, `recorded 26 rows`; uptime load 2.36 at start (00:17), 2.30 at end (00:22); step p95 2.174, team_tick p95 2.878, plumbing mean 1.1163 | honest-speed-report 990ac6f5 plus Task 6 changes |

## Rulings

| Date | Ruling | Why | Cost if wrong |
|---|---|---|---|
