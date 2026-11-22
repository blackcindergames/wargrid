# SB5a Worker mode, the thread: Implementation Plan

**Status:** revision 3, draft (agent, 2026-11-22). The owner questions are answered ("Owner answers"). Two Opus readiness reviews (the first: 3 blockers, 19 should-fix, 14 nits; the second: 1 blocker, 10 should-fix, 7 nits; reports private, `sb5a-readiness-review.md`, `sb5a-readiness-review-2.md`) and the owner's two planning briefs (private) are applied; the disposition is in "Review disposition". The second review needs only a diff check against its list, not a third full review. The plan is not approved. Approving does not start implementation: the run starts from its handoff (private, `sb5a-build-prompt.txt`).

> **For agentic workers:** run rules: [milestone prompt](../../milestone-prompt.md) and, unattended, [night run](../../night-run.md#coordinator-rules). One fresh subagent per task, each starting from the SB5a resume record in [sim boundary verification](../../reference/sim-boundary-verification.md) (Task 1 adds the section). Every task subagent also reads "Labels", "Global Constraints", "Beside P2.3b", "Capacity and the full-queue trace", "Ownership", "Thread lifecycle", "Same-tick and ordering cases" and "Stop conditions" (`rg -n '^## ' <plan>`).

**Goal:** `SimPump` can run every job on one worker thread, native and headless, switched on by `WARGRID_SIM_THREAD=1`, off by default. With the switch off nothing changes. With it on: digests are equal to inline on four loads, the scene suite is green with every scene pump in worker mode, a fault ends the match within 5 s, and a loopback online match with one worker client plays to its end with equal hashes.

**Architecture:** One code path; the inline pump stays the reference. `post` accepts a job (responsibility for that tick passes to the pump at that instant) only when there is room. The worker runs the same `run_job` outside the lock and publishes the note and a fresh slot under the lock. `drain` takes them under the same lock. `query` waits for its own reply with a deadline. A worker-side failure travels as a marker in the queue and becomes one main-side `failure()` reason. Drivers ask for room before they build a job or take a lockstep tick.

**Tech stack:** Godot 4.7.2 typed GDScript (`Thread`, `Mutex`, `Semaphore`, `Logger`), suite runner `game/tests/run_tests.gd` with `tools/run_tests.sh`, Python checks under `tools/`, POSIX sh tools. `relay/`, `protocol/` and `game/scripts/simulation/` untouched.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md): the API block, "One code path", the SB5a row of "Package cut", [SB5a inherits](../specs/2026-11-15-sim-boundary-design.md#sb5a-inherits) and [Verification](../specs/2026-11-15-sim-boundary-design.md#verification). Decisions: [critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18); [packages](../../packages.md#night-lane) item 6. Background (private): the sim boundary critique (changes 4, 10, 21 to 31; findings A1 to A8, C2, C4), the Pump hardening "Notes for SB5a" and its open items (`sim-boundary-verification.md:448`). Riders from night 8: [play on after a leave](2026-11-21-play-on-after-a-leave.md) Review Focus 1 and 7. Template: [Pump hardening plan](2026-11-18-pump-hardening.md).

## Labels

Every decision below carries one label, so a reviewer can tell them apart:

- **[owner]**: an owner decision, with its date; changing it needs the owner.
- **[proposed]**: an agent decision, reversible on the owner's word ("Decided for you" in AGENTS.md).
- **[probe]**: an engine or platform behaviour not yet verified; the task that settles it is named. **[probed]**: verified in this planning session (Godot 4.7.2 Linux editor build, headless, scratch scripts outside the repository).

## Target revision

- Code base: `main` `83d00e8` (checked 2026-11-22: `origin/main` is still `83d00e8`; no SB5a or worker code on any branch; `p2-3b-build-from-the-dock` is not on GitHub). Task 1 checks again before any task is assigned, and Task 14 moves the base to `main` with P2.3b in it.
- Prerequisites at that base: Pump hardening merged (fresh slot per job, null job fails the pump, `close_match`, `record()` with the log, nested freeze); night 8 Play on after a leave merged; the Deck no-threads arms measured before this plan ([packages](../../packages.md#night-lane) item 6: none helped) **[owner, 2026-11-19]**.
- Scheduling: SB5a is night lane only and never ahead of a day package **[owner, 2026-11-20]**; it is built beside P2.3b and merges after it **[owner, 2026-11-22]**.

## One page

- **What a player notices:** nothing; every build this package ships has the switch off. It gives SB6 a thread to measure. On the Steam Deck in Firefox the team load misses 49 % of frames inline and 0 % with the spike's worker (`ow/worker-threads/results.md:70-77`, private).
- **What would refute it:** a digest that differs between inline and worker on any load, or a scene case that fails only with worker pumps. First evidence (headless): `test_sim_pump.gd`'s 900-tick digest cases in both modes (Task 3).
- **Existing data first:** the spike's DIGEST lines, if they are on the machine (Task 1 Step 4). The check `docs/reference/worker-thread-spike-verification.md:62` is still open, so this tree runs it either way.
- **First slice:** Tasks 2 and 3.
- **Out:** threaded Web preset, COOP/COEP, pause-menu toggle, launcher off position, release Web fault probe (SB5b); go-rule limits, Deck decision rows, `Engine.max_physics_steps_per_frame` (SB6); uneven-arrival interpolation (P4); overtaken-order wording (P2.3a); scene-client bot seats (M9).

## Beside P2.3b

P2.3b's plan (2026-11-21, branch `p2-3b-build-from-the-dock`, not yet pushed; file list taken from its handoff, private, `p2-3b-build-prompt.txt`, until the branch is readable) owns `orders.gd`, `hud.gd`, `hud_model.gd`, the dock and command-card scripts, `match_screen.gd`'s input and selection functions, the F33 rider in `offline_driver.gd` (standing preview request on every job) and its T2b hunk in `online_driver.gd`.

- **SB5a never edits:** `game/scripts/match/orders.gd`, `game/scripts/match/hud.gd`, `game/scripts/match/hud_model.gd`, the dock and command-card scripts, and `match_screen.gd`'s `_input`, `_unhandled_input`, `_select_kind`, `_hud_selection`. Guard at every task: `git diff <base> --stat -- game/scripts/match/orders.gd game/scripts/match/hud.gd game/scripts/match/hud_model.gd` is empty.
- **The preview code stays as it is** in both drivers (`offline_driver.gd:24-25, 61-74, 84, 137-142`; `online_driver.gd:35-36, 119, 126, 129-140, 189-194` at `83d00e8`). In particular `online_driver.gd:119` (`last`) is not changed: when room runs out mid catch-up, the preview request stays and rides on the next frame's job (one frame later, nothing lost; tested in Task 7).
- **Named hunks SB5a may add:** `match_screen.gd` `_exit_tree` (stop the driver), a first-failure hook beside `_drain_notes`, `_header` (the `sim` field) and the F3 mode wiring (`_perf.extra` at `:129-132`, refreshed in `_restart_world`); both drivers' `create` (stop the old pump before the new simulation is built); offline `step` (room) and `drain` (failure read); online `start` (null query), `step` (room before `take`), `drain` (failure read and end), `_report` (null query, `sim` field), `notice` (night-8 guard), new `failure()` and `sim_mode()`.
- **The pending-build flag** is cleared through the existing `orders.reset()` (`orders.gd:86`, already called at `match_screen.gd:532`). It also clears selection, placement and attack-move, visible under the freeze card; the player-experience reviewer looks at that, and Task 14 checks whether P2.3b changed `reset()`.
- **Shared documents wait:** `docs/STATUS.md`, `docs/packages.md`, `docs/reference/perf-history.csv`, the README roadmap and guide chapters 05 and 13 are edited only in Task 15, after Task 14. Before then notes go to the verification file only.
- **If P2.3b has not merged when Task 13 is done**, the run stops and reports. It never merges, rebases onto or pushes P2.3b's branch.

## Global Constraints

- **Base and logs:** worktree `$W`, branch `sim-boundary-sb5a` from `main` `83d00e8`; a cloud session uses its own branch name, recorded in the resume record. Logs `$L`: on the Mac `~/projects/wargrid-overnight-work/sb5a/logs`; in a cloud session the session's scratch directory, with every ledger figure copied into the verification file before the session ends (cloud logs are lost with the container). Notation only: commands use absolute paths; tracked files use `~/...`, never a typed absolute path (`sh tools/check_public.sh`).
- **Nothing pinned moves:** the four suite traces, `run_netplay.sh match` and `rematch`, the `TEAM MATCH` line, IC1, IC2, OD1, S3, RB8. These come from direct-sim suites and inline headless clients, so they guard the inline path only. Worker evidence is the both-mode pump digests (Task 3), the four-load digests (Task 11) and the worker loopback (Task 10).
- **Allowed test edits (exactly these):**
  1. Scene drive sites go through two helpers in `test_base_scene.gd`: `BaseScene.tick` (physics, wait for an idle pump, drain) and `BaseScene.settle(main)` (wait for an idle pump, bounded). `BaseScene.publish` waits after its post. Each direct `_physics_process(`, `driver.step()`, `pump.post(` or drain site that Task 1 lists gets one `settle` call after its post. No expected value changes.
  2. Cases that run two or more physics frames before one drain on purpose (Task 1 lists them, e.g. `test_two_tick_frame_keeps_earlier_results`, `test_sb3_online_two_notes`, `test_sb4_three_callbacks_one_drain`, the catch-up cases) and the ten Profiler cases run with inline pumps under the switch, through the mode hook. Each is named in one list and counted like a skip (Task 9).
  3. `test_sim_pump.gd`'s existing cases gain a mode loop through `_pump(mode)`, in three groups that Task 1 lists: (a) pump-only cases without a query, in Task 3; (b) query and record cases, in Task 4; (c) driver cases (pumps built by `OnlineDriver.adopt` or `OfflineDriver`), in Task 7. Cases that assert a synchronous failure (`test_ph_null_job_fails_pump`, `test_sim_pump.gd:240-271`; Task 1 lists any others) stay inline under the switch (counted as forced, Task 9) and get a worker counterpart instead. `SimPump.new` in that file stays inline unless the hook asks for worker; `_pump(mode)` and the loop helpers stop every pump they built at the end of the case.
  4. New `test_sb5a_*` cases, their helper classes, and the `test_runner.gd` case for the runner hunk.
  5. One hunk in `run_tests.gd`'s per-case loop (`:100-116`, beside the `AudioSettings` cleanup at `:108`): after each case, `SimPump.stop_live_for_test()`, `reset_process_latch_for_test()` and `force_mode_for_test("")`; under the switch a case that left a live worker fails (`FAIL: live sim worker after <case>`), unless it is on the "stops on its own" list (empty at the start). No existing case is edited for the latch.
  No assertion is removed or loosened. `test_sb4_refused_post_ends_match` stays unchanged.
- **Untouched paths:** `relay/`, `protocol/`, `game/scripts/simulation/`, `game/scripts/net/` (all of it: `headless_client.gd`, `seat_sim.gd`, `wire.gd`, `relay_transport.gd`, `lockstep.gd`), the Beside-P2.3b files, `game/scripts/presentation/` except `perf_overlay.gd`, `web/`, `game/export_presets.cfg`, `game/benchmarks/run_profile.gd`.
- **Inline unchanged:** with the switch off, no `Thread` is created, `busy()` is false and `post` runs the job at once. Every code task ends with `SUITE` and `TRACES` in the default mode.
- **Contract:** `docs/reference/sim-interface.md` gains exactly this, and anything more is a stop. Pump: `has_room()`, `mode()`, `static worker_wanted()`, the worker-mode rule per method (the Ownership table), the failure reasons. Drivers: `sim_mode()`, online `failure()`. Playtest header and desync report: the `sim` field. Test seams, test-only and named as such: `SimPump.force_mode_for_test(mode)`, `reset_process_latch_for_test()`, `cap_for_test(n)`, `frame_source` (a `Callable`), `gate_publish_for_test(semaphore, where)` with `where` = `"before_publish"` (between `run_job` and the lock) or `"inside_publish"` (after the note is appended, before READY and the count, inside the lock), `live_workers()`, `stop_live_for_test() -> int`, `pump_counts()`; constants `MAX_QUEUED`, `STALL_FRAMES`, `STALL_MSEC`, `WAIT_MSEC`; a `clock` seam beside `frame_source`.
- **Tests:** new cases `test_sb5a_*` (no existing case or file contains `test_sb5a_`), appended to `cases()`. Simulation interface, the pump and the drivers only; `pump.live()` only while `busy()` is false. Fault and stall cases print error lines on purpose, so they run in their own processes (Task 6). Test waits are bounded (`try_wait` loops with a deadline), so a red case fails instead of hanging until the runner's watchdog.
- **Red is a failed named check.** New members first appear bare and behaviour-neutral (Step 0). A red run with `suite failed to load`, `SCRIPT ERROR` or a parse error is not red.
- Typed GDScript (tests exempt from `untyped_declaration` only); one-line WHY comments; edits with the Edit tool only. Subagents never commit, push, merge or open a window; the coordinator makes one local commit per green task. Never push or merge without the owner.
- **Commands** (Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker; on failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:|NETPLAY FAILED' <log>`), from `$W`:
  - `SUITE(<tag>)`: `WARGRID_REPLAY_TRACE=<abs $L>/replay-<tag>.tsv WARGRID_ECONOMY_REPLAY_TRACE=<abs $L>/economy-<tag>.tsv WARGRID_COMBAT_REPLAY_TRACE=<abs $L>/combat-<tag>.tsv WARGRID_TEAM_REPLAY_TRACE=<abs $L>/team-<tag>.tsv sh tools/run_tests.sh > <abs $L>/<tag>-suite.log 2>&1; echo "exit=$?"` → `TESTS PASSED <n>`.
  - `WSUITE(<tag>)`: `WARGRID_SIM_THREAD=1` and four trace paths named `w<tag>`; also → `SIM PUMPS worker=<w> forced=<f> inline=<i>` with `w > 0` and `i == 0` (`forced` counts every pump whose mode came from `force_mode_for_test`, including the inline-under-switch list and the inline halves of mode loops), and `SIM PUMPS LIVE 0`.
  - `ONLY(<tag>, <filter>)` / `WONLY(<tag>, <filter>)`: `WARGRID_TEST_ONLY=<filter> sh tools/run_tests.sh`, the second with the switch.
  - `TRACES(<tag>)`: `python3 tools/compare_replays.py` of each trace against `base`, team with `--interval 200 --rows 100`; each `REPLAYS MATCHED`.
  - `NET(<tag>, <s>)`: `NETPLAY_OUT=<abs $L>/<tag>-np-<s> sh tools/run_netplay.sh <s>` → `NETPLAY PASSED`; `NETEQ(<tag>)` compares `s1.tsv` and `cmp`s `s1.cmd` of `match` and `rematch` against base.
  - `FAULTS(<tag>)`: `sh tools/run_pump_faults.sh > <abs $L>/<tag>-faults.log 2>&1` → `PUMP FAULTS PASSED <n>`.
  - `DIGESTS(<tag>)`: `sh tools/run_worker_digests.sh > <abs $L>/<tag>-digests.log 2>&1` → `WORKER DIGESTS MATCHED 4`.
  - `CHECKS(<tag>)`: `sh tools/run_checks.sh` → `CHECKS PASSED 5`.
- **Benchmarks run alone:** `uptime`, `pgrep -fl godot` first; above load 2.5 the row is labelled `(host under load)` and an evening rerun is owed. Never kill a process the run did not start. Never loosen a budget.
- **Mutation proofs:** `git add <file>`; mutate with the Edit tool; the named `ONLY`/`WONLY`/`FAULTS` → red; revert; `git diff --exit-code -- <file>` → exit 0.
- **No visible window, no sound.** No `sh tools/run_game.sh`, `fly`, `deploy_web.sh`, `gh pr`.

## Model routing and reviews

- Implementer per task: Sonnet. Diagnosis of an unexpected red: Opus (high) first.
- **Per-task review** (simulation boundary and netplay, AGENTS.md step 3): after `GREEN`, one fresh Opus (high) reviewer with paths only (task heading, "Capacity and the full-queue trace", "Ownership", "Thread lifecycle", "Same-tick and ordering cases", `git diff -U30 HEAD`, `git status --short`) writes `<abs $L>/t<N>-review.md`, naming per new test the production change that makes it fail. High and medium findings get one fix round, test-first.
- **Gate (Task 16):** one fresh Opus whole-branch review (same brief rule; an empty or one-line report is a failed review and gets a narrower second one); Gemini 4 Neon (high) through `agy`, skipped and said so when `agy` is missing or out of quota; the [player-experience reviewer](../../../.claude/agents/player-experience-reviewer.md) on the F3 mode line and the `orders.reset()` effect under the freeze card.

## Capacity and the full-queue trace

**Rule [proposed]:** `MAX_QUEUED = 2` counts accepted jobs that have not yet been published: the executing job plus the waiting ones. Queries are not counted (the caller blocks, so at most one exists) and never enter the drain queue. The spec left this open (API block). SB6 measures caps 1 and 2 (critique question 6).

- **Accepted, unfinished ticks:** at most 2. If only waiting jobs counted, it would be 3 (one executing plus two waiting); the plan does not use that rule.
- **Completed, undrained notes** are counted separately: publishing frees capacity before the main thread drains, so further physics steps in the same render frame can post again. The bound is posts per render frame: online `CATCH_UP_STEPS` (2) × physics steps per render frame (engine default at most 8) = 16; offline 8. `drain` empties them every `_process`. Task 3 tests the bound with a frame script.

**Single producer:** only the main thread calls `post`, `query`, `stop`, `has_room`, `drain`. The worker only decreases the unpublished count (publishing) or sets a failure marker. So between `has_room()` true and `post`, room can only grow. The one race is a terminal failure, handled in step 2.

**Healthy trace** (online, input delay D, ticks N, N+1, N+2):

1. The worker is running N; N+1 is waiting; unpublished = 2. Packets for N+2 arrive. Main's `step()` polls the transport, `Lockstep.receive` buffers them, the catch-up loop reads `pump.has_room()` → false and breaks **before** `take(N+2)`. Bookkeeping unchanged: `_next_tick == N+2`, `_taken == [N, N+1]`, credit not spent, `pump.failure() == ""`, the lockstep still holds N+2's packets. Test: `test_sb5a_full_pump_leaves_next_tick_in_lockstep`.
2. The worker finishes N. Under the lock, in this order: append N's note, set READY to N's slot, unpublished -= 1. Unlock. In one critical section it checks the quit flag and takes N+1 (N+1 was already counted); an empty queue with quit set exits, an empty queue without quit waits on the semaphore again. It runs N+1 outside the lock. N's note is readable by main from the unlock, and main reads it only at its next `drain`. The next `step()` sees room, calls `take(N+2)`, posts it, unpublished = 2. If the worker failed between `has_room()` and `post` (marker queued), `post` refuses. Main then reads the marker inside `post`, sets the pump's first failure reason itself, and returns false. The online driver ends the lockstep with `sim pump failed: <reason>`, not "sim pump refused tick", and closes the transport. N+2's packets are consumed, but the match is over anyway.
3. A render frame drains N and N+1 together: `_finish_job` pops `_taken` front-first, checks `note.tick == taken + 1` (N+1, then N+2), records each note's own `issued`, and calls `finish_tick` with that note's own snapshot and digest (computed inside that job). The existing end exceptions are unchanged: a note past the end with no tick movement records nothing (`online_driver.gd:151-152`), and pairing on a foreign note is a protocol end (`:153-156`). Catch-up stays at 2 ticks per physics frame with credit 4 (`:10-11`, unchanged), and stays bounded at input delay + 1 = 5 ticks per rendered frame, because own packets are sent from `drain` (accepted limit, measured, not fixed **[owner, 2026-11-22]**; Task 10). The preview rides on the `last` job as today; a pending build is cleared by its answer as today. Test: `test_sb5a_two_notes_one_frame_pair_in_order`.
4. **Leave before drain.** `leave()` ends the lockstep and closes the transport; `close_match` calls `driver.stop()` → `pump.stop()`. N, the running job, finishes and publishes; the worker re-checks quit after every job (spec: "join, at most one job"), so it exits before N+1. `stop()` drops N+1 and subtracts the one job it dropped; N's own publish brings the count to 0. Main waits for the exit acknowledgement (bounded, see "Thread lifecycle") and joins. `keep_match` then calls `record()`. After a join the pump's owner is main again, so the record's query runs inline on the caller. It returns the log and digest of the jobs that ran (through N), which agree with each other: replaying the log gives the digest. N+1's commands are lost with the leave, as the player left. The old match's notes stay in the old pump, and nothing drains them, because the screen changes scene.
5. **Restart or rematch with jobs undrained.** Both drivers' `create` now stop the old pump **before** `Skirmish.create` builds the new simulation (today `adopt` stops it after, `offline_driver.gd:36-41`, `online_driver.gd:64-76`). So an old worker never runs beside the new match's cache warm-up, or a test's `clear_test_kinds`. The driver's only reference is the new pump. The old pump's notes, and any late result, sit in the old object, which no driver or screen can reach. Tests: `test_sb5a_restart_drops_old_notes`, `test_sb5a_create_stops_old_pump_first`.

**Stalled trace** (N runs past the stall limit):

1. N is running and N+1 is waiting. The stall clock (F frames, T milliseconds) was set at the `post` that took the unpublished count from 0 to 1, and is set again at every `drain` that took at least one note while the count stays above 0; it is checked only while the count is above 0 and no failure is set (Decided 2). So an idle pump, the offline pause menu and an online wait for a slow peer can never trip it. Each `drain` first takes any published notes; a note that arrived counts, even if it was finished while the app was suspended. When **both** frames ≥ F + `STALL_FRAMES` (90, 3 s at 30 Hz) and wall time ≥ T + `STALL_MSEC` (3000) hold, main sets `failure() = "stall: job at tick N ran over 90 frames"`. Requiring both means a suspend (wall time jumps, frames stop) and a burst of catch-up frames each cannot trip it alone. Main then calls `_abandon(cause)` (see "Lifetime of a failed pump"). Offline: the freeze card shows (`FREEZE_NOTICE`). Online: the lockstep ends with `sim pump failed: stall`, the transport closes in the same frame, and the peer sees "Your opponent left" with no result recorded **[owner, 2026-11-18]**.
2. A leave during the stall, before the stall limit: `stop()` waits up to `WAIT_MSEC` (5000 ms) for the exit acknowledgement, does not get it, calls `_abandon("stall: stop waited 5000 ms")` and never calls `wait_to_finish()`. A `stop()` on a pump that is already abandoned (stall found by `drain`, `query` or the start handshake) returns at once. `record()` on a pump whose thread is still alive returns the last shown tick and view, an empty log, `digest ""`; the end text comes from `failure()`.
3. A new match after the stall runs inline (latch). If N ever returns, the worker publishes into the abandoned pump, sees quit, and exits. It never takes N+1.

## Ownership

| Method | Caller | Owns while running | Lock | Can wait for |
|---|---|---|---|---|
| `post(job)` | main only | the job until it is appended; from the unlock on, the job belongs to the worker | queue mutex, to append and count | nothing |
| `run_job` (static, via `_run_owned`) | the owner thread: main inline, before spawn and after a join; the worker in between | the simulation, the recorder, the job, the new note and slot | none: never under the queue lock | nothing |
| worker loop | the worker | nothing between jobs | the queue mutex to take a job, and again to publish | the work semaphore |
| `drain()` | main only | the taken notes and slots from the unlock on; never written again by anyone | queue mutex, to take notes, swap slots, read markers | nothing |
| `query(job)` | main only | nothing; the job goes to the worker at the unlock | queue mutex to append; the reply is read under it | its reply semaphore, as a `try_wait` poll with a `WAIT_MSEC` deadline; returns null at once on a failed pump; runs inline after a join |
| `record()` | main only | nothing | as `query` | as `query` |
| `stop()` | main only | the thread object, until it joins or abandons it; waiting jobs are dropped | queue mutex, to set quit, drop the waiting jobs and reset the count | the exit acknowledgement for at most the running job, polled up to `WAIT_MSEC` |
| `live()` | main, tests and setup only | the simulation, but only while `busy()` is false, or after a join | none | nothing; debug `assert(not busy())` |
| `has_room()`, `busy()` | main only | nothing | queue mutex (they read the unpublished count) | nothing |

- **A note becomes readable** at the publish unlock, and main reads it only through `drain` or a query reply. A query's reply never touches READY, `current()` or `previous()` (its slot is null), so `record()` or the desync query followed by `drain` keeps the shown slot.
- **Pure data across threads:** `Job`, `Note` and `Slot` hold only `int`, `bool`, `String`, `Dictionary`, `Array` and packed arrays. They hold no `Node`, `Resource`, `Callable` or `Signal`, because whichever thread drops the last reference runs the destructor. A static check enforces it (Task 3).
- **Owner thread [owner, 2026-11-18]:** the pump keeps `_owner_id`, which is the main id until spawn. The worker writes its id at loop entry and posts a start semaphore; `start()` waits for it (bounded) and stores the id. After a successful join `_owner_id` is main again. `_run_owned` compares `OS.get_thread_caller_id()` with `_owner_id` in every build. A mismatch calls `push_error`, fails the pump (`owner thread`) and publishes a failure marker. `_run_owned` is not overridable: the test seam `_note_for` sits inside it, so `failing_pump.gd` cannot bypass the check.
- **Profiler [proposed]:** the Profiler writes static dictionaries and is not thread-safe. In worker mode `start()` calls `assert(not Profiler.enabled)` (debug). The ten Profiler cases run with inline pumps under the switch (Allowed test edits 2). No mutex.
- **Two pumps at once:** while an old abandoned worker or a test's second pump runs beside the main thread, the shared static writes inside the simulation (for example `destination_allocation.last_cells_examined`) are benign debug counters. Task 1 lists them; a non-debug static write found there is a stop.

## Thread lifecycle

`Thread.wait_to_finish()` has no timeout **[probed]**, so every bounded wait is a poll on main: a deadline from `Time.get_ticks_msec()`, `try_wait()` or a flag read under the lock, and `OS.delay_usec(200)` between reads. A join happens only after the worker has acknowledged its exit.

| State | Who signals quit | Who wakes it | Who sees the exit | Who keeps its objects | Who joins |
|---|---|---|---|---|---|
| idle, asleep on the work semaphore | `stop()` sets quit under the lock | `stop()` posts the work semaphore once | the worker sets `_exited` under the lock as its last act; `stop()` polls it | the pump's self-reference (below) | `stop()`, right after it sees `_exited` |
| healthy, inside a job | the same | not needed; the worker re-checks quit after the job | the same, after it publishes that one job | the same | the same, within `WAIT_MSEC` |
| exited (loop returned or thread died) | n/a | n/a | `drain` reads `not _thread.is_alive()` while unpublished > 0 → `dead thread` failure; `stop()` sees `_exited` or a dead thread at once | the same | `stop()` joins at once (the thread has finished) |
| alive after a stall | `stop()` or the stall check sets quit | `stop()` posts the semaphore (harmless) | nobody: no acknowledgement arrives | the abandoned list, until the process exits | nobody, ever |

**Self-reference [probed]:** a `Thread`'s `Callable` does not keep a `RefCounted` owner alive. In the probe, dropping the last reference freed the object while its thread ran, and Godot printed "Could not call function on previously freed instance" and "A Thread object is being destroyed without its completion having been realized". So the pump keeps `_keep_alive = self` from spawn until a successful join, when it clears it. A failed pump moves into the abandoned list instead.

**Lifetime of a failed pump [proposed]:** every main-side stall (found by `drain`, `query`, `stop` or the start handshake, whose cause is `stall: worker did not start`) goes through one helper, `_abandon(cause)`: set quit under the lock, post the work semaphore, set the first failure reason, set the process latch, clear `_keep_alive`, append to `_abandoned`. On an abandoned pump `stop()` returns at once, `query` returns null and `record()` uses its fallback at once. `static var _abandoned: Array[SimPump]` holds every pump whose thread may still run. It keeps the pump, its `Thread`, simulation, recorder and notes alive until the process exits. Nothing reads them again; `record()` on such a pump uses only main-side copies (the last drained slot, `failure()`). The process latch makes every later pump inline. Each new pump's `start()` joins any abandoned pump whose `_exited` is set (no wait, the thread has finished) and drops it from the list. A thread still running at process exit prints Godot's "Thread object is being destroyed" line, so the fault harness judges each case by its marker and exit status only, never by the absence of error lines. An abandoned thread at process exit exited cleanly on Linux in the critique's probe (5 of 5); on Windows and macOS this is unknown **[probe, Task 6 on Linux and in CI on Windows; macOS at the Mac gate]**.

**Screen exit [proposed]:** `match_screen._exit_tree` calls `driver.stop()` after `orders._set_attack_move(false)` (the spec's "`_exit_tree` calls `stop()`"; today it calls only `detach`). `stop()` is idempotent (Pump hardening), so `close_match` followed by `_exit_tree` is safe.

## Failure channel

- **Causes and who decides:** the worker never writes `_failure`. It queues a marker (`cause`, `tick`) or sets a note flag under the lock: null result, `owner thread`, `fault` (logger count rose during the job). Main turns the first marker it sees, in `drain`, `post` or `query`, into the first failure reason. Main itself detects `stall` (frames, or a query or stop deadline) and `dead thread`. A full queue and an ordinary stop keep `failure()` empty **[owner, 2026-11-18, inherits list]**.
- **After a marker:** in the same critical section that queues its marker, the worker drops the waiting jobs, subtracts them and the failed job from the unpublished count (which is then 0), sets `_exited` and returns. `drain` drops every note after the marker and keeps the slots, so no state from an untrusted simulation reaches the screen. **Count rule, one place:** `post` adds 1; a publish or a marker subtracts its own job; `stop()` and the first marker subtract the waiting jobs they drop; so the count never goes below 0. Once `_failure` is set, `busy()` returns false and `has_room()` returns true, read before the count (a failed pump's `post` still refuses). `record()`'s fallback reads `_recorder` only after `_exited` was seen; otherwise it returns the empty log.
- **Callers:** offline `drain` calls `_read_failure()` right after `pump.drain()`, before its empty-notes return (`offline_driver.gd:78`), because a stall produces no note (freeze card). Online `drain` reads `pump.failure()`; on a new reason it ends the lockstep (`set_protocol_error("sim pump failed: " + reason)`) and closes the transport in the same frame. The online driver gains `failure()` (passthrough). Online `start()` on a null query result ends with a protocol error before any packet is sent. `_report()` on a null query writes an empty ring. The screen calls `orders.reset()` once, when `driver.failure()` first turns non-empty.
- **`query` interrupted:** if the queried job's reply is a marker, `query` returns null and the reason is already set by main. The three production callers are covered: online startup digest (`start`), final command log (`record`), desync ring (`_report`); offline `flush` is test-only and already handles null (`offline_driver.gd:102-114`).
- **Logger [proposed; attribution probed]:** `PumpLogger extends Logger`, installed once per process in debug builds (`OS.is_debug_build()`) when the first worker pump starts. `_log_error` takes the logger's own mutex, increments a count for `OS.get_thread_caller_id()` (error types only, not warnings), unlocks, and calls nothing that logs, so it cannot recurse. `_log_message` does nothing (the drivers' `printerr` lines arrive there and are not faults). The worker reads its own count before and after each job. **Probed:** a `push_error` and a script error on a worker thread arrive with the worker's id (two errors), and a main-thread `push_error` arrives with the main id (one), so a main-thread error during a worker job does not fault it. A release build detects no script fault: online, the 30-tick digest is the backstop; offline there is none.
- **Unchanged checks:** null result (Pump hardening), owner thread, stall, dead thread each keep their own cause string and their own fault case.

## Decided for you

[proposed], reversible on the owner's word.

1. Capacity rule: `MAX_QUEUED = 2`, counting the executing job (see "Capacity").
2. Stall = `STALL_FRAMES = 90` physics frames **and** `STALL_MSEC = 3000` wall time since the stall clock was last set, read in `drain` after it has taken any published notes. The clock is set at the `post` that takes the unpublished count from 0 to 1 and at every `drain` that took a note while the count stays above 0; the check runs only while the count is above 0 and no failure is set. A manual `_physics_process` call in a test does not advance `Engine.get_physics_frames()`, so the suite cannot trip it by accident. Frames come from an injectable `frame_source` (default `Engine.get_physics_frames()`). The inherits list asks for the stall in frames **[owner, 2026-11-18]**; the wall-time condition is added **[proposed]**. Detection at about 3 s leaves room inside the spec's "fault ends the match within 5 s". The Deck's worst job is far below it (p95 26.84 ms, spec "Why"); cold-start or GC pauses on Deck Firefox are not measured **[probe, SB6]**. `drain` runs every `_process`, also while the offline pause menu is open, so a stall during pause is caught. If `drain` never runs nothing is shown, and `query` and `stop` keep their own deadlines.
3. `WAIT_MSEC = 5000` for `query`, `stop` and the start handshake.
4. Effective mode: `worker_wanted()` = `WARGRID_SIM_THREAD == "1"` and `OS.has_feature("threads")` and the process latch not set **[owner rule, 2026-11-18; the latch's form is proposed]**. A pump decides its mode in `_init`. The runner resets the latch and the forced mode after every case (allowed edit 5), so one failing case cannot turn the rest of a shard inline. `force_mode_for_test("worker")` overrides the latch, so a test can check that a forced worker pump still starts after a failure.
5. Mode field: `"sim": "inline" | "worker" | "inline-fallback"`, computed by the drivers' `sim_mode()`: `pump.mode()`, except `"inline-fallback"` when the switch is on and `mode()` is `"inline"`. Shown in the playtest header and the desync report; `Sim: worker`, `Sim: inline` or `Sim: inline (fallback)` on the F3 overlay's first line. The screen reads `driver.sim_mode()`, never `driver.pump`.
6. `stop()` lets only the running job finish and drops the waiting one, as the spec's table says ("join, at most one job"). The record after `close_match` covers the jobs that ran; its log and digest agree, but it can end one tick earlier than inline's.
7. `has_room()` is capacity only: false only when the unpublished count is at the cap (or `cap_for_test`'s cap; inline with a cap it counts posted-but-undrained notes). A stopped or failed pump has room. Its `post` refuses, and the existing protocol end fires (`test_sb4_refused_post_ends_match` unchanged).
8. Online preview: when room runs out mid catch-up, the request waits one frame (Beside P2.3b). No lookahead.
9. Headless netplay clients stay inline: `tools/run_netplay.sh` starts its clients with `WARGRID_SIM_THREAD` unset. The worker client is covered by Task 10's scene loopback. CI's netplay step never sets the switch.
10. CI's switch-on step sets the four `WARGRID_*_REPLAY_TRACE` variables to empty, so it cannot overwrite the inline traces that the job uploads and compares (`ci.yml:57-60`).
11. Packed arrays inside frozen caches: `make_read_only` does not cover them. No writer exists after the freeze (Pump hardening Review Focus 5), and a packed array copies on write **[probe, Task 3 Step 0: two threads read a cached packed array while a test write is attempted on main; record whether the reader ever sees the change]**. If the probe shows a shared write, it is a stop (the fix touches `simulation/`).
12. `worker_ab.py` comes from the spike (private) if the source is on the machine, trimmed to the bench's line format; otherwise it is written fresh.

## Review Focus

1. **Lock scope:** the lock is held only to append or take a job, to publish (note, READY, count) and to drain. `run_job` never runs under it. Task 8's gated-publish case fails deterministically if `drain` skips the lock.
2. **Nothing read across threads without the lock:** the unpublished count, markers, READY, `_exited`, quit. `_failure` and the latch are main-only.
3. **`live()`** asserts in debug builds only. Release builds rely on the owner-thread check in `_run_owned`.
4. **Room before `take`:** a consumed tick can never be posted again, so the check comes first. A refusal after a successful check can only come from a terminal failure (Capacity, step 2).
5. **Two drains in one frame:** the second returns nothing and keeps the slots, in both modes.
6. **Quit re-check after each job** (inherits list) is observable: `stop()` with one running and one waiting job ends with the waiting job never run (`test_sb5a_stop_with_job_in_flight`).

## Same-tick and ordering cases

No new simulation command. Changed flow:

| Operation | Against | Expected | Test |
|---|---|---|---|
| online `step`, pump full, N+2's packets buffered | lockstep tick | `take` not called; `_next_tick`, `_taken`, credit unchanged; `failure()` empty | `test_sb5a_full_pump_leaves_next_tick_in_lockstep` |
| next frame, room again | N+2 | taken and posted; pairs as N+3's note | same |
| room runs out mid catch-up | preview request | kept; rides on the next frame's job; answer one frame later | `test_sb5a_preview_waits_for_room` |
| offline `step`, pump full | queue, preview request | kept; `_next_tick` unchanged; next frame posts both | `test_sb5a_offline_waits_for_room` |
| `post` at the cap | worker | false; not queued; `failure()` empty | `test_sb5a_post_refused_when_full` |
| failure marker between `has_room` and `post` | online tick | `post` false; reason set by main inside `post`; lockstep ends `sim pump failed`; transport closed | `test_sb5a_failure_between_room_and_post` (gated worker) |
| two notes in one frame | pairing | in post order; each with its own `issued` and digest | `test_sb5a_two_notes_one_frame_pair_in_order` |
| drain before publish / after one / after two publishes | slots, notes | nothing and slots unchanged / one / two in order; each once | `test_sb5a_drain_at_publish_boundary` |
| a view held from tick N through N+1 | its packed and nested data | unchanged, by deep hash, after N+1 is published and drained | `test_sb5a_held_view_never_changes` |
| `query` while tick jobs are queued | order | runs after them; its note not in `drain`; slots unchanged | `test_sb5a_query_waits_behind_jobs` |
| `record()` with jobs unpublished | log, digest | waits; equals the inline record of the same posts | `test_sb5a_record_waits_for_queue` |
| `query` whose job faults | caller | null; failure `fault` set by main | fault process `fault_in_query` |
| `stop()` idle | thread | joined within `WAIT_MSEC` (catches a missed wakeup) | `test_sb5a_stop_idle_worker` |
| `stop()` with one running and one waiting job | log | the running one finishes, the waiting one never runs; joined; later `query` inline; the record's log replays to its digest | `test_sb5a_stop_with_job_in_flight` |
| restart or rematch | old worker | stopped before the new simulation is built | `test_sb5a_create_stops_old_pump_first` |
| `record()` then `drain` | slots | `current()` unchanged by the query | `test_sb5a_query_never_touches_slots` (Task 4) |
| marker with one job waiting | count, `busy()` | count 0; `busy()` false at the next drain; later posts refused | `test_sb5a_null_job_marker_fails_pump` |
| null job in worker mode | pump | the post is accepted; the marker becomes `post job returned no note after tick N` at the next `drain` or `post`; earlier notes drain; later posts refused | same |
| `stop()` after a drain-found stall | caller | returns in under one frame | fault process `stall_restart` |
| idle for 200 frames and 10 s, then a post | stall check | no stall | `test_sb5a_idle_is_no_stall` |
| hash tick 30 (`want_digest`) and 31 in one drain | `finish_tick` | tick 30's note's own snapshot and digest, not `current()` | `test_sb5a_hash_tick_note_carries_digest` |
| desync at tick 60 with 61 already run | desync report | ring rows are tick-labelled and include 60; `tick` field 60; `desync_diff.py` and `desync_bisect.py` key by tick (`tools/desync_diff.py:36-37`) | `test_sb5a_ring_may_trail_desync_tick` |
| leave or restart with undrained notes | old pump | stopped; its notes unreachable | `test_sb5a_restart_drops_old_notes` |
| pause (offline menu open) | posts | none; worker idle; drain still runs | `test_sb5a_pause_posts_nothing` (both modes) |
| error logged in a worker job | pump | failed `fault`; that note and every later one dropped; slots kept | fault process `logged_error` |
| main-thread error during a worker job | pump | healthy | fault process `main_error_control` |
| `run_job` on a non-owner thread | pump | `push_error`, failed `owner thread` | fault process `wrong_thread` |
| stalled job, offline | match | freeze card within 5 s wall time; next pump inline | fault process `stall_offline` |
| stalled job, online | match, peer | `ended_protocol`, transport closed within 5 s; peer `opponent_left()` within 5 s + 1 s (critique A8) | fault process `stall_online` |
| a note finished while frames were paused (suspend) | stall check | the note is drained; no stall | `test_sb5a_suspend_is_no_stall` (frame source and clock injected) |
| stall, then restart / leave (finite 8 s job) | caller | returns within `WAIT_MSEC`; the job ends after the drop with no crash; exit 0 | fault processes `stall_restart`, `stall_leave` |
| stop during a stall, before the stall limit | thread | `stop` returns after `WAIT_MSEC`, fails `stall`, never joins | fault process `stall_stop` |
| query on a stalled worker | caller | null after `WAIT_MSEC`; failed `stall` | fault process `stall_query` |
| thread dead with jobs queued | pump | failed `dead thread` at the next drain | fault process `dead_thread` |
| `left` while waiting | `notice()` | no index error with an empty `waiting_for()` (night 8 rider 7) | `test_sb5a_notice_waiting_empty` |
| foreign note with `_taken` empty | online drain | protocol end (SB4 rider) | `test_sb5a_pairing_rejects_foreign_note` |

## Files

| File | Change | Task |
|---|---|---|
| `game/scripts/match/sim_pump.gd` | `worker_wanted`, latch, `mode`, `has_room`; thread, queue, lock, semaphores, handshake, self-reference, abandoned list; `_run_owned`; publish and drain under the lock; failure markers; `query` deadline; `stop` acknowledgement; stall and dead-thread checks; test seams | 2-6 |
| `game/scripts/match/pump_logger.gd` (new) | error counts per thread id | 6 |
| `game/scripts/match/offline_driver.gd` | `sim_mode`; `create` stops first; `step` room; `drain` failure read | 2, 5, 7 |
| `game/scripts/match/online_driver.gd` | `sim_mode`, `failure`; `create` stops first; `start` null; `step` room before `take`; `drain` failure end; `_report` null and `sim`; pairing guard; `notice` guard | 2, 7 |
| `game/scripts/match/match_screen.gd` | `_header` `sim`; `_exit_tree` stop; first-failure `orders.reset()` | 2, 5, 7 |
| `game/scripts/presentation/perf_overlay.gd` | `Sim:` word | 2 |
| `tools/test_sim_boundary.py` | `PUMP_COUNTS` by exact deltas, in every task that adds pump accesses; `Job`, `Note`, `Slot` field types | 2, 3, 5, 7 |
| `game/tests/test_sim_pump.gd`, `test_base_scene.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`, plus the sites Task 1 lists (e.g. `test_playtest_overlay.gd`, `test_graphics_settings.gd`) | mode loop, helpers, `settle` calls, new cases | 3-10 |
| `game/tests/run_tests.gd`, `tools/run_tests.sh`, `game/tests/test_runner.gd` | the per-case cleanup (allowed edit 5, Task 5); the inline-under-switch list and the `SIM PUMPS worker/forced/inline` and `LIVE` counts per shard, summed in the summary; a runner case | 5, 9 |
| `game/tests/pump_faults.gd` (new), `tools/run_pump_faults.sh` (new) | fault cases, one process each, outer `timeout 20` | 6 |
| `game/benchmarks/run_worker_digests.gd` (new), `tools/run_worker_digests.sh` (new) | four loads in both modes, digest every 30 ticks, first mismatch report | 11 |
| `game/benchmarks/run_match_bench.gd` (new), `game/scenes/match_bench.tscn` (new), `tools/worker_ab.py` (new), `tools/test_worker_ab.py` (new) | real match screen on the pump, both modes, go-rule metrics | 12 |
| `tools/run_netplay.sh` | clients start with the switch unset | 10 |
| `.github/workflows/ci.yml` | switch-on suite step, traces empty | 9 |
| docs | Task 15 | 15 |

---

### Task 1: Base, counts, lists and line map

**Files:** `docs/reference/sim-boundary-verification.md` (new `## SB5a`: resume record, ledger, counts, lists, line map). Nothing else.

- [ ] **Step 1:** Branch and base (Target revision); `git diff 83d00e8 --stat -- game tools relay protocol` empty; `git fetch origin main` and record whether `main` moved; `uptime`, `pgrep -fl godot`.
- [ ] **Step 2:** `SUITE(base)`; `ONLY` for `test_sim_pump`, `test_online_scene`, `test_skirmish_scene`, `test_base_scene`; `NET(base, match)`, `NET(base, rematch)`; `sh tools/run_team_match.sh`; `CHECKS(base)`. Red base is a stop.
- [ ] **Step 3: lists** (each into the verification file, path:line):
  - drive sites: `rg -n "_physics_process\(|driver\.step\(\)|pump\.post\(|BaseScene\.publish|\.publish\(main|\.drain\(\)" game/tests`, each marked "settle after post" or "multi-physics on purpose: inline under the switch";
  - the ten Profiler cases (named in Ownership);
  - every `failing_pump.gd` or other deliberate-failure use;
  - `test_sim_pump.gd` cases in the three groups of allowed edit 3, and the synchronous-failure cases;
  - every direct `OnlineDriver.new`, `OfflineDriver.new` and bare `SimPump.new` under `game/tests` (`rg -n "OnlineDriver.new|OfflineDriver.new|SimPump.new" game/tests`), each marked "stopped by its helper" or "stopped by the runner";
  - static writes reachable from `run_job` (`rg -n "^static var" game/scripts/simulation`), each marked debug counter or not;
  - `PUMP_COUNTS` (10 and 9 at `83d00e8`); the catch-up rule (`CATCH_UP_STEPS`, `MAX_CATCH_UP_CREDIT`);
  - engine calls reachable from `run_job` that a Web build proxies to the browser's main thread (`FileAccess`, `ResourceLoader`, `DisplayServer`, `OS.`, `Time.`): `rg -n "FileAccess|ResourceLoader|DisplayServer|OS\.|Time\." game/scripts/simulation`, each marked; native builds are unaffected, so this is input for SB5b's plan, not a stop here.
- [ ] **Step 4:** spike evidence: if `~/projects/wargrid-wt-worker` or `~/projects/wargrid-overnight-work/worker-threads/` exists, record its DIGEST lines and the path of `worker_ab.py`; else "not on this machine".
- [ ] **Step 5:** P2.3b state: merged or not; if its branch is readable, its file list against "Beside P2.3b" (a conflict outside the named hunks is a stop for the owner).
- [ ] **Step 6:** line map of every cite in this plan, by symbol; `sh tools/check_public.sh`. Commit.

### Task 2: The switch, the mode, and where it shows

**Files:** `sim_pump.gd`, `offline_driver.gd`, `online_driver.gd` (`sim_mode`, `_report`), `match_screen.gd` (`_header` `:189-190`), `perf_overlay.gd` (`refresh_text`), `tools/test_sim_boundary.py`. Tests: `test_sim_pump.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`.

**Interfaces:** `static func worker_wanted() -> bool`; `static func force_mode_for_test(mode: String)` (`""` clears) and `reset_process_latch_for_test()`; `func mode() -> String` fixed in `_init`. The pump still runs inline in both modes in this task.

- [ ] **Step 1: Tests.** `test_sb5a_mode_from_switch` (forced on → `"worker"`; off → `"inline"`; on after the latch → `"inline"`; latch reset → `"worker"`). `test_sb5a_header_names_mode` and `test_sb5a_f3_shows_mode` assert the expected mode (`SimPump.worker_wanted()`), not a literal, so they hold under the switch.
- [ ] **Steps 2-6:** red; implement; `SUITE(t2)`, `TRACES(t2)`, `CHECKS(t2)` (with the new `PUMP_COUNTS`); mutation: `worker_wanted` ignores the latch → `ONLY(t2m, test_sb5a_mode)` red; review; commit.

### Task 3: The queue (first slice)

**Files:** `sim_pump.gd`. Test: `test_sim_pump.gd`.

**Interfaces:** worker mode in `start()`: `_warm_and_freeze`, job 0 on the caller (owner main), spawn, start handshake (bounded) recording `_owner_id`, `_keep_alive = self`. `post` (main): refuse when stopped, failed, a marker is pending (read it and set the reason), or at the cap; append under the lock; count; post the work semaphore. Worker loop (Ownership). Publish: under the lock, the note, READY, count -= 1. `drain`: under the lock, take notes and markers, swap slots, then (unlocked) the stall and dead-thread checks. `has_room()`, `busy()` under the lock. Test seams: `cap_for_test`, `gate_publish_for_test(semaphore, where)` (Contract; the worker waits on it with a bounded `try_wait` loop), `frame_source`, `clock`, `live_workers()`, `stop_live_for_test()`, `pump_counts()`. Job 0's note and slot are built before the spawn, so the worker's first read of the simulation is ordered by the spawn and the handshake semaphore.

- [ ] **Step 0:** the bare members; the packed-array probe (Decided 11) as a scratch script (`quit()` on every path), result into the ledger. `ONLY(t3s0, test_sim_pump)` green.
- [ ] **Step 1: Tests.** `_modes()` and `_pump(mode)`; the group (a) cases of `test_sim_pump.gd` run in both modes (allowed edit 3) with the same expected values, through a bounded wait-for-idle before each drain. New: `test_sb5a_null_job_marker_fails_pump` (the worker counterpart of `test_ph_null_job_fails_pump`: `fail_next` set before the post and cleared only after the pump is idle); `test_sb5a_idle_is_no_stall`; `test_sb5a_post_refused_when_full` (gate at `before_publish`: two posts accepted, third refused, `failure()` empty, release, both notes drain in order); `test_sb5a_empty_drain_keeps_slots`; `test_sb5a_drain_at_publish_boundary`; `test_sb5a_held_view_never_changes` (deep hash of view N, packed rows and nested dictionaries, before and after N+1); `test_sb5a_undrained_notes_bounded` (a frame script of 8 physics steps per render frame); `test_sb5a_worker_runs_off_main` (a test subclass records the thread id in `_note_for`, so `Note` gains no field). `tools/test_sim_boundary.py` gains a check that `Job`, `Note` and `Slot` declare only pure-data field types (Ownership).
- [ ] **Step 2:** `ONLY(t3red, test_sb5a_)` red on named checks only.
- [ ] **Step 3:** implement.
- [ ] **Step 4:** `SUITE(t3)`, `TRACES(t3)`, `WONLY(t3w, test_sim_pump)`, `CHECKS(t3)`.
- [ ] **Step 5:** mutations: count released before the note is appended → `test_sb5a_drain_at_publish_boundary` red; `has_room` ignores the executing job → `test_sb5a_post_refused_when_full` red.
- [ ] **Step 6:** review; commit. **First evidence:** pump digests equal in both modes, into the ledger.

### Task 4: `query` and `record` through the worker

**Files:** `sim_pump.gd` (`query` `:98-101`, `record` `:103-112`). Tests: `test_sim_pump.gd`, `test_skirmish_scene.gd`.

**Interfaces:** worker `query`: append a query job with its own reply semaphore; poll `try_wait` against the `WAIT_MSEC` deadline, also reading markers, so expiry is detected inside the call; on expiry fail `stall` and return null. After a join, `query` runs inline (owner main). `record()`'s alive-thread branch (Stalled trace, step 2).

- [ ] **Step 1: Tests.** The group (b) cases of `test_sim_pump.gd` gain the mode loop. `test_sb5a_query_never_touches_slots`; `test_sb5a_query_waits_behind_jobs`; `test_sb5a_record_waits_for_queue` (40 jobs posted with a wait for room between posts, then `record()` while at least one is unpublished; equal to inline); `test_sb5a_query_after_stop_runs_inline`; offline `match_log` and online `start()` (startup digest) equal inline in worker mode.
- [ ] **Steps 2-6:** red; implement; `SUITE(t4)`, `TRACES(t4)`, `WONLY(t4w, test_sim_pump)`; mutation: a query note appended to the drain queue → red; review; commit.

### Task 5: Stop, exit, restart

**Files:** `sim_pump.gd` (`stop` `:123-124`), `offline_driver.gd` and `online_driver.gd` (`create`), `match_screen.gd` (`_exit_tree` `:138-141`), `run_tests.gd` (allowed edit 5), `tools/test_sim_boundary.py` (`PUMP_COUNTS` for the `create` hunks). Tests: `test_sim_pump.gd`, `test_skirmish_scene.gd`, `test_online_scene.gd`.

- [ ] **Step 1: Tests.** `test_sb5a_stop_idle_worker`; `test_sb5a_stop_with_job_in_flight`; `test_sb5a_stop_is_idempotent`; `test_sb5a_restart_drops_old_notes` (offline `_restart_world` and online rematch); `test_sb5a_create_stops_old_pump_first`; `test_sb5a_exit_tree_stops_worker` (`main.free()` leaves `live_workers() == 0`). The runner prints `SIM PUMPS LIVE 0` at the end of each shard under the switch. Steps 2-6 also run `CHECKS(t5)`.
- [ ] **Steps 2-6:** red; implement; `SUITE(t5)`, `TRACES(t5)`, `WONLY(t5w, test_sim_pump)`; mutations: `stop` skips the join on the clean path → `test_sb5a_exit_tree_stops_worker` red; `stop` runs the waiting job → `test_sb5a_stop_with_job_in_flight` red; review; commit.

### Task 6: Fault flag and the fault processes

**Files:** `pump_logger.gd` (new), `sim_pump.gd`, `game/tests/pump_faults.gd` (new), `tools/run_pump_faults.sh` (new).

**Interfaces:** the Failure channel. `pump_faults.gd` is a `SceneTree` script, one case per process (`--case=<name>`), real 30 Hz physics frames, printing `FAULT CASE <name> PASSED <ms>` or `FAILED <why>`, `quit()` on every path. Cases: `logged_error`, `main_error_control`, `wrong_thread`, `fault_in_query`, `stall_offline`, `stall_online`, `stall_restart`, `stall_leave`, `stall_stop`, `stall_query`, `dead_thread`, `next_match_inline` (after any failure, the next pump's `mode()` is `"inline"`). `run_pump_faults.sh` runs each under `timeout 20`, checks the marker and the exit status, and prints `PUMP FAULTS PASSED 12`. It runs as its own gate line, outside `run_checks.sh`.

- [ ] **Steps 1-6:** the cases first (red: markers missing); implement; `FAULTS(t6)`; `SUITE(t6)` + `TRACES(t6)`; mutations: the logger compare skipped → `logged_error` red; the stop deadline removed → `stall_stop` times out at the outer bound (red); `sh tools/run_shell_checks.sh`; review; commit. The ledger records the abandoned-thread exit status per case (Linux).

### Task 7: Drivers: room, failure, online end, riders

**Files:** the named hunks in "Beside P2.3b"; `tools/test_sim_boundary.py`. Tests: `test_skirmish_scene.gd`, `test_online_scene.gd`.

- [ ] **Step 1: Tests.** `test_sb5a_offline_waits_for_room`; `test_sb5a_full_pump_leaves_next_tick_in_lockstep`; `test_sb5a_preview_waits_for_room`; `test_sb5a_two_notes_one_frame_pair_in_order`; `test_sb5a_failure_between_room_and_post`; `test_sb5a_online_failure_ends_and_closes` (loopback through `FakeTransport` with the relay frame-order rule; the failure comes from `failing_pump.gd`, so no ERROR line; the peer reads `opponent_left()` and `rematch_line() == "Your opponent left"`, no result recorded); `test_sb5a_online_start_null_query`; `test_sb5a_pairing_rejects_foreign_note`; `test_sb5a_notice_waiting_empty`; `test_sb5a_failure_clears_pending_build`; `test_sb5a_pause_posts_nothing` (and the in-flight job still drains while paused); `test_sb5a_hash_tick_note_carries_digest`; `test_sb5a_ring_may_trail_desync_tick`; `test_sb5a_suspend_is_no_stall`; the group (c) cases of `test_sim_pump.gd` gain the mode loop. Room cases use `cap_for_test`, so they also run inline (counted as forced). Steps 2-6 also run `CHECKS(t7)`.
- [ ] **Steps 2-6:** red; implement; `SUITE(t7)`, `TRACES(t7)`, `NET(t7, match)`, `NET(t7, rematch)`, `NETEQ(t7)`, `WONLY(t7w, test_sim_pump)` and `WONLY(t7w2, test_sb5a_)` (the whole scene suite under the switch waits for Task 9's helpers); mutation: room checked after `take` → `test_sb5a_full_pump_leaves_next_tick_in_lockstep` red; review; commit.

### Task 8: The lock proof and a free-running run

**Files:** `test_sim_pump.gd`. No production change expected; a red is a finding for Task 3.

- [ ] **Step 1:** `test_sb5a_lock_guards_publish`: the publish gate at `inside_publish` pauses the worker after it has appended the note but before READY and the count. A helper thread calls `drain` and polls `try_lock`-style through a bounded wait (it never calls an unbounded `lock()`); main opens the gate after a fixed delay. With the lock, that drain waits until the gate opens and sees note and slot together. Mutation: `drain` without the lock → `current().tick == last note tick` fails on every run.
- [ ] **Step 2:** `test_sb5a_free_running_equals_inline`: 900 bot ticks, posts whenever there is room, drains every loop without waiting for idle; notes, issued results and `StateHash.digest(slot.view)` per drained slot equal an inline run; on a mismatch the case prints the first tick, its commands and both hashes; `drain`'s longest lock wait into the ledger.
- [ ] **Step 3:** `SUITE(t8)`, `WONLY(t8w, test_sim_pump)`; review; commit.

### Task 9: The scene suite under the switch, and CI

**Files:** `test_base_scene.gd` and the drive sites Task 1 listed; `run_tests.gd`, `tools/run_tests.sh`, `test_runner.gd`; `.github/workflows/ci.yml`.

- [ ] **Step 1:** `BaseScene.tick`, `settle`, `publish` (allowed edit 1); the inline-under-switch list (allowed edit 2), checked by name before each case, with the case's pumps counted as forced; the runner prints per shard `SIM PUMPS worker=<w> forced=<f> inline=<i>` and `SIM PUMPS LIVE <n>`, and `run_tests.sh` sums them in the summary. `test_runner.gd` gets a case for the list and the count.
- [ ] **Step 2:** `SUITE(t9)` (counts unchanged, `SIM PUMPS worker=0`); `WSUITE(t9)` (`worker > 0`, `inline == 0`, `SIM PUMPS LIVE 0`). Any other red under the switch: Opus diagnosis first; a fix outside the pump, the drivers or the allowed test edits is a stop. Mutation: the runner's latch reset removed → `inline` rises above 0 → red.
- [ ] **Step 3:** CI: one step `WARGRID_SIM_THREAD=1 sh tools/run_tests.sh` after the existing suite on Linux and Windows, with the four trace variables empty (Decided 10). `CHECKS(t9)`.
- [ ] **Step 4:** review; commit.

### Task 10: Loopback online with one worker client

**Files:** `test_online_scene.gd`, `tools/run_netplay.sh` (Decided 9).

- [ ] **Step 1:** `test_sb5a_worker_peer_against_inline_peer`: two scene drivers through `FakeTransport` with the relay frame-order rule, seat 1 worker, seat 2 inline, the SB4 reference script through two hash ticks and the match end: command logs, every hash-tick hash and the end status equal.
- [ ] **Step 2:** `run_netplay.sh` starts clients with the switch unset; `NET(t10, left-mid-pump)` and one `trio-*` scenario with `WARGRID_SIM_THREAD=1` in the caller's environment still pass (proof that the clients stay inline).
- [ ] **Step 3: catch-up bound** (accepted limit **[owner, 2026-11-22]**). `test_sb5a_catch_up_bound_per_frame`: a frame script at 10, 6 and 4 rendered fps (physics steps per rendered frame 3, 5 and 8), in both modes. Checks: at most input delay + 1 = 5 ticks taken per rendered frame; an inline client at 6 fps or more keeps pace with the switch on. The case records, in the ledger, the lowest rendered fps at which a worker client keeps pace. The record is report-only: falling behind is not a stop, because the bound is accepted.
- [ ] **Step 4:** `SUITE(t10)`; review; commit.

### Task 11: Digests on four loads, both modes

**Files:** `game/benchmarks/run_worker_digests.gd`, `tools/run_worker_digests.sh`.

- [ ] **Step 1:** for skirmish3v3, team, hordes300 and late_game_3v3, a headless run with the Profiler off, posting only when there is room, draining each loop, `record()` digests every 30 ticks to a fixed end tick, once inline and once worker (forced through the hook). It prints `DIGEST <load> tick=<t> <hash>`. The shell script `cmp`s the files. On a mismatch it prints the earliest differing tick, that tick's posted commands, both digests and both view hashes; otherwise `WORKER DIGESTS MATCHED 4`. `run_profile.gd` is not changed (its pump row stays inline, Profiler on).
- [ ] **Step 2:** `DIGESTS(t11)`; `sh tools/run_shell_checks.sh`; commit. **Cloud run ends here** (owner answer 2); the run reports and stops.

### Task 12: Match bench and `worker_ab.py` (Mac)

**Files:** `game/benchmarks/run_match_bench.gd`, `game/scenes/match_bench.tscn`, `tools/worker_ab.py`, `tools/test_worker_ab.py`.

- [ ] **Step 1:** The bench runs the real match screen on Ashfall, 3v3 bots (team load), in either mode, with a scripted input track (box selects and moves every 2 s, one build every 20 s). `Engine.max_fps = 60` headless, so frame shares mean something. It asserts that the input track ran inside the timed window (AGENTS.md benchmark rule). One `MATCH BENCH` line per run: mode, ticks, `tick_rate`, refused posts, longest refusal run, pace (average and worst two-second window), share of ticks shown 1, 2 and 3 frames after the previous one, drains with two ticks, answer latency in frames (p50, p95), main frame CPU p95 and p99, end digest.
- [ ] **Step 2:** `worker_ab.py report <dirs>`: median and range per arm; its test covers a missing field, a one-run arm, and equal or unequal digests across arms.
- [ ] **Step 3:** one headless run per mode into the ledger. The rows are report-only. The 29.7 ticks/s floor is the go rule's **[owner, 2026-11-18]** and is printed as a reference only; refusal limits are unset **[open, SB6]**. `sh tools/run_python_checks.sh`; commit.

### Task 13: Deck waiting-line rider (Mac, over SSH, no owner needed)

Rider **[owner, 2026-11-17; kept in SB5a 2026-11-22]**: with SB4's quiet take, "Waiting for player N" shows only once the in-flight jobs drain; SB5a measures it with a 1 s hold on the Deck under team load.

- [ ] **Step 1:** if the Deck answers `ssh -o BatchMode=yes <deck> true`, copy a native Linux debug export of this tree and run a real-time loopback (two native clients through the local relay path, team load, worker mode), with 20 holds of 1 s on seat 2's packets. Per hold, record the wall-clock delay from the hold start to the first rendered frame with the line, and whether the line showed at all. Frames run in real time, not test-paced.
- [ ] **Step 2:** p99 at most about 150 ms and the line in every hold: done. Otherwise the wall-clock waiting line (about 1 s, [M9 drops Q12](../../questions/next-m9-drops.md)) becomes Task 13b, and the run stops for the owner (the owner's rule).
- [ ] **Step 3:** Deck unreachable: "not run" into the owner list; the gate does not wait. **Step 4:** remove only the copied export from the Deck; ledger; commit.

### Task 14: Merge `main` after P2.3b

Runs only when P2.3b is on `main`.

- [ ] **Step 1:** `git merge main` (asks the owner). Expected conflicts: the preview lines in both drivers (F33, T2b) and `match_screen.gd` near `_drain_notes` and `_exit_tree`. P2.3b's preview rule wins; SB5a's hunks are re-applied around it. Check whether `orders.reset()` changed.
- [ ] **Step 2:** a new base trace set on `main` after P2.3b; `SUITE(t14)`, `TRACES(t14)`, `WSUITE(t14)`, `NET(t14, match)`, `NET(t14, rematch)`, `NETEQ(t14)`, `FAULTS(t14)`, `DIGESTS(t14)`, `CHECKS(t14)`; F33's preview cases under the switch (`WONLY(t14w, preview)`).
- [ ] **Step 3:** ledger; commit the merge.

### Task 15: Docs

- [ ] `docs/reference/sim-interface.md`: the Contract list, the Ownership table, the failure reasons.
- [ ] `docs/reference/determinism-rules.md:14`: "one owner thread".
- [ ] Spec: the API block from `sim_pump.gd`; the SB5a row's state; the inherits list ticked with its test per item; "five ticking cases" → the ten Profiler cases; the Thread lifecycle and failed-pump lifetime as one paragraph.
- [ ] Guide chapters `01-big-picture`, `04-the-tick`, `05-presentation`, `12-performance-and-platforms`, `13-testing-and-tooling`, each with its `Checked against` footer.
- [ ] `docs/STATUS.md` night 6 row (one status line), `docs/packages.md` item 6, `python3 tools/roadmap.py`.
- [ ] One fresh Opus (high) docs review, one fix round; `sh tools/check_public.sh`; commit.

### Task 16: Gate

- [ ] The spec's checks: `CHECKS(gate)`, `SUITE(gate)` + `TRACES(gate)`, `NET(gate, match)`, `NET(gate, rematch)`, `NETEQ(gate)`, `sh tools/run_conformance.sh`, `PERF_LABEL="Sim boundary SB5a" sh tools/run_benchmark.sh` (alone). SB5a's own: `WSUITE(gate)`, `FAULTS(gate)`, `DIGESTS(gate)`.
- [ ] Push the branch for CI once (pre-authorized in the handoff only); `gh run watch --exit-status`; Linux and Windows green with the switch-on step and the abandoned-thread exit on Windows; `sh tools/compare_local_traces.sh <run id>` on the Mac (macOS traces; the macOS abandoned-thread exit by running `FAULTS` there once).
- [ ] Reviews (Model routing); one fix round, test-first.
- [ ] Owner items: the rendered rerun owed after the merge (`game/scripts/match/` and `perf_overlay.gd` changed; it opens a window); the catch-up rider wording (below).
- [ ] Report: implemented, verified (with the tree each check ran on), pending, Decided for you, owner items.

## Evidence to move from SB5a to SB5b

SB5b (threaded Web preset, headers, pause-menu toggle) may start when all of these hold on the merged tree:

1. `WORKER DIGESTS MATCHED 4`, and every `test_sim_pump` case green in both modes (spec exit: digests equal on four loads in both modes).
2. `WSUITE` green, with `worker > 0`, `inline == 0` and `SIM PUMPS LIVE 0` (spec exit: scene suite green under the flag).
3. `PUMP FAULTS PASSED 12`, with `stall_offline` and `stall_online` ending the match within 5 s of wall time and the peer's leave within 6 s (spec exit: a fault ends the match within 5 s).
4. `test_sb5a_worker_peer_against_inline_peer` green (spec exit: loopback online with one worker client).
5. The inline gate unchanged: traces, netplay, conformance, benchmark row, CI Linux and Windows (switch-on step included), macOS traces.
6. The bench and `worker_ab.py` merged, with one row per mode in the ledger (SB6's input).
7. The Deck rider either done or recorded "not run" for the owner, and Task 13b not pending.
8. The Opus and Gemini gate reviews with every high finding fixed.

## Stop conditions

Never ruled on, always parked for the owner:

- any pinned digest, trace or pin moving; a worker digest differing from inline;
- a weakened or removed assertion, or a test edit outside "Allowed test edits";
- an edit outside the named hunks or to an untouched path; a contract change beyond "Contract";
- a red under the switch whose fix lies outside the pump, the drivers or the allowed test edits;
- the lock proof green under the mutation (Task 8);
- the packed-array probe showing a shared write (Decided 11);
- a non-debug static write reachable from `run_job` (Task 1);
- the Deck rider failing (Task 13): stop before 13b;
- P2.3b not merged when Task 13 is done;
- a task not green after two fix rounds: it parks (`git stash push --include-untracked -m park-t<N>-sb5a`, the stash SHA in the ledger, never popped). Dependent tasks: 4, 5, 6 need 3; 7 needs 5; 8, 9, 10 need 7; 11 needs 4; 12 needs 7; 13 needs 10;
- a budget exceeded or `run_benchmark.sh` exit 1;
- about 100M processed tokens (`python3 tools/session_usage.py` after each task; the cloud session reports its usage line instead).

Red under host load (above 2.5): one rerun with `uptime` before each; green is "flake under load", red twice is a stop.

## Review disposition

Readiness review (Opus, 2026-11-22, private report `sb5a-readiness-review.md`); every item is applied unless noted:

- **Blockers.** B1: the latch resets per case, and `SIM PUMPS` counts prove the mode (Decided 4, Task 9). B2: allowed test edits widened; Task 1 lists every drive site. B3: `_exit_tree` stops, self-reference, abandoned list, `stall_restart` and `stall_leave` (Thread lifecycle, Task 6). The engine claim behind B3 was probed.
- **Should-fix.** S1 (poll loops, never join after a timeout), S2 (physics-frame source), S3 (owner handshake, `_run_owned`), S4 (failure markers; `stop` finishes only the running job, Decided 6), S5 (online `failure()`, null queries), S6 and S7 (counts per task, mode-relative asserts), S8 (capacity-only `has_room`, SB4 test unchanged), S9 (no lookahead, preview waits a frame), S10 (`run_worker_digests.gd`), S11 (gated, deterministic lock proof), S12 (full Contract list), S13 (real frames, wall time, peer bound), S14 (CI traces empty), S15 (netplay clients inline), S16 (HUD paths), S17 (posts wait for room), S18 (runner and `run_tests.sh` in Files, a runner case), S19 (Decided 11; `run_profile` untouched, its loop bound stays open; the quit-frame refusal stays as the owner chose it, Pump hardening choice 4).
- **Nits.** N1, N3, N5, N6, N8, N9, N10, N11, N12, N13 and N14 are applied. N2: the spec text is fixed in Task 15. N4: moved to the owner list. N7: covered by Task 3's mode loop and `test_sb5a_pause_posts_nothing`.

Second readiness review (Opus, 2026-11-22, private report `sb5a-readiness-review-2.md`). NB-1: the three `test_sim_pump` groups, synchronous-failure cases inline with a worker counterpart (allowed edit 3, Tasks 3, 4 and 7). S-2: the stall clock and its idle guard (Decided 2). S-3: one count rule (Failure channel). S-4: `_abandon` (Lifetime of a failed pump). S-5: two gate positions (Contract, Tasks 3 and 8). S-6: `worker/forced/inline` counts. S-7 and S-10: the runner's per-case cleanup (allowed edit 5). S-8: named hunks. S-9: `PUMP_COUNTS` and `CHECKS` in Tasks 5 and 7. S-11: offline failure read before the empty return. Nits N-1 to N-7 are applied; N-6 is on the owner list.

Owner planning brief (2026-11-22, private): the full-queue trace, the ownership table, the four thread states, the failed-pump lifetime, the query deadline, the logger contract, the publication-boundary and held-view tests, the external fault bounds, the SB6 carry-over, the labels and the SB5b evidence are all in this revision.

Second owner brief (SB5a, SB5b and SB6, 2026-11-22, private): applied to SB5a are the stall threshold (both conditions, about 3 s, so 5 s holds), `stop()` finishing at most one job, query replies never touching the slots, pure-data notes, stopping the old pump before the new simulation, the hash-tick and desync-ring cases, the suspend case, the `inline-fallback` mode value, and the Web-proxied call audit (for SB5b). Where the brief differs from this plan:

- **Deck baseline before the plan:** done already. The no-threads arms were measured unattended and none helped, and the attended look moved to before SB6 (D14, [low-end research decisions](../../reference/design-answers-2026-11-08.md#low-end-research-decisions-user-2026-11-19)) **[owner, 2026-11-19]**.
- **Profiler cases:** the brief cites five (the spec's old lines); there are ten at `83d00e8` (Ownership).
- **`MAX_QUEUED`:** the brief's section 5 says "un-drained pipeline depth". This plan counts unpublished jobs. Counting undrained notes would refuse a second physics step in a long render frame even with an idle worker, slowing game time with no backlog. The undrained bound is stated separately (Capacity).
- **`query()` after `stop()`:** the brief returns an empty note. This plan keeps the Pump hardening rider **[owner, 2026-11-18]**: after a join the query runs inline, so `record()` still returns log and digest. A failed pump returns null at once, as the brief says.
- **Mixed loopback through `run_netplay.sh`:** covered by the scene loopback (Task 10). The headless clients stay inline (Decided 9).
- **For the SB5b and SB6 plans, not here:** the toggle reveal, its subtext and persistence in private browsing; header coverage of every asset; the Wasm heap under hordes300 and rematches; chat-app WebViews and `window.opener`; the release Web fault probe; the refusal-streak limits (an acceptance bar, so the owner's call).

## Owner answers (user, 2026-11-22)

1. **Build beside P2.3b:** yes. Built in parallel, merging only after P2.3b is on `main`.
2. **Where it runs:** Tasks 1 to 11 in a cloud session; Tasks 12, 13 and the Mac parts of the gate on the Mac afterwards.
3. **Deck rider:** stays in SB5a (Task 13).
4. **Catch-up bound:** catch-up is bounded at input delay + 1 = 5 ticks per rendered frame, because own packets are sent from `drain`. It is an accepted limit, measured but not fixed (Task 10 Step 3), and the wording is in [packages](../../packages.md#night-lane) item 6 and the spec's inherits list.

## For the owner

- **`run_profile` loop bound** (left open by Pump hardening, `sim-boundary-verification.md:448`): SB5a does not touch `run_profile.gd`. Recommended: carry it into SB6's bench work.
- Still owed before a run: a diff check of revision 3 against the second review's list, the owner's approval of this plan, and the run handoff (private, `sb5a-build-prompt.txt`).
