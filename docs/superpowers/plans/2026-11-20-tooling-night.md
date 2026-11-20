# Tooling night: hash rows, case times, definitions lint

Night run plan (prepared 2026-11-20; readiness review applied). Decisions: [design answers, Tooling night (user, 2026-11-20)](../../reference/design-answers-2026-11-08.md#tooling-night-user-2026-11-20). Findings closed or reworded: STATUS rows F15 and F19. Verification and resume record: [tooling night verification](../../reference/tooling-night-verification.md). Branch `tooling-night` in worktree `~/projects/wargrid-wt-tooling`, cut from `main` after this plan's commit.

No player change, no simulation behaviour change, no trace re-pin. Tests, tools, the offline recording path and docs only.

## Global constraints

- Typed GDScript; `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass after every GDScript task. New tests use only the [simulation interface](../../reference/sim-interface.md) plus static `definitions/` data; `python3 tools/test_sim_boundary.py` passes, and its pinned counts (`PUMP_COUNTS`, allowlists) are never raised to make it pass.
- Python: `sh tools/run_python_checks.sh` passes after every Python task. Shell: `sh tools/run_shell_checks.sh` after every shell task.
- Suite: `sh tools/run_tests.sh > <log> 2>&1; echo "exit=$?"`, read only the `CASES … CHECKS … FAILURES …` line and `FAIL:` lines. While iterating: `WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh`. Every suite, benchmark, lint and parity call passes `timeout: 600000`.
- Logs go to `~/projects/wargrid-overnight-work/tooling-night/logs/`. In commands, expand every `~/` path below to the absolute home path (the night allow rules match absolute paths, not `~`).
- Test first: each task's Red is a named assertion that fails for the named reason (a `has_method`, `get(key, null)` or stub-returning check), not a parse or script error.
- Never weaken an assertion. Adding a check for a new key is fine; removing or loosening a check is not.
- Determinism rules ([determinism rules](../../reference/determinism-rules.md)): the recording only reads state; it never feeds back into the simulation.
- Park a task with a dirty tree: `git stash push --include-untracked -m park-t<N>`, record the stash name in the ledger and the resume record. Never `git reset` or `git commit --amend` (ask rules, denied at night); a fix is a new commit.

## Model routing

| Work | Model | Effort |
|---|---|---|
| Tasks 1, 2, 3, 5 (implement) | Sonnet | high |
| Task 4 (investigate, evidence only) | Sonnet | medium |
| Task 6 (docs) | Sonnet | high |
| Per-task review (Tasks 1, 2, 3, 5) | Opus | high |
| Diagnosis, unblock, fix round | Opus | high |
| Gate (Task 7) | see Task 7 | |

## Riskiest contracts

1. Recording must not change any outcome: `end_digest`, pinned traces and replay oracles stay identical with recording on (Task 1, TH2).
2. Recording cost on the low-end target (Task 1, TH5; the benchmark never runs the offline driver, so TH5 is the only measurement).
3. The replay compare must report the first differing row, not only a final difference, and must still accept sessions without rows (Task 2).

## Task 1: Record the tick hash every 30 ticks offline

```text
Task: offline matches record "<tick>\t<16 hex>" rows of the live tick hash at every tick that is a multiple of 30; the session record carries them as `tick_hashes`.
Owns: game/scripts/simulation/simulation.gd (public tick_hash; the set_hash_ring comment), game/scripts/match/sim_pump.gd (Job.want_tick_hash, Note.tick_hash), game/scripts/match/offline_driver.gd (a local tick counter, collect rows in drain(), reset in adopt(), expose them in record()), game/scripts/match/match_screen.gd (_match_record merges tick_hashes), tests in game/tests/test_sim_pump.gd, test_lockstep.gd or the suite that already steps a bare sim (TH1, TH2, pump check), test_playtest_replay.gd (TH3, TH4 offline), test_playtest_overlay.gd (PO12, PO28), test_online_scene.gd (N-PT1), docs/reference/sim-interface.md (same change as the public method, including the set_hash_ring line).
Invariant: with recording on, end_digest, every pinned trace and every existing case outcome are unchanged; the ring stays off offline (set_hash_ring(false) untouched); online matches carry no tick_hashes key; offline_driver.gd keeps exactly its current number of pump accesses (PUMP_COUNTS in tools/test_sim_boundary.py stays 10).
Boundary: rows reset in adopt() (restart, RP5 test_restart_starts_new_record, PO12's two matches); rows are collected in drain(), so a record taken while the last hashed tick's job is posted but not drained may lack that row (the compare checks only rows present); a match shorter than 30 ticks records no rows (key present, empty); a failed simulation (record() fallback, sim_pump.gd:106-107) keeps the rows it already has.
Red: TH1-TH4 and the pump check fail as assertions before the change.
Green: TH1-TH4, the pump check, the full suite.
Stop: TH2 or the suite shows any outcome or trace change; TH5 p99 over 0.6 ms.
```

Design (approved, user 2026-11-20):

- `Simulation.tick_hash() -> String`: the current `_tick_hash()` formatted exactly as a `hash_ring()` row value (`"%08x%08x"` of the high and low halves, `simulation.gd` `hash_ring`), computed on demand, independent of `_ring_on`. Reuse the formatting; do not duplicate the hash walk.
- `SimPump.Job.want_tick_hash: bool`; `run_job` fills `Note.tick_hash` after the step when set (same place as `want_digest`/`want_ring`, `sim_pump.gd:158-161`); empty otherwise.
- Offline driver keeps a local `_next_tick`, set in `adopt()` from `first_note.tick` and +1 after each stepping `post`; it sets `want_tick_hash` when `_next_tick % 30 == 0` (the online driver keeps its own counter the same way, `online_driver.gd:133`). In `drain()` it appends `"%d\t%s" % [note.tick, note.tick_hash]` for every note with a non-empty `tick_hash`. `record()` returns the rows as `tick_hashes`. No new `pump.` access: the tick comes from the counter, the hash from notes the driver already drains.
- `match_screen.gd` `_match_record` (lines 192-194) adds `"tick_hashes"` from the record; the mid-match header (`playtest_header`) does not.
- Update the stale comment on `set_hash_ring` (`simulation.gd`, "nobody compares hashes") and `sim-interface.md:52` the same way: the ring stays off offline; offline rows are taken every 30 ticks through `tick_hash()`.

Tests (put each in the suite that already covers the path):

- TH1: `sim.tick_hash()` equals the hex part of `sim.hash_ring()[-1]` on a sim with the ring on, at three ticks. Red: `sim.has_method("tick_hash")` check fails first.
- TH2: two sims from the same seed, map and commands stepped 300 ticks, one calling `tick_hash()` every 30 ticks and one never: `StateHash.digest(snapshot())` equal at the end. RP4 (`test_playtest_replay.gd:100-127`: the recorded `end_digest` equals the live digest, and the oracle, which records nothing, replays to it) stays green with recording on. The full suite green (pins V1-V7 are suite checks).
- Pump check (`test_sim_pump.gd`): `Note.tick_hash` is empty unless `want_tick_hash` is set, and equals `sim.tick_hash()` after the step when set.
- TH3 (real offline record, beside RP4): a match played to at least tick 95 has `tick_hashes` rows at 30, 60, 90 exactly (ticks drained by then), each matching `^\d+\t[0-9a-f]{16}$`; a match recorded before tick 30 has an empty list. Red: `record.get("tick_hashes", null) != null` fails first.
- TH4: PO12 asserts each of its two matches carries its own rows (match 2's first row is tick 30 of match 2, not a leftover); PO28 (`test_playtest_overlay.gd:1034`) adds `not header.has("tick_hashes")`; N-PT1 (`test_online_scene.gd:1285-1294`, the online record) adds `not record.has("tick_hashes")`. PT9 (`test_playtest.gd:347`, a synthetic fixture) stays as it is.
- TH5 (measurement, not a test): scratch script `~/projects/wargrid-overnight-work/tooling-night/th5.gd` (extends SceneTree, `quit()` on every path), run with `godot --headless --path ~/projects/wargrid-wt-tooling/game --script ~/projects/wargrid-overnight-work/tooling-night/th5.gd`. It builds `CombatWorkload.create("hordes300")` (`game/scripts/debug/combat_workload.gd`), steps 300 warm-up ticks, then times 200 `tick_hash()` calls (one per step) with `Time.get_ticks_usec`, and prints mean and p99 µs. Cross-check: the performance ledger's Sim quick wins row has about 73 µs per `_tick_hash` on hordes300. Limit (user decision to park on a budget miss, 2026-11-20; the limit is the ledger's Lockstep overhead p99 dev budget, 0.6 ms, i.e. 3.3 ms at F = 5.5): p99 over 0.6 ms parks the task. Record mean, p99, mean/30 (amortised per tick) and `uptime` load in the verification file.

## Task 2: Replay names the first differing row

```text
Task: replay_session.sh compares the recorded tick_hashes with the oracle's per-tick ring rows and reports the first differing tick and the last equal one; sessions without tick_hashes keep today's end_digest check.
Owns: tools/playtest_session.py (--replay-args writes the .hashes file; --compare-hashes), tools/replay_session.sh, tools/test_playtest_session.py, game/tests/test_playtest_replay.gd (RH5), tools/compare_replays.py only if reusing first_divergence needs no caller change.
Invariant: for sessions without rows, today's lines and exit codes are unchanged (REPLAY MATCHED / REPLAY DIFFERS / REPLAY FAILED, replay_session.sh, guide chapter 13); the oracle's existing flags keep their output.
Boundary: recorded rows beyond the replay's last tick; a malformed recorded row; the first recorded row differs; rows equal but end_digest differs (the ring does not cover status, combat timers, paths or containers; guide chapter 10); a stale .hashes file from an earlier --replay-args run for a match that now has no rows.
Red: RH1-RH4 and RH6 fail as assertions before the change.
Green: RH1-RH6, tools/run_python_checks.sh, tools/run_shell_checks.sh, the full suite.
Stop: on a clean replay (same build) the oracle's ring rows and the recorded rows disagree — recording and replay hash different state: diagnose, never loosen.
```

Design:

- `--replay-args` writes `<stem>-m<k>.hashes` (beside `<stem>-m<k>.cmd`, the same stem rule) with one recorded row per line when the match has `tick_hashes` (even empty), and deletes a stale `<stem>-m<k>.hashes` when it has none.
- `replay_session.sh`: when `${cmd%.cmd}.hashes` exists, add `--ring-log <tmp>` (a second `mktemp`, removed by the existing trap) to the oracle call. The oracle writes per-tick rows `"<tick>\t<16 hex>"` from tick 1 (`headless_client.gd:264`). Then run `python3 tools/playtest_session.py --compare-hashes <hashes> <ring>`.
- `--compare-hashes RECORDED RING`: walks recorded rows in order, looks up each tick in the ring rows. Exit 0 and no output when all equal; exit 1 with one line on the first problem: `first differing row at tick <T>, last equal row at tick <T-30>`; `first recorded row differs: start state or hash function changed` (when the first row differs); `replay ended before tick <T>`. Exit 2 with `malformed hash row <n>` for a bad recorded or ring row.
- Output of `replay_session.sh` per match with rows: compare exit 1 → `REPLAY DIFFERS <k> <compare line> (recorded on build <build>)`, status 1, end_digest line skipped; compare exit 2 → `REPLAY FAILED <k>: <compare line>`, status 1; compare exit 0 → today's end_digest check, and if the digest differs, today's REPLAY DIFFERS line followed by `hash rows all equal; difference is in unhashed state`.
- Reuse `compare_replays.first_divergence` if it fits without changing its callers; otherwise a small function in `playtest_session.py`.

Tests:

- RH1 (Python): equal rows → exit 0, no output.
- RH2 (Python): rows differing from tick 90 → exit 1, `first differing row at tick 90, last equal row at tick 60`.
- RH3 (Python): malformed recorded row → exit 2 naming the row; first row differs → the start-state line; recorded tick beyond the ring → the ended-early line.
- RH4 (Python): a session without `tick_hashes` gives the same `--replay-args` row as today (`test_playtest_session.py:47-60` fixture) and no `.hashes` file; a stale `.hashes` file is deleted.
- RH5 (GDScript, beside RP4): record an offline match, replay it with the oracle and `--ring-log`: every recorded row is in the ring rows. Then replay RP4's mutated log (a dropped command line) with `--ring-log` too, take the first per-tick ring row T where the two ring logs differ, and assert the compare reports `ceil(T/30)*30` as the first differing row with the row before it equal.
- RH6 (shell path, the fake client harness in `test_playtest_session.py:160-178`, `_replay`, `WARGRID_CLIENT`): the fake client writes ring rows to its `--ring-log` argument; equal rows → `REPLAY MATCHED 1`, exit 0; one changed row → `first differing row at tick 60`, exit 1; equal rows with a differing end digest → the `hash rows all equal` line.

## Task 3: Measured case times

```text
Task: the runner can print each case's seconds and checks; a tool regenerates CASE_SECONDS from that output.
Owns: game/tests/run_tests.gd (CASE_STAT lines behind WARGRID_CASE_STATS=1, and the regenerated CASE_SECONDS line), tools/case_times.py (new), tools/test_case_times.py (new), docs/guide/13-testing-and-tooling.md (usage line).
Invariant: without WARGRID_CASE_STATS no CASE_STAT line is printed; sharding (shard(), run_tests.gd:24) and the watchdog unchanged.
Boundary: a failing case still gets its CASE_STAT line; shard runs print only their cases; a table key that no longer names a case is dropped by the regeneration; a log from a WARGRID_TEST_ONLY run is refused for --write.
Red: CT1-CT3 fail as assertions before the change.
Green: CT1-CT3, the two log counts below, run_python_checks.sh, lint, warnings, full suite.
Stop: none expected.
```

- Output line, one per case after it completes (pass or fail): `CASE_STAT <method> <seconds, one decimal> <checks added by the case>` (checks = `checks - before`; `before` is at `run_tests.gd:100`).
- `tools/case_times.py LOG [LOG...]`: reads CASE_STAT lines (logs of one run's shards are merged), keeps cases at or above 1.0 s, sorted by seconds descending, prints the `const CASE_SECONDS := {...}` line. `--write TARGET` replaces the one `const CASE_SECONDS :=` line in TARGET (normally `game/tests/run_tests.gd`) and exits 2 unless exactly one such line exists (asserted replacement, AGENTS.md). `--write` exits 2 when the log's CASE_STAT count differs from its `CASES` total or the log has no `CASES` line (a partial or `WARGRID_TEST_ONLY` run).
- CT1: two logs merged, threshold applied, order descending. CT2: `--write` on a temp copy with zero or two matching lines exits 2 and leaves the file unchanged; a partial log exits 2. CT3: a malformed CASE_STAT line is an error naming the line.
- Log counts: a plain run's log has 0 CASE_STAT lines; a stats run's log has as many as its CASES total (`rg -c '^CASE_STAT' <log>`; report the number as printed).
- Then one full run with `WARGRID_CASE_STATS=1` on a quiet host (`uptime` load below 2.5), `python3 tools/case_times.py <log> --write game/tests/run_tests.gd`, and the suite again. Record both totals in the verification file.

## Task 4: Check-count drift (evidence only)

```text
Task: explain why CHECKS varied between 144200 and 144212 across night runs (~/projects/wargrid-overnight-work/tighter-gates/ledger.md line 21: "probably the trace-env runs").
Owns: the verification file only (and the STATUS F19 wording in Task 6).
Invariant: no code change; the CASE_SECONDS table stays as Task 3 left it across all three runs.
Stop: a case whose check count changes between two identical runs with no environment change is a finding to record, not to fix tonight.
```

Needs Task 3. Run the full suite with `WARGRID_CASE_STATS=1` three times: twice plain, once with `WARGRID_REPLAY_TRACE`, `WARGRID_ECONOMY_REPLAY_TRACE`, `WARGRID_COMBAT_REPLAY_TRACE` and `WARGRID_TEAM_REPLAY_TRACE` set to files under the logs folder (as `tools/compare_local_traces.sh` sets them; put `WARGRID_CASE_STATS=1` first on the command line). Diff the per-case check counts with a short script run as `python3 -I ~/projects/wargrid-overnight-work/tooling-night/<name>.py`. Record which cases differ, by how many, and why (read only those cases). Suite counts have grown since (1239 cases at 0.14.0), so compare runs of this tree only.

## Task 5: Definitions lint

```text
Task: one test fails when a kind has a key nobody reads or a reference that does not resolve.
Owns: game/tests/test_definitions_lint.gd (new), game/tests/run_tests.gd (SUITES entry), docs/guide/03-entities.md only if its key table (around line 187) lacks vision's second use.
Invariant: no data or production change; the whitelist is today's key set, so the lint passes on main.
Boundary: test kinds added with Registry.add_test_kind are linted the same way and cleared after; an empty string means none for weapon and prerequisite.
Red: DL1 and DL2 fail as assertions against a stub lint that returns no errors.
Green: DL1-DL3, lint, warnings, the full suite.
Stop: the lint finds a real unknown key or dangling reference in today's data: record it in the verification file and park this task (a data fix may change behaviour).
```

Source: OpenRA review (private), finding 5. Kinds are dictionaries in `game/scripts/simulation/definitions/usa.gd`, `china.gd`, `frc.gd`, `shared.gd`, read through `definitions.gd` (`Registry`) and `combat_definitions.gd`; lookups default silently (`combat_definitions.gd:14` weapon, `:29` vision, `:32` armour).

- The lint is a function over a kinds dictionary returning error strings, so a test can feed it a bad row; the suite runs it over every kind `Registry` knows (`Registry.units()`, `Registry.buildings()` and any other id source in `definitions.gd`).
- Top-level keys only; the whitelist is every top-level key in today's data, written out in the test (a new key needs a whitelist line, which is the point). Nested dictionaries (`collects`, `contains`) are not linted tonight.
- References that must resolve: `weapon` and `weapon_tiers` (keys of `Shared.WEAPONS`; `""` = none), `armor` (keys of `Shared.ARMOR`), `locomotor` (the set written in the test from today's values, `air legs treads wheels`; `locomotion.gd` compares strings), `builds`, `produces`, `spawns_on_complete` and `prerequisite` (known kind ids; `""` = none).
- DL1: a test kind with key `visoin` fails, naming kind and key. DL2: a test kind with `weapon: "no_such_gun"` fails, naming kind, key and value. DL3: the real registry gives no errors.
- Docs: `docs/guide/08-combat.md:105` already says a bot-owned unit scans its vision times a guard modifier; add a line to `03-entities.md` only if its key table misses that use.

## Task 6: Docs

Sonnet high, after Tasks 1-5 (parked ones excluded).

- `docs/STATUS.md` F15: done on branch `tooling-night` (rows every 30 ticks, first differing row reported), with the rerun bisect (Zero Hour `-DebugCRCFromFrame` workflow) named as a later step. F19: strike the items fixed on `main` with their commits (`ae094737` desync_diff ring only; `4f0e5ecc` bisect exit codes, tick order, the test that stayed green; `9983818b` m2 seed, map and starts; `92fd4b84` W3D nits), the time table (Task 3), check-count drift (Task 4's finding), definitions lint (Task 5); m7 dropped (no bug today, user 2026-11-20); m4 stays a note; extra-cell re-measure stays open.
- `docs/reference/determinism-rules.md:26` (the ring "not on the wire … never acted on"): add that offline sessions store `tick_hash()` rows that the replay compares, never across engine versions.
- Guide: chapter 10 (determinism and replays: session hash rows and the replay compare, keeping "never compare across engine versions" beside it), chapter 13 (testing and tooling: CASE_STAT, `case_times.py`, the lint, the new replay lines), each chapter's `Checked against` footer. Keep the guide's style (payoff first).
- `docs/reference/sim-interface.md`: verify Task 1's entries and the status line.
- `docs/development.md` only if a command it lists changed.
- `sh tools/check_public.sh` and `python3 tools/roadmap.py --check` pass.

## Task 7: Gate (stop gate; no merge)

1. `uptime` (load below 2.5, else wait with a Monitor until-loop, never sleep polls), `pgrep -fl 'godot|generalszh'`.
2. `sh tools/run_checks.sh`, full suite, `python3 tools/test_sim_boundary.py`.
3. Traces: latest green `main` CI run id (`gh run list --branch main --workflow ci.yml --status success -L 1 --json databaseId --jq '.[0].databaseId'`), then `sh tools/compare_local_traces.sh <id>`: the branch's local traces must equal `main`'s CI traces.
4. Benchmark alone: `PERF_LABEL="Tooling night gate" sh tools/run_benchmark.sh` (about 7 min, pair step included; `timeout: 600000`, or in the background with the completion notice). It writes a `docs/reference/perf-history.csv` row and regenerates the README and ledger tables: expected, commit them as one local commit "Record the tooling night gate benchmark". `BUDGET EXCEEDED open dense hordes300` is printed on `main` today (accepted rows) and is not a stop. Stop only on a `BUDGET EXCEEDED` line naming any other row, a non-zero exit, or `PAIR GATE FAILED`/`PAIR GATE INCONCLUSIVE`; compare with the latest `main` row in `perf-history.csv`. A `CEILING ALARM` alone is not a stop.
5. Reviews, each with the [gate review](../../milestone-prompt.md#gate-review) brief: Opus whole-branch (high); Grok normal `-m grok-4.7` if available (recipe in `grok-handoff.md`, private; missing or failing: a second Opus pass); `pr-review-toolkit:silent-failure-hunter`; `pr-review-toolkit:pr-test-analyzer`; `ponytail:ponytail-review` on Sonnet. No player-experience reviewer: `match_screen.gd` gains a record-only key, no player-visible change. No Codex (not named here).
6. One fix round (Opus high) for confirmed findings, as new commits; rerun the affected checks; record rulings.
7. Stop. The branch waits for the owner's merge.

## Stop conditions

[Milestone prompt stop conditions](../../milestone-prompt.md#stop-conditions), plus each task's Stop line. Parked tasks go to the morning summary; the run continues with the next independent task (Tasks 3 and 5 do not depend on 1-2; Task 4 needs 3; Task 2 needs 1).

## Owner items after the gate

- Merge (`git merge --squash`, tag `tooling-night-tip` first, AGENTS.md).
- Rendered rerun after the merge: `match_screen.gd` changes, so a rendered benchmark row is owed (window, owner).
- The rerun bisect step for F15 stays a later decision.

## Not in this plan

Online hash rows in the session file (user, 2026-11-20: offline only); per-subsystem hashes (add only if a divergence does not reproduce on the recorded build); a coarser interval; the extra-cell re-measure; the m4 profiler zone; the map lint (map pack); nested-key linting.
