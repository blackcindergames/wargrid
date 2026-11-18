# Pump hardening: Implementation Plan

**Status:** ready for the run (agent, 2026-11-18): the owner's answers are in "Owner answers" (user, 2026-11-18); the Opus and Fable readiness reviews are applied (fix list `review-fixes.md`, private). Approving does not start implementation: the run starts from its handoff, as a hybrid start in an attended session ("Run setup").

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: [milestone prompt](../../milestone-prompt.md) (one fresh subagent per task, each starting from the Pump hardening resume record in [sim boundary verification](../../reference/sim-boundary-verification.md#pump-hardening)) and [night run](../../night-run.md#coordinator-rules). Every task subagent also reads "Global Constraints", "Determinism notes", "Same-tick and ordering cases" and "Stop gate and stop conditions" (`rg -n '^## ' <plan>`).

**Goal:** Close the inline-testable part of the sim boundary critique before SB5a, so SB5a shrinks back to the queue, with all inline tests green and every digest, trace and pin equal.

**Architecture:** `SimPump` publishes a fresh `Slot` per job and turns a null `run_job` result into a failed pump; a sequence is stamped only when the job asks (`Job.stamp_sequence`, offline only); `record()` returns the command log from its own query job (`Job.want_log`, `Note.log`) and `recorder()` goes. The offline driver keeps its queue and preview request on a refused post. The match screen gets one `close_match` call for leave, quit and window close that stops the pump before the playtest record. `Lockstep.take` and `finish_tick` refuse out-of-order calls and calls after the end; the online driver asks for the preview on the last job of a step call. Tests gain the relay's frame-order rule, a reference test against a plain `advance(sim)` peer, and a wider static check; `run_profile.gd` gains one team-load row through `post` and `drain`.

**Tech Stack:** Godot 4.7.2 typed GDScript, suite runner `game/tests/run_tests.gd`, Python checks under `tools/`, POSIX sh tools. Relay and protocol untouched.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md), package row "Pump hardening" (`:205` at `6ae89cd`) and "SB5a inherits" (`:210`, out of scope here); [critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18); [STATUS](../../STATUS.md) F32 (`post` part only), F35; [packages](../../packages.md) night-lane item 6. Background (private): the sim boundary critique, changes 2, 5, 6, 7, 9 to 17. Template: [SB4 plan](2026-11-17-sim-boundary-sb4.md).

## Global Constraints

- **Base:** worktree `$W` = `~/projects/wargrid-wt-pump`, branch `pump-hardening`, code base local `main` `6ae89cd`; the prep commit (this plan, the verification section) sits on top before Task 1, so HEAD is not `6ae89cd`; `main` `6854ff5` merged at `07f0c59` (user, 2026-11-18), so code checks compare against `6854ff5` and line cites stay `6ae89cd` (no cited file changed). Logs `$L` = `~/projects/wargrid-overnight-work/pump-hardening/logs`. `$W`, `$L`, `~` are notation: commands use absolute paths (`<abs $W>`, `<abs $L>`); tracked files use `~/...` or the tags below, never a typed absolute path (`sh tools/check_public.sh`).
- **Nothing pinned moves (the row's gate):** the four suite traces (replay, economy, combat, team), `run_netplay.sh match` and `rematch` (terminal tick 9013, `run_netplay.sh:161,179`; `s1.tsv`, `s1.cmd`), `TEAM MATCH won tick=38786 winner=2 units_peak=268` (`run_team_match.sh:13`), IC1 (`test_input_script_offline`), IC2 (`test_input_script_online`), OD1, S3, RB8. Any of them moving is a stop; never re-pin. Every code task (2-8, 10) ends with `SUITE(tN)` and `TRACES(tN)` against base, so a moved trace stops the task that moved it.
- **Allowed test edits (exactly these; anything else red is a stop):** `test_sim_pump.gd` `_job` helper sets `stamp_sequence = true` (Task 3); `test_sb3_slot_invariant`'s "at most four slots" check becomes "a new slot per job" (Task 2; owner answer 11, closed 2026-11-18); `pump.recorder()` calls replaced as listed in Task 4, and `test_sb3_match_log_equals_recorder` gains a replay check (Task 4); `test_lockstep.gd` L19 and `test_sb4_finish_tick_uses_given_digest` fixtures made sequential, assertions unchanged (Task 6; user, 2026-11-18, choice 3); the comment `test_online_scene.gd:1783` "Lockstep.take trusts its caller's tick" reworded (Task 6, comment only); `FakeTransport` (`test_online_scene.gd`) and `PairTransport` (`test_sim_pump.gd`) gain the relay's frame-order rule, which also reaches `FakeTransport`'s users `test_launcher.gd`, `test_order_voice.gd`, `test_sound.gd` (files unchanged) (Task 7); new `test_ph_*` cases and their helper classes. No assertion is removed or loosened. Non-test edit: `game/benchmarks/run_lockstep.gd` gets one checked `peer.take(tick)` (Task 6; owner, 2026-11-18, after the benchmark's peer was found never to call `take`).
- **Untouched paths:** `relay/`, `protocol/`, `game/scripts/simulation/` except `definitions/definitions.gd`, `game/scripts/presentation/`, `game/scripts/lab/` (P2.3a lab, merged on `main` `6854ff5`), `game/scripts/net/headless_client.gd`, `seat_sim.gd`, `wire.gd`, `relay_transport.gd`, `game/benchmarks/run_movement.gd`, `run_combat.gd`, `game/scripts/playtest/command_recorder.gd`. `git diff 6854ff5 --stat -- <those>` is empty at every gate.
- **Contract:** `docs/reference/sim-interface.md` changes only by what the row names: fresh slot per job; a failed pump refuses posts; `Job.stamp_sequence`; `record()` with `commands` (via `Job.want_log`, `Note.log`); `recorder()` removed; `take` and `finish_tick` refusals. Anything more is a stop.
- **Inline only:** no `Thread`, `Mutex`, `MAX_QUEUED`, flag or owner-thread check (SB5a). `run_job` stays the only function that touches the simulation.
- **Tests:** new cases `test_ph_*` (filter `WARGRID_TEST_ONLY=test_ph_`; no existing case and no suite file name contains that text, `run_tests.gd:86`), appended to their suite's `cases()` list (the runner runs listed cases only, `run_tests.gd:87`). Tests use the [simulation interface](../../reference/sim-interface.md), the pump and the drivers; `driver.pump.live()` only to build or check state.
- **Red is a failed named check.** A task whose tests need a new field or method first adds it bare and behaviour-neutral (Step 0, named per task), so the red run fails on named checks only. A red run with `suite failed to load`, `SCRIPT ERROR` or a parse error is not red: fix Step 0 or the test, then rerun.
- Typed GDScript (tests exempt from `untyped_declaration` only); comments one line, WHY only; edits with the Edit tool only. Subagents never commit, push, merge or open a window; the coordinator makes one local commit per green task on `pump-hardening` (user, 2026-11-18). Never push or merge.
- **Commands:** every suite, lint, warnings, checks, netplay, team-match, profile and benchmark call has Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker (`TESTS PASSED <n>`, `CHECKS PASSED 5`, `NETPLAY PASSED`, `REPLAYS MATCHED`, `PYTHON TESTS PASSED`, `PUBLIC CHECK PASSED`, `PROFILE COMPLETE 11`, `LOCKSTEP BENCHMARK PASSED 1`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:|NETPLAY FAILED' <log>`. Forms, run from `$W`:
  - `SUITE(<tag>)`: `WARGRID_REPLAY_TRACE=<abs $L>/replay-<tag>.tsv WARGRID_ECONOMY_REPLAY_TRACE=<abs $L>/economy-<tag>.tsv WARGRID_COMBAT_REPLAY_TRACE=<abs $L>/combat-<tag>.tsv WARGRID_TEAM_REPLAY_TRACE=<abs $L>/team-<tag>.tsv sh tools/run_tests.sh > <abs $L>/<tag>-suite.log 2>&1; echo "exit=$?"`
  - `ONLY(<tag>, <filter>)`: `WARGRID_TEST_ONLY=<filter> sh tools/run_tests.sh > <abs $L>/<tag>-only.log 2>&1; echo "exit=$?"`
  - `NET(<tag>, <s>)`: `NETPLAY_OUT=<abs $L>/<tag>-np-<s> sh tools/run_netplay.sh <s> > <abs $L>/<tag>-np-<s>.log 2>&1; echo "exit=$?"`
  - `TRACES(<tag>)`: `python3 tools/compare_replays.py <abs $L>/replay-base.tsv <abs $L>/replay-<tag>.tsv`, the same for economy and combat, team with `--interval 200 --rows 100`; each `REPLAYS MATCHED`.
  - `NETEQ(<tag>)`: `compare_replays.py` on `s1.tsv` of `match` and `rematch` against base with `--interval 30 --rows 0`, each `REPLAYS MATCHED`; then `cmp` of both `s1.cmd` pairs: silent.
  - `EQUAL(<tag>)`: `TRACES(<tag>)` and `NETEQ(<tag>)`.
  - `STATIC(<tag>)`: `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_tests.sh`, each `> <abs $L>/<tag>-<name>.log 2>&1; echo "exit=$?"`.
  - `PY(<tag>)`: `sh tools/run_python_tests.sh > <abs $L>/<tag>-py.log 2>&1; echo "exit=$?"`. `CHECKS(<tag>)`: `sh tools/run_checks.sh > <abs $L>/<tag>-checks.log 2>&1; echo "exit=$?"`.
- **Benchmarks run alone.** `uptime` first. Load above 2.5 (another session, P2.3a art lab, may load the host): run anyway, label it `Pump hardening (host under load)`, and list "rerun `PERF_LABEL=\"Pump hardening\" sh tools/run_benchmark.sh` in the evening" for the owner (user, 2026-11-18). Foreign Godot processes of that session (`~/projects/wargrid-wt-p23a-ab`) are expected: they never stop a benchmark task or the run (night-run Start step 4 is overridden here, user, 2026-11-18), and the run never kills a Godot process it did not start. Never loosen a budget. The pump row is report-only (no budget).
- **Mutation proofs:** `git add <file>` first; mutate with the Edit tool; run the named `ONLY`; revert with the Edit tool; `git diff --exit-code -- <file> > <abs $L>/<tag>-revert.log 2>&1; echo "exit=$?"` → exit 0. One `<tag>` per proof. A proof that stays green: see stop conditions.
- **No visible window, no sound:** headless only. No `sh tools/run_game.sh` (an `ask` rule), no `gh pr`, `git merge`, `git push`, `fly`, `deploy_web.sh` (ask rules in `.claude/settings.json`, `~/.claude/settings.json`).

## Model routing

- Implementer per task: Sonnet. Task 1 and the gate runs (Task 14a-c): Sonnet.
- **Per-task review loop (Tasks 2-12), run by the coordinator; the handoff copies it, since the coordinator reads no task bodies:** (1) the implementer returns `GREEN`, uncommitted; (2) the coordinator dispatches one fresh-context Opus (high) reviewer with paths only: this plan's task heading, "Same-tick and ordering cases", the commands `git diff -U30 HEAD` and `git status --short`; it writes `<abs $L>/t<N>-review.md` and names, per new test, the production change that would make it fail; (3) high and medium findings go to a fresh Sonnet implementer with that file's path, fixed test-first, Step 4 rerun, `GREEN` again; (4) one fix round; what is left goes to the ledger for the gate; (5) the coordinator commits.
- Tasks 13a and 13b (docs with code claims): one fresh Opus (high) docs review over both after 13b, same loop.
- Gate (Task 14d): Opus (high) whole-branch, Grok normal (not fast; Opus alone if Grok is missing or fails), `silent-failure-hunter` and `pr-test-analyzer` (Opus), the [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md) (user, 2026-11-18, choice 5: Task 5 rewires quit, window close and leave filing of the playtest card; Task 6 adds HUD reason strings), then `/ponytail-review` on Sonnet. All read-only, in parallel, on the branch diff `main...HEAD` (three dots; merge base `6854ff5`); each writes `<abs $L>/gate-<reviewer>.md`. Fixes in Task 15.
- Diagnosis of any unexpected red or BLOCKED: an Opus (high) agent first (night-run rule).

## Review Focus

1. **Job 0 or a query returning null.** `post` and `query` turn a null note into a failed pump; `start` and `query` callers (`record`, online `start`, `_report`, `flush`) would then read a null note. Expected: a script error already printed, so the suite fails loudly; real fault handling is SB5a (fault flag). No `push_error` is added for a null note. The reviewer checks no caller hides a null.
2. **Offline after a refused post.** The pump stays stopped or failed, so the kept queue never runs and the match freezes without a line. Expected for this package (no queue cap inline); SB5a's "room before take" owns recovery. Task 3 pins that nothing is lost.
3. **Window close twice, quit then close** (PO14, PO7 in `test_playtest_overlay.gd`). `close_match` stops the pump every time (idempotent) and still files the sitting on the second close. Task 5 keeps PO7, PO14, NB9, NB11, NB14 green unchanged.
4. **Rematch frame and the take check.** A relay `start` swaps in a new lockstep inside `step()`'s poll while the driver's `_next_tick` is still the old match's; the loop breaks on `_last.over` before `take`, so `take`'s new tick check never sees the old tick. Guarded by `test_sb4_rematch_starts_from_new_pump`, N18, and Task 7's rematch frame-order test.
5. **A nested freeze reveals a writer.** A simulation path that writes into a cached view dictionary now prints an error. Expected: none exists (the views hold scalars, `definitions.gd:64-98`); if the suite shows one, BLOCKED (fixing it touches `simulation/`).
6. **Offline `flush()` after a refused post.** `flush()` (test-only) goes through `query`, which has no stopped check, so a kept queue can still be issued by a later flush; "nothing issued" holds for `step` only. `record()` after `close_match` needs `query` on a stopped pump, so `query` stays unblocked.

## Determinism notes

- No simulation file changes except `definitions.gd`'s freeze (values unchanged, only read-only flags). Warm-up order changes from per kind to per cache; caches are looked up by key, never iterated in the simulation, so no digest moves.
- Offline jobs set `stamp_sequence`, so sequences stay "last accepted plus one" (answer 21): IC1, OD1, S3 unchanged. Online and lockstep commands carry their own `sequence` and `tick`; a peer command without one is now refused, as the headless client and the replay oracle refuse it (`simulation.gd:230`, "Missing field: sequence").
- A fresh slot per job changes no value: `run_job` already assigns a fresh `view_state()`.
- `take` and `finish_tick` refusals never fire for a legal caller: the headless client, the lockstep benchmark and the online driver call them in tick order.

## Same-tick and ordering cases

No new simulation command. Changed command flow:

| Operation | Against | Expected | Test |
|---|---|---|---|
| offline `post` refused (stopped or failed pump) | queued orders | queue kept in submit order; nothing issued by `step` (Review Focus 6 for `flush`) | `test_ph_refused_post_keeps_queue_and_preview` |
| offline `post` refused | submit after the refusal | appends behind the kept orders | same |
| offline `post` refused | preview request | kept; a newer `request_preview` replaces it; `request_preview({})` clears request and answer | same |
| offline `step` | match over, queue and request empty | posts nothing (unchanged early return) | SB3 cases unchanged |
| `post` returns null note | notes filed earlier in the frame | earlier notes still drain; no slot or note from the failed job; every later post false | `test_ph_null_job_fails_pump` |
| `query` returns null note | later posts | false | same |
| two posts, one drain | slots | `current()` is the second job's slot, `previous()` the old current; the first job's slot is never shown; a held slot never changes | `test_ph_fresh_slot_per_job` |
| online two-tick step call | preview request | only the last job carries it; the answer reflects the second tick (RP8) | `test_ph_preview_on_last_job_of_catch_up`, RP8 |
| online step call, next tick's packets missing | preview request | the one job carries it | `test_ph_preview_on_single_job_when_next_tick_waits` |
| online step call, second take refused after `can_step` said ready (hash or leave) | preview request | no job carries it; request kept for the next call | none (match ends on that path) |
| online stalled step call | preview request | kept (RP4) | RP4 unchanged |
| `finish_tick` | lockstep already ended | sends nothing, status and reason unchanged | `test_ph_finish_tick_refuses_after_end` |
| `start` (`finish_tick(0)`) | lockstep already ended | sends nothing, no hash row 0, reason unchanged | `test_ph_start_after_end_sends_nothing` |
| `finish_tick` | tick + delay not last sent + 1 (gap or repeat) | `ended_protocol` "own tick P after L", nothing sent | `test_ph_finish_tick_refuses_out_of_order` |
| `take` | tick not `_next_tick`, loud or quiet | `ended_protocol` "take tick T, expected N" (quiet does not hide a caller bug) | `test_ph_take_checks_next_tick` |
| `take` | lockstep ended | null, status unchanged (checked before the tick) | same |
| relay `error` received in a later physics callback while a tick job is undrained | that job's drain | tick recorded, no packet, no `over`, room closed in the same drain | `test_ph_receive_ends_lockstep_with_undrained_job` |
| leave, pause quit, window close | playtest record | pump stopped before `match_record` runs | `test_ph_every_exit_stops_pump_before_record` |
| second window close | stopped pump | stop is idempotent; sitting filed (PO14) | PO14 unchanged |
| natural match end (`playtest_overlay.end_match`) | playtest record | runs on a pump that is not stopped (inline, outside the row); listed for SB5a | none |
| `playtest_header` | marker save | builds no command log | `test_ph_header_builds_no_log` |

## Files

| File | Change | Task |
|---|---|---|
| `game/scripts/match/sim_pump.gd` | fresh slot, `_note_for` seam and failed state; `Job.stamp_sequence`, `Job.want_log`, `Note.log`; `record()` with commands; `recorder()` removed; warm-up from the freeze list | 2, 3, 4, 10 |
| `game/scripts/match/offline_driver.gd` | stamp flag; keep queue and request on refusal; `match_header`; `stop`; `:149` shortcut comment goes with its code | 3, 4, 5 |
| `game/scripts/match/online_driver.gd` | `match_header`; `stop`; drop the `_finish_job` end guard; preview on the last job | 4, 5, 6, 8 |
| `game/scripts/match/match_screen.gd` | `close_match`; `_notification`; `playtest_header` from `match_header` | 4, 5 |
| `game/scripts/playtest/playtest_overlay.gd` | window-close handler moves to the screen | 5 |
| `game/scripts/net/lockstep.gd` | `take` tick check; `finish_tick` refusals | 6 |
| `game/scripts/simulation/definitions/definitions.gd` | nested freeze, `cache_names()`, `:119-120` comments | 10 |
| `game/tests/relay_frame_order.gd` (new) and its `.gd.uid` (created by the import; the coordinator commits it) | the relay's per-seat frame-order rule | 7 |
| `game/tests/test_sim_pump.gd`, `test_online_scene.gd`, `test_skirmish_scene.gd`, `test_playtest_overlay.gd`, `test_lockstep.gd` (L19 fixture) | tests | 2-10 |
| `tools/test_sim_boundary.py` | wider scan, pump access with per-file counts | 11 |
| `game/benchmarks/run_profile.gd`, `tools/run_benchmark.sh`, `tools/run_profile.sh`, `tools/perf_record.py`, `tools/test_perf_charts.py` | pump row, marker 10 → 11 | 12 |
| docs | Tasks 13a, 13b | 13 |

---

### Task 1: Base counts and line map

**Files:** Modify: `docs/reference/sim-boundary-verification.md` (`## Pump hardening`: resume record, ledger first row, base counts, line map). Nothing else.

- [ ] **Step 1:** `git rev-parse --show-toplevel` prints `<abs $W>`, `git rev-parse --abbrev-ref HEAD` prints `pump-hardening`; `git diff 6854ff5 --stat -- game tools relay protocol` prints nothing and `git log --first-parent --oneline 6ae89cd..HEAD` lists only `706bebf`, `ff7c39a` and the main merge `07f0c59` (else stop). `mkdir -p <abs $L>`. `uptime` and `pgrep -fl godot` into the ledger (foreign Godot processes expected, Global Constraints).
- [ ] **Step 2:** `SUITE(base)`; `ONLY(base-pump, test_sim_pump)`, `ONLY(base-online, test_online_scene)`, `ONLY(base-lock, test_lockstep)`, `ONLY(base-overlay, test_playtest_overlay)`, `ONLY(base-skirmish, test_skirmish_scene)`; `NET(base, match)`, `NET(base, rematch)`; `sh tools/run_team_match.sh > <abs $L>/base-team.log 2>&1; echo "exit=$?"`; `STATIC(base)`. Record cases, checks, markers, the team line, both terminal ticks. A red base is a stop.
- [ ] **Step 3:** Counts: `cases()` lengths of the five suites above; `rg -c '\bpump\s*\.' game/scripts/match/offline_driver.gd game/scripts/match/online_driver.gd` (8, 8 at `6ae89cd`); `rg -n 'recorder\(\)' game tools` (list; the `tools/test_sim_boundary.py:146` string fixture stays for the whole run); `rg -n 'shortcut:|SB5' game/scripts/match/offline_driver.gd game/scripts/simulation/definitions/definitions.gd`.
- [ ] **Step 4:** Line map: re-find each cite of "Line map (plan, at 6ae89cd)" in the verification file by symbol (`rg -n '^(class|func|var|const|static func) <name>' <file>`); write the right column. A missing symbol is a stop.
- [ ] **Step 5:** `sh tools/check_public.sh > <abs $L>/t1-public.log 2>&1; echo "exit=$?"` → `PUBLIC CHECK PASSED`. Coordinator commits.

### Task 2: Fresh slot per job; a null job fails the pump

**Files:** Modify: `game/scripts/match/sim_pump.gd` (fields :39-47, `start` :53-63, `post` :65-69, `drain` :71-75, `query` :83-84, `_publish` :115-119, `_rotate` :121-126). Test: `game/tests/test_sim_pump.gd`.

**Interfaces:**
- Produces: `func _note_for(job: Job, slot: Slot) -> Note` (instance; calls `run_job(_sim, _recorder, job, slot)`; the one call site of `run_job` for `start`, `post`, `query`; the test seam). `var _ready: Slot = null`. `start()`: job 0's slot becomes `_current`, `_previous` stays null (`test_sb3_two_notes_one_drain` depends on it). `post(job) -> bool`: false when stopped or failed; builds `Slot.new()`, and on a null note sets `_failed = true` and files nothing, else `_ready = slot`. `drain()`: if `_ready` is not null, `_previous = _current`, `_current = _ready`, `_ready = null`. `query`: a null note sets `_failed = true` and returns it. No `push_error` on a null note (the real fault printed one; the runner fails on any `ERROR:` line, `run_tests.sh:46`; the fault flag is SB5a). `_write`, `_published`, `_publish`, `_rotate` go. No public `failed()` (agent call: nothing reads it yet).
- Test helper class in `test_sim_pump.gd`: `class NullJobPump extends SimPump` with `var fail_next: bool = false` and `func _note_for(job: SimPump.Job, slot: SimPump.Slot) -> SimPump.Note` returning null when `fail_next`, else `super(job, slot)`.

- [ ] **Step 0:** add `_note_for` as above and route `start`, `post`, `query` through it, no behaviour change. `ONLY(t2s0, test_sim_pump)` exit 0.
- [ ] **Step 1: Tests.**
  - `test_ph_fresh_slot_per_job`: `_pump()`; `held = current()`, keep `held.tick`, `held.view`; six rounds of `post(_job())`, `drain()`. Checks "PH a held slot never changes after publishing": `held.tick` and `is_same(held.view, kept_view)` and `held.view.tick == held.tick`; "PH every drain shows a new slot": seven distinct slot objects seen. Then `old = current()`; `post`, `post`, `drain`: "PH two posts, one drain: current is the second job, previous the old current": `current().tick == old.tick + 2 and is_same(previous(), old)`.
  - In `test_sb3_slot_invariant` replace the check `seen.size() <= 4` (`:171`) with `seen.size() == 61`, message `"PH every job publishes a new slot, answer 11 (%d)"`. The other three checks stay.
  - `test_ph_null_job_fails_pump`: `NullJobPump.new(_sim())`, `start()`; `post(_job())` true, `drain()`; `shown = current()`; `post(_job())` true (undrained); `fail_next = true`; check "PH a null job is refused": `not post(_job())`; check "PH notes filed before the failure still drain": `drain().size() == 1`; check "PH a null job publishes nothing": `current().tick == shown.tick + 1` (the good job's slot); `fail_next = false`; check "PH a failed pump refuses every later post": `not post(_job())` and `drain().is_empty()`. A second `NullJobPump`, started: `fail_next = true`; check "PH a null query fails the pump": `query(_job()) == null`, then with `fail_next = false` `not post(_job())`.
- [ ] **Step 2:** `ONLY(t2red, test_ph_)` and `ONLY(t2red-inv, test_sb3_slot_invariant)` → exit 1; only the new and the replaced checks fail.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** `SUITE(t2)` exit 0, `TRACES(t2)`; `STATIC(t2)` exit 0.
- [ ] **Step 5:** Mutation proof: in `post`, publish the slot before the null check (`_ready = slot` first) → `ONLY(t2m1, test_ph_null_job)` exit 1; revert, prove.
- [ ] **Step 6:** Per-task review loop; coordinator commits.

### Task 3: Offline job flow (F35 stamp on request, F32 refused post)

**Files:** Modify: `sim_pump.gd` (`Job` :12-18, `run_job` stamp :133), `offline_driver.gd` (`step` :42-51, `flush` :73-80). Test: `test_sim_pump.gd`, `test_online_scene.gd`, `test_skirmish_scene.gd`.

**Interfaces:**
- Produces: `Job.stamp_sequence: bool = false`; `run_job` stamps a missing `sequence` only when it is true (the `tick` stamp stays as is). Offline `step` and `flush` set it. Offline `step` clears `_queue` and `_preview_request` only after `pump.post(job)` returns true.

- [ ] **Step 0:** declare `var stamp_sequence: bool = false` on `Job` (unused). `ONLY(t3s0, test_sim_pump)` exit 0.
- [ ] **Step 1: Tests.**
  - `test_sim_pump.gd` `_job` helper: add `job.stamp_sequence = true` (offline jobs). `test_ph_sequence_stamp_only_on_request`: a `SimPump.Job.new()` with `job.commands.assign([_move(id)])` and no flag → check "PH without the flag a missing sequence is refused": `issued[0].ok == false and issued[0].error == "Missing field: sequence" and live().last_sequence(1) == -1`; then `_job([_move(id)])` → check "PH with the flag it is stamped": `ok and command.sequence == 0`.
  - `test_online_scene.gd` `test_ph_peer_command_without_sequence_refused`: seat 2; `_peer_packets(transport, 1, 4, 5)`; a tick-6 packet with `{"type": "stop", "entity_ids": [3], "tick": 6, "player": 1}` (no `sequence`); `_peer_packets(transport, 1, 7, PEER_TICKS)`; `_run(main, 12)`. Check "PH a peer command without a sequence is refused, as the headless client refuses it": `driver.pump.live().last_sequence(1) == 0` (only tick 4's faction choice) and status `running`.
  - `test_skirmish_scene.gd` `test_ph_refused_post_keeps_queue_and_preview`: `_setup(runner)`; 5 × `BaseScene.tick`; `submit` a stop for entity 1; `req = {"player": 1, "builder_id": <own builder>, "kind": "usa_power_plant", "origin": Vector2i(10, 10)}`; `driver.request_preview(req)`; `driver.pump.stop()`; `BaseScene.tick(main)`. Checks "PH a refused post keeps the queued order": `queued().map(type) == ["stop"]`; "PH ... keeps the preview request": `driver.get("_preview_request") == req`; submit a move → "PH a submit after the refusal queues behind": `["stop", "move"]`; `request_preview(req2)` (another origin), tick → "PH a newer request replaces the kept one": `== req2`; `request_preview({})` → request and `preview_answer()` empty (fixture; true before and after the change).
- [ ] **Step 2:** `ONLY(t3red, test_ph_)` exit 1, only the new checks fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t3)` exit 0 (IC1, OD1, S3 unchanged), `TRACES(t3)`; `STATIC(t3)`.
- [ ] **Step 5:** Mutation proof: `step` clears `_queue` before `post` → `ONLY(t3m1, test_ph_refused_post)` exit 1; revert, prove.
- [ ] **Step 6:** Per-task review loop; commit.

### Task 4: `record()` returns the command log; `recorder()` goes

**Files:** Modify: `sim_pump.gd` (`Job`, `Note`, `run_job`, `record` :86-91, `recorder` :102-103), `offline_driver.gd` (`record` :85-86, `:149-151`), `online_driver.gd` (`match_log` :263-265), `match_screen.gd` (`playtest_header` :149-151). Test: `test_sim_pump.gd` (:137), `test_skirmish_scene.gd` (:1169, :1479), `test_playtest_overlay.gd`.

**Interfaces:**
- Produces: `Job.want_log: bool = false`, `Note.log: Array[Dictionary] = []` (`run_job`: when `want_log`, a deep copy of the recorder's accepted commands). `SimPump.record() -> Dictionary` = `{tick, digest, match, commands}`, one query job with `want_digest` and `want_log` (user, 2026-11-18, choice 6). `recorder()` deleted. Both drivers: `match_header() -> Dictionary` = `{mode, factions}`; `match_log()` = `match_header().merged({"commands": ...})`; offline commands `Lockstep.log_lines(pump.record().commands)` (the `:149` shortcut comment goes: no caller-side read is left); online `Lockstep.log_lines(_lockstep.command_log())` unchanged. `match_screen.playtest_header()` calls `driver.match_header()` only.

- [ ] **Step 0:** declare `Job.want_log`, `Note.log` (unused) and both drivers' `match_header()`; `playtest_header` still calls `match_log`. `ONLY(t4s0, test_sim_pump)` exit 0.
- [ ] **Step 1: Tests.**
  - `test_ph_record_returns_command_log` (`test_sim_pump.gd`): `post(_job([_move(id), _move(999999)]))`, drain; `r = record()`. Checks "PH record has tick, digest, match and commands": `r.keys() == ["tick", "digest", "match", "commands"]`; "PH the log holds the accepted command only": `r.get("commands", []).size() == 1 and r.commands[0].entity_ids == [id]`; mutate `r.commands[0].type = "x"` → "PH record hands a copy": `record().commands[0].type == "move"`; "PH recorder() is gone": `not pump.has_method("recorder")`.
  - `test_ph_header_builds_no_log` (`test_playtest_overlay.gd`): `class LogSpy extends "res://scripts/match/offline_driver.gd"` with `var logs: int = 0` and `func match_log() -> Dictionary` incrementing then `return super()`; `_begin()`; `main = Skirmish.instantiate()`, `main.driver = LogSpy.new(1)` before `add_child` (as `_scene` does, then `await runner.process_frame`). Checks "PH playtest_header builds no command log": `main.playtest_header()` has PO28's keys and `spy.logs == 0`; "PH playtest_match builds it once": after `main.playtest_match()`, `spy.logs == 1`.
  - Replace: `test_sim_pump.gd:137` `pump.recorder().issue_command(command)` → `pump.live().issue_command(command)`; `test_skirmish_scene.gd:1169` `driver.pump.recorder().commands().size() == 2` → `driver.record().commands.size() == 2`; `:1479` `main.driver.pump.recorder().commands()` → `main.driver.record().commands`. Messages and assertions otherwise unchanged.
  - `test_sb3_match_log_equals_recorder` gains one check, so the swap does not compare the log with itself: "SB3 a replay of the recorded commands reaches the recorded digest": an oracle `Skirmish.create(true, "ai", main.factions, main.map_path, main.starts)` (the scene's statics, `match_screen.gd:30-32`, passed to the driver's `create`, `offline_driver.gd:25`) that never calls `Skirmish.issue_opponents` (bot orders are in the log with their own `tick`, `skirmish.gd:112`; checked 2026-11-18), each command issued at its `tick` before that tick's step (as `test_lockstep.gd:128-135`), stepped to `record().tick`; `StateHash.digest(oracle.snapshot()) == record().digest`. A red here gets the Opus diagnosis (setup mismatch or a log gap) before any change; never drop the check.
- [ ] **Step 2:** `ONLY(t4red, test_ph_)` exit 1 (record keys, spy count).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t4)` exit 0, `TRACES(t4)`; `rg -n 'recorder\(\)' game` → no hit (the `tools/test_sim_boundary.py:146` string fixture tests the `.simulation()` spelling and stays); `STATIC(t4)`.
- [ ] **Step 5:** Mutation proof: `playtest_header` back to `driver.match_log()` → `ONLY(t4m1, test_ph_header)` exit 1; revert, prove.
- [ ] **Step 6:** Per-task review loop; commit.

### Task 5: One `close_match` call on every exit path

**Files:** Modify: `match_screen.gd` (quit wiring :84-87, `_leave` :175-181, new `_notification`), `offline_driver.gd`, `online_driver.gd` (new `stop`), `playtest_overlay.gd` (`_notification` :91-92 deleted). Test: `test_playtest_overlay.gd`.

**Interfaces:**
- Produces: both drivers `func stop() -> void: pump.stop()`. `match_screen.close_match(file_sitting: bool) -> void`: `driver.stop()`, then `_playtest.close_out()` when `file_sitting`, else `_playtest.keep_match()`. `_leave`: `driver.leave()`, `gui_release_focus()`, `close_match(false)`, change scene (order of today otherwise). Pause quit: `close_match(true)`, then `quit.call()`. `_notification(what)`: `NOTIFICATION_WM_CLOSE_REQUEST` and `not _playtest.web` → `close_match(true)`; the overlay's comment "web files at the next launcher open instead" moves with it. Online quit and window close stop the pump only and do not call `driver.leave()`; transport closing stays as today (user, 2026-11-18, choice 4).

- [ ] **Step 1: Test** `test_ph_every_exit_stops_pump_before_record`: for each of `"leave"` (`HUD/PauseMenu` `leave_requested.emit()`), `"pause quit"` (`quit_requested.emit()`, `main.quit` a no-op), `"window close"` (`_close_window(main)`): `_begin()`; `main = await _scene(runner)`; `_scenes(main)`; `overlay.match_record = func() -> Dictionary: stopped.append(not main.driver.pump.post(<step = false job>)); return main.playtest_match()`; trigger. Check "PH <exit>: the pump is stopped before the match is recorded": `stopped == [true]`. Then `main.free()`, `_end(saved)`. A second pass per exit with `_begin(false)` (helper off, so `match_record` never fires): "PH <exit> with the helper off stops the pump": `not main.driver.pump.post(job)` after the exit. Plus one online case via the file's `_online(runner)`: after `leave_requested`, "PH online leave stops the pump": `not main.driver.pump.post(job)`.
- [ ] **Step 2:** `ONLY(t5red, test_ph_every_exit)` exit 1.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t5)` exit 0 (PO7, PO13, PO14, NB9, NB10, NB11, NB14 and the launcher cases unchanged), `TRACES(t5)`; `STATIC(t5)`.
- [ ] **Step 5:** Mutation proof: delete `driver.stop()` from `close_match` → `ONLY(t5m1, test_ph_every_exit)` exit 1 for all three exits; revert, prove.
- [ ] **Step 6:** Per-task review loop; commit.

### Task 6: Lockstep refuses out-of-order `take` and `finish_tick`

**Files:** Modify: `game/scripts/net/lockstep.gd` (`take` :107-123, `finish_tick` :148-169), `online_driver.gd` (`_finish_job` :153-154). Test: `test_sim_pump.gd`; fixtures `test_lockstep.gd:607`, `test_sim_pump.gd:570,573`; comment `test_online_scene.gd:1783`.

`run_lockstep.gd`: one checked `peer.take(tick)` added (owner, 2026-11-18, after the benchmark's peer was found never to call `take`).

**Interfaces:**
- `take(tick, quiet)`: after the existing `_ended()` return, `tick != _next_tick` → `_end("ended_protocol", "take tick %d, expected %d" % [tick, _next_tick])`, null, quiet or not (user, 2026-11-18, choice 2).
- `finish_tick(tick, state, digest)`: first `if _ended(): return`; then `tick + _delay != _last_sent + 1` → `_end("ended_protocol", "own tick %d after %d" % [tick + _delay, _last_sent])`, return; rest unchanged (user, 2026-11-18, choice 1). `start` is unchanged (it resets `_last_sent` before `finish_tick(0)`, so an ended lockstep's `start` now sends nothing).
- `_finish_job` calls `finish_tick` without its `if not _ended()` guard (the rule now lives in one place); its comment goes.

- [ ] **Step 1: Tests** (`_twin`, `_twin_at_four`, `_peer` helpers exist; `_twin()`'s `start` leaves `_last_sent` at 4):
  - `test_ph_finish_tick_refuses_after_end`: `_twin()`; `ls.set_protocol_error("probe")`; `finish_tick(1, null)` → "PH finish_tick sends nothing after the end and keeps its reason": frame count unchanged, `status() == "ended_protocol" and end_reason() == "probe"`.
  - `test_ph_start_after_end_sends_nothing`: a lockstep built as `_twin()` builds it, before `start`: `set_protocol_error("probe")`, then `start(sim.snapshot())` → "PH start after the end sends nothing and logs no hash row": frames empty, `hash_rows().is_empty()`, `end_reason() == "probe"`.
  - `test_ph_finish_tick_refuses_out_of_order`: twin A `finish_tick(2, null)` → "PH a gap is refused": no frame, `end_reason() == "own tick 6 after 4"`; twin B `finish_tick(1, null)` twice → "PH a repeat is refused": the frame count grows by one only, `"own tick 5 after 5"`; twin C ticks 1, 2, 3 → "PH in order sends each": frames for ticks 5, 6, 7, status `running`.
  - `test_ph_take_checks_next_tick`: three `_twin_at_four()`; `take(5)` → "PH take ahead ends the lockstep": null, `"take tick 5, expected 4"`; `take(3, true)` → "PH a quiet take does not hide a wrong tick": null, `ended_protocol`; third: `receive(_peer(4))`, `take(4) != null`.
  - Fixtures (no assertion change): `test_lockstep.gd` L19, the line before `ls.finish_tick(9_999_990, …)`: `ls._last_sent = 9_999_990 + ls._delay - 1`; `test_sb4_finish_tick_uses_given_digest`: before `finish_tick(30, …)` `for t in range(1, 30): twin.ls.finish_tick(t, null)`, before `finish_tick(60, …)` the same for 31-59. Comment `test_online_scene.gd:1783`: the driver's count must restart because `take` now refuses any other tick.
- [ ] **Step 2:** `ONLY(t6red, test_ph_)` exit 1 (new checks only); `ONLY(t6l, test_lockstep)` exit 0 with the fixture.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t6)` exit 0, `TRACES(t6)`; `NET(t6, <s>)` for `match`, `rematch`, `left-mid`, `perturb`, `relay-down`, `kill`, `stall`, each `NETPLAY PASSED`; `NETEQ(t6)`; `uptime`, then `godot --headless --path <abs $W>/game --script res://benchmarks/run_lockstep.gd > <abs $L>/t6-lockstep.log 2>&1; echo "exit=$?"` → functional pass: an `LOCKSTEP overhead_ms=` line and no `stalled` or `workload invalid` line; `LOCKSTEP BENCHMARK PASSED 1`, or a `LOCKSTEP BUDGET FAIL` that is recorded and judged at 14c when load is above 2.5 (at load 2.5 or below it is a stop: budget exceeded); `STATIC(t6)`.
- [ ] **Step 5:** Mutation proofs: drop the `_ended()` return in `finish_tick` → `ONLY(t6m1, test_ph_finish_tick_refuses_after_end)` exit 1; drop the tick check in `take` → `ONLY(t6m2, test_ph_take_checks)` exit 1; revert, prove each.
- [ ] **Step 6:** Per-task review loop; commit.

### Task 7: The relay's frame-order rule in the fake transport

**Files:** Create: `game/tests/relay_frame_order.gd` (and its `.gd.uid`). Modify: `test_online_scene.gd` (`FakeTransport` :31-48, `cases()`), `test_sim_pump.gd` (`PairTransport` :22-37).

**Interfaces:**
- `relay_frame_order.gd` (`extends RefCounted`; one-line comment: mirrors `relay/room.go` `forward`, `onOver`, `onAgain`, `rematch` at `6ae89cd` for one seat): `var delay: int = 4`, `var refusals: Array[String] = []`; `func accepts(text: String) -> bool` decodes with `Wire.decode`: `tick` refused when over or `tick != max(last, delay - 1) + 1`; `over` refused when over or no tick sent yet; `again` refused when not over or already again; other types accepted; a refusal appends `"<type> <tick or ''> refused"` and returns false; `func rematch() -> void` resets last tick, over, again.
- Both test files: `const RelayFrameOrder = preload("res://tests/relay_frame_order.gd")`.
- `FakeTransport`: `var order := RelayFrameOrder.new()`; `send_text` appends to `sent`, and when `order.accepts` is false appends `Wire.encode({"type": "error", "reason": "invalid message"})` to `frames` and sets `is_closed = true` (what the relay does, `room.go` `refuse`); `poll()` calls `order.rematch()` for each returned frame with `Wire.decode(text).get("message", {}).get("type", "") == "start"` (a frame that fails to decode, as in `test_start_without_settings_is_a_protocol_error`, has no `message`). `PairTransport`: `var order := RelayFrameOrder.new()`; `send_text` calls `order.accepts(text)` (records only).

- [ ] **Step 1:** Create `relay_frame_order.gd`. **Tests** (`test_online_scene.gd`):
  - `test_ph_fake_relay_frame_order`: on a bare `RelayFrameOrder`: ticks 4, 5 accepted; 5 again refused; `over` accepted then tick 6 refused; fresh one: `over` first refused, `again` before `over` refused; after `rematch()` tick 4 accepted. One check per line, worded "PH relay rule: …".
  - `test_ph_receive_ends_lockstep_with_undrained_job`: seat 2; `_peer_packets(transport, 1, 4, 7)`, `_peer_stop(transport, 8)`, `_peer_packets(transport, 1, 9, PEER_TICKS)`; `_run(main, 8)`; fixture check `driver.current().tick == 8` (as in `test_sb4_foreign_note_ends_match`); `kept = _sent_ticks(transport)`; `main._physics_process(1.0 / 30.0)` (takes tick 8 with the stop and posts its job, undrained; fixture check `driver.get("_next_tick") == 9`); append `Wire.encode({"type": "error", "reason": "room closed"})`; `main._physics_process(1.0 / 30.0)` (the poll ends the lockstep, no take); `main._drain_notes()`. Checks: "PH a receive that ends the lockstep still records the undrained tick": `command_log()` has a `stop` with `tick == 8`; "PH nothing is sent for it": `_sent_ticks(transport) == kept`; "PH no over after the end": `_sent_types(transport, "over") == 0`; "PH the HUD names the end": `driver.notice() == "Relay: room closed"`; "PH the same drain closes the room": `driver.over() and transport.closed()`; "PH legal frames only": `transport.order.refusals.is_empty()`.
  - `test_ph_frame_order_through_end_and_rematch`: seat 2; `_end_in_catch_up(runner, online, PEER_TICKS, [])` (the match ends on the first of two physics ticks in one frame) → "PH the catch-up end sends only legal frames": `refusals.is_empty()`, `_sent_types(transport, "over") == 1`, `_contiguous(_sent_ticks(transport), 4)`, status not ended; then the rematch steps of `test_sb4_rematch_starts_from_new_pump` (seat 1's `again`, Play again, `_rematch_start(99)`, `_peer_packets(transport, 1, 4, 4)`, one `_run`; restore `SkirmishMain` as that test does) → "PH the rematch sends only legal frames": `refusals.is_empty()`, `_sent_types(transport, "again") == 1`, the last sent frame is a `tick` with `tick == 4`.
- [ ] **Step 2:** `ONLY(t7, test_ph_)`, `ONLY(t7o, test_online_scene)`, `ONLY(t7p, test_sim_pump)`, `ONLY(t7l, test_launcher)`, `ONLY(t7v, test_order_voice)`, `ONLY(t7s, test_sound)`, each exit 0. The new cases test existing behaviour and may pass at once. Any existing case going red under the rule is a real frame-order bug in the scene client: BLOCKED with the case names and the refused frames (Opus diagnosis), never a fixture change.
- [ ] **Step 3:** Mutation proofs: (over rule) duplicate the `_transport.send_text(Wire.encode({"type": "over"}))` line in `online_driver.gd` `_finish` → `ONLY(t7m1, test_ph_frame_order)` exit 1 on "PH the catch-up end sends only legal frames"; (tick rule) in `Lockstep.finish_tick` set `packet_tick = tick + _delay + 1` → `ONLY(t7m2, test_ph_frame_order)` exit 1; revert, prove each.
- [ ] **Step 4:** `SUITE(t7)` exit 0, `TRACES(t7)`; `STATIC(t7)`. Per-task review loop; commit (with the `.gd.uid`).

### Task 8: Online preview on one job per step call

**Files:** Modify: `online_driver.gd` (`step` :104-122, `_tick_job` :124-129). Test: `test_online_scene.gd`.

**Interfaces:** `_tick_job(commands: Array[Dictionary], with_preview: bool) -> SimPump.Job`. In `step`, after `_credit -= 1`: `var last: bool = i == CATCH_UP_STEPS - 1 or _credit < 1 or not _lockstep.can_step(_next_tick + 1)`; the job carries `_preview_request` only when `last`; `_preview_request = {}` only after a job that carried it was posted (replaces the `if posted` clear). The last job, not the first: RP8 (`test_sb2_preview_after_catch_up`, `:1586-1605`) requires the answer to reflect the second tick.

- [ ] **Step 1: Tests:**
  - `test_ph_preview_on_last_job_of_catch_up`: RP8's fixture up to the two-tick frame; then `main._physics_process(1.0 / 30.0)` and `notes = main.driver.drain()`. Checks "PH a two-tick step call asks for the preview once": `notes.size() == 2` and exactly one note has a preview; "PH on its last job": `not notes[-1].preview.is_empty()`.
  - `test_ph_preview_on_single_job_when_next_tick_waits`: RP8's fixture up to `tick` (stalled at 9), then peer packets for `tick` only (`_peer_packets(online.transport, 2, tick, tick)`): `take(tick)` succeeds, `can_step(tick + 1)` is false; checks `notes.size() == 1 and not notes[0].preview.is_empty()`.
- [ ] **Step 2:** `ONLY(t8red, test_ph_preview)` exit 1 (two previews today).
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t8)` exit 0 (RP4, RP8, N5 unchanged), `TRACES(t8)`; `STATIC(t8)`.
- [ ] **Step 5:** Per-task review loop; commit.

### Task 9: Reference test: scene driver against a plain `advance(sim)` peer

**Files:** Test: `game/tests/test_sim_pump.gd` (helpers beside `_pair_drivers`). Needs Task 7 (`RelayFrameOrder`, `PairTransport.order`).

- [ ] **Step 1:** `test_ph_driver_matches_advance_peer`, modelled on `test_sb4_two_drivers_match_end` (`test_sim_pump.gd:449`).
  - Wiring: `a := PairTransport.new()` is the driver's transport, `b := PairTransport.new()` the peer's inbox, `a.peer = b` (the driver's tick frames land in `b.inbox`, its `over` in `a.others`); `peer_order := RelayFrameOrder.new()`. Driver: `OnlineDriver.new(a, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)`, `create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)`, `start()`. Peer: `ls = Lockstep.new(2, [1, 2] as Array[int])`, `sim = Skirmish.create(true, "human", {}, Skirmish.MAP_PATH, [] as Array[int])`; `ls.send` calls `peer_order.accepts(text)` and appends tick frames only to `a.inbox`; `ls.submit({"type": "choose_faction", "faction": "china"})`, then `ls.start(sim.snapshot())` (the driver's `start` order). End: `a.peer = null`.
  - Per frame, until `driver.over() and sim.match_over()` or 400 frames: peer `ls.receive` each of `b.poll()`; at `sim.tick() == 100` once `remove_object(4)`, `(6)`; `if ls.advance(sim): ls.finish_tick(sim.tick(), sim.snapshot() if ls.wants_snapshot(sim.tick()) else null)`; once `sim.match_over()`, one `over` through `peer_order.accepts` only (never delivered: the relay ends `over`); then `driver.step(); driver.drain()`, and at `driver.current().tick == 100` once the same removals on `driver.pump.live()`. At frame 20 the driver submits a move for its own unit and one for entity 999; at frame 40 the peer submits a move for its own unit.
  - Checks: fixture "both sides removed at tick 100"; "PH both end the match": `driver.over() and sim.match_over()`; "PH hash rows equal through the end": `driver._lockstep.hash_rows() == ls.hash_rows()` with at least 4 rows (0, 30, 60, 90); "PH command logs equal": `Lockstep.log_lines(driver._lockstep.command_log()) == Lockstep.log_lines(ls.command_log())`, at least 3 lines; "PH same end tick and digest": `driver.record().tick == sim.tick() and driver.record().digest == StateHash.digest(sim.snapshot())`; "PH every frame of both sides is legal at the relay": `a.order.refusals` and `peer_order.refusals` empty; one `over` each.
  - Per-frame order: peer first, then driver; if the "removed at tick 100" fixture check fails (the driver took 99 and 100 in one call), put the driver first; both orders failing it is BLOCKED. Never change a check to make it pass.
- [ ] **Step 2:** `ONLY(t9, test_ph_driver_matches)` exit 0 (characterization). Mutation proof: `_tick_job` with `wants_snapshot(_next_tick)` instead of `_next_tick + 1` → exit 1 (rows differ); revert, prove.
- [ ] **Step 3:** `STATIC(t9)`; per-task review loop; commit.

### Task 10: Nested cache freeze, warm-up from the freeze list

**Files:** Modify: `definitions.gd` (comments :119-120, `freeze_caches` :121-122, new `cache_names`), `sim_pump.gd` (`_warm_and_freeze` :105-113). Test: `test_sim_pump.gd`.

**Interfaces:** `Registry.cache_names() -> Array[String]` (`assign` from `_named_caches().keys()`). `freeze_caches()` makes each cache and every Dictionary or Array inside it read-only, recursively (`static func _freeze(value: Variant) -> void`). Comment `:119-120` becomes one line on why (a lazy insert or write after the warm-up fails loudly instead of racing SB5a's worker); the "shortcut: top level only" line goes. `sim_pump.gd`: `static func _warm_reach(id: String) -> void` = today's `if not CombatDefinitions.weapon(CombatDefinitions.profile(id).get("weapon", "")).is_empty(): Combat.reach_of(id)` (`sim_pump.gd:111`); `static func _warmers() -> Dictionary` = `{"unit": Registry.unit_view, "building": Registry.building_view, "profile": Registry.profile_view, "radius": CombatDefinitions.radius, "reach": _warm_reach}` (static Callables from a preloaded const are not verified on 4.7: fall back to `Callable(Registry, "unit_view")` and the like); `_warm_and_freeze` loops `for name in Registry.cache_names(): for id in units + buildings: _warmers()[name].call(id)`, so a cache added to the freeze list without a warmer errors at every pump start.

- [ ] **Step 1: Test** `test_ph_nested_cache_freeze`: `_pump()`; for every id in `Registry.units() + Registry.buildings()`, each non-empty `unit_view`, `building_view`, `profile_view` → "PH start freezes every cached view (%d views)": all `is_read_only()`, count > 0. `Registry.add_test_kind("ph_probe", <rifle row>)` → "PH a test kind resets to writable caches": `not Registry.unit_view("ph_probe").is_read_only()`; `Registry.clear_test_kinds()`.
- [ ] **Step 2:** `ONLY(t10red, test_ph_nested)` exit 1.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `SUITE(t10)` exit 0 (a write into a cached view anywhere prints an error and fails the suite: BLOCKED, Review Focus 5), `TRACES(t10)`; `STATIC(t10)`.
- [ ] **Step 5:** Mutation proofs: `_freeze` without recursion → `ONLY(t10m1, test_ph_nested)` exit 1; a sixth entry `"probe": {}` in `_named_caches` → `ONLY(t10m2, test_sim_pump)` exit 1 (no warmer; red by error line, as designed); revert, prove each.
- [ ] **Step 6:** Per-task review loop; commit.

### Task 11: Static check: any pump access outside the drivers, per-file counts

**Files:** Modify: `tools/test_sim_boundary.py` (`LIVE_READ` :45, `screen_files` :93-94, `test_screen_reads_no_live_sim` :156-159).

**Interfaces:**
- `SCAN_EXCLUDED = ("game/scripts/simulation/", "game/scripts/debug/", "game/scripts/lab/", "game/scripts/net/headless_client.gd")`; `scanned_files(root) -> list[Path]`: every `game/scripts/**/*.gd` whose posix path does not start with an excluded entry; replaces `screen_files` (the live-read test scans it too).
- `PUMP_ACCESS = re.compile(r"\.pump\b(?:\s*\.\s*\w+)?|\bpump\s*\.\s*\w+|\bget\(\s*[\"']pump[\"']\s*\)")` (the `\.pump\b` branch catches a pump held under another name, `var p: SimPump = driver.pump`); `pump_accesses(path, text) -> list[str]` (`[]` for `game/scripts/match/sim_pump.gd`; comments stripped with `strip_comment`).
- `PUMP_COUNTS: dict[str, int]` for `offline_driver.gd` and `online_driver.gd`, pinned to what `pump_accesses` returns on this task's tree, cross-checked with `rg -c '\bpump\s*\.'` (8 and 8 at `6ae89cd`; Tasks 3-8 change them). Every other scanned file: 0.

- [ ] **Step 1: Tests:** `test_pump_access_flagged` (`driver.pump.current().tick` in `hud.gd` → `[".pump.current"]`; `var p = driver.pump` → `[".pump"]`; `pump . post(job)` flagged; `get("pump")` flagged; `SimPump.Note`, `pump_count`, a comment not flagged); `test_pump_access_counts_pinned` (each scanned file's count equals `PUMP_COUNTS.get(path, 0)`, message names file and count); `test_pump_counts_files_exist`; `test_scan_covers_scripts` (`match_screen.gd`, `playtest_overlay.gd`, `launcher.gd` in, `simulation.gd`, `headless_client.gd` out).
- [ ] **Step 2:** `PY(t11red)` exit 1 (new names missing), then implement, `PY(t11)` exit 0.
- [ ] **Step 3:** Mutation proof: add `var t: int = driver.pump.current().tick` to `hud.gd` → `PY(t11m1)` exit 1 naming `hud.gd 1`; revert, prove.
- [ ] **Step 4:** `sh tools/run_python_checks.sh > <abs $L>/t11-pychecks.log 2>&1; echo "exit=$?"` exit 0; per-task review loop; commit.

### Task 12: Profiled team-load row through `post` and `drain`

**Files:** Modify: `game/benchmarks/run_profile.gd` (`_run` :22-47, `_team_match` :129-147), `tools/run_benchmark.sh:31`, `tools/run_profile.sh:17`, `tools/perf_record.py:37`, `tools/test_perf_charts.py:50`.

**Interfaces:**
- `_team_match`: `var zone: int = Profiler.begin(); TeamMatch.step(sim); Profiler.end(&"team.tick", zone)` (a profiler zone, not `_harness()`, which turns the profiler off, `run_profile.gd:54-58`); before its `_phase`, store `_direct_ms = _zone_mean(&"team.tick") + _zone_mean(&"view_state")`, `_direct_end_tick`, `_direct_status`.
- `_team_match_pump()`, run right after `_team_match()` (outside `only_new`, so both `done` counts grow by one): `SimPump.new(TeamMatch.create())`, `start()`; each tick a `Job` with `bots` = every `TeamMatch.SEATS` seat, zones `pump.post` and `pump.drain` around the calls, `_view.set_view(pump.current().view, _no_selection)`, `Profiler.end_tick()`; label `team_match_pump`; same warm-up and end rule as `_team_match`. Inside the sampled window (after `WARMUP`) count drained notes and stepped ticks. Then print `PROFILE_PUMP team_match end_tick=<final tick> status=<s> window_ticks=<n> notes=<n> direct_ms=%.4f pump_ms=%.4f extra_ms=%.4f extra_pct=%.2f` (`pump_ms` = `pump.post` + `pump.drain` means). `push_error` (fails the run) when `notes != window_ticks`, or `end_tick` or `status` differs from the direct row.
- `_zone_mean(zone: StringName) -> float`: sum of `Profiler.series(zone)` / `Profiler.ticks()`.
- `PROFILE COMPLETE 10` → `11` in `run_benchmark.sh`, `run_profile.sh`, `perf_record.py` `MARKERS`, the `test_perf_charts.py` fixture.
- Expected side effect: `perf_record.py`'s `HANDOFF` regex (`:44`, `_headless_handoff`) records a new `team_match_pump:profile` plumbing row at 14c; Task 13b's `performance.md` sentence names it.

- [ ] **Step 1:** `PY(t12red)` exit 1 after only the fixture edit (marker test), then the marker edits → `PY(t12)` exit 0.
- [ ] **Step 2:** Implement. `uptime`; `sh tools/run_profile.sh > <abs $L>/t12-profile.log 2>&1; echo "exit=$?"` with `run_in_background: true` (two team matches; wait for the notice) → exit 0, no `ERROR:` line, `PROFILE COMPLETE 11`, one `PROFILE_PUMP` line whose `end_tick` and `status` equal the `PROFILE_END team_match ticks=` and `status=` values. Record the line in the ledger. Nothing is written to `perf-history.csv` here.
- [ ] **Step 3:** `STATIC(t12)`, `sh tools/run_shell_checks.sh > <abs $L>/t12-shell.log 2>&1; echo "exit=$?"` exit 0; per-task review loop; commit.

### Task 13a: Docs: contract, spec and core chapters

**Files:** `docs/reference/sim-interface.md` (Pump section; Commands-in sequence line; Advance line; status line; `:69` preview "at most once per step that ran" → once per step call, on its last job). Spec `docs/superpowers/specs/2026-11-15-sim-boundary-design.md`: API listing (`post` `:106`, `record` `:111`, `recorder` `:112`), "Slots and notes" (`:123-127`, "Today four Slot objects"), Verification item 4 (`:191`, "the freeze is shallow … until Pump hardening"), the row's exit state (`:205`), and every other line naming Pump hardening as future (`rg -n 'Pump hardening' <spec>`). Guide chapters `01-big-picture` (slots, `record`, `recorder`), `04-the-tick` (offline refused post, online preview, `take`/`finish_tick`), `10-determinism-and-replays` (stamp on request), `11-multiplayer` (refusals, frame order), each with its `Checked against` footer on the branch tip; `09-ai` only if a passage names `recorder()` or the stamp.

- [ ] **Step 1:** Edit, keeping each chapter's style (payoff first; terms explained where they appear). Link, do not duplicate numbers.
- [ ] **Step 2:** Link and anchor check by hand on the changed docs; `sh tools/check_public.sh > <abs $L>/t13a-public.log 2>&1; echo "exit=$?"`. Coordinator commits (review after 13b).

### Task 13b: Docs: presentation, performance, testing, status

**Files:** guide `05-presentation` (playtest wiring: `close_match`, header without log), `12-performance-and-platforms` (pump row), `13-testing-and-tooling` (static check, `relay_frame_order.gd`, reference test, `test_ph_*`), each with its footer. `docs/reference/performance.md` (one sentence: `team_match_pump:profile` is a report-only plumbing row, recorded by `perf_record.py` from the `PROFILE team_match_pump` lines). `docs/STATUS.md` F32 (`post` part done, rest open) and F35 (closed); `docs/packages.md` item 6 text (done on branch, not merged); `docs/STATUS.md` night 6 row: Pump hardening implemented on branch `pump-hardening` (gate result), not merged. Keep the P2.3a clauses and file lists main added (`6854ff5`) in the guide 05 and 13 footers; add the Pump hardening clause and files beside them.

- [ ] **Step 1:** Edit as 13a.
- [ ] **Step 2:** Link and anchor check by hand; `python3 tools/roadmap.py` (regenerates the README block), then `python3 tools/roadmap.py --check`; `CHECKS(t13)` (`CHECKS PASSED 5`).
- [ ] **Step 3:** Fresh Opus (high) docs review over 13a and 13b (code claims against the branch), `<abs $L>/t13-review.md`; fixes by a fresh implementer; commit.

### Task 14: Gate (short subagents, in order)

- [ ] **14a checks:** `CHECKS(gate)` (`CHECKS PASSED 5`); `SUITE(gate)` (`TESTS PASSED`, cases = 1141 (1122 at `07f0c59` + 19 `test_ph_*`: T2 2, T3 3, T4 2, T5 1, T6 4, T7 3, T8 2, T9 1, T10 1, minus any parked task's cases)); `sh tools/run_team_match.sh > <abs $L>/gate-team.log 2>&1; echo "exit=$?"` (pinned line); untouched-path diff against `6854ff5` empty.
- [ ] **14b netplay:** `lockstep.gd` runs in every headless client, so all 15 CI scenarios (`ci.yml:156`: match, rematch, left-mid, perturb, relay-down, maps, map-mismatch, kill, stall, spike, version, proxy-clean, proxy-burst, proxy-reset, proxy-blackhole) plus `silent`: `NET(gate, <s>)` each `NETPLAY PASSED`; then `EQUAL(gate)`. `relay-term` is not in CI and is skipped, as at SB4.
- [ ] **14c benchmark (alone):** `uptime`; `PERF_LABEL="Pump hardening" sh tools/run_benchmark.sh > <abs $L>/gate-bench.log 2>&1; echo "exit=$?"` with `run_in_background: true` (label per Global Constraints when loaded). Exit 0; `PROFILE COMPLETE 11`; the ledger row records itself (`perf_record.py`, `perf_chart.py`), including the new `team_match_pump:profile` plumbing row; copy the `PROFILE_PUMP` line and the `uptime` at start and end into the ledger. Exceeded rows other than the accepted combat `open`, `dense`, `hordes300` are a stop; a 14c stop does not block 14d and Task 15.
- [ ] **14d reviews:** the coordinator dispatches the six gate reviewers (Model routing) with the diff scope `main...HEAD`, the plan, this file's ledger; each writes `<abs $L>/gate-<reviewer>.md`; the ledger gets each finding count. An empty or one-line report is a failed review: a second reviewer with a narrower brief.

### Task 15: Review fixes (short subagent)

- [ ] **Step 1:** Fix P1 and P2 findings test-first; record rulings for the rest. Re-run what the fixes touch: `ONLY` of the touched suites, `SUITE(fix)`, `TRACES(fix)`, `STATIC(fix)`, `CHECKS(fix)`; netplay 14b when `lockstep.gd` or `online_driver.gd` changed; 14c when `run_profile.gd` or `sim_pump.gd` changed. Footers re-pointed to the final tip.
- [ ] **Step 2:** Resume record to the final state; coordinator commits. **Stop gate.**

## Stop gate and stop conditions

Stop gate after Task 15: report implemented, verified and pending; notify the user; end. Never ruled on, always parked for the owner:

- any digest, trace or pin moving (Global Constraints);
- a weakened or removed assertion, or a test edit outside "Allowed test edits";
- a contract change to `docs/reference/sim-interface.md` beyond the row (Global Constraints, Contract);
- a budget exceeded beyond the three accepted combat rows, or `run_benchmark.sh` exit 1;
- an existing case red under the frame-order rule or the nested freeze (Task 7, Task 10);
- Task 12's `push_error`: the pump row's end tick, status or note count differs from the direct row;
- Task 9: both per-frame orders fail the "removed at tick 100" fixture;
- a mutation proof still green after one strengthening round (below);
- a red check twice under host load (below);
- the resume record disagreeing with the tree.

Rulings that apply to every task (proposed from the plan reviews, confirmed by the owner, user 2026-11-18):

- **Red under host load:** a red check, scenario or benchmark line while `uptime` shows load above 2.5 gets one rerun, `uptime` before each run in the ledger. Green on the rerun: recorded as "flake under load", go on. Red twice: stop. Red at load 2.5 or below: an ordinary unexpected red (Opus diagnosis first).
- **Mutation proof stays green:** the test does not guard. The implementer adds checks to the new test (never removes one, never swaps or skips the mutation) once and reruns the proof; still green is a stop.
- **Parked task:** the coordinator sets its changes aside with `git stash push --include-untracked -m park-t<N>-pump`, records the entry's SHA (`git stash list --format='%H %gs'`) in the ledger and never pops it, so the next task starts from the last commit. Tasks that need it park too (9 needs 7); the others go on (7 parked: 8, 10, 11, 12 go on; 10 parked: 11, 12 go on). Tasks 13a-15 run on what is committed and name the parked tasks.

Owner items after the gate: merge decision; rendered rerun owed after a merge (`game/scripts/match/` changed); an evening benchmark rerun if 14c ran under load; the SB4 owner check still owed (if it finds a bug, this branch's commits are re-checked against the fix; user, 2026-11-18).

## Owner answers

All six plan choices answered (user, 2026-11-18); the tasks are written for them:

1. `finish_tick` with a tick that is not the last sent plus one, or after the lockstep ended, ends the match with a protocol error (Task 6).
2. `take` with an out-of-order tick ends the match, quiet takes included (Task 6).
3. The out-of-order `finish_tick` fixtures (`test_lockstep.gd` L19, `test_sim_pump.gd`) become sequential, assertions unchanged: an allowed test edit, not a stop condition (Task 6).
4. Online quit and window close: the one end-the-match call stops the pump only; transport closing stays as today (Task 5).
5. The gate adds the player-experience reviewer (Task 14d).
6. `record()` gets the command log through `Job.want_log` / `Note.log`, like `want_digest` (Task 4).

## Notes for SB5a

- `record()` rider (user, 2026-11-18, with answer 6; not implemented here): after the worker is joined or faulted, `query()` runs inline on the caller, so `record()` still returns log and digest.
- The natural match end records on a pump that is not stopped (ordering table); SB5a decides whether that record waits for the worker.

## Run setup

Hybrid start in an attended session (user, 2026-11-18): no night settings; the owner is remote and approves prompts by phone; the handoff says "hybrid start", which night-run Start step 3 requires. Foreign Godot processes of the P2.3a session do not stop the run (Global Constraints, Benchmarks). For a later night start, the proposed settings copy (`night-settings.proposed.json`, private, never the live file) carries the allow rules this plan needs: `Edit(//<abs $W>/**)`, `Bash(cd <abs $W>*)`, `Bash(mkdir -p <abs ~>/projects/wargrid-overnight-work/pump*)`, `Bash(WARGRID_REPLAY_TRACE=<abs $L>/*)`, `Bash(NETPLAY_OUT=<abs $L>/*)`, `Bash(git stash list:*)`. Already allowed: `WARGRID_TEST_ONLY=*`, `PERF_LABEL=*`, `godot`, `uptime`, `cmp`, `git stash push --include-untracked -m park-t*`, the `sh tools/run_*.sh` checks, `python3 tools/compare_replays.py`, `python3 tools/roadmap.py`.
