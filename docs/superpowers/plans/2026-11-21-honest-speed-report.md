# Honest speed report: night 14 plan

> **For agentic workers:** run as a night-run coordinator ([night run](../../night-run.md#coordinator-rules), [milestone prompt](../../milestone-prompt.md)): one fresh subagent per task, each starting from the resume record in the [verification file](../../reference/honest-speed-report-verification.md). Steps use checkbox (`- [ ]`) syntax.

**Goal:** the README speed block shows a pass/fail colour only where a known route to green exists and plain trend elsewhere, gains three 3v3 "headroom" rows from the profile pass, and shows the Steam Deck real-scene row as "not measured yet"; gap 12 (profiler overhead on the hand-off rows and in Wasm) is measured as evidence.

**Decisions:** [low-end report loose ends (user, 2026-11-20)](../../reference/design-answers-2026-11-08.md#low-end-report-loose-ends-user-2026-11-20) (D1 owner variant, D5 (a), the package); [packages](../../packages.md#night-lane) night lane item 14; [STATUS](../../STATUS.md) row "night 14". Owner rulings for this plan (user, 2026-11-21): D3 and D4 stay at the SB6 plan, so the Deck row shows "not measured yet" with no thresholds; gap 12 as below, an unreachable Deck parks only its Wasm half; busy-host order; branch and worktree; an advisory War Room round as the owner check.

**Architecture:** no game code changes. `tools/perf_record.py` learns two metrics from the `PROFILE team_match` lines that `run_benchmark.sh` already feeds it. `tools/perf_chart.py` gains three goal lines (ledger verdicts), a trend rule, and a README block of two tables; the ledger block keeps every verdict. Gap 12 runs in `git archive` copies outside the repository and lands as ledger rows only.

**Tech stack:** Python 3.12 (stdlib; ruff and mypy through `sh tools/run_python_checks.sh`), Godot 4.7.2 headless for the measurements, the War Room round format (`warroom/README.md`, "Rounds: the data contract").

## Global constraints

- Branch `honest-speed-report` in worktree `~/projects/wargrid-wt-speed`, cut from `main` after the preparation's commit; the preparation makes it and starts the session inside it (a missing worktree is `BLOCKED`). One local commit per green task is pre-authorized; no push, PR, merge or fly deploy.
- Logs and scratch go to `~/projects/wargrid-overnight-work/night-14/` (`logs/`, `gap12/`, `deck/`, `round/`, made at the preparation); `…/logs/` below is short for `~/projects/wargrid-overnight-work/night-14/logs/`. In commands, expand every `~/` and `…/` to the absolute path and write every path out: no shell variables, no `git -C` (night allow rules match the command text); tracked files keep `~/` (`sh tools/check_public.sh`).
- **Night helpers**, written and checked (`sh -n`, `shellcheck`) at the preparation in `~/projects/wargrid-overnight-work/night-14/`; call them as `sh <abs path>` or `python3 -I <abs path>`, never edit them at night:
  - `wait-quiet.sh <worktree> <HH:MM>`: waits until the 1-minute load is below 2.5 and `pgrep -ifl 'godot|generalszh'` shows nothing outside `<worktree>`; re-checks every 60 s; prints `uptime`; exit 0 quiet, 3 at the deadline (with the other processes listed).
  - `copy-tree.sh <worktree> <dest>`: `git archive HEAD` of the worktree unpacked into a new folder under `night-14/`.
  - `gap12_digest.py mac <gap12 folder> <worktree>` and `gap12_digest.py deck <deck logs folder>`: the Task 7 and Task 8 digests (checks, medians of 3, ranges, overhead); exit 1 on a missing line, an `ERROR` line or a differing match outcome.
  - `deck/deck-job14.sh`: the Deck job of Task 8; `deck-wait.sh <address> <minutes>`: waits for it (exit 0 `DONE14`, 4 unit stopped without it, 3 timeout, 5 ssh failing).
  - `agy-review.sh <model> <prompt file>`: the read-only `agy` review recipe (`agy-handoff.md`, private, "Shared invocation" and "Review task"), run from the worktree; the prompt file and the diff it names sit together in `…/logs/`; prints the answer, exit 1 on any failure.
- **No limit changes.** `Budget` values (`SIM_P95`, `SIM_P99`, `PLUMBING`, `FRAME`, `LOCKSTEP`), `NOISE_PCT`, `BUSY_LOAD`, `CLOSE_PCT`, the slowdown factor F 5.5 and every ledger budget stay as they are. A step that seems to need one is a stop condition.
- Test first: each Red is a named assertion that fails for the named reason (missing key, wrong text), not an import or syntax error. Never weaken an existing assertion; the existing `PerfChartTest`, `PerfRecordTest` and `RunBenchmarkTest` cases pass unchanged.
- Python tasks: `sh tools/run_python_checks.sh > <log> 2>&1; echo "exit=$?"` (ruff format and check, mypy, every `tools/test_*.py`; ends `PYTHON TESTS PASSED`). While iterating: `tools/.venv/bin/python3 tools/test_perf_charts.py`. The new worktree has no venv until Task 1 Step 0 builds it.
- Every suite, benchmark, Godot measurement and lint call passes `timeout: 600000` or runs in the background with the completion notice.
- **Busy host** (user, 2026-11-21): Tasks 1-5 never wait. Tasks 6-7 (Mac measurements) start only when the 1-minute load is below 2.5 and no other session's Godot runs. The wait: `sh ~/projects/wargrid-overnight-work/night-14/wait-quiet.sh ~/projects/wargrid-wt-speed 05:00 > …/logs/wait-<task>.log 2>&1; echo "exit=$?"` with `run_in_background` and the completion notice (never `sleep` polls). Exit 0: quiet, go on. Exit 3: the 05:00 fallback; they run anyway: the CSV label gets the suffix ` (host under load)` (no comma: the label is a CSV field), the ledger row says "host under load", and an evening rerun is owed (morning item). Task 8's Mac export runs after Task 7 and alone; its measurements run on the Deck.
- Same-tick interaction cases do not apply: no new command and no simulation change.
- No presentation change, so no rendered rerun is owed; CI runs when the owner pushes.
- Parking and commits: [Coordinator card](#coordinator-card); a fix is always a new commit.

## Coordinator card

The coordinator reads only the handoff and the resume record ([night run](../../night-run.md#coordinator-rules)), so the handoff copies this card.

- **Order:** Tasks 1, 2, 3, then 4 and 5, then 6, 7, 8 (last), then the Gate. Tasks 1-5 never wait for the host.
- **At each task boundary:** `git status --short` against the paths the subagent reported; after `GREEN` the coordinator makes the task's local commit (subagents never commit); `pgrep -ifl 'godot|generalszh'` and `TaskStop` on anything the run started; before Tasks 6 and 7, `uptime` and the same `pgrep`: quiet goes on, else the `wait-quiet.sh` wait (Global constraints, busy host).
- **Park:** `git stash push --include-untracked -m park-t<N>` on a dirty tree, the stash named in the resume record; never `git reset` or `git commit --amend`.
- **What parks** (the run goes on): Task 8 alone on any Deck failure (unreachable, battery, display, Firefox, export, a page without `BENCH DONE`, `gap12_digest.py deck` exit 1, including `TEAM MATCH` lines that differ between pages); the run then goes to the Gate. Task 5 on a `quality.sh` failure outside the round files and outside its network steps (the round stays unlisted); the Gate notes it. Dependencies: Task 2 builds its own test rows, so it does not need Task 1; Task 3 needs 2; Tasks 4 and 5 need 3; Task 6 needs 1-3; Tasks 7 and 8 need only a quiet host and the Deck.
- **What stops** (park for the owner, take the handoff's next backup): the [stop conditions](#stop-conditions), Task 7's `gap12_digest.py mac` reporting a differing `PROFILE_END team_match` among them.
- **Gate set** (details in [Gate](#gate-stop-gate-no-merge)): Opus whole-branch (high); Gemini 4 Neon high through `agy-review.sh` (missing or failing: a second Opus high pass); `pr-review-toolkit:silent-failure-hunter` and `pr-review-toolkit:pr-test-analyzer` (Opus high); `ponytail:ponytail-review` (Sonnet high); the player-experience reviewer (Opus high); one Opus high fix round; stop at the advisory round, no merge.

## Model routing

| Work | Model | Effort |
|---|---|---|
| Tasks 1, 2, 3 (Python, test-first) | Sonnet | high |
| Task 4 (docs) | Sonnet | high |
| Task 5 (War Room round page) | Sonnet | high |
| Task 6 (gate benchmark run and its row) | Sonnet | low |
| Tasks 7, 8 (gap 12 scratch patches, runs, digest) | Sonnet | high |
| Per-task review (Tasks 1-5) | Opus | high |
| Per-task shadow (Tasks 1-5) | Gemini 4 Neon medium via `sh ~/projects/wargrid-overnight-work/night-14/agy-review.sh gemini-4-neon-medium …/logs/shadow-t<N>.md`, background, same diff and brief ([night run](../../night-run.md#coordinator-rules), "Reviews and task size"; recipe `agy-handoff.md`, private, "Review task"); results in the private shadow ledger | |
| Diagnosis, unblock, fix round | Opus | high |
| Gate reviews | see Gate | |

Tasks 6-8 produce measurement rows, not code; the gate reviewers read their rows.

## Riskiest contracts

1. The parser must read only the direct team match (`PROFILE team_match ` with a space), never `team_match.warmup` or `team_match_pump` (Task 1, PR1).
2. The trend rule: latest point against the median_low of the last three earlier same-method points (fewer: those there are, owner answer 5); inside `NOISE_PCT` reads "same"; trend text carries no colour and no percent of a limit (Task 2, TR1-TR6).
3. Honesty of the block: the checked table counts only checked rows, the tracked table says its rows are over their limit, and the ledger keeps every verdict, goal rows included (Task 3, RB1-RB4).
4. No limit changes: pinned by a test (Task 2, TR8).
5. Gap 12 arms differ only in `Profiler.enabled`; the match outcome must be identical in every run (Task 7).

## Interfaces

- `run_profile.gd` `_team_match()` prints, through `Profiler.report("team_match")` (`game/scripts/debug/profiler.gd:69`), one line per zone: `PROFILE team_match zone=<zone> mean_ms=<m> share=<s>% p50=<x> p95=<y> max=<z> calls_per_tick=<c>`. Zone `step` is the simulation step alone (`simulation.gd:671`); zone `team.tick` wraps `TeamMatch.step` (bots then `sim.step`, `run_profile.gd:144-146`). The profile pass prints no p99. `run_benchmark.sh` already concatenates `profile.log` into the log it passes to `perf_record.py` (`tools/run_benchmark.sh:39-42`), so no shell change is needed.
- New CSV rows (scenario `team_match:profile`, method inherited as today): metric `step` (p95 and mean from zone `step`) and metric `team_tick` (p95 and mean from zone `team.tick`). The existing `plumbing` row for `team_match:profile` stays as it is.

---

## Task 1: Record the 3v3 profile rows

```text
Task: perf_record.py records metric step and metric team_tick (p95_ms and mean_ms) for scenario team_match:profile from the PROFILE team_match lines.
Owns: tools/perf_record.py, tools/test_perf_charts.py (PerfRecordTest only)
Invariant: every existing sample, marker check and refusal unchanged; HANDOFF_PROFILE_LOG still yields exactly {("plumbing", "movement_open:profile")}.
Boundary: team_match.warmup and team_match_pump lines are ignored; a log with team rows but no "PROFILE COMPLETE 11" is refused.
Red: PR1 test_team_match_profile_records_sim_rows fails on assertIn(("step", "team_match:profile"), s).
Green: PR1-PR3 plus sh tools/run_python_checks.sh.
Stop: none expected.
```

- [ ] **Step 0: Venv.** `sh tools/ensure_venv.sh > …/logs/t1-venv.log 2>&1; echo "exit=$?"` → 0 (the new worktree has none); non-zero is `BLOCKED`.
- [ ] **Step 1: Red.** In `tools/test_perf_charts.py` add a module constant `TEAM_PROFILE_LOG` and three `PerfRecordTest` cases:

  ```python
  TEAM_PROFILE_LOG = """\
  PROFILE team_match.warmup zone=step mean_ms=9.0000 share=100.0% p50=9.0000 p95=9.0000 max=9.000 calls_per_tick=1.00
  PROFILE team_match.warmup zone=team.tick mean_ms=9.5000 share=105.0% p50=9.5000 p95=9.5000 max=9.500 calls_per_tick=1.00
  PROFILE team_match zone=team.tick mean_ms=1.5400 share=114.6% p50=1.3000 p95=2.8610 max=12.000 calls_per_tick=1.00
  PROFILE team_match zone=step mean_ms=1.3440 share=100.0% p50=1.2000 p95=2.1760 max=11.000 calls_per_tick=1.00
  PROFILE team_match zone=view_state mean_ms=0.4000 share=29.8% p50=0.4000 p95=0.5000 max=1.000 calls_per_tick=1.00
  PROFILE team_match zone=view.sort mean_ms=0.0500 share=3.7% p50=0.0500 p95=0.0600 max=0.100 calls_per_tick=1.00
  PROFILE team_match zone=view.batch mean_ms=0.6700 share=49.9% p50=0.6700 p95=0.8000 max=1.500 calls_per_tick=1.00
  PROFILE team_match_pump zone=step mean_ms=7.0000 share=100.0% p50=7.0000 p95=7.0000 max=7.000 calls_per_tick=1.00
  PROFILE team_match_pump zone=team.tick mean_ms=7.5000 share=107.0% p50=7.5000 p95=7.5000 max=7.500 calls_per_tick=1.00
  PROFILE COMPLETE 11
  """
  ```

  - PR1 `test_team_match_profile_records_sim_rows`: `s = {(x.metric, x.scenario): x for x in perf_record.parse_log(TEAM_PROFILE_LOG)}`; `assertIn(("step", "team_match:profile"), s)` first, then `s["step", ...].p95_ms == 2.176`, `.mean_ms == 1.344`, `.p99_ms is None`; `s["team_tick", "team_match:profile"].p95_ms == 2.861`, `.mean_ms == 1.54`; `("step", "team_match_pump:profile")` and `("team_tick", "team_match_pump:profile")` not in `s`; plumbing `team_match:profile` mean equals `0.4 + 0.05 + 0.67` (unchanged behaviour).
  - PR2 `test_team_rows_need_the_profile_marker`: the log without its last line raises `ValueError` matching `missing marker: PROFILE COMPLETE 11`.
  - PR3 `test_team_rows_written_with_p95_and_mean`: `self.record(self.write_log("t.log", TEAM_PROFILE_LOG), "--method", "P1")` returns 0; `rows` = the CSV rows with metric `team_tick`; `assertEqual(len(rows), 1)` first, then `rows[0]` has `p95_ms == "2.861"`, `mean_ms == "1.54"`, `p99_ms == ""`, scenario `team_match:profile`.
- [ ] **Step 2:** `tools/.venv/bin/python3 tools/test_perf_charts.py > ~/projects/wargrid-overnight-work/night-14/logs/t1-red.log 2>&1; echo "exit=$?"` → non-zero; PR1 and PR3 fail on the missing key or row (PR2 may already pass through the plumbing rows; record which).
- [ ] **Step 3: Green.** In `tools/perf_record.py`, beside `HANDOFF`:

  ```python
  # Direct team match only: the trailing space skips team_match.warmup and team_match_pump.
  TEAM = re.compile(r"^PROFILE team_match zone=(step|team\.tick) mean_ms=([\d.]+) .*? p95=([\d.]+)", re.M)
  TEAM_METRICS = {"step": "step", "team.tick": "team_tick"}
  ```

  and a `_team_samples(text) -> list[Sample]` returning `Sample(TEAM_METRICS[zone], "team_match:profile", float(p95), None, float(mean))` per match. In `parse_log`, after `handoff = _headless_handoff(text)`, add the team samples to `samples` and `found.add("profile")` when there are any (so the marker check covers them).
- [ ] **Step 4:** same test command → exit 0; then `sh tools/run_python_checks.sh > ~/projects/wargrid-overnight-work/night-14/logs/t1-py.log 2>&1; echo "exit=$?"` → exit 0, `PYTHON TESTS PASSED`.

## Task 2: The trend rule and the goal lines

```text
Task: perf_chart.py gets three goal lines in LINES (ledger verdicts), a TRENDS tuple of single-scenario lines, and trend_text(rows, line) giving "<n>% slower|faster since <date>, <stat> <ms> ms", "same as <date>, …" or "first run, …".
Owns: tools/perf_chart.py, tools/test_perf_charts.py (PerfChartTest only)
Invariant: status_table, summary_lines and the ledger block keep their wording; every Budget and NOISE_PCT value unchanged; existing tests unchanged.
Boundary: fewer than three earlier same-method points; no earlier point; earlier points of another method only; zero baseline; busy latest point; a line without a NOISE_PCT entry.
Red: TR1 test_trend_against_median_of_last_three fails (no trend_text).
Green: TR1-TR8 plus sh tools/run_python_checks.sh.
Stop: any need to change a Budget, NOISE_PCT, BUSY_LOAD or CLOSE_PCT value.
```

- [ ] **Step 1: Red.** Add to `PerfChartTest` (helper `pl(label, mean, **kw)` = `row(label=label, metric="plumbing", scenario="combat_hordes300:profile", mean_ms=mean, **kw)`; `line = next(t for t in perf_chart.TRENDS if t.name == "Background upkeep, huge crowds (stress)")`):
  - TR1 `test_trend_against_median_of_last_three`: labels a-d on dates 11-01..11-04 with means 1.0, 1.2, 1.1 (b, c, d) after a = 5.0, then e (11-05) 1.21 → `"10% slower since 2026-11-04, mean 1.21 ms"` (median_low of b, c, d is d at 1.1; a is outside the last three).
  - TR2 `test_trend_skips_other_methods`: b (11-02) 1.0, c (11-03) 9.0 with `method="pre-P1"`, d (11-04) 1.1, e (11-05) 1.21 → `"21% slower since 2026-11-02, mean 1.21 ms"` (c ignored; with two earlier points median_low takes b).
  - TR3 `test_trend_inside_noise_reads_same`: line "Combat, huge battles (stress)" over `combat_tick`/`hordes300` p95 rows: three points at 2.90 on 11-01, 11-02, 11-03, latest 3.90 (+34 %, inside 40.7) → `"same as 2026-11-02, p95 3.90 ms"`; latest 4.21 (+45 %) → `"45% slower since 2026-11-02, p95 4.21 ms"`.
  - TR4 `test_trend_without_noise_rounds_to_same`: plumbing 1.0 → 1.004 → starts with `"same as "`; 1.0 → 0.98 → `"2% faster since "`.
  - TR5 `test_trend_first_runs`: one point → `"first run, mean 1.00 ms"`; earlier points only of method `pre-P1` → `"first run of method P1, mean 1.00 ms"`; no point → `trend_text` returns `None`.
  - TR6 `test_trend_text_has_no_colour_or_limit`: for every TR1-TR5 result, `text.isascii()` and `"budget" not in text`; a latest point with `load="3.1"` ends with `" (busy host)"`.
  - TR7 `test_goal_lines_judged_against_their_limits`: `team_tick`/`team_match:profile` p95 `2.861` → `assertTrue(any(s.startswith("3v3 bots + sim p95: 157% of budget") for s in perf_chart.summary_lines(rows)))`; the bots + sim line's budget is `perf_chart.SIM_P95` (D5 (a), 1.82 ms); the upkeep goal line's budget is `PLUMBING`.
  - TR8 `test_limits_unchanged`: `SIM_P95 == Budget(10.0, 1.82, "p95")`, `SIM_P99 == Budget(20.0, 3.64, "p99")`, `PLUMBING == Budget(5.0, 0.91, "mean")`, `FRAME == Budget(16.7, 3.04, "p95")`, `LOCKSTEP == Budget(3.3, 0.6, "p99")`, `NOISE_PCT` equals today's five entries (50.3, 50.3, 57.5, 57.5, 40.7), `BUSY_LOAD == 2.5`, `CLOSE_PCT == 85`.
- [ ] **Step 2:** `tools/.venv/bin/python3 tools/test_perf_charts.py > …/logs/t2-red.log 2>&1; echo "exit=$?"` → TR1-TR7 fail on the missing names; TR8 passes (it is a guard; record that).
- [ ] **Step 3: Green.** In `tools/perf_chart.py`:

  ```python
  GOAL = (
      Line("3v3 upkeep", ("plumbing",), PLUMBING, ("team_match:profile",), "3v3 match, background upkeep (headroom)"),
      Line("3v3 sim p95", ("step",), SIM_P95, ("team_match:profile",), "3v3 match, simulation (headroom)"),
      Line("3v3 bots + sim p95", ("team_tick",), SIM_P95, ("team_match:profile",), "3v3 match, bots and simulation (headroom)"),
  )
  ```

  appended to `LINES` (`LINES = (…today's ten…, *GOAL)`), and after `NOISE_PCT`:

  ```python
  # A trend line keeps its source line's title, so its NOISE_PCT entry applies unchanged.
  TRENDS = (
      Line("plumbing, horde", ("plumbing",), PLUMBING, ("combat_hordes300:profile",), "Background upkeep, huge crowds (stress)"),
      Line("combat stress p95", ("combat_tick",), SIM_P95, ("hordes300",), "Combat, huge battles (stress)"),
      Line("plumbing, movement layouts", ("plumbing",), PLUMBING, ("movement_dense:profile",), "Background upkeep, armies on the move (stress)"),
      Line("combat stress p95", ("combat_tick",), SIM_P95, ("open",), "Combat, big armies in the open (stress)"),
      Line("combat stress p95", ("combat_tick",), SIM_P95, ("dense",), "Combat, big armies packed close (stress)"),
      *GOAL,
  )
  ```

  `trend_text(rows, line) -> str | None`: `points = series(rows, line)`; none → `None`. `latest = points[-1]`; `value = f"{line.budget.stat} {latest.worst_pct * line.budget.dev_ms / 100:.2f} ms"`. `earlier = [p for p in points[:-1] if p.method == latest.method][-3:]`. No `points[:-1]` → `f"first run, {value}"`; points but no `earlier` → `f"first run of method {latest.method}, {value}"`. Else `base = sorted(earlier, key=lambda p: p.worst_pct)[(len(earlier) - 1) // 2]` (median_low, so the date is a real run's); `base.worst_pct == 0` → first run; `pct = (latest.worst_pct / base.worst_pct - 1) * 100`; `noise = NOISE_PCT.get(line.title)`; same when `abs(pct) <= noise`, or with no entry when `f"{abs(pct):.0f}" == "0"`; text `f"same as {base.date}, {value}"` or `f"{abs(pct):.0f}% {'slower' if pct > 0 else 'faster'} since {base.date}, {value}"`; append `" (busy host)"` when `latest.busy`.
- [ ] **Step 4:** test file → exit 0; `sh tools/run_python_checks.sh` → `PYTHON TESTS PASSED`.

## Task 3: The README block

```text
Task: the README block becomes a checked table (LINES minus the trend titles, plus the Deck row) and a tracked table (TRENDS with trend_text); the ledger block stays status_table + Details over all LINES.
Owns: tools/perf_chart.py, tools/test_perf_charts.py (PerfChartTest only), README.md and docs/reference/performance.md generated blocks (by tools/.venv/bin/python3 tools/perf_chart.py only)
Invariant: status_table(rows) output is unchanged for the same lines; the README block still starts "Performance against the low-end budget (generated):" and ends "Details: [performance ledger](docs/reference/performance.md)."
Boundary: a trend line with no data is left out; a checked table with nothing over; the Deck row always last in the checked table.
Red: RB1 test_readme_checked_rows_are_the_seven fails (no PASS_FAIL).
Green: RB1-RB4, the existing main/idempotence tests, sh tools/run_python_checks.sh, python3 tools/roadmap.py --check.
Stop: none expected.
```

- [ ] **Step 1: Red.** Add:
  - RB1 `test_readme_checked_rows_are_the_seven`: `[l.name for l in perf_chart.PASS_FAIL]` equals `["Unit movement", "Unit movement, slowest moments", "Combat, normal fights", "Combat, normal fights, slowest moments", "Drawing the screen", "Drawing the screen, big map (Ashfall)", "Online play overhead"]`.
  - RB2 `test_readme_block_layout`: rows `mv("a", "2.73")` (red movement p95), `row(label="a", metric="combat_tick", scenario="hordes300", p95_ms="2.9")` and `row(label="a", metric="plumbing", scenario="combat_hordes300:profile", mean_ms="1.93")`; `block = perf_chart._readme_block(rows)`; lines in order: `"Performance against the low-end budget (generated):"`, `"**Checked against the limit: 1 of 1 areas over budget**"`, the checked header `"| Area | Status | Budget used | vs last run | As of |"`, `perf_chart.DECK_ROW`, `perf_chart.CAPTION`, `"**Tracked, no route under the limit yet**"`, `perf_chart.TREND_INTRO`, `"| Area | Change on this Mac | As of |"`, then the two tracked rows in `TRENDS` order, then the Details line. No line after the tracked header contains `"█"`, `"\U0001f534"` or `"% of"`.
  - RB3 `test_readme_headline_when_nothing_checked_is_over`: `mv("a", "1.0")` → `"**Checked against the limit: nothing over budget**"`.
  - RB4 `test_ledger_keeps_every_verdict`: the ledger block (`perf_chart._ledger_block(rows)`) for RB2's rows still has `"| **Combat, huge battles** | \U0001f534 Over |"` and a `"combat stress p95: "` Details line; for an added `row(label="a", metric="team_tick", scenario="team_match:profile", p95_ms="2.861")` it has `"| **3v3 match, bots and simulation (headroom)** | \U0001f534 Over |"`.
- [ ] **Step 2:** Red run → RB1-RB4 fail on the missing names or text.
- [ ] **Step 3: Green.** In `tools/perf_chart.py`:
  - `areas(rows, lines=LINES)`; split `status_table`'s table rows into `_table_rows(entries) -> list[str]` (header, divider, one row per entry, same text as today) so `status_table(rows)` returns exactly what it returns today.
  - `PASS_FAIL = tuple(x for x in LINES if x.title not in {t.title for t in TRENDS})`.
  - Constants, worded exactly (the War Room round shows them as the built options):

    ```python
    DECK_ROW = "| Smooth on a Steam Deck in Firefox, 3v3 match | Not measured yet | | | |"
    TREND_HEAD = "**Tracked, no route under the limit yet**"
    TREND_INTRO = (
        "These areas are over their limit and no known change brings them under it yet, so they show only how they move: "
        "the last run against the median of the three runs before it, with a change inside the run-to-run spread shown as same. "
        "Stress = far more units than a real match; headroom = a real 3v3 match on this Mac. Every limit is in the ledger."
    )
    ```

  - `_readme_block(rows)`: `entries = areas(rows, PASS_FAIL)` sorted as `status_table` sorts; head `**Checked against the limit: nothing over budget**` or `**Checked against the limit: {over} of {len(entries)} areas over budget**`; `_table_rows(entries)` plus `DECK_ROW`; blank line; `CAPTION`; blank; `TREND_HEAD`; blank; `TREND_INTRO`; blank; `| Area | Change on this Mac | As of |`, `| --- | --- | --- |`, one `| {line.name} | {text} | {latest.date} |` per `TRENDS` line whose `trend_text` is not `None` (`latest` = `series(rows, line)[-1]`); blank; the Details line as today.
- [ ] **Step 4:** tests → exit 0; `sh tools/run_python_checks.sh` → `PYTHON TESTS PASSED`.
- [ ] **Step 5: Regenerate.** `tools/.venv/bin/python3 tools/perf_chart.py; echo "exit=$?"` → 0. `git diff --stat` touches only `README.md` and `docs/reference/performance.md`, and `git diff README.md` only between the `perf-table` markers. Expected: checked table of seven rows, all OK today, plus the Deck row; tracked table of six rows (the two 3v3 simulation rows have no data until Task 6); ledger table now 11 rows (upkeep goal line included, from the existing `team_match:profile` plumbing rows). `python3 tools/roadmap.py --check; echo "exit=$?"` → 0. `sh tools/check_public.sh` → `PUBLIC CHECK PASSED`.

## Task 4: Docs

Sonnet high. Mechanism only; numbers come in Tasks 6-8.

- [ ] `docs/reference/performance.md` (outside the generated block): one paragraph **README speed block (night 14, D1, user 2026-11-20)** after "**`TEAM TIMING` is profiled.**": which rows stay checked (the seven of `PASS_FAIL`) and why (a known route to green: they pass), the eight tracked rows (`TRENDS`) and their fixed scenarios, the trend rule (latest worst run against the median_low of the last three earlier same-method runs, or of those there are, `NOISE_PCT` as today, so stress combat rows read any change under 41 % as same; plumbing and goal rows have no entry and read same only when the change rounds to 0 %), the goal rows (`team_match:profile`: plumbing, metric `step` sim-only p95 and metric `team_tick` bots + sim p95, both judged against 1.82 ms, D5 (a); the profile pass prints no p99; profiled, gap 12), the Deck real-scene row "not measured yet" until the worker ships (D3, D4 at the SB6 plan), and that every limit and verdict stays in this ledger's table. Restate the known gap accurately: none of the README's checked rows fails today and the goal rows are tracked, so no README row stands for the goal before SB6. In the "Rule per milestone" paragraph (`perf_record.py` sentence) add that the profile pass also records `step` and `team_tick` for `team_match:profile`.
- [ ] Guide [chapter 12](../../guide/12-performance-and-platforms.md): in "One benchmark run, from command to ledger row", a step 6 after step 5: the record step appends CSV rows and `perf_chart.py` writes two places, the ledger's verdict table for every line and the README's checked and tracked tables (payoff first: why a tracked row shows no colour). Add `tools/perf_chart.py` to "Where in the code". Footer: add "the README speed block passage against the `honest-speed-report` working tree over `<Task 3 commit>` (2026-11-21, not merged)" and `tools/perf_chart.py` to Files.
- [ ] Guide [chapter 13](../../guide/13-testing-and-tooling.md): in the **Performance** bullet one sentence that `tools/test_perf_charts.py` also pins the trend rule, the README layout, the team-match parser and the limit values (TR8). Footer: the same branch note.
- [ ] `docs/STATUS.md` row "night 14": `Built 2026-11-21 on branch honest-speed-report (not merged); owner check: advisory War Room round n14-speed-report; gap 12 rows in the ledger` (Task 8 parked: say so in the gate step).
- [ ] `python3 tools/roadmap.py --check`, `sh tools/check_public.sh`, and a link check of every link the task added (`rg -o '\]\([^)]+\)'` on the changed lines, each target exists).

## Task 5: War Room round page

Sonnet high. The round skeleton is already in `warroom/rounds/n14-speed-report/` (not yet listed in `index.yaml`, so it is not served).

```text
Task: the advisory round n14-speed-report shows the README speed block on main (Today) against the branch's block, plus five wording steps.
Owns: docs/images/speed-report/readme-blocks.html (new), warroom/rounds/index.yaml, warroom/rounds/n14-speed-report/*.yaml, warroom/internal/rounds/rounds_test.go (shipped round count 3 -> 4), ~/projects/wargrid-overnight-work/night-14/round/blocks_page.py (scratch, not tracked)
Invariant: existing rounds unchanged; the built options' texts equal Task 3's constants and trend wording.
Boundary: the page must render both states at the round's frame size without cutting the tracked table.
Red: TestShippedRoundsLoadClean fails with "index 4, rounds 4, want 3 and 3" after the index entry is added.
Green: go test ./internal/rounds/ ./internal/web/; go run . open lists the round as advisory with no "warning: n14-speed-report/" line; sh warroom/tools/quality.sh.
Stop: none expected.
```

- [ ] **Step 1:** Write `blocks_page.py` (stdlib only, outside the repository): reads the README block between `<!-- perf-table:begin -->` and `<!-- perf-table:end -->` from `git -C ~/projects/wargrid-wt-speed show main:README.md` (old) and the worktree's `README.md` (new); converts paragraphs, `**bold**`, `[text](url)` and pipe tables to HTML; asserts each state has its tables with as many `<tr>` as markdown table rows; writes one page with `<section id="old">` and `<section id="new">`, a script that shows the section named by `shot` in `location.hash`, GitHub-like table styling on a dark background, system fonts, emoji kept, and a first-line comment `<!-- Frozen copies of the README speed block on main and on honest-speed-report, for the War Room round n14-speed-report. -->`. No absolute paths in the output.
- [ ] **Step 2:** `python3 -I ~/projects/wargrid-overnight-work/night-14/round/blocks_page.py docs/images/speed-report/readme-blocks.html; echo "exit=$?"` → 0 (`-I`: stdlib only, nothing imported from the script's folder).
- [ ] **Step 3:** One offscreen check per state (no visible window; UI-round exception, user 2026-11-14): `/Applications/Firefox.app/Contents/MacOS/firefox --headless --window-size=1280,1000 --screenshot ~/projects/wargrid-overnight-work/night-14/round/<state>.png "file://<abs path>/docs/images/speed-report/readme-blocks.html#shot=<state>"`. If the new state is taller than 1000 px, raise `h` in `round.yaml` to fit (the stage scales to fit). Firefox missing or failing: record it, skip the check.
- [ ] **Step 4: Red/Green.** Add `- {id: n14-speed-report, title: 'Night 14 Honest speed report: the README speed block'}` to `warroom/rounds/index.yaml`; `cd ~/projects/wargrid-wt-speed/warroom && go test ./internal/rounds/` → fails on the count; change the count in `TestShippedRoundsLoadClean` to 4 and 4 → passes. `cd ~/projects/wargrid-wt-speed/warroom && go run . open` lists the round with "advisory: answer when you like" and prints no `warning: n14-speed-report/` line. Check every step's built option text against Task 3's constants and `trend_text`'s wording.
- [ ] **Step 5:** `sh warroom/tools/quality.sh > …/logs/t5-quality.log 2>&1; echo "exit=$?"` → 0. If a network step fails at night (`go tool govulncheck` or `npm ci`), record which step and that every step before it passed (the script runs `set -eu`, so the log ends at the failure); a `govulncheck` failure also skips `check_generated.sh`, which is fine: the task changes no `.templ`, island or schema source, so it has nothing to regenerate. `sh tools/check_public.sh` → passed.

## Task 6: Gate benchmark

Sonnet low. Decision-free: run, check, record.

- [ ] **Step 1:** `sh tools/run_checks.sh > …/logs/t6-checks.log 2>&1; echo "exit=$?"` and the full suite `sh tools/run_tests.sh > …/logs/t6-suite.log 2>&1; echo "exit=$?"` (both `timeout: 600000`; read the summary lines only). Both exit 0, else `BLOCKED`.
- [ ] **Step 2:** the busy-host wait (`wait-quiet.sh`, Global constraints), log `…/logs/wait-t6.log`. Record its end time and whether it was the 05:00 fallback (exit 3).
- [ ] **Step 3:** alone: `PERF_LABEL="night 14 honest speed report" sh tools/run_benchmark.sh > ~/projects/wargrid-overnight-work/night-14/logs/t6-bench.log 2>&1; echo "exit=$?"` (fallback label `night 14 honest speed report (host under load)`), in the background with the completion notice. No `game/` change against the merge base, so the pair step is skipped. The log starts and ends with `uptime`.
- [ ] **Step 4:** Checks: exit 0; `BUDGET EXCEEDED` names only `open dense hordes300` (as on `main`); no `PAIR GATE` failure line; a `recorded <n> rows` line and no `perf: WARNING`; `rg -c ',night 14 honest speed report[^,]*,dev,(step|team_tick),team_match:profile,' docs/reference/perf-history.csv` → 2; the README tracked table now has the two 3v3 simulation rows reading `first run, p95 <x> ms` (in the 05:00 fallback ending ` (busy host)`). A `CEILING ALARM` alone is not a stop.
- [ ] **Step 5:** ledger History row in `docs/reference/performance.md` (form of the 2026-11-20 rows): tree, label, `uptime` start and end, the gated rows, the three goal rows (team-match upkeep mean, sim-only p95, bots + sim p95 against 1.82), "host under load" if the fallback ran. Verification evidence row.
- [ ] **Step 6:** rerun `blocks_page.py` (Task 5 Step 2) so the round shows the final block. After `GREEN` the coordinator commits "Record the night 14 gate benchmark".

## Task 7: Gap 12, Mac half

Sonnet high. Evidence only; the measurements never change a limit.

`<g12>` below stands for `~/projects/wargrid-overnight-work/night-14/gap12`: type it out in every command.

- [ ] **Step 1:** Two copies of the branch tip: `sh ~/projects/wargrid-overnight-work/night-14/copy-tree.sh ~/projects/wargrid-wt-speed <g12>/on` and the same with `<g12>/off`; each prints `COPIED <sha>`.
- [ ] **Step 2:** Patch `game/benchmarks/run_profile.gd` `_team_match()` in both copies identically (Edit tool), except the flag and the label. Before (`:137-147`):

  ```gdscript
  	Profiler.reset()
  	Profiler.enabled = true
  	…
  		Profiler.end(&"team.tick", zone)
  		_frame(sim)
  ```

  After (`off` copy; the `on` copy keeps `Profiler.enabled = true` and prints `PROFILE_ON`):

  ```gdscript
  	Profiler.reset()
  	Profiler.enabled = false
  	var handoff_us: int = 0
  	var handoff_ticks: int = 0
  	…
  		Profiler.end(&"team.tick", zone)
  		var started: int = Time.get_ticks_usec()
  		_frame(sim)
  		if sim.tick() > WARMUP:
  			handoff_us += Time.get_ticks_usec() - started
  			handoff_ticks += 1
  ```

  and after the loop, before `_direct_ms`: `print("PROFILE_OFF team_match handoff_ms=%.4f ticks=%d" % [handoff_us / 1000.0 / maxi(handoff_ticks, 1), handoff_ticks])`. The window (`sim.tick() > WARMUP` after the step) matches the profiler's reset at `WARMUP`.
- [ ] **Step 3:** `godot --headless --path <g12>/<arm>/game --import > <g12>/import-<arm>.log 2>&1; echo "exit=$?"` for both, then the busy-host wait (`wait-quiet.sh`, log `…/logs/wait-t7.log`).
- [ ] **Step 4:** Interleaved `on off on off on off`, one at a time: `uptime >> <g12>/runs.txt; godot --headless --path <g12>/<arm>/game --script res://benchmarks/run_profile.gd > <g12>/<arm>-<i>.log 2>&1; echo "exit=$?"; uptime >> <g12>/runs.txt` (`timeout: 600000` each). Each run exits 0.
- [ ] **Step 5:** Digest: `python3 -I ~/projects/wargrid-overnight-work/night-14/gap12_digest.py mac <g12> ~/projects/wargrid-wt-speed > <g12>/digest.txt 2>&1; echo "exit=$?"` → 0 and `GAP12 DIGEST OK`. It checks each log for `PROFILE COMPLETE 11`, no `ERROR` line, one `PROFILE_ON`/`PROFILE_OFF` line, and the same `PROFILE_END team_match …` line in all six (`PROFILE_END team_match DIFFERS` is a stop: the profiler must not change the match); it prints medians of 3 and ranges for off (timed), on (timed), on (zone sum: plumbing `team_match:profile` through the worktree's `perf_record.parse_log`) and the overhead on - off in ms and %. Report those with Task 6's `team_match:profile` row beside them. Ledger History row (Mac half of gap 12, evidence; names the 0.91 ms plumbing limit unchanged) and verification evidence rows. After `GREEN` the coordinator commits "Record gap 12, Mac half".

## Task 8: Gap 12, Wasm half on the Steam Deck (last task)

Sonnet high. The Deck address is in `~/projects/wargrid-native-work/deck-address.txt`; type it into each command, never into a tracked file (tracked text says `deck@<address>`). The Deck takes headless and windowed runs at any time (user, 2026-11-20; [packages](../../packages.md#night-lane) item 6), so a Firefox window on its screen is fine. Night 4 pattern: ssh/scp, one `systemd-run --user` unit at a time, one Deck folder removed afterwards. `<deck>` below stands for `~/projects/wargrid-overnight-work/night-14/deck`; type it out. Every `ssh` is written `ssh -o BatchMode=yes -o ConnectTimeout=10 deck@<address> …` in full (one allow rule matches that form; macOS `ssh` takes no options after the host).

- [ ] **Step 1: Preflight.** `ssh -o BatchMode=yes -o ConnectTimeout=10 deck@<address> 'cat /sys/class/power_supply/ACAD/online; cut -d" " -f1-3 /proc/loadavg; systemctl --user show-environment | grep -E "^(DISPLAY|WAYLAND_DISPLAY)="; flatpak info org.mozilla.firefox | grep -i version'`. Unreachable, on battery, no display or no Firefox: `BLOCKED`, park this task only (morning item), the run goes to the gate.
- [ ] **Step 2: Exports on the Mac** (after Task 7, alone). `sh ~/projects/wargrid-overnight-work/night-14/copy-tree.sh ~/projects/wargrid-wt-speed <deck>/tree-on`, the same with `<deck>/tree-off`; in `tree-off` change only `game/benchmarks/bench_runner.gd` `_team` (`:67`) `Profiler.enabled = true` to `false` (Edit tool). Each: `godot --headless --path <deck>/tree-<arm>/game --import > <deck>/import-<arm>.log 2>&1; echo "exit=$?"`, then `sh <deck>/tree-<arm>/tools/export_build.sh "Web Bench" <deck>/exports/web-<arm>/index.html > <deck>/export-<arm>.log 2>&1; echo "exit=$?"` → 0 and `test -f <deck>/exports/web-<arm>/index.html`.
- [ ] **Step 3: Job script.** `<deck>/deck-job14.sh` was written at the preparation from `lowend-deck/deck/deck-job.sh`: `B=$HOME/wargrid-n14`, the server at `$B/tools/serve_web_bench.py`, pages `web-on-<i>` and `web-off-<i>` interleaved for i in 1 2 3, markers `DONE14` then (exit trap) `JOB14 END`. Do not change it; `shellcheck -s sh <deck>/deck-job14.sh` → exit 0.
- [ ] **Step 4: Copy and launch.** `ssh -o BatchMode=yes -o ConnectTimeout=10 deck@<address> mkdir -p wargrid-n14/web wargrid-n14/tools wargrid-n14/logs`; `scp -r <deck>/exports/web-on <deck>/exports/web-off deck@<address>:wargrid-n14/web/`; `scp ~/projects/wargrid-wt-speed/tools/serve_web_bench.py deck@<address>:wargrid-n14/tools/`; `scp <deck>/deck-job14.sh deck@<address>:wargrid-n14/`; `ssh -o BatchMode=yes -o ConnectTimeout=10 deck@<address> systemd-run --user --collect --same-dir --unit=wargrid-n14-job systemd-inhibit --what=sleep:idle --who=wargrid --why=benchmark sh wargrid-n14/deck-job14.sh`; `ssh -o BatchMode=yes -o ConnectTimeout=10 deck@<address> systemctl --user is-active wargrid-n14-job` → `active`.
- [ ] **Step 5: Wait.** `sh ~/projects/wargrid-overnight-work/night-14/deck-wait.sh <address> 150 > …/logs/deck-wait.log 2>&1; echo "exit=$?"` with `run_in_background` and the completion notice (six pages of about 11 min each; 150 min is the hard stop). Exit 0 goes on; 3, 4 or 5 parks Task 8 after Step 6's fetch (for the record) and Step 7.
- [ ] **Step 6: Fetch and digest.** `scp -r deck@<address>:wargrid-n14/logs <deck>/`; `python3 -I ~/projects/wargrid-overnight-work/night-14/gap12_digest.py deck <deck>/logs > <deck>/digest.txt 2>&1; echo "exit=$?"` → 0 and `GAP12 DIGEST OK`. It checks per page `BENCH DONE`, `cross_origin_isolated`, one `TEAM MATCH`, `TEAM TIMING` and `TEAM MEAN` line, and every page's `TEAM MATCH` line equal (`TEAM MATCH DIFFERS` or any exit 1 parks Task 8: the profiler must not change the match); it prints medians of 3 per arm for p50, p95, p99 and mean, with ranges and the difference. Beside it the earlier Deck Firefox team p95 15.16 [15.10-15.30] (different tree, context only). Ledger History row (Wasm half of gap 12, evidence; no limit change) and verification rows.
- [ ] **Step 7: Clean up.** `ssh -o BatchMode=yes -o ConnectTimeout=10 deck@<address> rm -rf wargrid-n14`; if denied, a morning item. After `GREEN` the coordinator commits "Record gap 12, Wasm half".

## Gate (stop gate; no merge)

1. `git status --short` clean; resume record current.
2. Reviews in parallel, each with the [gate review](../../milestone-prompt.md#gate-review) brief (changed contracts: the CSV metrics `step` and `team_tick`, the README block, `areas(rows, lines)`; previous rulings; evidence paths: verification file, ledger rows, this plan; name per new test the production change that makes it fail):
   - Opus whole-branch (high);
   - Gemini 4 Neon high: `git diff main...HEAD > …/logs/gate.diff`, the review prompt body of `agy-handoff.md` (private, "Review task") written to `…/logs/gate-agy.md` naming that diff, then `sh ~/projects/wargrid-overnight-work/night-14/agy-review.sh gemini-4-neon-high …/logs/gate-agy.md > …/logs/gate-agy.txt 2>&1; echo "exit=$?"` in the background; exit 1 or `AGY MISSING`: a second Opus high pass;
   - `pr-review-toolkit:silent-failure-hunter` and `pr-review-toolkit:pr-test-analyzer` (owner answer 6; the night-run rule for a test diff), each pinned to Opus high;
   - `ponytail:ponytail-review`, pinned to Sonnet high;
   - the player-experience reviewer ([agent](../../../.claude/agents/player-experience-reviewer.md), Opus high) on the README block (`README.md` between the `perf-table` markers, old against new) and the round YAML: the README text is player-facing.
3. One fix round (Opus high) for confirmed findings, test-first; the coordinator commits each fix as a new commit after its `GREEN`. A fix under `tools/perf_*.py` reruns the Python checks, `tools/.venv/bin/python3 tools/perf_chart.py` and `blocks_page.py` (`python3 -I`, Task 5 Step 2); a fix under `game/` or in `tools/run_benchmark.sh` reruns Task 6. Record rulings for the rest.
4. Update `docs/STATUS.md` night 14 with the final state (Task 8 parked or done), the resume record and the morning summary.
5. Stop at the advisory War Room round `n14-speed-report`: it never blocks a merge; the run does not merge, push or deploy War Room to fly.

## Stop conditions

[Milestone prompt stop conditions](../../milestone-prompt.md#stop-conditions), plus:

- any change to a limit, `NOISE_PCT`, `BUSY_LOAD`, `CLOSE_PCT`, F or the assumed slowdown, or a trend rule that seems to need one;
- Task 6: non-zero exit, `BUDGET EXCEEDED` naming a row other than `open`, `dense`, `hordes300`, or a `PAIR GATE FAILED`/`INCONCLUSIVE` line;
- Task 7: a match outcome that differs between arms or runs (`PROFILE_END team_match DIFFERS`);
- the resume record disagrees with the tree.

What parks instead of stopping: [Coordinator card](#coordinator-card).

## Owner items after the gate

- Answer the advisory round when convenient (a contradiction becomes a follow-up on the next package that touches the README block); deploying War Room to the fly test app for the phone needs approval.
- Merge (`git merge --squash`, tag `honest-speed-report-tip` first, AGENTS.md); after the merge, `python3 tools/perf_chart.py` on `main` (the CSV merges as a union of lines).
- If the 05:00 fallback ran: the evening rerun on a quiet host.
- Revisit the stress spread 40.7 % at the benchmark pair gate calibration (report section 2.2); unchanged here.

## Owner answers (user, 2026-11-21)

Each took the recommendation ([design answers, night 14 prep](../../reference/design-answers-2026-11-08.md#night-14-prep-user-2026-11-21)):

1. The seven rows that pass today keep their pass/fail colour (`PASS_FAIL`, Task 3).
2. `movement_dense:profile` is the one "armies on the move" row (`TRENDS`, Task 2).
3. Combat stress `open` and `dense` get a tracked row each (`TRENDS`).
4. Today's `NOISE_PCT` stays: stress combat rows read "same" under about 41 %, plumbing and goal rows only when the change rounds to 0 % (TR3, TR4, TR8); narrower spreads are a later calibration item (Owner items).
5. With fewer than three earlier runs a row compares with the median_low of those there are (TR2).
6. The gate adds `silent-failure-hunter` and `pr-test-analyzer` (Gate step 2).
7. Gap 12 adds a profiler-on arm with the same timing code, on the Mac and the Deck, three runs each (Tasks 7 and 8).
8. `combat_hordes300:profile` is the one "huge crowds" row (`TRENDS`, TR1).
