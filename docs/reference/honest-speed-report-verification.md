# Honest speed report verification

Plan: [honest speed report](../superpowers/plans/2026-11-21-honest-speed-report.md). Decisions: [design answers, low-end report loose ends (user, 2026-11-20)](design-answers-2026-11-08.md#low-end-report-loose-ends-user-2026-11-20); owner rulings for the plan (user, 2026-11-21) in the plan header. Night lane item 14 in [packages](../packages.md#night-lane).

```text
Resume record (updated 2026-11-22, Task 1 green, uncommitted)
Branch / base commit / working-tree state: honest-speed-report in ~/projects/wargrid-wt-speed, base d6141edf, Task 1 changes uncommitted
Last green task / next incomplete task: Task 1 (awaiting the coordinator's commit) / Task 2
Changed paths since last commit: tools/perf_record.py, tools/test_perf_charts.py, this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 152754 checks / 0 failures / exit 0 / TESTS PASSED 152754; run_python_checks exit 0 PYTHON TESTS PASSED; lint exit 0; warnings exit 0 (189 files)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: one local commit per green task (pre-authorized); no push, PR, merge or fly deploy; D3 and D4 at the SB6 plan; the plan's owner answers (user, 2026-11-21) all took the recommendations
Usage so far (python3 tools/session_usage.py <session files>): none
Next exact action: coordinator commits Task 1, then starts Task 2 (Sonnet high)
```

## Tasks

| Task | What | Model | Status | Commit |
|---|---|---|---|---|
| 1 | Record the 3v3 profile rows (`step`, `team_tick`) | Sonnet high | green, uncommitted | |
| 2 | The trend rule and the goal lines | Sonnet high | not started | |
| 3 | The README block (checked and tracked tables, Deck row) | Sonnet high | not started | |
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

## Rulings

| Date | Ruling | Why | Cost if wrong |
|---|---|---|---|
