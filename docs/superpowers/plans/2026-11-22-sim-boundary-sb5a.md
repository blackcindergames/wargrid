# SB5a Worker mode, the thread: Implementation Plan

**Status:** draft (agent, 2026-11-22); the three placement questions are answered ("Owner answers"); the plan itself is not approved and has had no readiness review. Approving does not start implementation: the run starts from its handoff (private, `sb5a-build-prompt.txt`). 

> **For agentic workers:** run rules: [milestone prompt](../../milestone-prompt.md) and, unattended, [night run](../../night-run.md#coordinator-rules). One fresh subagent per task, each starting from the SB5a resume record in [sim boundary verification](../../reference/sim-boundary-verification.md) (Task 1 adds the section). Every task subagent also reads "Global Constraints", "Beside P2.3b", "Determinism notes", "Same-tick and ordering cases" and "Stop conditions" (`rg -n '^## ' <plan>`).

**Goal:** `SimPump` can run every job on its own thread, native and headless, switched on by `WARGRID_SIM_THREAD=1` and off by default. With the switch off nothing changes; with it on, digests, traces and pins are equal, the scene suite is green, a fault ends the match within 5 s, and a loopback online match with one worker client plays to its end.

**Architecture:** One code path. `post`, `drain`, `query`, `record`, `stop` keep their signatures. In worker mode `post` hands the job to a queue (`Mutex` plus `Semaphore`, at most `MAX_QUEUED` jobs not yet published, the running one included). The worker thread runs the same `run_job`, publishes the note and a fresh slot under the lock, and `drain` takes them under the same lock. `query` waits for its own note. A failure on the worker (null result, wrong thread, logged error, stall, dead thread) becomes one main-side `failure()` reason at the next `drain`. Drivers ask for room before they build a job or take a lockstep tick.

**Tech stack:** Godot 4.7.2 typed GDScript (`Thread`, `Mutex`, `Semaphore`, `Logger`), suite runner `game/tests/run_tests.gd`, Python checks under `tools/`, POSIX sh tools. `relay/`, `protocol/` and `game/scripts/simulation/` untouched.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md): the API block, "One code path", the SB5a row of "Package cut" and [SB5a inherits](../specs/2026-11-15-sim-boundary-design.md#sb5a-inherits). Decisions: [critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18) (owner-thread check approved; peer of a faulted client sees "Your opponent left"), [packages](../../packages.md#night-lane) item 6 (Deck waiting-line rider; pairing-guard and catch-up riders). Background (private): the sim boundary critique, changes 4, 10, 21 to 31 and findings A1 to A8, C2, C4. Riders from night 8: [play on after a leave](2026-11-21-play-on-after-a-leave.md) Review Focus 1 and 7. Template: [Pump hardening plan](2026-11-18-pump-hardening.md).

## One page

- **What a player notices:** nothing, with the switch off, which is every build this package ships. What a player gets is SB6's decision, which needs this thread to measure. With the switch on, a Steam Deck player in the Firefox team row would see the simulation leave the main thread (inline misses 49 % of frames there; the spike's worker missed 0 %, `ow/worker-threads/results.md:70-77`, private).
- **What would refute it:** a digest that differs between inline and worker on any of the four loads, or a scene case that fails only under the switch. The first evidence is headless: `test_sim_pump.gd`'s existing 900-tick digest cases run once per mode (Task 3), before any driver changes.
- **Look in existing data first:** the spike (`~/projects/wargrid-wt-worker`, private worktree) produced equal digests inline and worker on three loads (`docs/reference/worker-thread-spike-verification.md:62` lists the check as open). Task 1 reads its logs if they are on the machine. Either way the headless check runs again on this tree.
- **First slice:** Tasks 2 and 3 (the switch and the queue, with the pump suite in both modes). Everything after that hardens the slice.
- **Out:** the threaded Web preset, COOP/COEP headers, the pause-menu toggle and the launcher off position (SB5b); Deck decision rows, the go rule's limits, `Engine.max_physics_steps_per_frame` (SB6); interpolation for uneven tick arrival (P4); overtaken-order wording (P2.3a); bot seats in the scene client (M9).

## Beside P2.3b

This package is built in parallel with P2.3b Build from the dock and merges after it, so it never goes ahead of a day package (user, 2026-11-20). P2.3b's plan (2026-11-21, on the unpushed branch `p2-3b-build-from-the-dock`) owns `orders.gd`, the HUD and dock scripts, the input half of `match_screen.gd`, the F33 rider in `offline_driver.gd` (a standing preview request on every job) and its T2b hunk in `online_driver.gd`.

- **SB5a never edits** `game/scripts/match/orders.gd`, `game/scripts/presentation/hud*.gd`, the dock or command-card scripts, or `match_screen.gd`'s `_input`, `_unhandled_input` and selection functions. `git diff <base> --stat -- game/scripts/match/orders.gd game/scripts/presentation/hud.gd` is empty at every task.
- **The preview path stays as it is.** SB5a carries `Job.preview` and `Note.preview` through the queue and does not reorder or redesign the preview code in either driver (`offline_driver.gd:24-25, 61-74, 84, 137-142`; `online_driver.gd:35-36, 119-140, 189-194` at `83d00e8`). Task 14 adapts to F33 and T2b after P2.3b merges.
- **Driver hunks stay small and named:** offline `step` (room check) and `drain` (failure read); online `step` (room before `take`), `drain` (failure read) and `notice` (night-8 guard). Each is listed per task.
- **The pending-build flag** is cleared through the existing `orders.reset()` (`orders.gd:86`, called from `match_screen.gd:532`), called from the screen when the driver reports a failure. No new `orders.gd` code.
- **Shared documents wait:** `docs/STATUS.md`, `docs/packages.md`, `docs/reference/perf-history.csv`, the README roadmap and guide chapters 05 and 13 are edited only in Task 15, after Task 14 has merged `main` with P2.3b in it. Before then, notes go to the verification file only.
- **If P2.3b has not merged when Task 13 is green**, the run stops at Task 13, reports, and waits. It does not merge P2.3b's branch, rebase onto it, or push.

## Global Constraints

- **Base:** worktree `$W`, branch `sim-boundary-sb5a` from `main` `83d00e8` (a cloud session uses its own branch name; the resume record names it). Logs `$L` = `~/projects/wargrid-overnight-work/sb5a/logs`. `$W`, `$L`, `~` are notation: commands use absolute paths; tracked files use `~/...`, never a typed absolute path (`sh tools/check_public.sh`).
- **Nothing pinned moves, in either mode:** the four suite traces (replay, economy, combat, team), `run_netplay.sh match` and `rematch` (terminal tick pinned in `run_netplay.sh`), the `TEAM MATCH` line pinned in `run_team_match.sh`, IC1, IC2, OD1, S3, RB8. Any of them moving is a stop; never re-pin.
- **Allowed test edits (exactly these):** `BaseScene.tick` and the other scene tick helpers wait for an idle pump (bounded) before the drain (Task 9); the Profiler cases Task 1 lists are skipped under the switch by name, with a counted skip line (Task 9); `test_sb4_refused_post_ends_match` becomes "a refused post without room keeps the tick", because room-before-take replaces its premise (Task 7, inherits list, user, 2026-11-18); new `test_sb5a_*` cases and their helper classes. No assertion is removed or loosened otherwise.
- **Untouched paths:** `relay/`, `protocol/`, `game/scripts/simulation/`, `game/scripts/net/headless_client.gd`, `seat_sim.gd`, `wire.gd`, `relay_transport.gd`, `game/scripts/match/orders.gd`, `game/scripts/presentation/` except `perf_overlay.gd`, `web/`, `game/export_presets.cfg`.
- **Inline unchanged:** with the switch off, `sim_pump.gd` behaves exactly as at base: no `Thread` is created, `busy()` is false, `post` runs the job at once. Every task ends with the full suite and `TRACES` in the default mode.
- **Contract:** `docs/reference/sim-interface.md` changes only by what this plan names: the worker-mode rule per pump method, `has_room()`, `mode()`, the failure reasons. Anything more is a stop.
- **Tests:** new cases `test_sb5a_*` (no existing case or suite file contains `test_sb5a_`), appended to their suite's `cases()` list. They use the [simulation interface](../../reference/sim-interface.md), the pump and the drivers; `pump.live()` only while `busy()` is false. Fault and stall cases print error lines on purpose, so they live outside the suite (Task 6).
- **Red is a failed named check.** A task whose tests need a new field or method first adds it bare and behaviour-neutral (Step 0). A red run with `suite failed to load`, `SCRIPT ERROR` or a parse error is not red: fix Step 0 or the test, then rerun.
- Typed GDScript (tests exempt from `untyped_declaration` only); comments one line, WHY only; edits with the Edit tool only. Subagents never commit, push, merge or open a window; the coordinator makes one local commit per green task. Never push or merge without the owner.
- **Commands** (Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker; on failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:|NETPLAY FAILED' <log>`), run from `$W`:
  - `SUITE(<tag>)`: `WARGRID_REPLAY_TRACE=<abs $L>/replay-<tag>.tsv WARGRID_ECONOMY_REPLAY_TRACE=<abs $L>/economy-<tag>.tsv WARGRID_COMBAT_REPLAY_TRACE=<abs $L>/combat-<tag>.tsv WARGRID_TEAM_REPLAY_TRACE=<abs $L>/team-<tag>.tsv sh tools/run_tests.sh > <abs $L>/<tag>-suite.log 2>&1; echo "exit=$?"` → `TESTS PASSED <n>`.
  - `WSUITE(<tag>)`: the same with `WARGRID_SIM_THREAD=1` in front and `w<tag>` in every file name.
  - `ONLY(<tag>, <filter>)` and `WONLY(<tag>, <filter>)`: `WARGRID_TEST_ONLY=<filter> sh tools/run_tests.sh`, the second with `WARGRID_SIM_THREAD=1`.
  - `TRACES(<tag>)`: `python3 tools/compare_replays.py` of each trace against `base`, team with `--interval 200 --rows 100`; each `REPLAYS MATCHED`.
  - `NET(<tag>, <s>)`: `NETPLAY_OUT=<abs $L>/<tag>-np-<s> sh tools/run_netplay.sh <s>` → `NETPLAY PASSED`; `NETEQ(<tag>)` compares `s1.tsv` and `cmp`s `s1.cmd` of `match` and `rematch` against base.
  - `CHECKS(<tag>)`: `sh tools/run_checks.sh` → `CHECKS PASSED 5`.
- **Benchmarks run alone:** `uptime` and `pgrep -fl godot` first. Above load 2.5 the row is labelled `Sim boundary SB5a (host under load)` and an evening rerun is owed. Another session's Godot never stops a task, and the run never kills a process it did not start. Never loosen a budget.
- **Mutation proofs:** `git add <file>`; mutate with the Edit tool; run the named `ONLY` or `WONLY` → exit 1; revert with the Edit tool; `git diff --exit-code -- <file>` → exit 0.
- **No visible window, no sound.** No `sh tools/run_game.sh`, no `fly`, no `deploy_web.sh`, no `gh pr`.

## Model routing and reviews

- Implementer per task: Sonnet. Diagnosis of an unexpected red: Opus (high) first.
- **Per-task review (simulation boundary and netplay diff, AGENTS.md step 3):** after `GREEN`, one fresh Opus (high) reviewer with paths only (this plan's task heading, "Same-tick and ordering cases", `git diff -U30 HEAD`, `git status --short`) writes `<abs $L>/t<N>-review.md` and names, per new test, the production change that makes it fail. High and medium findings get one fix round, test-first; the rest go to the ledger.
- **Gate (Task 16):** one fresh Opus whole-branch review (its brief names, per new test, the production change that makes it fail; an empty or one-line report is a failed review and gets a narrower second one); Gemini 4 Neon (high) through `agy` as the second reviewer (the branch touches netplay and will pass 500 lines), skipped and said so when `agy` is missing or out of quota; the [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md) on the one player-facing line (the F3 overlay's mode text, Task 2).

## Decided for you

Implementation and measurement details, reversible on the owner's word.

1. **`MAX_QUEUED = 2` counts the running job.** A post is refused while two jobs are posted and not yet published. This bounds answer latency to two jobs and keeps the worker fed. The spec left this open (API block, "whether it counts the running job is not decided"). SB6 measures caps 1 and 2 (critique question 6).
2. **The stall limit is counted in physics frames:** `STALL_FRAMES = 150`, 5 s at 30 Hz, counted by `drain` while a job is in flight and no note arrives. A device suspend stops frames, so it cannot trip the limit (critique A5).
3. **Bounded waits for `query` and `stop` are in wall time:** `WAIT_MSEC = 5000`. The main thread is the waiter, so frames do not advance while it waits.
4. **Effective mode** is one static, `SimPump.worker_wanted()`: `WARGRID_SIM_THREAD == "1"`, `OS.has_feature("threads")`, and no pump has failed in this process. A pump decides its mode once, in `_init`, and `mode()` returns `"worker"` or `"inline"`.
5. **The mode field** is `"sim": "inline" | "worker"` in the playtest header (`match_screen._header`) and the desync report (`online_driver._report`), plus `Sim: worker` or `Sim: inline` on the F3 overlay's first line. `mode` already means offline or online there.
6. **Profiler:** the Profiler cases run inline only and are skipped by name under the switch. That is ten cases at `83d00e8`, listed by Task 1. The Profiler gets no mutex: it is debug tooling, and a lock would cost every zone call.
7. **Fault flag:** an error-count `Logger` (`OS.add_logger`) in debug builds only (`OS.is_debug_build()`), counting errors per thread id. A job that logged an error on the worker thread fails the pump. A release build detects no script fault: online, the 30-tick digest is the backstop; offline there is none (critique A3).
8. **`record()` after a failure:** if the worker thread is no longer alive, `record()` reads the log inline as today's failed path does (last shown tick and view, no digest). If it is still alive (stalled), the record has an empty log and `end` reads `sim pump stalled`. Both drivers already write `end` from `failure()`. After a clean `stop()` (joined), `query()` runs inline on the caller (rider of Pump hardening answer 6).
9. **The natural match end** (`playtest_overlay.end_match`) records through `query`, which waits for the worker. No extra stop is needed (Pump hardening "Notes for SB5a").
10. **Catch-up rider:** `online_driver.gd` now takes at most `CATCH_UP_STEPS = 2` ticks per frame with a credit of 4 (`:10-11`), not the "input delay + 1 = 5" the rider names. Task 1 records the fps below which a client falls behind (15 fps). SB5a changes nothing here unless Task 10's worker loopback falls behind where inline keeps up, which is a stop.
11. **The pending-build flag** is cleared with `orders.reset()` when the driver first reports a failure (Beside P2.3b).
12. **`worker_ab.py`** comes from the spike (`~/projects/wargrid-overnight-work/worker-threads/`, private), trimmed to the metrics the bench prints. If the source is not on the machine, Task 12 writes it fresh against the bench's line format.

## Review Focus

1. **Lock scope.** The worker holds the lock only to publish (append the note, set READY) and to take the next job; `drain` holds it only to take notes and swap slots. `run_job` never runs under the lock. A lock held across `run_job` passes every digest check and freezes frames, so Task 8's free-running case measures `drain`'s lock wait.
2. **Nothing read across threads without the lock:** `_failure` is written on main only; the worker reports through fields on the note (`note.fault`, `note.thread_ok`) or through a `_worker_state` read under the lock. Every `failure()` cause has a test.
3. **`live()` in worker mode** asserts `not busy()` in debug builds and returns the simulation. Release builds have no asserts, which is why the owner-thread check lives in `run_job`.
4. **Stop and leak.** `stop()` sets the quit flag, posts the semaphore, waits up to `WAIT_MSEC`, then joins; after a failure it never joins, and the stalled thread leaks (the spec's "infinite loop in a job" risk). Task 5 checks that every scene test ends with zero live worker threads.
5. **Online room before `take`.** A tick whose packets `take` consumed can never be posted again, so the room check comes first; a refused post after a successful room check is impossible in one thread (main), and stays a protocol end as a guard.
6. **Two drains in one frame.** Tests and `_drain_notes` may drain twice before the worker publishes: the second drain returns nothing and leaves the slots unchanged (inline: the same).

## Determinism notes

- The simulation runs on one owner thread for a pump's lifetime: the worker in worker mode, main inline. Jobs run in post order; `run_job` is unchanged, so command, bot and step order are unchanged. `determinism-rules.md:14` is reworded from "the main thread" to "one owner thread" (Task 15).
- `query` and `record` are jobs in the same FIFO, so a record never reads mid-step.
- Caches stay frozen before the thread starts (`_warm_and_freeze` in `start`, on the caller); the worker reads them only.
- Packed arrays and dictionaries in a published note or slot are never written after publishing, on either side (answer 11).

## Same-tick and ordering cases

No new simulation command. Changed flow:

| Operation | Against | Expected | Test |
|---|---|---|---|
| `post` with two jobs unpublished | worker busy | false; job not queued; `failure()` empty | `test_sb5a_post_refused_when_full` |
| offline `step` without room | queue and preview request | kept, nothing posted, `_next_tick` unchanged; next frame posts both | `test_sb5a_offline_waits_for_room` |
| online `step` without room | lockstep tick | `take` not called; the tick is taken on the next frame | `test_sb5a_online_room_before_take` |
| online `step` with room for one of two catch-up ticks | second tick | taken next frame; preview on the one job that was posted | same |
| `drain` with no note published | slots | `current()` and `previous()` unchanged; empty array | `test_sb5a_empty_drain_keeps_slots` |
| `drain` with two notes | slots | `current()` is the second job's slot, `previous()` the old current | both-mode run of `test_ph_fresh_slot_per_job` |
| `query` while a tick job runs | that job | query runs after it; its note is not in the drain queue; slots unchanged | `test_sb5a_query_waits_behind_jobs` |
| `query` on a stalled worker | caller | returns null after `WAIT_MSEC`; pump failed with the stall reason | fault process `stall_query` |
| `record()` at the natural end, jobs in flight | log | waits for them; digest equals an inline record of the same commands | `test_sb5a_record_waits_for_queue` |
| `stop()` with a job in flight | thread | joined within `WAIT_MSEC`; later posts false; later `query` runs inline | `test_sb5a_stop_with_job_in_flight` |
| `stop()` after a failure | thread | returns at once, never joins | fault process `stall_stop` |
| restart or rematch, jobs undrained | old pump | stopped; its notes never reach the new driver state | `test_sb5a_restart_drops_old_notes` |
| `run_job` on a thread other than the owner | pump | `push_error`, pump failed `owner thread`, nothing published | fault process `wrong_thread` |
| error logged inside `step()` on the worker | pump | failed `fault`; the faulty job's note and slot not shown | fault process `logged_error` |
| job longer than `STALL_FRAMES` | pump | failed `stall`; offline freeze card; online ends with `ended_protocol` | fault process `stall_offline`, `stall_online` |
| worker thread not alive with a job queued | pump | failed `dead thread` at the next drain | fault process `dead_thread` |
| pump failure online | lockstep, transport | lockstep ended with reason `sim pump failed: <reason>`; transport closed in the same frame; peer sees "Your opponent left", no result recorded | `test_sb5a_online_failure_ends_and_closes` |
| `left` arrives while waiting | `notice()` | no index error when `waiting_for()` is empty (night 8 rider 7) | `test_sb5a_notice_waiting_empty` |
| note pairing with `_taken` empty | foreign job | protocol end, not accepted silently (SB4 rider) | `test_sb5a_pairing_rejects_foreign_note` |
| `live()` while busy (debug) | caller | assert fires; tests never do it | none (assert) |

## Files

| File | Change | Task |
|---|---|---|
| `game/scripts/match/sim_pump.gd` | `worker_wanted()`, `mode()`, `has_room()`; thread, queue, lock, semaphore; publish and drain under the lock; `query` through the worker; `stop` bounded; stall and dead-thread watch; owner-thread check; error logger; failure reasons | 2-6 |
| `game/scripts/match/pump_logger.gd` (new) | `Logger` subclass counting errors per thread id | 6 |
| `game/scripts/match/offline_driver.gd` | `step` checks `has_room()`; `drain` reads `failure()` | 7 |
| `game/scripts/match/online_driver.gd` | room before `take`; failure ends the lockstep and closes the transport; pairing guard; `notice` guard; `sim` field in `_report` | 2, 7 |
| `game/scripts/match/match_screen.gd` | `sim` in `_header`; `orders.reset()` on the first failure; F3 mode line feed | 2, 7 |
| `game/scripts/presentation/perf_overlay.gd` | the `Sim:` word on the first line | 2 |
| `game/tests/test_sim_pump.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`, `test_base_scene.gd` | both-mode cases, tick helper, skip list | 3-10 |
| `game/tests/run_tests.gd` | a named skip list under the switch, counted in the summary (the runner has no skips today) | 9 |
| `game/tests/pump_faults.gd` (new), `tools/run_pump_faults.sh` (new) | fault and stall cases, one process each | 6 |
| `tools/run_worker_digests.sh` (new) | the four loads inline and worker, `cmp` of DIGEST lines | 11 |
| `game/benchmarks/run_match_bench.gd` (new), `game/scenes/match_bench.tscn` (new), `tools/worker_ab.py` (new), `tools/test_worker_ab.py` (new) | real match screen on the pump, both modes, go-rule metrics | 12 |
| `.github/workflows/ci.yml` | one suite run under `WARGRID_SIM_THREAD=1` on Linux and Windows | 9 |
| `tools/test_sim_boundary.py` | `PUMP_COUNTS` updated by exact deltas | 7 |
| docs | Task 15 | 15 |

---

### Task 1: Base, counts and line map

**Files:** `docs/reference/sim-boundary-verification.md` (new `## SB5a` section: resume record, ledger, base counts, line map). Nothing else.

- [ ] **Step 1:** HEAD is `sim-boundary-sb5a` on `83d00e8` plus the plan commit; `git diff 83d00e8 --stat -- game tools relay protocol` is empty. `uptime`, `pgrep -fl godot` into the ledger.
- [ ] **Step 2:** `SUITE(base)`; `ONLY` per suite: `test_sim_pump`, `test_online_scene`, `test_skirmish_scene`, `test_base_scene`; `NET(base, match)`, `NET(base, rematch)`; `sh tools/run_team_match.sh`; `CHECKS(base)`. A red base is a stop.
- [ ] **Step 3:** Counts and lists: `cases()` lengths of the four suites; `PUMP_COUNTS` (10 and 9 at `83d00e8`); every `Profiler.enabled = true` case under `game/tests` that ticks a scene (ten at `83d00e8`: `test_base_scene` `test_one_snapshot_per_refresh`, `test_ticks_take_no_snapshot`; `test_online_scene` `test_sb1_online_snapshot_per_hash_tick`; `test_skirmish_scene` `test_one_snapshot_per_refresh`, `test_sb1_idle_offline_ticks_take_no_snapshot`, `test_sb1_submit_takes_no_snapshot`, `test_sb1_economy_input_reads_shown`, `test_sb1_combat_input_reads_shown`, `test_sb3_over_stops_refreshing`, `test_sb3_one_view_per_tick`); every scene tick helper (`rg -n 'static func tick|func _tick' game/tests`); the catch-up floor (Decided 10).
- [ ] **Step 4:** Spike evidence: if `~/projects/wargrid-wt-worker` or `~/projects/wargrid-overnight-work/worker-threads/` exists, record its DIGEST lines per load and the path of `worker_ab.py`; otherwise write "not on this machine".
- [ ] **Step 5:** P2.3b state: `git log --oneline main -- game/scripts/match/orders.gd | head -3` and whether `p2-3b-build-from-the-dock` has merged. Record it.
- [ ] **Step 6:** Line map of every cite in this plan, re-found by symbol. `sh tools/check_public.sh` → `PUBLIC CHECK PASSED`. Commit.

### Task 2: The switch, the mode, and where it shows

**Files:** `sim_pump.gd`, `match_screen.gd` (`_header` `:189-190`), `online_driver.gd` (`_report` `:300-307`), `perf_overlay.gd` (`refresh_text`). Test: `test_sim_pump.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`.

**Interfaces:** `static func worker_wanted() -> bool` (Decided 4); `static var _failed_in_process: bool` set by the first failure in either mode; `func mode() -> String`, fixed in `_init`. In this task `mode()` is computed and shown, but the pump still runs inline in both modes.

- [ ] **Step 1: Tests.** `test_sb5a_mode_from_switch`: with a test hook that overrides the environment read, the switch on gives `"worker"`, off gives `"inline"`, and the switch on after `_failed_in_process` gives `"inline"`. `test_sb5a_header_names_mode`: offline `playtest_header().sim == "inline"`; online `_report().sim` likewise. `test_sb5a_f3_shows_mode`: the overlay's first line contains `Sim: inline`.
- [ ] **Step 2:** red; **Step 3:** implement; **Step 4:** `SUITE(t2)`, `TRACES(t2)`, `CHECKS(t2)`; **Step 5:** mutation: `worker_wanted` ignores `_failed_in_process` → `ONLY(t2m, test_sb5a_mode)` red; **Step 6:** review, commit.

### Task 3: The queue (first slice)

**Files:** `sim_pump.gd`. Test: `test_sim_pump.gd`.

**Interfaces:** worker mode creates `Thread`, `Mutex`, `Semaphore` in `start()` after `_warm_and_freeze` and job 0 (job 0 runs on the caller, as the spec says). `post` (main): refuse when stopped, failed or `not has_room()`; append the job under the lock; post the semaphore; return true. The worker loop: wait, take one job under the lock, check the quit flag, `run_job` outside the lock, publish note and fresh slot under the lock, check the quit flag again. `drain` (main): under the lock take the notes and swap slots as inline. `has_room()`: inline true unless stopped or failed; worker `_unpublished < MAX_QUEUED`. `busy()`: worker `_unpublished > 0`. The owner thread is recorded at `start` (`OS.get_thread_caller_id()` on the worker's first job); `run_job` keeps its static signature and the pump checks the caller id in `_note_for`.

- [ ] **Step 0:** `has_room()` returning true; `MAX_QUEUED` constant. `ONLY(t3s0, test_sim_pump)` green.
- [ ] **Step 1: Tests.** A helper `_modes()` returns `["inline", "worker"]`, and `_pump(mode)` builds a pump in that mode through the test hook. Every existing digest and slot case in `test_sim_pump.gd` that the pump drives (the 900-tick bot match, the 150-tick battle, the 300-tick team run, `test_ph_fresh_slot_per_job`, the SB3 rotation cases) gains a worker-mode run through a wait-for-idle drain helper, with the same expected values. New: `test_sb5a_post_refused_when_full` (a gate job that blocks the worker on a test semaphore; two posts accepted, the third refused, `failure()` empty, release the gate, both notes drain in order); `test_sb5a_empty_drain_keeps_slots`; `test_sb5a_worker_runs_off_main` (the note's recorded thread id differs from main in worker mode and equals it inline).
- [ ] **Step 2:** `ONLY(t3red, test_sb5a_)` red on named checks only.
- [ ] **Step 3:** implement.
- [ ] **Step 4:** `SUITE(t3)`, `TRACES(t3)`; `WONLY(t3w, test_sim_pump)` green; `CHECKS(t3)`.
- [ ] **Step 5:** mutations: (a) publish the slot before the note under two separate lock sections → `WONLY(t3m1, test_sim_pump)` red, or record it as not caught and hand it to Task 8; (b) `has_room` ignores the running job → `WONLY(t3m2, test_sb5a_post_refused)` red.
- [ ] **Step 6:** review, commit. **First evidence reached:** the pump digests are equal in both modes. Report it in the ledger.

### Task 4: `query` and `record` through the worker

**Files:** `sim_pump.gd` (`query` `:98-101`, `record` `:103-112`). Test: `test_sim_pump.gd`, `test_skirmish_scene.gd`.

**Interfaces:** worker `query(job)`: post it as a query job (no slot) behind the queue, wait on its own reply semaphore up to `WAIT_MSEC`, return its note. A query does not count against `MAX_QUEUED` (it blocks the caller, so at most one exists) and its note never enters `drain`. On timeout the pump fails with `stall` and returns null. After a clean `stop()` the query runs inline (Decided 8). `record()` keeps its body; it only gains the stalled-thread branch.

- [ ] **Step 1: Tests.** `test_sb5a_query_waits_behind_jobs`; `test_sb5a_record_waits_for_queue` (post 40 jobs, `record()` at once, digest equals an inline pump's record after the same 40); `test_sb5a_query_after_stop_runs_inline`; the offline `match_log` and online `start()` (job 0 digest query) in worker mode equal inline.
- [ ] **Steps 2-6:** red, implement, `SUITE(t4)` + `TRACES(t4)` + `WONLY(t4w, test_sim_pump)`, mutation (query note appended to `_notes` → red), review, commit.

### Task 5: Stop, stall and dead thread

**Files:** `sim_pump.gd` (`stop` `:123-124`, `drain`). Test: `test_sim_pump.gd`, `test_base_scene.gd` (the live-thread count).

**Interfaces:** `stop()`: set quit, post the semaphore, wait up to `WAIT_MSEC` for the loop to finish, then `wait_to_finish()`; after a failure only set quit and return. `drain` counts frames with a job in flight and no new note; at `STALL_FRAMES` the pump fails with `stall`. `drain` also checks `_thread.is_alive()` while `_unpublished > 0`, and fails with `dead thread`. `static func live_workers() -> int` counts started and not joined threads, for tests.

- [ ] **Step 1: Tests.** `test_sb5a_stop_with_job_in_flight`; `test_sb5a_stop_is_idempotent`; `test_sb5a_restart_drops_old_notes` (offline `_restart_world` and online rematch with undrained jobs); every scene suite's teardown checks `SimPump.live_workers() == 0` under the switch (a check added to the shared helper, counted once per case). The stall itself runs in Task 6's process.
- [ ] **Steps 2-6:** red, implement, `SUITE(t5)` + `TRACES(t5)` + `WONLY(t5w, test_sim_pump)`, mutation (`stop` returns without joining on the clean path → live-worker check red), review, commit.

### Task 6: Fault flag and the fault process

**Files:** `pump_logger.gd` (new), `sim_pump.gd`, `game/tests/pump_faults.gd` (new), `tools/run_pump_faults.sh` (new). Test: the new script.

**Interfaces:** `PumpLogger extends Logger`: `_log_error` increments a per-thread count under its own mutex; the pump installs one logger per process (debug builds) and compares the worker's count before and after each job; a rise sets `note.fault`. Main turns `note.fault` into `failure() == "fault in job at tick N"` at drain, and shows neither the note's events nor its slot. `pump_faults.gd` is a `SceneTree` script, one case per process (`--case=<name>`), each printing `FAULT CASE <name> PASSED` or `FAILED <why>` and calling `quit()` on every path. Cases: `logged_error`, `wrong_thread`, `stall_offline`, `stall_online` (match ends within 5 s of wall time with `STALL_FRAMES` driven by a fake frame counter), `stall_query`, `stall_stop`, `dead_thread`. `run_pump_faults.sh` runs each with a 20 s timeout, greps the marker, and prints `PUMP FAULTS PASSED 7`. It joins `tools/run_checks.sh` only if that keeps the checks under a minute; otherwise it is a separate gate line.

- [ ] **Steps 1-6:** the cases first (red: the markers are missing), implement, `sh tools/run_pump_faults.sh` → `PUMP FAULTS PASSED 7`, `SUITE(t6)` + `TRACES(t6)`, mutation (the logger compare skipped → `logged_error` red), review, commit. `sh tools/run_shell_checks.sh` passes.

### Task 7: Drivers: room, failure, online end, riders

**Files:** `offline_driver.gd` (`step` `:59-74`, `drain` `:76-89`), `online_driver.gd` (`step` `:110-127`, `drain` `:137-145`, `_finish_job` `:147-158`, `notice` `:332-340`), `match_screen.gd` (the first-failure hook beside `_drain_notes`), `tools/test_sim_boundary.py` (`PUMP_COUNTS`). Test: `test_skirmish_scene.gd`, `test_online_scene.gd`.

**Interfaces:** offline `step` returns early, keeping the queue and request, when `not pump.has_room()`; `drain` calls `_read_failure()` after `pump.drain()`. Online `step` breaks the catch-up loop before `take` when `not pump.has_room()`; `drain` reads `pump.failure()`, and on a new reason calls `_lockstep.set_protocol_error("sim pump failed: " + reason)`, then `_transport.close()` in the same frame. A refused post after a room check stays a protocol end. `_finish_job` with `_taken` empty and a note whose tick moved is a protocol end (SB4 rider); a note from `adopt`'s job 0 is not passed to it. `notice` returns `"Waiting for players"` when `waiting_for()` is empty. The screen calls `orders.reset()` once when `driver.failure()` first turns non-empty.

- [ ] **Step 1: Tests.** `test_sb5a_offline_waits_for_room`; `test_sb5a_online_room_before_take`; `test_sb5a_online_failure_ends_and_closes` (loopback through `FakeTransport` with the relay frame-order rule: the peer driver reads `opponent_left()` and `rematch_line() == "Your opponent left"`, and records no result); `test_sb5a_pairing_rejects_foreign_note`; `test_sb5a_notice_waiting_empty`; `test_sb5a_failure_clears_pending_build`. `test_sb4_refused_post_ends_match` becomes "a full pump keeps the tick for the next frame" (allowed edit). The room cases use a test-only cap (`pump.cap_for_test(n)`) so they run inline.
- [ ] **Steps 2-6:** red, implement, `SUITE(t7)` + `TRACES(t7)` + `NET(t7, match)` + `NET(t7, rematch)` + `NETEQ(t7)`, `WONLY(t7w, test_online_scene)`, mutation (room check after `take` → `test_sb5a_online_room_before_take` red), review, commit.

### Task 8: Races the idle-waiting suite cannot see

**Files:** `test_sim_pump.gd`. No production change expected; a red here is a finding for Task 3's code.

- [ ] **Step 1:** `test_sb5a_free_running_equals_inline`: worker mode, no wait for idle, 900 bot ticks posted whenever there is room and drained every loop iteration. The notes' ticks, issued results and a hash of every drained slot's view (`StateHash.digest(slot.view)`) are compared with an inline run; `drain`'s longest lock wait is recorded in the ledger.
- [ ] **Step 2:** `test_sb5a_publish_drain_orders`: no thread, a stepper that runs the pump's publish and drain halves in every order for up to three jobs (the enumerated interleavings); each order keeps "after `drain`, `current().tick` is the last note's tick" and "no note lost or doubled".
- [ ] **Step 3: Lock proof.** Remove the lock from `drain` (mutation) → `WONLY(t8m, test_sb5a_free_running)` red within three runs. If it stays green, strengthen the case once (more jobs, a slower drain); still green is a stop.
- [ ] **Step 4:** `SUITE(t8)`, `WONLY(t8w, test_sim_pump)`; review, commit.

### Task 9: The scene suite under the switch, and CI

**Files:** `test_base_scene.gd` (`tick` `:69-71`), the other tick helpers Task 1 listed, the skip list, `.github/workflows/ci.yml`.

- [ ] **Step 1:** Tick helpers: physics, then wait for `not pump.busy()` with a bound of `WAIT_MSEC` (fail the case on timeout), then drain. Inline the wait returns at once. Skip list: the ten Profiler cases, each printing `SKIP <case> (Profiler inline only)` under the switch; the runner counts skips and prints them in the summary.
- [ ] **Step 2:** `SUITE(t9)` (inline, unchanged count), `WSUITE(t9)` → `TESTS PASSED <n>` with the skip count equal to the list. Any other red under the switch is a finding: diagnose (Opus) before any fix; a fix that is not in the pump or drivers is a stop.
- [ ] **Step 3:** CI: one job step `WARGRID_SIM_THREAD=1 sh tools/run_tests.sh` after the existing suite on Linux and Windows. No new trace upload. `sh tools/run_checks.sh` passes.
- [ ] **Step 4:** review, commit.

### Task 10: Loopback online with one worker client

**Files:** `test_online_scene.gd`, `tools/run_netplay.sh` only if a scenario switch is needed (agent call; prefer a scene test).

- [ ] **Step 1:** `test_sb5a_worker_peer_against_inline_peer`: two scene drivers through `FakeTransport` with the relay frame-order rule, seat 1 in worker mode, seat 2 inline, the SB4 reference script through two hash ticks and the match end. The command logs, the hashes at every hash tick and the end status are equal.
- [ ] **Step 2:** `NET(t10, match)` and `NET(t10, rematch)` with `WARGRID_SIM_THREAD=1` for the scene client if `run_netplay.sh` runs one (else: recorded "headless clients only, switch has no effect").
- [ ] **Step 3:** catch-up floor (Decided 10): the worker client keeps up at the same frame rates as inline in the test's frame script; falling behind earlier is a stop.
- [ ] **Step 4:** `SUITE(t10)`, review, commit.

### Task 11: Digests on four loads, both modes

**Files:** `tools/run_worker_digests.sh` (new).

- [ ] **Step 1:** For skirmish3v3, team, hordes300 and late, run the headless load once inline and once with `WARGRID_SIM_THREAD=1` through the pump (`run_profile.gd`'s pump row path), print `DIGEST <load> tick=<t> <hash>`, and `cmp` the two files; print `WORKER DIGESTS MATCHED 4`.
- [ ] **Step 2:** `sh tools/run_shell_checks.sh`; commit. The script is an exit-evidence line, not part of `run_checks.sh`.

### Task 12: Match bench and `worker_ab.py`

**Files:** `game/benchmarks/run_match_bench.gd`, `game/scenes/match_bench.tscn`, `tools/worker_ab.py`, `tools/test_worker_ab.py`.

- [ ] **Step 1:** The bench loads the real match screen on Ashfall with 3v3 bots (team load) in either mode, runs a scripted input track (box selects and moves every 2 s, one build every 20 s), headless or rendered, and prints one `MATCH BENCH` line per run: mode, ticks, `tick_rate`, refused posts, the longest run of refusals, pace over the worst two-second window and the average, the share of ticks shown 1, 2 and 3 frames after the previous one, drains with two ticks, answer latency in frames (p50, p95), main frame CPU p95 and p99, and the end digest.
- [ ] **Step 2:** `worker_ab.py report <dirs>` tabulates the lines per arm (median and range). Its test covers a missing field, an arm with one run, and equal or unequal digests across arms.
- [ ] **Step 3:** one headless run per mode on the dev machine into the ledger (report-only; no limits until SB6). `sh tools/run_python_checks.sh` passes. Commit.

### Task 13: Deck waiting-line rider (over SSH, no owner needed)

Rider (user, 2026-11-17): with SB4's quiet take, "Waiting for player N" shows only once the in-flight jobs drain. SB5a measures it in its online loopback test with a 1 s hold on the Deck under team load.

- [ ] **Step 1:** If the Deck answers SSH (`ssh -o BatchMode=yes <deck> true`), copy a native Linux debug export of this tree, run Task 10's loopback with team load and a 1 s hold on seat 2's packets, 20 holds, worker mode, and record per hold the delay from the hold start to the first frame that shows the line, plus whether the line showed at all.
- [ ] **Step 2:** Verdict per the rider: p99 at or below about 150 ms and the line shown in every hold: done. Otherwise the wall-clock waiting line (about 1 s, [M9 drops Q12](../../questions/next-m9-drops.md)) moves into this package as Task 13b, and the run stops for the owner to start it. This is already the owner's rule.
- [ ] **Step 3:** If the Deck does not answer: record "not run, Deck unreachable" and carry it to the owner list. The gate does not wait for it.
- [ ] **Step 4:** cleanup on the Deck (remove the copied export only); ledger; commit.

### Task 14: Merge `main` after P2.3b

Runs only when P2.3b is on `main`; until then the run stops here (Beside P2.3b).

- [ ] **Step 1:** `git merge main` (asks the owner). Conflicts are expected only in `offline_driver.gd` and `online_driver.gd` around the preview request (F33, T2b) and in `match_screen.gd` near `_drain_notes`. Keep P2.3b's preview rule and re-apply SB5a's room and failure hunks around it.
- [ ] **Step 2:** `SUITE(t14)` against a new base trace set taken on `main` after P2.3b (P2.3b's re-pin, if any, is the reference; SB5a moves nothing on top), `WSUITE(t14)`, `NET(t14, match)`, `NET(t14, rematch)`, `sh tools/run_pump_faults.sh`, `sh tools/run_worker_digests.sh`, `CHECKS(t14)`. F33's "preview on every job" also runs in worker mode: `WONLY(t14w, preview)`.
- [ ] **Step 3:** ledger; commit the merge.

### Task 15: Docs

- [ ] `docs/reference/sim-interface.md`: the worker-mode rule per pump method, `has_room()`, `mode()`, failure reasons.
- [ ] `docs/reference/determinism-rules.md:14`: "one owner thread".
- [ ] Spec: the API block refreshed from `sim_pump.gd`; the SB5a row's state; the inherits list ticked item by item with the test that covers each.
- [ ] Guide chapters `01-big-picture`, `04-the-tick`, `05-presentation`, `12-performance-and-platforms`, `13-testing-and-tooling`, each with its `Checked against` footer.
- [ ] `docs/STATUS.md` night 6 row (one status line), `docs/packages.md` item 6, `python3 tools/roadmap.py`.
- [ ] One fresh Opus (high) docs review over the docs diff; one fix round. `sh tools/check_public.sh`. Commit.

### Task 16: Gate

- [ ] `CHECKS(gate)`, `SUITE(gate)` + `TRACES(gate)`, `WSUITE(gate)`, `NET(gate, match)` + `NET(gate, rematch)` + `NETEQ(gate)`, `sh tools/run_conformance.sh`, `sh tools/run_pump_faults.sh`, `sh tools/run_worker_digests.sh`.
- [ ] `PERF_LABEL="Sim boundary SB5a" sh tools/run_benchmark.sh` (runs alone). A rendered rerun is owed after the merge because `game/scripts/match/` and `perf_overlay.gd` changed (an owner item; it opens a window).
- [ ] Push the branch for CI once (pre-authorized in the handoff only); `gh run watch --exit-status`; Linux and Windows green, with the switch-on step; `sh tools/compare_local_traces.sh <run id>` on the Mac.
- [ ] Reviews (Model routing): Opus whole-branch, Gemini through `agy`, player-experience reviewer on the F3 line. Fixes in one round, test-first; the ledger records what was left and why.
- [ ] Report: implemented, verified (with the tree each check ran on), pending, Decided for you, owner items.

## Stop conditions

Never ruled on, always parked for the owner:

- any digest, trace or pin moving, in either mode;
- a weakened or removed assertion, or a test edit outside "Allowed test edits";
- an edit to a path under "Beside P2.3b" or "Untouched paths";
- a contract change beyond "Contract";
- a red under the switch whose fix is outside the pump and the drivers (Task 9);
- the lock proof staying green after one strengthening round (Task 8);
- the worker client falling behind earlier than inline (Task 10);
- the Deck rider failing (Task 13): the run stops before Task 13b;
- P2.3b not merged when Task 13 is done (Task 14);
- a task not green after two fix rounds: it parks (`git stash push --include-untracked -m park-t<N>-sb5a`, the stash SHA in the ledger, never popped). Dependent tasks park too: 4 and 5 need 3; 7 needs 5; 8, 9, 10 need 7; 11 and 12 need 3; 13 needs 10;
- a budget exceeded or `run_benchmark.sh` exit 1;
- about 100M processed tokens (`python3 tools/session_usage.py` after each task).

Red under host load (load above 2.5): one rerun, `uptime` before each in the ledger; green on the rerun is "flake under load", red twice is a stop.

## Owner answers (user, 2026-11-22)

1. **Build beside P2.3b:** yes. SB5a is built in parallel and merges only after P2.3b is on `main`, under "Beside P2.3b".
2. **Where it runs:** Tasks 1 to 11 in a cloud session; Tasks 12 and 13, and `compare_local_traces.sh` at the gate, on the Mac afterwards. A cloud session uses its own branch (Global Constraints, Base). It records "spike sources not on this machine" at Task 1 Step 4 and stops after Task 11 for the Mac part.
3. **Deck rider:** stays in SB5a (Task 13).

Still owed before a run: the owner's approval of the plan itself, and a handoff (private). Answering these questions did not start implementation.
