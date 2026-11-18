# Benchmark pair gate: Implementation Plan

**Status:** approved for the night run (user, 2026-11-18): Tasks 1-5 and Task 6 Step 1a tonight, then park; Task 6 day half, Tasks 7-8 later. Written from the owner's decision of 2026-11-18 (below). The questions (`~/projects/wargrid-overnight-work/benchmark-pair-gate/questions.md`, private) are answered: Q1-Q11 all A (owner, 2026-11-18); every task names the answer it depends on. Approving this plan does not start implementation.

**Night run (owner, 2026-11-18):** Tasks 1-5 run unattended; Task 6 runs only its night half (A/A gates `aa-s1-1`..`aa-s1-4`), then the run parks at Task 6. The day half (`aa-s2-1`..`aa-s2-4`), the derivation, the ledger section and the owner's threshold decision follow in an attended day session; Tasks 7-8 wait for it. The coordinator makes one local commit per green task on `benchmark-pair-gate`; never push or merge.

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: [milestone prompt](../../milestone-prompt.md) and [night run](../../night-run.md#coordinator-rules). Every task subagent reads "Global Constraints", "Edge cases" and "Stop gate and stop conditions" first (`rg -n '^## ' <plan>`). This plan lives at `docs/superpowers/plans/2026-11-18-benchmark-pair-gate.md` (committed to `main` by the prep session; relative links assume that place).

**Decision (owner, 2026-11-18):** replace the blocking absolute regression ceiling with a relative pair gate. Merge base (A, the reference) and branch (B) run alternately, A B A B A B; per guarded row the median of the 3 pair ratios B/A must not exceed a threshold of about 1.02. The threshold is fixed only after an A/A calibration (the same tree against itself). Absolute rows are still recorded in `docs/reference/perf-history.csv`; the absolute ceiling becomes a report-only alarm on `main`. Why: the hordes300 p95 ceiling 3.07 ms has a 5.4 % margin, this host swings 5-7 % between sessions on identical code, `main` itself misses it, and the load average cannot see the swing (r 0.00-0.21). The Pump hardening gate went red twice and green once, by 0.011 ms, on noise.

**Evidence (private, outside the repo):** `~/projects/wargrid-overnight-work/pump-hardening/benchmark-noise-investigation.md` (verdict, history, proposal §4) and `.../pump-hardening/logs/gate-14c-diagnosis.md`. Measured there and re-derived for this plan from `.../pump-hardening/logs/gate-bench2-pair-{A,B}{1,2,3}.log` (branch `pump-hardening` vs `main` `6854ff5`, no combat-path diff, so effectively A/A):

| Row | p95 pair ratios | p95 median | p99 pair ratios | p99 median |
|---|---|---|---|---|
| open | 1.0005 / 1.0081 / 1.0075 | 1.0075 | 0.9958 / 1.0110 / 1.0051 | 1.0051 |
| dense | 0.9949 / 0.9995 / 1.0021 | 0.9995 | 1.0288 / 1.0031 / 1.0087 | 1.0087 |
| hordes300 | 1.0029 / 1.0010 / 0.9955 | 1.0010 | 0.9989 / 0.9919 / 0.9963 | 0.9963 |

p95 single-pair ratios stay inside ±0.9 %; p99 single-pair ratios reach 1.029 (dense), so p99 needs its own threshold (Q1). One session only, n 3: this is not the calibration.

**Goal:** `sh tools/run_benchmark.sh` blocks a branch only when a guarded combat row is slower than its merge base by more than the calibrated threshold, measured in alternating pairs; the absolute ceilings print a report-only alarm; nothing else about the gate, the budgets or the recorded rows changes.

**Architecture:** a new `tools/run_bench_pairs.sh` resolves the reference (`PERF_REF`, default `git merge-base HEAD main`), skips when `game/` is unchanged since it, otherwise extracts it with `git archive <ref> game | tar -x` into a `mktemp -d` directory (no `git worktree add`), imports it, and runs `run_combat.gd` 6 times, reference first in each pair. A new `tools/perf_pairs.py` reads the 6 logs and prints the verdict (exit 0 pass, 1 fail, 2 inconclusive). `run_benchmark.sh` calls the pair script right after its absolute combat step. `run_combat.gd` stops failing on `STRESS_CEILING` and prints `COMBAT STRESS PASS|ALARM` instead, with every workload check still enforced. Guarded rows are read from the branch logs' `COMBAT STRESS` lines, so `STRESS_CEILING` stays the one list.

**Tech Stack:** POSIX sh, Python 3 (ruff, mypy, unittest via `sh tools/run_python_checks.sh`), Godot 4.7.2 typed GDScript. Relay, protocol, simulation untouched.

## Global Constraints

- **Base:** worktree `$W` = `~/projects/wargrid-wt-pairgate`, branch `benchmark-pair-gate`, created by the attended prep session from local `main` as its last step, after every commit on `main` (never by the night run; no `git worktree add` at night). Line cites below are at `main` `2b7bbe5` (Pump hardening merged). Logs `$L` = `~/projects/wargrid-overnight-work/benchmark-pair-gate/logs`; the resume record (ledger) is `~/projects/wargrid-overnight-work/benchmark-pair-gate/ledger.md` (run folder root, beside the morning summary; every task subagent starts from it and appends its result). `$W`, `$L`, `~` are notation: commands use absolute paths; tracked files use `~/...`, never a typed absolute path (`sh tools/check_public.sh`).
- **Never loosen a budget.** `BUDGET_P95_MS` 1.82, `BUDGET_P99_MS` 3.64 (`game/scripts/debug/timing_stats.gd:3-4`), the lockstep 0.6, F 5.5 and the seven budget-gated combat rows stay blocking and unchanged. `STRESS_CEILING` values (`run_combat.gd:12`) stay unchanged; only their effect changes (blocking → report-only alarm), which the owner decided. open, dense and hordes300 stay reported as exceeded.
- **The threshold is a budget-like number.** It lives in one constant, `MAX_RATIO` in `tools/perf_pairs.py`, with no environment or CLI override. It is set from the A/A calibration (Task 6) and approved by the owner; it is never raised later to make a row pass. Until approval it carries the provisional value 1.02 for p95 and p99 and the comment says provisional.
- **Untouched:** `game/scripts/`, `game/benchmarks/run_movement.gd`, `run_lockstep.gd`, `run_profile.gd`, `run_team_match.gd`, `tools/perf_chart.py`, `tools/perf_record.py`, `relay/`, `protocol/`, `.github/`. The generated blocks (`<!-- perf-charts:begin -->` in `docs/reference/performance.md` and `README.md`) are never hand-edited. `git diff main...HEAD --stat -- game/scripts tools/perf_chart.py tools/perf_record.py relay protocol .github` is empty at every gate.
- **No method change:** nothing inside the timed window changes, so CSV `method` stays `P1`.
- **Commands:** every check, benchmark and pair call has Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker. Checks and suites may use `run_in_background: true` and the completion notice; `PAIRS`, single combat runs and Task 8a run in the **foreground** (the Bash timeout is their deadline, see "Deadlines"). Forms; each starts with `cd <abs $W> && ` (the shell's cwd resets between calls):
  - `FMT(<files>)`: `tools/.venv/bin/ruff format <files>`, then `tools/.venv/bin/ruff check --fix <files>` unconditionally. Before every `PY` that follows a Python edit.
  - `PY(<tag>)`: `sh tools/run_python_checks.sh > <abs $L>/<tag>-py.log 2>&1; echo "exit=$?"` → `PYTHON TESTS PASSED`.
  - `ONLYPY(<tag>, <file>)`: `tools/.venv/bin/python3 tools/<file> > <abs $L>/<tag>-only.log 2>&1; echo "exit=$?"` (the venv exists after Task 1's `PY(base)`); unittest's last line `OK` or `FAILED (...)`.
  - `SHELL(<tag>)`: `sh tools/run_shell_checks.sh > <abs $L>/<tag>-shell.log 2>&1; echo "exit=$?"` → exit 0, empty log (ShellCheck prints nothing when clean).
  - `GD(<tag>)`: `sh tools/run_lint.sh > <abs $L>/<tag>-lint.log 2>&1; echo "exit=$?"` → exit 0; `sh tools/run_warnings.sh > <abs $L>/<tag>-warnings.log 2>&1; echo "exit=$?"` → `WARNINGS CHECKED <n> FILES`.
  - `CHECKS(<tag>)`: `sh tools/run_checks.sh > <abs $L>/<tag>-checks.log 2>&1; echo "exit=$?"` → `CHECKS PASSED 5`.
  - `PAIRS(<tag>)`: `uptime > <abs $L>/<tag>-pairs.log; PERF_REF=HEAD sh tools/run_bench_pairs.sh >> <abs $L>/<tag>-pairs.log 2>&1; echo "exit=$?"; uptime >> <abs $L>/<tag>-pairs.log` (wall time = first to last `uptime` line) → final `PAIR GATE` line `PAIR GATE PASSED|FAILED|INCONCLUSIVE ...` (`rg -n '^PAIR GATE ' <log>`).
  - On failure read only `rg -n 'FAIL|ERROR|PAIR GATE|INCONCLUSIVE' <log>`.
- **Benchmarks and pair runs run alone** (no suite, review agent, backup or other Godot run of this session at the same time). `uptime` first. Foreign Godot processes are listed, never killed; one present at a measurement means that measurement is skipped and the task returns `PARK — foreign Godot process`.
- **Deadlines:** the foreground Bash timeout (600000, 10 min) is the deadline for `PAIRS` and for a single combat run. On a timeout: `kill` the `run_bench_pairs.sh` wrapper first (so it cannot start the next run), then every Godot PID from `pgrep -fl godot` whose args contain the wrapper's `PAIR WORK <dir>` (first lines of the pair log) or `<abs $W>`/`<abs $L>`, never another session's; `pgrep -fl godot` again shows none of them; record INCONCLUSIVE. This cleanup runs before any rerun, park or next dispatch.
- **Pair-run outcomes (every `PAIRS` call, every task; Q6).** Classify first, then apply the load rule:
  - Expected results are success, never rerun: Task 5's `PAIR GATE FAILED` naming `hordes300:p95`; any complete Task 6 verdict (`PASSED` or `FAILED <row:metric ...>`) is data.
  - Unusable: final line `PAIR GATE INCONCLUSIVE`, no `PAIR GATE` final line, or a timeout: rerun the same call once as `<tag>-r`; unusable twice in a row on the same tree is a stop (BLOCKED), Task 6 included.
  - `PAIR GATE FAILED branch run <i>`: stop.
  - Unexpected red: a `FAILED <row:metric ...>` verdict in Task 4 (unless it names only `:p99`: calibration data, ledger) or Task 8a; Task 5 passing or failing without `hordes300:p95`. Load rule for unexpected reds only (1-minute value of any `PAIR ref-`/`PAIR branch-` line above 2.5): one rerun (`<tag>-r`) first; red twice is a stop. At load 2.5 or below an unexpected red is a stop at once.
  - Above 2.5 in an expected or data run: keep the run, tag the ledger row "host under load".
  - One accepted log per slot (Task 4 Step 5, Task 5, each `aa-s1-<n>`): the ledger names it; every attempt is listed.
- **Baseline:** Task 1 runs `sh tools/run_tests.sh > <abs $L>/base-suite.log 2>&1; echo "exit=$?"` once (exit 0, completion marker) and records it in the ledger. Later tasks run it as their milestone-prompt step 3 only when they need it, never while a `PAIRS` or combat run is going.
- **Mutation proofs:** `git add <file>` first; mutate with the Edit tool; run the named check; revert with the Edit tool; `git diff --exit-code -- <file> > <abs $L>/<tag>-revert.log 2>&1; echo "exit=$?"` → exit 0.
- Typed GDScript; Python typed for mypy; comments one line, WHY only; edits with the Edit tool only. Subagents never commit, push, merge or open a window; the coordinator makes one local commit per green task with a tracked change on `benchmark-pair-gate` (pre-authorized by the owner for this run, 2026-11-18). Never push or merge.

## Model routing

- Implementers: Sonnet (Tasks 2-4, 7). Task 1 and the measuring tasks 5, 6 and 8a: Sonnet (decision-free runs; the threshold derivation in Task 6 is a fixed formula, the decision is the owner's).
- Failing tests are the spec: written by the Sonnet implementer from the test list in each task; the per-task Opus reviewer names, per test, the production change that would make it fail.
- Per-task review (Tasks 2, 3, 4, 7): one fresh-context Opus (high) reviewer, paths only (task heading, "Edge cases", and `git add -N <every new file of the task>` before `git diff -U30 HEAD`, so new files show in the diff), writes `<abs $L>/t<N>-review.md`; high and medium findings fixed test-first by a fresh Sonnet implementer; one fix round; the fix implementer then reruns every check the final diff touches (Task 2 Step 4; Task 3 Steps 2-4; Task 4 Step 6) and the commit lists every changed in-scope file; high findings left after it → BLOCKED (park the task).
- Task 7 (docs with code claims): fresh Opus (high) docs review.
- Gate (Task 8b), tooling and test diff: Opus (high) whole-branch, Grok normal (Opus alone if Grok is missing or fails), `silent-failure-hunter` and `pr-test-analyzer` (Opus), then `/ponytail-review` on Sonnet. No player-experience reviewer (no UI, art or player text).
- Diagnosis of any unexpected red: an Opus (high) agent first.

## Measured cost (wall time)

From the Pump hardening logs on this Mac (file times):

| Step | Time | Source |
|---|---|---|
| full `run_benchmark.sh` today | about 5 min (16:46 to 16:51:32) | `gate-bench3.log` |
| of which `run_profile.gd` | about 4.5 min | `gate-bench2-lockstep.log` 16:21:39 → `gate-bench2-profile.log` 16:26:06 |
| one `run_combat.gd` run | 28-29 s | pair logs B1 16:19:11, A1 16:19:39, B2 16:20:07, A2 16:20:36 |
| 3 pairs (6 combat runs) | about 2.9 min | 16:18:43 (B1 start) → 16:21:33 (A3 end) |
| `git archive` + fresh `--import` of the reference | 2 s (exit 0, no `ERROR:`) | readiness review probe, 2026-11-18; Task 1 Step 3 re-measures |

**Gate estimate:** about 8 min per `run_benchmark.sh` on a branch that touches `game/` (5 min today + about 3 min pairs + the reference import); unchanged about 5 min on `main` and on branches that do not touch `game/` (pairs skipped). One A/A gate (`run_bench_pairs.sh` alone) is about 3-4 min; the calibration (8 gates) about 30 min.

## Edge cases (rules the code and tests implement)

| Case | Rule | Output, exit |
|---|---|---|
| `game/` unchanged since the reference (main, docs-only branch), no `PERF_REF` | pairs skipped; combat timing can only change through `game/` | `PAIR GATE SKIPPED game/ unchanged since <ref>`, 0 |
| uncommitted `game/` change on `main` | not skipped: the reference is `HEAD`, the branch is the working tree | normal verdict |
| `PERF_REF` set | pairs always run (the A/A calibration path) | normal verdict |
| no merge base (no local `main`) and no `PERF_REF` | cannot judge | `PAIR GATE INCONCLUSIVE no merge base with main (set PERF_REF)`, 1 |
| archive or reference import fails | cannot judge | `PAIR GATE INCONCLUSIVE ...` plus the import log, 1 |
| branch run exits non-zero or prints `ERROR:` | a real failure of the branch, as today | its log, `PAIR GATE FAILED branch run <i>`, 1 |
| branch run exits 0 without `COMBAT BENCHMARK PASSED 10` | crashed or truncated branch run | `PAIR GATE FAILED branch run <i>`, 1 |
| reference import exits 0 but prints `ERROR:` or `SCRIPT ERROR` | cannot trust the reference | `PAIR GATE INCONCLUSIVE import of <ref> failed`, 1 |
| reference run exits non-zero | its exit code is ignored; the log decides (next two rows) | |
| reference log complete: `COMBAT BENCHMARK PASSED 10`, or the legacy ceiling-fail end (a merge base from before this change): one or more `ERROR: Combat benchmark failed for <L>` lines, each `<L>` with a `COMBAT STRESS FAIL <L>` row and `ERROR: Combat stress ceiling exceeded for <L>`, and no other `ERROR:` line | usable (transition) | verdict from its `COMBAT <row> tick_ms=` lines |
| reference log not complete (neither ending above: killed, truncated, unrelated `ERROR:`), has `SCRIPT ERROR`, or no `COMBAT ... tick_ms=` line | crashed reference | `PAIR GATE INCONCLUSIVE ref run <i> unusable`, 2 (`run_benchmark.sh` exits 1) |
| guarded row missing in every reference log | row new on the branch: nothing to compare | `PAIR NEW <row> no reference row, not gated (alarm only)`, 0 (Q4) |
| guarded row missing in some reference logs | truncated reference run | `PAIR GATE INCONCLUSIVE ref run <i> lacks <row>`, 2 |
| guarded row set differs between branch logs | branch output unstable | INCONCLUSIVE, 2 |
| reference value 0 or negative | no ratio | INCONCLUSIVE, 2 |
| a row the reference has that the branch does not guard | not guarded (removed or promoted to a budget row, visible in the diff) | not printed |
| one disturbed pair (burst on one run) | median of 3 absorbs one bad pair | normal verdict |
| load above 2.5 at any pair start | no load-based verdict (load does not predict the swing; pairs cancel steady load). Reruns per "Pair-run outcomes" (Global Constraints) | `uptime` printed before each run |
| median exactly at the threshold | passes (`<=`, as `Stats.within`) | PASS |
| a FAIL and an INCONCLUSIVE row together | the measured regression wins | FAILED, 1 |

Verdict lines (one per guarded row and metric, then one final line):

```
PAIR REF 6854ff5
PAIR hordes300 p95 ref 3.092/3.085/3.090 branch 3.101/3.088/3.076 ratios 1.0029/1.0010/0.9955 median 1.0010 limit 1.020 PASS
PAIR hordes300 p99 ref ... median 0.9963 limit 1.020 PASS
PAIR GATE PASSED 3
```

Final line is one of `PAIR GATE PASSED <n>` (`<n>` = guarded rows compared; `PAIR NEW` rows not counted; all rows NEW gives `PAIR GATE PASSED 0`, exit 0), `PAIR GATE FAILED <row:metric ...>`, `PAIR GATE INCONCLUSIVE <reason>`, `PAIR GATE SKIPPED <reason>`. `perf_pairs.py` exits 0 / 1 / 2; `run_bench_pairs.sh` passes the code through; `run_benchmark.sh` turns any non-zero into exit 1 (its contract stays 0/1). A red pair gate means no CSV record, as for every failed run today (`test_failed_benchmark_never_records`).

## Files

| File | Change | Task |
|---|---|---|
| `tools/perf_pairs.py` (new) | pair verdict from 3+3 logs, `MAX_RATIO` | 2 |
| `tools/test_perf_pairs.py` (new) | unit tests of the verdict | 2 |
| `game/benchmarks/run_combat.gd` | ceiling report-only: `_stress_ok` → `_stress_report`, `:9` comment, `:162-165`, `:185-187`, `:206-215` | 3 |
| `tools/run_bench_pairs.sh` (new) | reference, skip rule, archive, import, 3 pairs, calls `perf_pairs.py` | 4 |
| `tools/run_benchmark.sh` | call the pair script after the combat step; `BUDGET EXCEEDED` wording; `CEILING ALARM` line | 4 |
| `tools/test_perf_charts.py` | `STUB_GODOT` reference/branch split, `COMBAT STRESS` fixture lines, new `RunBenchmarkTest` cases | 4 |
| `docs/reference/performance.md`, `docs/guide/12-performance-and-platforms.md`, `docs/guide/13-testing-and-tooling.md`, `docs/milestone-prompt.md`, `docs/night-run.md`, `docs/wrapup.md`, `docs/development.md`, `AGENTS.md` | docs | 7 |

---

### Task 1: Base and reference import time

**Files:** none tracked. Ledger (Global Constraints, run folder root).

- [ ] **Step 1:** in `<abs $W>`: `git rev-parse --abbrev-ref HEAD` prints `benchmark-pair-gate`; `git status --short` empty; `git rev-list --count main..HEAD` prints `0` (no branch commits yet; not `git merge-base`, which the `git merge:*` ask rule may catch at night; a later commit on `main` is fine; a branch commit the plan did not make is a stop); `test -f docs/superpowers/plans/2026-11-18-benchmark-pair-gate.md` (else stop). `<abs $L>`, `backups/night8/` and the seeded ledger exist (made at prep, handoff "Where things are"; missing: `mkdir -p <abs $L>` and say so in the ledger). Verify the ledger's resume-record block against these checks and update it (keep any evidence already recorded); `uptime >> <ledger>`, `pgrep -fl godot >> <ledger>`.
- [ ] **Step 2:** `PY(base)`, `SHELL(base)`, `GD(base)`, each exit 0 with its marker; then the suite baseline (Global Constraints), alone. A red base is a stop.
- [ ] **Step 3 (measure the reference import):** `cd <abs $W> && date +%s > <abs $L>/t1-import.time; mkdir -p <abs $L>/t1-ref && git archive HEAD game | tar -x -C <abs $L>/t1-ref && godot --headless --path <abs $L>/t1-ref/game --import > <abs $L>/t1-import.log 2>&1; echo "exit=$?"; date +%s >> <abs $L>/t1-import.time`. Exit 0, `rg -n 'ERROR:' <abs $L>/t1-import.log` empty. Record seconds (difference of the two lines) in the ledger; Task 7 copies it into this plan's cost table. Then `rm -rf <abs $L>/t1-ref`.
- [ ] **Step 4:** One timed combat run on the scratch copy is not needed (28-29 s is measured). Coordinator commits nothing (no tracked change).

### Task 2: `perf_pairs.py`, the verdict (test first)

**Files:** Create `tools/perf_pairs.py`, `tools/test_perf_pairs.py`.

**Interfaces:**
- `python3 tools/perf_pairs.py --ref R1 R2 R3 --branch B1 B2 B3` (the `PAIR REF` line comes from `run_bench_pairs.sh`, not from this tool) (equal-length lists, at least 1; the shell passes 3). Exit 0 / 1 / 2 as in "Edge cases"; prints the lines above.
- Reuses `perf_record.COMBAT` (`perf_record.py:40`) for `COMBAT <row> tick_ms=` lines; does not call `parse_log` (it raises on any `ERROR:` line, `:96-98`, which an old reference prints).
- `STRESS = re.compile(r"^COMBAT STRESS \S+ ([a-z0-9_]+) ", re.M)`: guarded rows are the layouts with a `COMBAT STRESS` line in the branch logs (matches today's `PASS|FAIL` and the new `PASS|ALARM`).
- `MAX_RATIO: dict[str, float] = {"p95": 1.02, "p99": 1.02}` with the one-line comment `# Provisional until the A/A calibration and the owner's approval; raise only with user approval and a ledger line.` (Task 6 replaces the values and the comment.)
- `def verdict(refs: list[str], branches: list[str]) -> tuple[int, list[str]]`: pure, takes log texts, returns exit code and output lines; `main()` reads files, prints, returns the code. Keep it about 60 lines; no classes.
- Before the row loop, any reference text that is not complete (Edge cases: `COMBAT BENCHMARK PASSED 10`, or the legacy ceiling-fail end with every `Combat benchmark failed for <L>` matched by `COMBAT STRESS FAIL <L>` and no other `ERROR:` line), has `SCRIPT ERROR`, or has no `COMBAT <row> tick_ms=` line at all gives `PAIR GATE INCONCLUSIVE ref run <i> unusable`, exit 2. Only then can a row be `PAIR NEW`.
- A guarded row with no tick line in some branch log: INCONCLUSIVE, exit 2 (never a `KeyError`). Every return path prints exactly one final `PAIR GATE …` line.

Sketch:

```python
def _rows(text: str) -> dict[str, dict[str, float]]:
    return {name: json.loads(raw) for name, raw in COMBAT.findall(text)}

def verdict(refs: list[str], branches: list[str]) -> tuple[int, list[str]]:
    ...  # unusable reference check first (Interfaces)
    guarded = [set(STRESS.findall(t)) for t in branches]
    if not guarded[0] or any(g != guarded[0] for g in guarded):
        return 2, ["PAIR GATE INCONCLUSIVE guarded rows differ between branch runs"]
    ...
    for row in sorted(guarded[0]):
        have = [row in r for r in ref_rows]
        if not any(have): lines.append(f"PAIR NEW {row} no reference row, not gated (alarm only)"); continue
        if not all(have): inconclusive.append(f"ref run {have.index(False) + 1} lacks {row}"); continue
        for metric, limit in MAX_RATIO.items():
            ratios = [b[row][metric] / a[row][metric] for a, b in zip(ref_rows, branch_rows)]
            median = statistics.median(ratios)
            ...  # PASS when median <= limit
```

- [ ] **Step 1: Tests** in `tools/test_perf_pairs.py` (`unittest`, log texts built from a helper `_log(rows: dict[str, tuple[float, float]], stress: tuple[str, ...], end: str = "COMBAT BENCHMARK PASSED 10") -> str` (p95, p99) that writes `COMBAT <row> tick_ms={...}` and `COMBAT STRESS PASS <row> ...` lines, then `end`). Names say the rule:
  - `test_identical_runs_pass_every_guarded_row` (exit 0, `PAIR GATE PASSED 3`).
  - `test_branch_three_percent_slower_on_hordes300_p95_fails_only_that_row` (ratios 1.03 ×3; exit 1; final line names `hordes300:p95`; open, dense PASS).
  - `test_one_slow_pair_is_absorbed_by_the_median` (ratios 1.00 / 1.10 / 1.00 → PASS).
  - `test_median_at_the_limit_passes_and_just_above_fails` (built from `perf_pairs.MAX_RATIO[metric]`: ref 1.000, branch = limit → PASS, limit + 0.001 → FAIL; ref 1.000 keeps the division exact, and Task 7 needs no test edit).
  - `test_p99_has_its_own_limit` (p95 equal, p99 ×1.03 → FAIL `:p99`; patch `MAX_RATIO` with `unittest.mock.patch.dict` to show the p99 key is the one used).
  - `test_unguarded_row_slower_never_fails` (`contact` ×1.10, no `COMBAT STRESS` line for it → PASS).
  - `test_row_new_on_branch_is_reported_not_gated` (reference lacks `hordes300` in all runs → `PAIR NEW hordes300`, exit 0).
  - `test_row_missing_in_one_reference_run_is_inconclusive` (exit 2).
  - `test_reference_with_script_error_is_inconclusive` (exit 2; the fixture keeps all tick lines, so the `SCRIPT ERROR` check is what makes it red).
  - `test_reference_without_any_tick_line_is_inconclusive_not_new` (3 references that are only `COMBAT BENCHMARK PASSED 10`, no `SCRIPT ERROR`, so the no-tick check alone makes it red → exit 2, no `PAIR NEW` line).
  - `test_three_identically_truncated_references_are_inconclusive` (3 references with only the `open` tick line, no end line → exit 2, no `PAIR NEW`, no `PASSED`).
  - `test_reference_killed_after_the_guarded_rows_is_inconclusive` (all tick lines, `end=""` → exit 2).
  - `test_old_reference_with_an_unrelated_error_is_inconclusive` (legacy ceiling-fail end plus `ERROR: Combat benchmark: no defence shots inside the timed window` → exit 2).
  - `test_guarded_rows_differ_between_branch_runs_is_inconclusive` (exit 2).
  - `test_branch_without_tick_line_for_guarded_row_is_inconclusive` (exit 2).
  - `test_old_reference_with_ceiling_errors_still_compares` (reference text contains `COMBAT STRESS FAIL hordes300 ...` and `ERROR: Combat stress ceiling exceeded for hordes300` lines plus all tick lines, `end="ERROR: Combat benchmark failed for hordes300"` → normal verdict, exit 0).
  - `test_zero_reference_value_is_inconclusive` (exit 2).
  - `test_fail_wins_over_inconclusive` (one row FAIL, another missing in one reference → exit 1).
  - `test_cli_reads_files_and_returns_the_code` (tempdir, 3+3 files, `main([...])` returns 1 for a slow branch).
- [ ] **Step 2:** `ONLYPY(t2red, test_perf_pairs.py)` exit 1 with failing named tests only (an import error is not red). Bare stub first: `MAX_RATIO` as in Interfaces, `verdict` returns `(0, [])`, `main` returns 0. Every test asserts both the exit code and the final `PAIR GATE` line, so all are red against the stub (none passes vacuously on exit 0).
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** `ONLYPY(t2, test_perf_pairs.py)` exit 0; `FMT(tools/perf_pairs.py tools/test_perf_pairs.py)`; `PY(t2)` exit 0 (ruff format, ruff, mypy, all Python tests).
- [ ] **Step 5:** Mutation proof: in `verdict` change `<=` to `<` → `ONLYPY(t2m1, test_perf_pairs.py)` exit 1 (the at-limit test); revert, prove. Second proof: take the mean instead of the median → exit 1 (the one-slow-pair test); revert, prove.
- [ ] **Step 6:** Per-task review; coordinator commits (`tools/perf_pairs.py`, `tools/test_perf_pairs.py`).

### Task 3: `run_combat.gd`: ceiling becomes a report-only alarm

**Files:** Modify `game/benchmarks/run_combat.gd` (`:9`, `:162-165`, `:185-187`, `:206-215`).

Before (`:206-215`):

```gdscript
func _stress_ok(layout: String, summary: Dictionary) -> bool:
	var ceiling: Array = STRESS_CEILING[layout]
	var over: String = Stats.over_budget_line(layout, summary)
	if not over.is_empty():
		print(over)
	var ok: bool = Stats.within(summary, ceiling[0], ceiling[1])
	print("COMBAT STRESS ", "PASS" if ok else "FAIL", " ", layout, " exceeds the ", Stats.BUDGET_P95_MS, "/", Stats.BUDGET_P99_MS, " budget, regression ceiling p95/p99 ", ceiling)
	if not ok:
		push_error("Combat stress ceiling exceeded for " + layout)
	return ok
```

After:

```gdscript
func _stress_report(layout: String, summary: Dictionary) -> void:
	var ceiling: Array = STRESS_CEILING[layout]
	var over: String = Stats.over_budget_line(layout, summary)
	if not over.is_empty():
		print(over)
	var held: bool = Stats.within(summary, ceiling[0], ceiling[1])
	print("COMBAT STRESS ", "PASS" if held else "ALARM", " ", layout, " exceeds the ", Stats.BUDGET_P95_MS, "/", Stats.BUDGET_P99_MS, " budget, drift alarm p95/p99 ", ceiling, " (report only)")
```

Callers: `:164-165` `if not _stress_ok(layout, summary): return false` → `_stress_report(layout, summary)`. `:185-187`:

```gdscript
	if STRESS_CEILING.has(layout):
		_stress_report(layout, summary)
	elif not _budget_ok(layout, summary):
		return false
```

`:9` comment → `# Drift alarms for rows over the budget, report only since the pair gate: worst of 13 quiet runs + 5% (T3, 2026-11-08); change only with user approval and a ledger line.` `STRESS_CEILING` values unchanged. Effect: an alarm no longer skips the hordes300 workload checks (`:166-175`) or the open/dense chase, retaliation and workload checks (`:188-196`), which today run only when the ceiling holds.

- [ ] **Step 0 (red on the old code, before the edit):** `cd <abs $W> && mkdir -p <abs $L>/t3-copy && git archive HEAD game | tar -x -C <abs $L>/t3-copy`; in the copy, with the Edit tool, ceilings 0.1 (as Step 3) plus `if window_reserved == 0:` → `if true:`; import as Step 3, then `uptime > <abs $L>/t3-old.log; godot --headless --path <abs $L>/t3-copy/game --script res://benchmarks/run_combat.gd >> <abs $L>/t3-old.log 2>&1; echo "exit=$?"` → exit 1, `rg -c '^COMBAT STRESS FAIL ' <abs $L>/t3-old.log` 3, `rg -n 'no retaliator was sent home' <abs $L>/t3-old.log` **no** hit (the old code returns before the check). `rm -rf <abs $L>/t3-copy`.
- [ ] **Step 1:** Edit as above.
- [ ] **Step 2:** `GD(t3)` exit 0; `WARGRID_TEST_ONLY=test_benchmark sh tools/run_tests.sh > <abs $L>/t3-bm.log 2>&1; echo "exit=$?"` → exit 0 (BM11 loads `run_combat.gd` and pins `STRESS_CEILING`, `game/tests/test_benchmark.gd:294-297`).
- [ ] **Step 3 (alarm path, scratch copy, no tracked edit):** `cd <abs $W> && mkdir -p <abs $L>/t3-copy && git archive HEAD game | tar -x -C <abs $L>/t3-copy && cp <abs $W>/game/benchmarks/run_combat.gd <abs $L>/t3-copy/game/benchmarks/run_combat.gd`, then set the copy's `STRESS_CEILING` (`:12`) to `{"open": [0.1, 0.1], "dense": [0.1, 0.1], "hordes300": [0.1, 0.1]}` with the Edit tool. `godot --headless --path <abs $L>/t3-copy/game --import > <abs $L>/t3-import.log 2>&1; echo "exit=$?"`, then `uptime > <abs $L>/t3-alarm.log; godot --headless --path <abs $L>/t3-copy/game --script res://benchmarks/run_combat.gd >> <abs $L>/t3-alarm.log 2>&1; echo "exit=$?"` → exit 0; `rg -c '^COMBAT STRESS ALARM ' <abs $L>/t3-alarm.log` 3; `COMBAT BENCHMARK PASSED 10`; `rg -c '^COMBAT BUDGET PASS ' <abs $L>/t3-alarm.log` 7; `rg -n 'ERROR:' <abs $L>/t3-alarm.log` empty. Keep the copy for Step 4.
- [ ] **Step 4 (workload checks still bite after an alarm):** in the same copy (ceilings 0.1), Edit the unique line `if window_reserved == 0:` (`:169` at `main`, one line higher after Step 1) → `if true:`; `uptime > <abs $L>/t3-reserve.log; godot --headless --path <abs $L>/t3-copy/game --script res://benchmarks/run_combat.gd >> <abs $L>/t3-reserve.log 2>&1; echo "exit=$?"` → exit 1, `rg -n 'no retaliator was sent home' <abs $L>/t3-reserve.log` one hit. Proves the check runs after an alarm. `rm -rf <abs $L>/t3-copy`.
- [ ] **Step 5:** Per-task review; coordinator commits (`game/benchmarks/run_combat.gd`).

### Task 4: `run_bench_pairs.sh` and the `run_benchmark.sh` wiring

**Files:** Create `tools/run_bench_pairs.sh`. Modify `tools/run_benchmark.sh` (`:21-24`, `:32-33`), `tools/test_perf_charts.py` (`STUB_GODOT` `:565-573`, `_stub_outputs` `:576-587`, `RunBenchmarkTest` `:590-690`).

`tools/run_bench_pairs.sh` (shape; ShellCheck-clean, POSIX sh, about 35 lines):

```sh
#!/bin/sh
# usage: [PERF_REF=<rev>] run_bench_pairs.sh — reference and working tree run_combat.gd in 3 alternating pairs; perf_pairs.py judges.
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
engine=${GODOT_BIN:-godot}
cd "$repo_root" || exit 1
ref=${PERF_REF:-$(git merge-base HEAD main)} || { echo "PAIR GATE INCONCLUSIVE no merge base with main (set PERF_REF)"; exit 1; }
name=$(git rev-parse --short "$ref") || { echo "PAIR GATE INCONCLUSIVE bad reference $ref"; exit 1; }
if [ -z "${PERF_REF:-}" ] && git diff --quiet "$ref" -- game && [ -z "$(git status --porcelain -- game)" ]; then
	echo "PAIR GATE SKIPPED game/ unchanged since $name"; exit 0
fi
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
echo "PAIR WORK $work (pid $$)"
git archive "$ref" game | tar -x -C "$work" || { echo "PAIR GATE INCONCLUSIVE archive of $name failed"; exit 1; }
if ! "$engine" --headless --path "$work/game" --import >"$work/import.log" 2>&1 || grep -E 'ERROR:|SCRIPT ERROR' "$work/import.log"; then
	cat "$work/import.log"; echo "PAIR GATE INCONCLUSIVE import of $name failed"; exit 1
fi
echo "PAIR REF $name ${PERF_REF:+(PERF_REF=$PERF_REF)}"
for i in 1 2 3; do
	echo "PAIR ref-$i $(uptime)"
	"$engine" --headless --path "$work/game" --script res://benchmarks/run_combat.gd >"$work/ref-$i.log" 2>&1
	echo "PAIR branch-$i $(uptime)"
	if ! "$engine" --headless --path "$repo_root/game" --script res://benchmarks/run_combat.gd >"$work/branch-$i.log" 2>&1 \
		|| grep -E 'ERROR:|SCRIPT ERROR:' "$work/branch-$i.log" \
		|| ! grep -q '^COMBAT BENCHMARK PASSED 10$' "$work/branch-$i.log"; then
		cat "$work/branch-$i.log"; echo "PAIR GATE FAILED branch run $i"; exit 1
	fi
done
python3 tools/perf_pairs.py --ref "$work"/ref-1.log "$work"/ref-2.log "$work"/ref-3.log --branch "$work"/branch-1.log "$work"/branch-2.log "$work"/branch-3.log
```

The reference exit code is ignored on purpose (Edge cases, transition); `perf_pairs.py` judges the reference log, including its completion line. The `uptime` lines carry the load per run; `PAIR WORK` names the temp dir and wrapper PID the deadline cleanup kills by (Global Constraints).

`tools/run_benchmark.sh` after `:24`:

```sh
sh "$repo_root/tools/run_bench_pairs.sh" || exit 1
```

`:32-33` before:

```sh
over=$(cat "$log_dir"/*.log | sed -n 's/^OVER BUDGET \([^ ]*\) .*/\1/p' | tr '\n' ' ')
[ -z "$over" ] || echo "BUDGET EXCEEDED ${over% } (regression ceilings held)"
```

after:

```sh
over=$(cat "$log_dir"/*.log | sed -n 's/^OVER BUDGET \([^ ]*\) .*/\1/p' | tr '\n' ' ')
[ -z "$over" ] || echo "BUDGET EXCEEDED ${over% }"
alarm=$(sed -n 's/^COMBAT STRESS ALARM \([^ ]*\) .*/\1/p' "$log_dir/combat.log" | tr '\n' ' ')
[ -z "$alarm" ] || echo "CEILING ALARM ${alarm% } (report only)"
```

Tests (`tools/test_perf_charts.py`):
- `RunBenchmarkTest.setUp` (`:591-618`) copy tuple (`:599`) gains `run_bench_pairs.sh` and `perf_pairs.py` (fixture change; without it every `RunBenchmarkTest` case fails on the missing script).
- `STUB_GODOT`: `*run_combat*)` prints `$STUB_DIR/combat.out` when `$*` matches `*"$STUB_REPO/game"*` (leading `*`: `sh` resolves the macOS temp dir to `/private/var/...`, so the path is a substring), else `$STUB_DIR/${STUB_REF:-combat}.out`; `run_script` passes `STUB_REPO=<self.repo>`. `--import` stays a silent exit 0, except that with `STUB_REF_IMPORT_FAIL=1` an `--import` whose path does not match `*"$STUB_REPO/game"*` exits 1, and with `STUB_REF_IMPORT_ERROR=1` it prints `ERROR: stub import` and exits 0.
- `_stub_outputs()["combat"]` gains `COMBAT STRESS PASS open x\n` and `COMBAT STRESS PASS dense x\n` (the fixture's combat rows are open and dense); a `ref_slow` stub output with the fixture's open p95 divided by 1.05 (branch 5 % slower).
- New cases: `test_clean_main_skips_the_pair_gate` (stdout `PAIR GATE SKIPPED`, exit 0, rows recorded as before); `test_branch_touching_game_runs_pairs_and_passes` (branch commit adding `game/x.gd`; `PAIR GATE PASSED`; exit 0); `test_branch_slower_than_reference_fails_and_never_records` (branch `spike-x` with a commit adding `game/x.gd`, `STUB_REF=ref_slow`, `PERF_LABEL="x"`; exit 1, stdout has `PAIR GATE FAILED open:p95`, CSV bytes unchanged, as `test_failed_benchmark_never_records`, `:685-689`); `test_uncommitted_game_file_on_main_runs_pairs` (untracked `game/y.gd`, no `PERF_REF` → `PAIR REF`); `test_reference_import_failure_is_inconclusive` (`PERF_REF=HEAD`, `STUB_REF_IMPORT_FAIL=1`, `PERF_LABEL="x"` → exit 1, `PAIR GATE INCONCLUSIVE import`, CSV unchanged); `test_docs_only_branch_skips_pairs` (branch commit under `docs/`); `test_perf_ref_forces_pairs_on_main` (`PERF_REF=HEAD`; `PAIR REF`); `test_missing_main_is_inconclusive` (repo with branch renamed off `main`, no `PERF_REF`; exit 1, `INCONCLUSIVE no merge base`); `test_ceiling_alarm_line_is_report_only` (combat stub with `COMBAT STRESS ALARM dense x`; exit 0, `CEILING ALARM dense (report only)`); `test_reference_import_error_line_is_inconclusive` (`PERF_REF=HEAD`, `STUB_REF_IMPORT_ERROR=1` → exit 1, `PAIR GATE INCONCLUSIVE import`); `test_branch_run_without_completion_marker_fails` (combat stub without `COMBAT BENCHMARK PASSED 10`, `PERF_REF=HEAD sh tools/run_bench_pairs.sh` run directly, since the outer script's own marker check stops first → exit 1, `PAIR GATE FAILED branch run 1`).
- New cases that commit use the author/committer env of `_git_repo` (`:445-453`; its `git` helper is local, and CI has no git identity).
- Existing cases stay green unchanged; `test_output_is_bracketed_by_uptime_on_pass_and_early_failure` still holds because the first and last lines are the outer `uptime` (the pair `uptime` lines are prefixed `PAIR`).

- [ ] **Step 1:** First create a placeholder `tools/run_bench_pairs.sh` with just `#!/bin/sh` and `exit 0` (same idea as Task 2's bare stub), and leave `run_benchmark.sh` unchanged. Then write the tests and run `ONLYPY(t4red, test_perf_charts.py)`: exit 1, the existing `RunBenchmarkTest`/`PerfRecordTest` cases pass, and every new case fails on an assertion, not in `setUp`.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** `ONLYPY(t4, test_perf_charts.py)` exit 0; `FMT(tools/test_perf_charts.py)`; `PY(t4)`, `SHELL(t4)` exit 0.
- [ ] **Step 4:** Mutation proof: in `run_bench_pairs.sh` drop the `-z "${PERF_REF:-}"` condition → `test_perf_ref_forces_pairs_on_main` red; revert, prove.
- [ ] **Step 5:** Real run, alone, foreground: `PAIRS(t4)` → exit 0, `PAIR GATE PASSED 3`, `rg -c '^PAIR (ref|branch)-' <abs $L>/t4-pairs.log` 6. Record the wall time (first and last `uptime` line in the log) in the ledger. Any other outcome: see "Pair-run outcomes".
- [ ] **Step 6:** Per-task review; after the fix round rerun Step 3 for any change, and Step 5 as `t4b` if `run_bench_pairs.sh` or `perf_pairs.py` changed. Coordinator commits every changed in-scope file (`tools/run_bench_pairs.sh`, `tools/run_benchmark.sh`, `tools/test_perf_charts.py`, and `tools/perf_pairs.py`/`tools/test_perf_pairs.py` if a fix touched them).

### Task 5: Sensitivity proof (the gate catches a ring-sized regression)

The real regression this gate must catch: the per-tick hash ring, +2.5-3.4 % on hordes300 (ring 3.3 % of the hordes300 step, `performance.md:135`; accepted, `:144`; p95 logs 2.849 → 2.919 / 2.947 in `pump-hardening/benchmark-noise-investigation.md:43`, private). Prove a +3 % slowdown fails and a 0 % change passes, on this host, now (the 0 % runs are Task 4 Step 5 and the Task 6 A/A gates). Runs unattended (owner, 2026-11-18). No tracked change, no commit.

- [ ] **Step 1:** `cd <abs $W> && git add game/benchmarks/run_combat.gd` (clean file, no-op that pins the revert target). With the Edit tool, after `sim.step()` at `:77` (inside the timed window, unchanged by Task 3) add, with the same two-tab indent, a 90 µs busy-wait on real wall time (a sleep overshoots; about 3 % of a 3 ms p95 tick; samples are not perturbed afterwards):

```gdscript
		if layout == "hordes300":
			var spin_until: int = Time.get_ticks_usec() + 90
			while Time.get_ticks_usec() < spin_until: pass
```
- [ ] **Step 2:** `PAIRS(t5slow)`, foreground → exit 1, the final line names `hordes300:p95` (likely also `hordes300:p99`): the expected result, success. Open and dense p95 PASS (`rg -n '^PAIR (open|dense|hordes300) ' <abs $L>/t5slow-pairs.log`). An extra `open:p99` or `dense:p99` in the FAILED list is calibration data (ledger), not a stop. Other outcomes: see "Pair-run outcomes". Record the measured hordes300 medians in the ledger; the hordes300 p95 median ratio is the injected slowdown; above 1.04 the ledger and morning summary say "sensitivity shown at +<x> %, not at +3 %" (owner item). **Every return of this task, BLOCKED, PARK and timeout included, runs Step 3 first.**
- [ ] **Step 3:** Revert with the Edit tool; `cd <abs $W> && git diff HEAD --exit-code -- game/benchmarks/run_combat.gd > <abs $L>/t5-revert.log 2>&1; echo "exit=$?"` → exit 0; `git status --short` empty. Not clean: the task returns BLOCKED and nothing else is dispatched until it is.
- [ ] **Step 4:** A proof that stays green (gate does not fail at +3 %) is a stop: the threshold or the pair count is wrong for this host, owner decides. The run parks (Task 6 needs a gate that can fail).

### Task 6: A/A calibration and threshold proposal (stop for the owner)

**What:** 8 A/A gates, `PERF_REF=HEAD` on the clean branch tip after Task 5 (reference = archive of `HEAD`, branch = the working tree at `HEAD`: exactly what the gate compares, with no code difference). Rows: open, dense, hordes300; metrics p95 and p99. 4 gates in one session, 4 in another host state (Q3: a quiet night slot and an ordinary day slot with the owner's usual desktop load, e.g. a browser open). 48 combat runs, about 30 min.

**Split (owner, 2026-11-18):** the night run does Step 1a only, then parks at Task 6. Steps 1b-4 and the stop gate are an attended day session; Tasks 7-8 wait for it.

- [ ] **Step 1a (night, session 1):** in `<abs $W>`, `git status --short` empty and `HEAD` = the Task 4 commit (Task 5 reverted). For `n` in 1..4: `PAIRS(aa-s1-<n>)` back to back, one at a time, each in the foreground. Outcomes per "Pair-run outcomes": a complete verdict, `PASSED` or `FAILED <row:metric>`, is data, never rerun (an A/A FAIL at the provisional 1.02 is exactly what calibration must find); an unusable run gets its one rerun (`aa-s1-<n>-r`). Ledger: `git rev-parse HEAD` once; per gate the accepted log path, every attempt, exit code, `rg -n '^PAIR GATE ' <accepted log>`, first `uptime` line, "host under load" if above 2.5. No tracked change, no commit. **Park:** the run reports Task 6 parked after `aa-s1-4`, with "day half pending" as the owner item.
- [ ] **Step 1b (day, session 2, attended):** same tree (`git rev-parse HEAD` equals the `aa-s1` gates' `HEAD`, recorded in the ledger), ordinary desktop load (Q3). For `n` in 1..4: `PAIRS(aa-s2-<n>)`, same rules.
- [ ] **Step 2 (day):** Extract with `rg -n '^PAIR (open|dense|hordes300) ' <the 8 accepted log paths from the ledger>` (never a glob: it would add the `-r` attempts) into a table in the ledger: per gate, per row and metric, the 3 pair ratios and the median; the `uptime` loads.
- [ ] **Step 3 (day): Derivation (fixed formula, no judgement):** for each metric `m`, `worst_m` = the largest A/A median over the 3 rows and 8 gates; `proposal_m = worst_m + 0.01`, rounded up to the next 0.005. For p95: when `proposal_p95 <= 1.02`, the proposal is 1.02 (the owner's value; Q2); otherwise the proposal is `proposal_p95` and it is flagged "above the owner's 1.02". Same for p99 with no 1.02 floor implied (Q1). Also report the sd of all 24 single-pair ratios per row and metric, and how many of the 8 A/A gates would have failed at the proposal (must be 0 by construction).
- [ ] **Step 4 (day):** Write the table and proposal into `docs/reference/performance.md` as a new section `## Pair gate (benchmark pair gate, <date>)` under "Rule per milestone" (`:174`, at `main` `2b7bbe5`): tree, host, sessions, loads, the table, the formula, the proposal, the Task 5 result, status **proposed, needs the owner's decision**. No `(user, DATE)` tag until the owner decides. Coordinator commits.
- [ ] **Stop gate:** report the proposal and stop. The owner approves or sets the values. Task 7 starts only after that answer is written into the section with its `(user, DATE)` tag.

### Task 7: Apply the threshold; docs

**Files:** `tools/perf_pairs.py` (`MAX_RATIO` values and comment), docs below.

- [ ] **Step 1:** `MAX_RATIO` = the approved values; comment `# A/A calibration <date> (performance ledger, pair gate), approved by the owner; raise only with user approval and a ledger line.` `PY(t7)`. If the approved p95 or p99 is below a value a Task 2 test relies on, adjust only the test's built ratios, never its rule.
- [ ] **Step 2: Docs** (link, do not duplicate numbers; the threshold value lives in the ledger section and the constant only):
  - `docs/reference/performance.md` "Rule per milestone" (`:176-178`): one paragraph: on a branch that touches `game/`, `run_benchmark.sh` also runs the pair gate (3 alternating pairs against the merge base, median ratio per guarded row against `MAX_RATIO`); open, dense and hordes300 are guarded; their `STRESS_CEILING` values are a report-only drift alarm (`CEILING ALARM`), on `main` its only check; `PERF_REF` sets the reference; red pair gates are not recorded. Under "Gate proposals (T3)" (`:378`), one sentence after the T8 paragraph: G3-G5 ceilings report-only since <date>, the regression verdict is the pair gate (link). Pair gate section from Task 6 gets the approved values. A History row for Task 8a.
  - `docs/guide/12-performance-and-platforms.md`: `:37` stress bullet (ceilings are a drift alarm; regressions judged in pairs), `:47` gate table row (pair step; "about 150 s before Pump hardening; the profile now plays the team match twice and is re-timed at the gate" → measured times from Task 4 and 8a), `:54` paragraph (two kinds of verdict: budget rows absolute, stress rows relative to the merge base; why: host swings 5-7 % between sessions, pairs cancel it), `:74` (`COMBAT STRESS PASS` → `PASS`/`ALARM`, report only), `:193-194` "Where in the code" (`run_bench_pairs.sh`, `perf_pairs.py`); `Checked against` footer (`:215`) gains a clause for this branch tip and the two new files. Keep the chapter's style: payoff first, terms explained where they appear.
  - `docs/guide/13-testing-and-tooling.md`: `:88` (`BUDGET EXCEEDED` informs; `CEILING ALARM` informs; `PAIR GATE FAILED` or `INCONCLUSIVE` fails), `:264` tool list; footer `:279`.
  - `docs/milestone-prompt.md:101-102`: "`run_benchmark.sh` then exits 1, so name the failing line" stays; add "a `PAIR GATE FAILED` or `INCONCLUSIVE` line is a stop; a `CEILING ALARM` line alone is not"; "a stress ceiling would need a re-pin" → "the pair threshold or a stress ceiling would need a change".
  - `docs/night-run.md:48` (Long commands): one clause: the benchmark gate takes about <measured> min on a branch that touches `game/`.
  - `docs/wrapup.md` step 1 and `AGENTS.md` after-merge bullet (`:49`): one clause each: a `CEILING ALARM` line on `main` goes to the owner's open items (report only, never a reason to loosen) (Q7).
  - `docs/development.md:81`: add `PERF_REF=<rev>` to the benchmark command comment.
- [ ] **Step 3:** Link and anchor check by hand on changed docs; `CHECKS(t7)` (`CHECKS PASSED 5`, includes `check_public.sh`).
- [ ] **Step 4:** Fresh Opus (high) docs review (code claims against the branch), `<abs $L>/t7-review.md`; fixes; commit.

### Task 8: Gate

- [ ] **8a benchmark (alone):** `uptime`; `PERF_LABEL="Benchmark pair gate" sh tools/run_benchmark.sh > <abs $L>/gate-bench.log 2>&1; echo "exit=$?"`, foreground. The reference is `main` (old `run_combat.gd`, blocking ceiling): this run exercises the transition path. Exit 0; `PAIR GATE PASSED 3` (the branch changes no timed code); `COMBAT BENCHMARK PASSED 10`; `PROFILE COMPLETE 11`; the row records itself. Copy `PAIR` lines, `CEILING ALARM` (if any) and `uptime` at start and end into the ledger; total wall time into the cost table. Pair lines per "Pair-run outcomes"; red: Opus diagnosis first.
- [ ] **8b checks:** `CHECKS(gate)`; `GD(gate)`; untouched-path diff empty (Global Constraints).
- [ ] **8c reviews:** the gate reviewers (Model routing) in parallel on `main...HEAD`, each `<abs $L>/gate-<reviewer>.md`.
- [ ] **8d fixes:** P1 and P2 findings test-first; rerun what they touch; 8a again only if `run_bench_pairs.sh`, `run_benchmark.sh`, `perf_pairs.py` or `run_combat.gd` changed. **Stop gate.**

## Stop gate and stop conditions

Stop gates: tonight's park after Task 6 Step 1a (owner, 2026-11-18); after Task 6 (threshold proposal, owner decides) and after Task 8d. Report implemented, verified and pending separately. Always parked for the owner, never ruled on by an agent:

- any change to a budget, F, a `STRESS_CEILING` value, or `MAX_RATIO` other than writing the approved values once in Task 7;
- an environment or CLI path that overrides `MAX_RATIO`;
- the Task 5 sensitivity proof staying green;
- an A/A proposal above the owner's 1.02 for p95 (it is reported, not applied);
- an unexpected `run_benchmark.sh` or pair red at load 2.5 or below, or red twice under load (expected and data results per "Pair-run outcomes" are never a stop);
- a stop under "Pair-run outcomes" (unusable twice in a row on the same tree, `FAILED branch run <i>`, an unexpected `FAILED` verdict);
- Task 5's revert not clean (`git diff HEAD --exit-code` non-zero or `git status --short` not empty);
- a foreign Godot process during a measurement (measurement skipped);
- an existing `RunBenchmarkTest` or `PerfRecordTest` case needing an edit beyond the stub and fixture changes Task 4 names;
- any edit to a generated status block, `perf_chart.py`, `perf_record.py` or `game/scripts/`.

Never loosen a budget. A threshold change after approval needs the owner and a ledger line, in both directions.

## Owner items after the gate

Merge decision; after a merge, the usual `main` benchmark (pairs skipped there; the `CEILING ALARM` line, if any, goes to the open items). Optional, not in this plan: the investigation's E1 (browser open vs closed) and re-deriving the alarm values from a multi-session batch (a raise is the owner's call).

## Not in this plan (skipped on purpose)

- No ratio gate on the seven budget rows or the movement and lockstep rows (they keep their absolute budgets; a ratio on a 0.8 ms row is too coarse).
- No reuse of the absolute combat run as the first branch run (saves 28 s, costs ordering logic).
- No recording of red runs in the CSV, no status-table or `perf_chart.py` change, no CI change (benchmarks stay a local gate).
- No kept pair logs: the `PAIR` lines carry every value the verdict used.

## Run setup

Attended prep: set the Status line (l.3) once the owner approves; commit this plan to `main` at `docs/superpowers/plans/2026-11-18-benchmark-pair-gate.md`, plus every other prep commit on `main`; as the last step create `$W` on branch `benchmark-pair-gate` and the B3 worktree on `rematch-after-quit` from that `main` (`git -C ~/projects/wargrid worktree add <abs $W> -b benchmark-pair-gate main`) and run `sh tools/ensure_venv.sh` once in each (builds `tools/.venv` through uv, so `PY(base)` and B3's `run_checks.sh` cannot go red on it); then create `<abs $L>`, `backups/night8/` (copies of night 8's `plan.md`, `questions.md`, `review.md`) and the ledger seeded with the resume record (both branches, base SHAs, clean checks, "next action: Task 1 Step 1"). The handoff, not the plan, states "Task 6 Step 1a only, then park; Tasks 6.1b-8 not tonight" (the coordinator never reads task bodies). Night run: the proposed settings copy (private, never the live file) adds `<abs $W>` to `additionalDirectories` and needs `Bash(PERF_REF=HEAD sh tools/run_bench_pairs.sh*)`, `Bash(mkdir -p <abs $L>*)`, `Edit(//<abs $W>/**)`, `Bash(cd <abs $W>*)`, plus, beyond the live night settings: `Bash(tools/.venv/bin/python3 tools/test_perf_*)` (`ONLYPY`), `Bash(tar -x -C <abs $L>/*)` and `Bash(date +%s*)` (Task 1 Step 3, Task 3), `Bash(cp <abs $W>/game/benchmarks/run_combat.gd <abs $L>/*)` (Task 3), `Bash(rm -rf <abs $L>/t1-ref)` and `Bash(rm -rf <abs $L>/t3-copy)`, `Bash(test -f *)` (Task 1 Step 1), `Bash(tools/.venv/bin/ruff format tools/*)` and `Bash(tools/.venv/bin/ruff check --fix tools/*)` (`FMT`). Already live and used: `Bash(git archive:*)`, `Bash(git add -N:*)` (per-task review), `Bash(WARGRID_TEST_ONLY=*)` and `Bash(sh tools/run_tests.sh:*)` (baseline, Task 3 Step 2), `Bash(kill:*)` and `Bash(pgrep:*)` (deadlines), `Edit(//<abs ~/projects/wargrid-overnight-work>/**)` (ledger). `git archive` inside the scripts runs as their child process and needs no rule. Task 6 needs two sessions in different host states (Q3): its night half runs tonight, its day half later (see "Night run", l.5).
