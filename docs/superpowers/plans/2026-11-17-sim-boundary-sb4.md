# Sim boundary SB4 "Online on the pump": Implementation Plan

**Status:** approved plan, questions answered (user, 2026-11-17: Q1 A, Q2 B, Q3-Q8 recommended, Q9 A night run; second round Q10-Q13 A, third round Q14-Q17), review-fable and review-questionnaire applied; **approved (user, 2026-11-17)**. Approving does not start implementation: the night run starts with `/prepare-night-run`. Choices in `~/projects/wargrid-overnight-work/sb4/plan/questions.md` (private, Q1-Q17); the plan is written for every recommendation and names what changes otherwise. Committed at `/prepare-night-run` (2026-11-17), as SB3's plan was. Resume record skeleton: `~/projects/wargrid-overnight-work/sb4/plan/verification.md` (private); it moves into `docs/reference/sim-boundary-verification.md` as a new `## SB4` section in Task 1. Two readiness reviews applied (`review.md`, then `review-fable.md` against `main` `1be405a`; fixes logged in `changes.md`; all in `~/projects/wargrid-overnight-work/sb4/plan/`, private).

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: [milestone prompt](../../milestone-prompt.md) (one fresh subagent per task, each starting from the SB4 resume record) and, for a night run (Q9), `docs/night-run.md` "Coordinator rules". Every task subagent also reads "Global Constraints", "Relay guards collision", "Determinism notes" and "Same-tick and interaction cases" (`rg -n '^## ' <plan>`).

**Goal:** The online driver runs every lockstep tick as one `SimPump` job, so no file under `game/scripts/match/` except `sim_pump.gd` reads the live simulation, with digests, traces, netplay pins and the online scene tests unchanged.

**Architecture:** `Lockstep.advance(sim)` splits into `take(tick)` (today's checks; the tick's commands in seat order, or null) and `record(tick, issued)` (command log, latency, rejections); `advance` stays as take, issue, record, step, so the headless client, replays, `test_lockstep.gd` and `run_lockstep.gd` keep calling it unchanged. The online driver's `step()` takes up to `CATCH_UP_STEPS` ticks and posts one job per tick (the commands, the preview, `want_digest` on hash ticks); its `drain()` hands each drained note to `record` and to `finish_tick(tick, state, digest)` (the digest from the job, not recomputed), then handles the end of the match. `Lockstep.start` gets tick 0's snapshot and digest from a query job (Q3); the desync report's ring comes from a query job with the new `want_ring` (Q4). A take made while one of our jobs is undrained is quiet (Q2): a refusal changes no status, so a match that ended in that job ends exactly as today. Rematch already builds a new pump through `create` → `adopt` (SB3); SB4 resets the driver's taken-tick queue there and starts the new lockstep from the new pump's query.

**Tech Stack:** Godot 4.7.2 typed GDScript, suite runner `game/tests/run_tests.gd`, Python check `tools/test_sim_boundary.py`, POSIX sh tools; the Go relay is untouched.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md) (package row SB4; "Ownership and API", "One code path", "Offline, online, restart" (Online and Restart bullets), "Snapshot, digest, ring", "Guard against live reads"; answers 5, 22, 23; agent calls 2, 3). Style and conventions: [SB3 plan](2026-11-16-sim-boundary-sb3.md). Read with it: [simulation interface](../../reference/sim-interface.md), [determinism rules](../../reference/determinism-rules.md), guide [chapter 11](../../guide/11-multiplayer.md).

## Global Constraints

- **Base (Q1):** `main` with Relay guards merged (`d56ad58`; night-lane order: Relay guards, P12, SB4; `docs/packages.md:52`). Path:line below is `main` `1be405a` (code and tests identical on `3f12f86`, which adds one docs commit). Every cite names its symbol; Task 1 refreshes the lines on the real base by symbol and records the map. Worktree `$W` = `~/projects/wargrid-wt-sb4`, branch `sim-boundary-sb4`, created at `/prepare-night-run`; the run's session starts inside `$W` (`docs/night-run.md` "Start"), so every relative `sh tools/...` command and every subagent shell runs on that tree. Logs `$L` = `~/projects/wargrid-overnight-work/sb4/logs`. `$W`, `$L` and `~` are notation only: in every command type the absolute path (written `<abs $W>`, `<abs $L>` below), never `~` or a shell variable in a command.
- **Public repository:** this plan and the verification file are tracked. Tracked files use `~/...`, `<abs $L>` or the `SUITE`/`NET`/`ONLY` tags, never the typed absolute path; a subagent never pastes a typed command into the ledger. `sh tools/check_public.sh` (`PUBLIC CHECK PASSED`) runs before the Task 1 commit and in Task 5.
- **Nothing pinned moves:** the four suite traces, `run_netplay.sh match` and `rematch` (terminal tick 9013, `run_netplay.sh:161,179`; `s1.tsv`; `s1.cmd`), the team match (`TEAM MATCH won tick=38786 winner=2 units_peak=268`), IC1, IC2 (`test_input_script_online`, `test_online_scene.gd:1413`), OD1, S3, RB8 (2 snapshots while the online sim passes tick 60, `test_sb1_online_snapshot_per_hash_tick`, `test_online_scene.gd:572-587`). Any of them moving is a stop; never re-pin.
- **Untouched files (spec exit evidence):** `game/tests/test_lockstep.gd`, `game/benchmarks/run_lockstep.gd`, `game/scripts/net/headless_client.gd`, `seat_sim.gd`, `wire.gd`, `relay_transport.gd`, `protocol/`, `relay/`, `game/scripts/simulation/`, `game/scripts/presentation/`, `game/scripts/match/match_screen.gd`, `offline_driver.gd`, `hud.gd`, `orders.gd`, `game/tests/test_base_scene.gd`. `git diff <base> --stat -- <those paths>` is empty at every gate.
- **Inline only:** no `Thread`, `Mutex` or flag; `run_job` stays the only function that touches the simulation. `SimPump` gains exactly `Job.want_ring` and `Note.ring`.
- **Existing tests:** no expected value changes and no allowed test edits are foreseen. A red existing case is a stop (Opus diagnosis).
- **Tests:** new cases named `test_sb4_*` (`WARGRID_TEST_ONLY=sb4_`), appended to their suite's `cases()` list (`test_sim_pump.gd:18-19`, `test_online_scene.gd:48-49`; the runner only runs listed cases, `run_tests.gd:87`). New tests use the [simulation interface](../../reference/sim-interface.md) plus the pump and the drivers; `driver.pump.live()` only to build or check state. Record each filtered run's case count.
- Typed GDScript (tests exempt from `untyped_declaration` only); comments one line, WHY only; edits with the Edit tool only. Subagents never commit, push, merge, deploy or open a window; the coordinator commits locally per green task when the run's handoff pre-authorizes it.
- **Commands:** every suite, lint, warnings, checks, netplay, conformance, team-match and benchmark call has Bash `timeout: 600000`, output to a file in `$L`, judged by exit code plus marker (`TESTS PASSED`, `CHECKS PASSED 5`, `NETPLAY PASSED <scenario>`, `CONFORMANCE PASSED <n>`, `REPLAYS MATCHED`, `PYTHON TESTS PASSED`, `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, `PUBLIC CHECK PASSED`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:|NETPLAY FAILED' <log>`. Forms, run from `$W`, written with absolute paths:
  - `SUITE(<tag>)`: `WARGRID_REPLAY_TRACE=<abs $L>/replay-<tag>.tsv WARGRID_ECONOMY_REPLAY_TRACE=<abs $L>/economy-<tag>.tsv WARGRID_COMBAT_REPLAY_TRACE=<abs $L>/combat-<tag>.tsv WARGRID_TEAM_REPLAY_TRACE=<abs $L>/team-<tag>.tsv sh tools/run_tests.sh > <abs $L>/<tag>-suite.log 2>&1; echo "exit=$?"`
  - `NET(<tag>, <scenario>)`: `NETPLAY_OUT=<abs $L>/<tag>-np-<scenario> sh tools/run_netplay.sh <scenario> > <abs $L>/<tag>-np-<scenario>.log 2>&1; echo "exit=$?"` (without `NETPLAY_OUT` the script's output folder is a temporary one).
  - `ONLY(<tag>, <filter>)`: `WARGRID_TEST_ONLY=<filter> sh tools/run_tests.sh > <abs $L>/<tag>-only.log 2>&1; echo "exit=$?"`
  - `EQUAL(<tag>)`: `python3 tools/compare_replays.py <abs $L>/replay-base.tsv <abs $L>/replay-<tag>.tsv` and the same for economy and combat; team with `--interval 200 --rows 100`; `--interval 30 --rows 0` for `<abs $L>/base-np-match/s1.tsv` against `<abs $L>/<tag>-np-match/s1.tsv` and the `rematch` pair; each `REPLAYS MATCHED`. Then `cmp <abs $L>/base-np-match/s1.cmd <abs $L>/<tag>-np-match/s1.cmd` and the `rematch` pair: silent.
  - Static: `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_tests.sh` (it runs `tools/test_sim_boundary.py`; a bare `python3 tools/test_sim_boundary.py` is not on the night allow list), each `> <abs $L>/<tag>-<name>.log 2>&1; echo "exit=$?"`.
- **Benchmarks:** `uptime` first; above 2.5, skip the run, record "host under load" and leave it as a morning item (no wait loop; user, 2026-11-17). The base run has no label: on branch `sim-boundary-sb4` `perf_record.py --auto` records nothing without one (`tools/run_benchmark.sh:38-39`), so no `PERF_RECORD=0` (that form is not on the night allow list). `PERF_LABEL="Sim boundary SB4"` at the gate. Never loosen a budget; exceeded rows are reported.
- **Mutation proofs:** before a mutation, `git add <file>` (production files changed by the task) or nothing (files clean against the base, Task 2); after the revert with the Edit tool, `git diff --exit-code -- <file> > <abs $L>/<tag>-revert.log 2>&1; echo "exit=$?"` → exit 0 proves the file is back. No copies, no `cp` (not on the night allow list). Each proof run gets its own `<tag>` so logs do not overwrite each other.
- **Evidence scope:** `run_netplay.sh` runs headless clients only (`--netclient` → `headless_client.gd`, `run_netplay.sh:101`), so every `NET(...)` row proves the lockstep composition (`advance` = take, issue, record, step) and says nothing about `online_driver.gd`; the online driver is covered by the Task 2 loopback and scene guards and the existing online scene suite.

## Model routing

- Implementers (Q10 A, user 2026-11-17): Opus (high) for Tasks 2, 3 and 4, against the "implement with the mid tier" default, because each needs judgment the plan cannot fully pin: the guards must be traced by hand on the base (frame and credit arithmetic), and the take-ahead and quiet-take semantics decide wire behaviour. Sonnet for Tasks 1, 5 and 6.
- Per-task review (`docs/night-run.md` "Reviews and task size"): before each commit in Tasks 2, 3 and 4 the coordinator dispatches one fresh-context Opus (high) reviewer, given the task's diff, the task text and "Same-tick and interaction cases" (paths, not history); it names per new test the production change that would make it fail; findings are checked against the source and fixed test-first. Each task's "Review" step says so; the coordinator does not read task bodies, so the step is also in the handoff.
- Gate (a protocol-adjacent test and driver diff): Opus (high) whole-branch, Grok normal (not fast; Opus alone if Grok is missing), `silent-failure-hunter` and `pr-test-analyzer`. Then `/ponytail-review` on Sonnet on the branch diff, cuts applied, gates rerun. Plus one read-only player-experience reviewer (`.claude/agents/player-experience-reviewer.md`) on the branch diff (Q15, user, 2026-11-17): no UI, HUD or text changes, but Q2's one-frame "Waiting" lag inside catch-up frames is a visible timing change (Risks below).
- Task 6 runs as short subagents, one each: checks (Step 1), benchmark (Step 2), reviews (Step 3, the coordinator dispatches the gate reviewers and one fix subagent), docs (Step 4: footers and resume record on the final tip). Briefs pass paths, never history.

## Review Focus

1. **Take-ahead past the end tick (Q2).** A catch-up or multi-callback frame takes tick e+1 while job e (which ends the match) is undrained. Expected: job e+1 runs on a finished match (its commands refused by `Simulation.issue_command`, `simulation.gd:196`; `step` returns at once, `:593`), its note's tick does not move and its `over` is true, so the driver records nothing and sends no packet for it; the take was quiet, so no `waiting`, `ended_left` or `ended_desync` appears. Guards `test_sb4_take_ahead_past_end`, `test_sb4_leave_on_end_tick_catch_up`, `test_sb4_no_waiting_after_end` (Task 2, green on the base; Task 4 Step 5 proves them).
2. **Own packet not yet sent.** Three physics callbacks before one `_process` after a stall: the sixth take needs the own packet that the first undrained job's `finish_tick` sends in the drain. The take is quiet, so no "Waiting for player <own seat>" (`OnlineDriver.notice`, `online_driver.gd:289`). Guard `test_sb4_three_callbacks_one_drain`.
3. **A note the driver did not post** (`BaseScene.publish`, `test_base_scene.gd:40-45`, posts a `step = false` job and calls `driver.drain()`): the taken-tick queue is empty, so the note records nothing and sends nothing. Guard `test_sb4_publish_is_not_a_tick`. Such a job posted between two driver jobs would mispair; the pairing guard (Q13) ends the match `ended_protocol` instead. Test `test_sb4_foreign_note_ends_match` (Task 4).
4. **Digest equality:** the job's `StateHash.digest(sim.snapshot())` (`run_job`, `sim_pump.gd:144-146`) equals what `finish_tick` computed on main; `finish_tick` uses a given digest and computes only when none is given. RB8 stays at 2 snapshots. Test `test_sb4_finish_tick_uses_given_digest` (Task 3).
5. **End of match in `drain` (Q5):** N4 (`test_match_end_sends_over_and_keeps_socket`, `:199-217`), N13 (`test_abnormal_end_closes_without_rematch`, `:219-236`) and N23 (`test_room_gone_on_the_ending_frame`, `:365-381`) expect the `over`, the close and the disabled Play again within the same `_run(main, 1)` frame; `_settle` runs the room-gone check right after `_finish`.
6. **Rematch:** the new lockstep's tick-0 hash row comes from the new pump's query. Guard `test_sb4_rematch_starts_from_new_pump`.
7. **Relay guards' refused-order answer** (`TOO_MANY_ORDERS`, appended to `_answers` in `OnlineDriver.submit`, `online_driver.gd:177`) still reaches the HUD before the same frame's drained answers. Its N-cap test (`test_too_many_orders_note`, `test_online_scene.gd:1651`) green unchanged.

## Relay guards collision

Relay guards is merged (`d56ad58`); its Task 4 ([Relay guards plan](2026-11-15-relay-guards.md), "Task 4: Client guards") and SB4 touch the same spots. SB4 keeps every symbol Relay guards names (`Lockstep.submit`, `finish_tick`, `advance`, `OnlineDriver.submit`, `_answers`, `take_answers`), so neither plan's "symbol gone" stop fires (Relay guards C26).

| # | Spot | Relay guards | SB4 | Rule |
|---|---|---|---|---|
| RG1 | `lockstep.gd` `submit` | returns `bool`; size check against `Wire.MAX_FRAME_BYTES - FRAME_RESERVE_BYTES`; new `_queue_bytes` | untouched | SB4 never reads `_queue_bytes`; `OnlineDriver.start` ignores the bool for `choose_faction`, as Relay guards' headless caller does |
| RG2 | `lockstep.gd` `finish_tick` | `_queue_bytes = 0` beside `_queue = []`; checked own-frame decode ending `ended_protocol` "own frame: …" before `_last_sent` and `send` | third parameter `digest: String = ""`; the `value` line only; `_finish_job` calls `finish_tick` only while the lockstep has not ended | both edits kept; an `ended_protocol` from `finish_tick` now happens inside `drain`; a later note of the same drain still records its tick but sends nothing (else packet t+1+delay would leave with t+delay missing, a tick gap the relay refuses); `_settle` then closes the transport in the same frame |
| RG3 | `online_driver.gd` `submit` | on a refused `Lockstep.submit` appends `{"command": payload, "ok": false, "error": TOO_MANY_ORDERS}` to `_answers` | `submit` untouched; `_new_answers()` moves from `step()` to the end of `drain()`; `_answers` stays the one buffer and `adopt` still clears it | answer order unchanged: input events run before physics, so the refusal precedes that frame's drained answers |
| RG4 | `cases()` lists | `test_online_scene.gd` N-cap; `test_lockstep.gd` L19, L20 | `test_sb4_*` into `test_online_scene.gd` and `test_sim_pump.gd`; `test_lockstep.gd` untouched (Q7) | one-line merge in `test_online_scene.gd` only |
| RG5 | `headless_client.gd` `_run_steps` | 5 s silence check | untouched | none |
| RG6 | guide chapter 11 and its `Checked against` footer | Relay guards Task 8 docs | Task 5 here | re-read the merged chapter before editing |

**Relay guards recheck on the base** (Task 1 Step 3, before any code; values below are `1be405a`): (a) `rg -n '^func (submit|finish_tick|start|advance|_verify_hashes)' game/scripts/net/lockstep.gd` and `rg -n '^func (submit|step|drain|adopt|start|_report|_new_answers)' game/scripts/match/online_driver.gd`; the Task 3 and Task 4 "before" descriptions still match, else re-anchor and record; (b) `finish_tick`'s own-frame early return (`lockstep.gd:146-148`) leaves the hash block at its top as it is, so the `value` line edit (`:133`) still applies; (c) L19 calls `finish_tick(9_999_990, pair[0].snapshot())` (`test_lockstep.gd:607`) and L20 `finish_tick(1, null)` (`:619`), both compatible with the default `digest`; (d) the base's netplay scenario count (17, `run_netplay.sh:2`), CI loop (15, `ci.yml:156`), conformance count (69) and vector count (19) go into the ledger; (e) N-cap, L19 and L20 green on the base; (f) the lockstep benchmark base row (Relay guards added an encode per submit).

## Determinism notes

- No simulation file changes. The tick's commands are issued in the same order as today: seat order, packet order (`take` keeps `advance`'s loops, `lockstep.gd:116-117`), then `step`; application order is `(tick, player, sequence)` anyway (`Simulation._command_before`, `simulation.gd:350-354`). `run_job` duplicates each command (`sim_pump.gd:129`), stamps nothing (lockstep commands carry `tick` and `sequence`, `:130-131`) and issues through the recorder, which calls `Simulation.issue_command` unchanged (`command_recorder.gd:11-14`).
- `record` reads the clock once per recorded tick, as `advance` does once per advanced tick (`lockstep.gd:115`), so latency samples keep their count and a fake clock sees the same call sequence. Inline the sample is taken at drain, inside the same frame as the job; in SB5 at most a frame later (latency display only, never a tick decision).
- A take-ahead job runs on a finished match: `issue_command` refuses every command before validation and `step` returns at once, so the state, digest and recorder do not change; the driver records nothing and sends nothing for it. A quiet take that refuses leaves `_status`, `_desync_tick` and `_end_reason` alone; the next loud take decides at the same tick as today.
- `finish_tick` with a given digest sends the value `StateHash.digest(state)` gives, because the job computed it from the same snapshot.
- The hash ring stays on for online sims (only the offline driver turns it off, `offline_driver.gd:29`).

## Same-tick and interaction cases

No new simulation command. New operations: `take` (loud and quiet), `record`, `finish_tick` with a digest, the online tick job, the start and ring query jobs. Each against the existing driver and lockstep events; a "frame" is the physics callbacks of one iteration, then one `_process` drain.

| Operation | Against | Expected | Test |
|---|---|---|---|
| take + issue + record + step | today's `advance` | same command log, latency count, rejections, hash rows, sent frames, digest | `test_sb4_take_record_equals_advance` (Task 3); netplay `s1.cmd`, `s1.tsv` equal |
| two takes in one callback | catch-up credit | two notes in tick order, both recorded and sent in order | N5 `test_catch_up_is_bounded` (`:533-544`), `test_sb3_online_two_notes` (`:1625-1649`) unchanged |
| take e+1 after job e ended the match | match end | job e+1 changes nothing; no record, no packet for e+1+delay; one `over`; status unchanged | `test_sb4_take_ahead_past_end` |
| quiet take, peer packet missing | match end in the in-flight job | no `waiting`; the HUD status line (`notice()`) stays empty behind the result panel | `test_sb4_no_waiting_after_end` |
| quiet take, peer packet missing | match goes on | `waiting` set by the next frame's loud take, one physics frame later than today | N2 waiting line (`test_status_lines_and_layout`, `:119-123`) unchanged; `test_sb4_quiet_take_keeps_status` |
| quiet take, `left` with `after_tick` = end tick | match end in the in-flight job | normal end, one `over`, "Your friend left", no `ended_left` (guide 11:178, L17 `test_left_on_normal_end_tick`, `test_lockstep.gd:564-577`) | `test_sb4_leave_on_end_tick_catch_up` |
| quiet take, `left` mid-match | match goes on | `ended_left` at the same tick on the next loud take | N13 (`:219-227`) unchanged |
| quiet take, hash mismatch | match goes on | `ended_desync` with the same desync tick on the next loud take; report as today | `test_sb4_quiet_take_keeps_status`; N2 desync (`:143-153`) |
| take, own packet missing (three callbacks, one drain) | catch-up | quiet refusal, no self-waiting; own packets sent contiguous after the drain | `test_sb4_three_callbacks_one_drain` |
| tick job | preview request | each job carries the request; the last drained answer wins; request cleared once a job was posted | RP8 `test_sb2_preview_after_catch_up` (`:1581`), RP4 unchanged |
| tick job | `submit` | `submit` still stamps `_last_sent + 1`; input is handled before physics, so a real frame never submits between step and drain (a test that submits there gets an earlier, still consistent stamp) | IC2 byte-equal |
| tick job | relay lost, closed or silent before the take | no take (lockstep ended); `_settle` in the drain finishes and closes | N13 lost half, N23 closed and silent |
| drain | `_finish` and room gone | same frame: `over` sent, room closed when gone, Play again disabled | N4, N23 |
| drain | `BaseScene.publish` note | skipped (no taken tick) | `test_sb4_publish_is_not_a_tick` |
| drain | a foreign `step = false` job posted between two driver jobs, mid-match (Q13) | its note pairs with the second taken tick t+1 but has `note.tick == t + 1` and `over` false: `ended_protocol` "note at tick t+1 for taken tick t+1", `_taken` cleared, the rest of the drain records nothing; no `over`; `_settle` finishes and closes in the same drain | `test_sb4_foreign_note_ends_match` (Task 4) |
| drain | jobs taken past the match end (`over` true, `note.tick` the end tick + 1, so `<= tick`; several in a multi-callback frame) | skipped before the pairing check; no `ended_protocol` | `test_sb4_take_ahead_past_end` (one such job); several: no test (same branch) |
| drain | Relay guards own-frame `ended_protocol` in `finish_tick` | later notes of the same drain record but send nothing; `_settle` finishes in the same drain | `test_sb4_no_send_after_end` (Task 4); L20 (lockstep only) |
| drain | Relay guards refused submit | refusal answer first, then the drained answers | N-cap (`test_too_many_orders_note`) |
| later physics callback of the frame | lockstep ended by `receive` (protocol error, relay `error`) or relay loss while a job is undrained | today that tick's packet and hash row left in `step`, and `over` too when the tick ended the match; SB4 records the tick and skips `finish_tick` (`if not _ended()`), and when that job ended the match no `over` is sent before the close; end state equal (transport closed, phase `done`) | none needed (end state equal); N13, N23 unchanged |
| start query | `choose_faction` queued before `start` | stamped tick 4 as today; row 0 equals the pump's tick-0 digest | `test_sb4_rematch_starts_from_new_pump`, N18 (`test_rematch_builds_new_match`, `:408-444`) |
| rematch | posted, undrained job of the old match | cannot happen: the old match is over, so `_last.over` stops takes, and a `start` is accepted only in phase `again` (`_on_session`, `online_driver.gd:55`); `adopt` clears the queue anyway | `test_sb4_rematch_starts_from_new_pump` |
| rematch | `start` and `left` in one batch | no new match, as today | N21 (`test_start_then_left_same_batch`, `:485-511`) unchanged |
| ring query | desync | report `hash_ring` equals the live ring at the desync; `hash_rows` include the last finished tick | `test_sb4_desync_report_ring`, `test_sb4_ring_query` |
| `leave()` | undrained job | `_finished` is already true; the drain records that job's tick, `_settle` does nothing more | leave tests (N-series, `test_pause_menu.gd`) unchanged |

## Files

| File | Change |
|---|---|
| `game/scripts/net/lockstep.gd` | `take`, `record`; `advance` composed of them; `finish_tick` and `start` take an optional digest; `_verify_hashes` takes `quiet`; `set_protocol_error` (Task 4, Q13) |
| `game/scripts/match/sim_pump.gd` | `Job.want_ring`, `Note.ring`, one line in `run_job` |
| `game/scripts/match/online_driver.gd` | `step` takes and posts; `drain` records, sends, settles; `start` and `_report` use query jobs; `adopt` resets `_taken` and `_next_tick`; no `pump.live()` left |
| `tools/test_sim_boundary.py` | `online_driver.gd` off `LIVE_ALLOWLIST`; exact-path test on `sim_pump.gd` |
| `game/tests/test_sim_pump.gd` | `test_sb4_*` loopback, lockstep and ring cases |
| `game/tests/test_online_scene.gd` | `test_sb4_*` scene guards |
| docs | guide `01-big-picture`, `04-the-tick`, `05-presentation`, `10-determinism-and-replays`, `11-multiplayer`, `12-performance-and-platforms`, `13-testing-and-tooling` (each `Checked against` footer); `docs/reference/sim-interface.md`; spec row SB4; `docs/STATUS.md` night-6 row; `docs/reference/sim-boundary-verification.md` `## SB4` |

---

### Task 1: Base, verification file and base evidence

**Files:** Modify: `docs/reference/sim-boundary-verification.md` (new `## SB4` section from `~/projects/wargrid-overnight-work/sb4/plan/verification.md`: resume record, ledger, base counts, line map, Relay guards recheck). The plan itself is already at `docs/superpowers/plans/2026-11-17-sim-boundary-sb4.md` (preparation commit).

- [ ] **Step 1:** Check, do not create: `git rev-parse --show-toplevel` prints `<abs $W>` and `git rev-parse --abbrev-ref HEAD` prints `sim-boundary-sb4` (the worktree comes from `/prepare-night-run`; if either differs, stop: every relative command would run on the wrong tree). `mkdir -p <abs $L>`. Record `git rev-parse HEAD` and `git log --oneline -1` as the ledger's first line. Q1 A: `rg -n 'TOO_MANY_ORDERS' game/scripts/match/online_driver.gd` and `rg -n 'FRAME_RESERVE_BYTES' game/scripts/net/lockstep.gd` each give at least one hit (Relay guards Task 4 is on the base, also after a fast-forward); otherwise stop and ask.
- [ ] **Step 2:** Refresh every path:line in this plan on the base by symbol (`rg -n '^func <name>' <file>`); write the map. A cited symbol that no longer exists is a stop.
- [ ] **Step 3:** Relay guards recheck (a)-(f) above; record each result.
- [ ] **Step 4:** Base evidence: `SUITE(base)`; `ONLY(base-l, test_lockstep)` and `ONLY(base-o, test_online_scene)` (the case counts Tasks 3 and 4 compare with); `NET(base, match)`; `NET(base, rematch)`; `sh tools/run_team_match.sh > <abs $L>/base-team.log 2>&1; echo "exit=$?"`; `sh tools/run_checks.sh > <abs $L>/base-checks.log 2>&1; echo "exit=$?"` (`CHECKS PASSED 5`); `sh tools/run_conformance.sh > <abs $L>/base-conf.log 2>&1; echo "exit=$?"`; `uptime` (Global Constraints, Benchmarks), then `sh tools/run_benchmark.sh > <abs $L>/base-bench.log 2>&1; echo "exit=$?"` (no label: nothing is recorded; it runs `run_lockstep.gd` and prints its log, `run_benchmark.sh:25`, so the lockstep base row is read from this log, not run a second time). Record cases, checks, markers.
- [ ] **Step 5:** Counts for the ledger: `rg -c 'pump\.live\(\)' game/scripts/match/online_driver.gd` (6 lines on `1be405a`: `start` :84, `step` :102, :109, :110, :114, `_report` :259); `rg -n 'shortcut: live read' game/scripts/match` (6); `rg -n 'online_driver' tools/test_sim_boundary.py` (3: `LIVE_ALLOWLIST` :49, `test_live_allowlist_is_exact_path` :154, :155); `rg -c 'pump\.live\(\)' game/tests/test_online_scene.gd` (46); the `cases()` lengths of `test_sim_pump.gd` (11) and `test_online_scene.gd` (62 on `1be405a`); suite base 1079 cases on `425aa44` (1039 at `relay-guards-verification.md:305`, plus P12's 40). Line numbers that moved since `1be405a` (P12: `match_screen.gd`, `test_online_scene.gd`, guide 05) are expected, not a stop; only a missing symbol stops.
- [ ] **Step 6: Frame order probe (Q12 A).** The take-ahead and three-callback cases (Review Focus 1, 2) and their fixtures (bare `_physics_process` calls, then one `_drain_notes`) assume Godot runs every physics callback of a main-loop iteration before that iteration's `_process`. With the Write tool create `<abs $L>/frame-order-probe.gd` (outside tracked source; covered by the night `Edit` rule on `~/projects/wargrid-overnight-work/**`): `extends SceneTree`; `_initialize()` first starts a SceneTree timer, `create_timer(10.0)`, whose timeout prints `FRAME ORDER FAILED timeout` and calls `quit(1)` (a script error inside the node cannot stop it), then adds one `Node` (an inner class) to `root` whose `_physics_process` appends `"P"` and whose `_process` appends `"R"`, each with `Engine.get_physics_frames()` and `Engine.get_process_frames()`; the 5th `_process` calls `OS.delay_msec(250)` (about 7 physics steps owed at the project's 30 ticks per second, `game/project.godot` `physics/common/physics_ticks_per_second=30`, under the default cap of 8 per iteration); after the 15th `_process` it prints every line, then `FRAME ORDER PASSED <n>` and `quit(0)` when the callbacks right after the stalled `R` are an unbroken run of n ≥ 3 `P` followed by one `R`, else `FRAME ORDER FAILED` and `quit(1)`; a `_process` count above 600 prints `FRAME ORDER FAILED timeout` and `quit(1)`, so every path quits (AGENTS.md "Implementation"). Run `godot --headless --path <abs $W>/game --script <abs $L>/frame-order-probe.gd > <abs $L>/t1-frame-order.log 2>&1; echo "exit=$?"` (Bash `timeout: 600000`; the night rule `godot` covers it). If Godot refuses the absolute script path (no marker, a load error), write a minimal `<abs $L>/frame-order/project.godot` (`config_version=5` first, then only `[physics]` `common/physics_ticks_per_second=30`) and `<abs $L>/frame-order/probe.gd` and run `godot --headless --path <abs $L>/frame-order --script res://probe.gd` the same way. Record the marker, n and the stalled iteration's lines (with their process-frame numbers) in the ledger. `FRAME ORDER FAILED` (other than a path refusal fixed by the fallback) is a stop (stop gate 2): the take-ahead and three-callback cases rest on that order.
- [ ] **Step 7:** `sh tools/check_public.sh > <abs $L>/t1-public.log 2>&1; echo "exit=$?"` → `PUBLIC CHECK PASSED` (no typed absolute path in the verification file); then the coordinator commits the verification file.

### Task 2: Loopback test and online guards on the base

Characterization first: these cases use only the SB3 driver API and must pass on the base before any production change, so Tasks 3 and 4 are measured against them.

**Files:** Modify: `game/tests/test_sim_pump.gd`, `game/tests/test_online_scene.gd` (cases and helpers, Q7 A).

**Interfaces (test-only):**
- In `test_sim_pump.gd`: `const OnlineDriver = preload("res://scripts/match/online_driver.gd")`, `const Lockstep = preload("res://scripts/net/lockstep.gd")`, `const Wire = preload("res://scripts/net/wire.gd")`.
- `class PairTransport extends RefCounted`: `var patient: bool = false`, `var peer`, `var inbox := PackedStringArray()`, `var others: Array[String] = []`; `poll()` returns and clears `inbox`; `send_text(text)` appends to `peer.inbox` when `Wire.decode(text).message.get("type") == "tick"` (the relay forwards ticks; `over` and `again` end at the relay), else to `others`; `closed()` false, `silent(_now)` false, `close()` does nothing, `rtt_samples()` an empty `PackedInt64Array` (the methods `OnlineDriver` calls on its transport, `online_driver.gd:97-98, 112, 213, 238, 265`).
- `_pair_drivers()`: two transports peered; `OnlineDriver.new(a, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)` and `OnlineDriver.new(b, Lockstep.new(2, [1, 2] as Array[int]), "china", 2)` (typed `seats`, as SK23, `test_skirmish.gd:693`); each `create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)` then `start()` (as `match_screen._ready` does, `match_screen.gd:96, 111`).
- `_frames(drivers, frames, lag)`: per frame `one.step(); one.drain()`, then the same for seat 2 unless `lag > 0 and frame % lag == 0` (seat 1 then stalls and catches up two ticks in one callback).
- `_replay_rows(lines, last_tick)`: a fresh `Skirmish.create(true, "human", {}, Skirmish.MAP_PATH, [] as Array[int])` (as `OnlineDriver.create`, `online_driver.gd:70`); for tick 0 to `last_tick`, issue every command of the log line for that tick (`Wire.decode(line).message.commands`), then step; at every tick `t` with `t % 30 == 0` (before stepping it) add `"%d\t%s" % [t, StateHash.digest(sim.snapshot())]`.
- In `test_online_scene.gd`, the guards use seat 2 and the existing helpers (`_online` :51-61, `_run` :68-69, `_peer_packets` :63-66, `_sent_types` :173-174, `_rematch_start` :190-191, `_end_match`'s removal of entities 4 and 6, :166-171) plus `_sent_ticks(transport) -> Array[int]` (the `tick` of every sent `tick` frame, in order) and `const StateHash = preload("res://scripts/simulation/state_hash.gd")`. Fixture `_end_in_catch_up(online, last_peer_tick, extra: Array)`: `_peer_packets(transport, 1, 4, 8)`; `_run(main, 12)` (frames 1-9 run ticks 0-8, frames 10-12 stall at tick 9 and raise the credit to 3); `remove_object(4)` and `remove_object(6)` on `pump.live()` (the next step ends the match, as in N23); append the peer packet for tick 9; when `last_peer_tick >= 10`, a tick-10 packet carrying `{"type": "stop", "entity_ids": [3], "tick": 10, "player": 1, "sequence": 1}`, then `_peer_packets(transport, 1, 11, last_peer_tick)`; append `extra`; one `_run(main, 1)` (credit 4: the job for tick 9 ends the match, the second take is tick 10).

- [ ] **Step 1: Write the tests:**
  - `test_sb4_two_drivers_loopback` (`test_sim_pump.gd`): `_pair_drivers()`; `_frames(drivers, 20, 0)`; seat 1 submits a move for its first own entity (`pump.live().snapshot().entities`, owner 1) and a move for entity 999 (refused at issue: missing entity); seat 2 a move for its own entity; `_frames(drivers, 360, 3)` (seat 2 steps on two frames of three, about 240 ticks). Checks: both `_lockstep.hash_rows()` agree on their common prefix, which has at least 8 rows (ticks 0 to 210); the two `match_log().commands` agree line by line up to the lower last stepped tick; `_replay_rows(one.match_log().commands, 210)` equals the first 8 rows; seat 1's `take_answers()` hold exactly one `ok == false` answer (the 999 move), seat 2's none; no `_lockstep.status()` starts with `ended`.
  - `test_sb4_two_drivers_match_end` (`test_sim_pump.gd`): as above without orders and with `lag = 0` (both seats then run one tick per frame, so each is seen at every tick); after each driver's own drain, when its `current().tick == 100`, `remove_object(4)` and `remove_object(6)` on its `pump.live()` (the same tick on both, so the sims stay equal; the test checks both were seen at tick 100); run until both `over()` or 400 frames. Checks: both `over()`; `record().tick` and `record().digest` equal on both; each transport's `others` holds exactly one `over`; no `ended_*` status.
  - `test_sb4_take_ahead_past_end`: `_end_in_catch_up(online, PEER_TICKS, [])`. Checks: `driver.current().tick == 10` and the match is over; `driver._lockstep.command_log()` has no entry with `tick == 10`; `_sent_ticks(transport)` ends with 14 (sent by `finish_tick(10)` after the ending tick) and holds each tick once (no 15); `_sent_types(transport, "over") == 1`; status `running`; `driver.notice() == ""`; `driver.record().tick == 10`.
  - `test_sb4_leave_on_end_tick_catch_up`: `_end_in_catch_up(online, 9, [Wire.encode({"type": "left", "seat": 1, "after_tick": 9})])`. Checks: status not `ended_left`; `not driver.opponent_left()`; `_sent_types(transport, "over") == 1`; `driver.rematch_line() == "Your friend left"` (guide 11:178).
  - `test_sb4_no_waiting_after_end`: `_end_in_catch_up(online, 9, [])`, then `_run(main, 3)`. Checks: status not `waiting`; `driver.notice() == ""`; `HUD/Status` text has no "Waiting".
  - `test_sb4_three_callbacks_one_drain`: `_run(main, 10)` (stall at tick 4, credit at its cap); `_peer_packets(transport, 1, 4, PEER_TICKS)`; three bare `main._physics_process(1.0 / 30.0)`, then `main._drain_notes()`. Checks: status `running`; `driver.notice() == ""`; `driver.current().tick >= 9` (9 on SB4: the sixth take waits for the own packet that the first job's `finish_tick` sends in the drain; 10 on the base, where `finish_tick` runs inside `step`); then `_run(main, 3)`: the tick advanced and `_sent_ticks(transport)` is contiguous from 4 with no gap.
  - `test_sb4_publish_is_not_a_tick`: peer packets 4..`PEER_TICKS`; `_run(main, 8)`; keep `command_log().size()` and `transport.sent.size()`; `BaseScene.publish(main)`; both sizes unchanged; `_run(main, 1)` advances exactly one tick.
  - `test_sb4_rematch_starts_from_new_pump`: N18's steps (`test_rematch_builds_new_match`, `:409-423`) up to the rematch frame; then `driver._lockstep.hash_rows() == PackedStringArray(["0\t" + StateHash.digest(driver.pump.live().snapshot())])` and the last sent frame is the new match's tick 4 carrying that hash.
  - `test_sb4_desync_report_ring`: no file (N2 writes and deletes `user://desync/desync-seat2.json` for seat 2, `test_online_scene.gd:148-152`, and the full suite runs up to 4 shard processes, `tools/run_tests.sh:25-34`, so a second writer of that path races it): N2w's web fixture (`:155-160`) with `driver.web = true` and `driver.download = func(buffer: PackedByteArray, _file_name: String, _mime: String) -> void: downloads.append(buffer)` (`OnlineDriver._write_report`, `online_driver.gd:247-249`); after `_run(main, 12)`, `downloads.size() == 1`; `JSON.parse_string(downloads[0].get_string_from_utf8())` gives a report whose `hash_ring` equals `Array(driver.pump.live().hash_ring())` and whose `hash_rows` equal `Array(driver._lockstep.hash_rows())` (no `file_exists` check: N2 may hold that path at the same moment).
- [ ] **Step 2:** `ONLY(t2, sb4_)` on the base → exit 0, 9 cases. Green by design; a red case is a stop (the base does not behave as this plan assumes; Opus diagnosis).
- [ ] **Step 3:** Two mutation proofs on the base, each reverted with the Edit tool and proven by `git diff --exit-code -- game/scripts/match/online_driver.gd` (Global Constraints, Mutation proofs): `OnlineDriver._new_answers` returns `[]` at once → `ONLY(t2m1, sb4_two_drivers)` exit 1 (answer check); in `OnlineDriver.step` the `_finish` check without its `pump.live().match_over()` clause → `ONLY(t2m2, sb4_take_ahead)` exit 1 (no `over`). Record. Task 4 Step 5 proves the guards against the new code.
- [ ] **Step 4:** `sh tools/run_lint.sh`, `sh tools/run_warnings.sh` exit 0; `sh tools/run_python_tests.sh` exit 0 (`test_new_files_clean`: no simulation privates read).
- [ ] **Step 5: Review:** the coordinator dispatches the per-task Opus (high) reviewer (Model routing) on the task's diff; fixes test-first, Step 2 rerun.
- [ ] **Step 6:** Coordinator commits.

### Task 3: Lockstep split

**Files:** Modify: `game/scripts/net/lockstep.gd` (`start` :61-63, `advance` :107-128, `finish_tick` :130-151, `_verify_hashes` :241-250 on `1be405a`). Test: `game/tests/test_sim_pump.gd`.

**Interfaces.** Before (`1be405a`): `start(state)` calls `finish_tick(0, state)`; `advance(sim)` checks `_ended() or sim.match_over()`, the left seat, `can_step`, `_verify_hashes`, then per seat issues each packet command, logs it and, for own commands, the latency and any rejection, erases the packets, steps and sets `_next_tick` and `_status`; `finish_tick(tick, state)` computes `StateHash.digest(state)` on hash ticks, then encodes and decodes its own frame and ends `ended_protocol` "own frame: …" without sending when the decode fails (`:146-148`). After:

```gdscript
func start(state: Dictionary, digest: String = "") -> void:
	_last_sent = _delay - 1
	finish_tick(0, state, digest)

# quiet: the caller cannot tell yet whether the tick before ended the match, so a refusal must not change the status.
func take(tick: int, quiet: bool = false) -> Variant:
	if _ended(): return null
	if _left_seat != 0 and (tick > _left_after or not _packets[_left_seat].has(tick)):
		if not quiet: _end("ended_left", "player %d disconnected" % _left_seat)
		return null
	if not can_step(tick):
		if not quiet: _status = "waiting"
		return null
	if not _verify_hashes(tick, quiet): return null
	var commands: Array[Dictionary] = []
	for s in _seats:
		for command: Dictionary in _packets[s][tick].commands: commands.append(command)
		_packets[s].erase(tick)
	_next_tick = tick + 1
	_status = "running"
	return commands

func record(tick: int, issued: Array[Dictionary]) -> void:
	var now: int = _clock.call()
	for entry: Dictionary in issued:
		var command: Dictionary = entry.command
		_command_log.append(command)
		if command.player != _seat: continue
		_latency.append(now - _submit_times[command.sequence])
		_submit_times.erase(command.sequence)
		if not entry.ok: _rejections.append({"tick": tick, "sequence": command.sequence, "error": entry.error})

func advance(sim: Simulation) -> bool:
	if sim.match_over(): return false
	var tick: int = sim.tick()
	var commands: Variant = take(tick)
	if commands == null: return false
	var issued: Array[Dictionary] = []
	for command: Dictionary in commands:
		var result: Dictionary = sim.issue_command(command)
		issued.append({"command": command, "ok": result.ok, "error": result.error})
	record(tick, issued)
	sim.step()
	return true
```

- `finish_tick(tick: int, state: Variant, digest: String = "")`: the line `var value: String = StateHash.digest(state)` (`:133`) becomes `var value: String = digest if not digest.is_empty() else StateHash.digest(state)`; nothing else in it changes (Relay guards' edits there stay, RG2).
- `_verify_hashes(tick: int, quiet: bool = false)`: on a mismatch, `if quiet: return false` before `_desync_tick = …` and `_end(…)`.
- `command.player` equals the packet's seat for every command (`_receive_tick` checks it, `:224`; own commands are stamped `_seat` in `submit`, `:68`), so `record`'s test is today's `if s != _seat` (`:120`).
- Unchanged: `submit`, `receive`, `can_step`, `waiting_for*`, `desync_report`, `log_lines`, every status string. Q2 A: drop `quiet` and its three branches.

- [ ] **Step 1: Write the failing tests** (`test_sim_pump.gd`, scene-free; two `Skirmish.create(true, "human")` sims; `Lockstep.new(1, [1, 2] as Array[int], 4, 30, clock)` with a counter clock `func() -> int` that adds 1000 per call; seat-2 packets from `Wire.tick_message`; `send` captured into an array):
  - `test_sb4_take_record_equals_advance`: twin A runs `advance(sim)` then `finish_tick(sim.tick(), sim.snapshot() if wants_snapshot else null)`; twin B runs `take(sim.tick())`, `sim.issue_command` per command, `record`, `sim.step()`, `finish_tick(tick, snapshot, StateHash.digest(snapshot))` on hash ticks; 70 ticks, with an own refused command (unknown entity), an own accepted move and a peer move. Equal on both: `command_log()`, `latency_samples()`, `rejections()`, `hash_rows()`, `status()`, the captured frames, `StateHash.digest(sim.snapshot())`.
  - `test_sb4_quiet_take_keeps_status`: (a) peer packet missing: `take(t, true)` null and `status()` unchanged; `take(t)` null and `status() == "waiting"`; (b) `left` with `after_tick` below `t`: quiet null, status not `ended_left`; loud → `ended_left`; (c) a peer packet whose hash differs: quiet null, `desync_report().tick == -1`, status not ended; loud → `ended_desync` and `desync_report().tick` the hash's tick; (d) a successful quiet take returns the same commands as a loud one on a twin, and `waiting_for()` then names the next tick's missing seats.
  - `test_sb4_finish_tick_uses_given_digest`: `finish_tick(30, snap, "feedfacecafebeef")` sends a frame whose `hash.value` is that string and `hash_rows()[-1]` ends with it; `finish_tick(60, snap)` sends `StateHash.digest(snap)`; `start(snap, d)` makes row 0 `"0\t" + d`.
- [ ] **Step 2:** `ONLY(t3red, sb4_)` → exit 1 (no `take`, no digest parameter). Record.
- [ ] **Step 3:** Implement as in Interfaces.
- [ ] **Step 4:** `ONLY(t3, sb4_)` exit 0, 12 cases; `ONLY(t3l, test_lockstep)` exit 0 with `ONLY(base-l, …)`'s case count (Task 1 Step 4); `git diff <base> --stat -- game/tests/test_lockstep.gd game/benchmarks/run_lockstep.gd game/scripts/net/headless_client.gd` empty; lockstep benchmark in the Task 1 form (`uptime`, then `sh tools/run_benchmark.sh > <abs $L>/t3-bench.log 2>&1; echo "exit=$?"`, no label; its lockstep row is in that log) `LOCKSTEP BENCHMARK PASSED 1`, p99 recorded against the base; `SUITE(t3)` exit 0 with base cases + 12; `NET(t3, match)`, `NET(t3, rematch)`; `EQUAL(t3)`; lint, warnings exit 0.
- [ ] **Step 5:** `git add game/scripts/net/lockstep.gd`; mutation proofs, each reverted and proven by `git diff --exit-code -- game/scripts/net/lockstep.gd`: `record` logs only own commands → `ONLY(t3m1, sb4_take_record)` exit 1; `quiet` ignored in the left branch → `ONLY(t3m2, sb4_quiet)` exit 1; `finish_tick` ignores `digest` → `ONLY(t3m3, sb4_finish_tick)` exit 1. Record.
- [ ] **Step 6: Review:** the coordinator dispatches the per-task Opus (high) reviewer (Model routing) on the task's diff; fixes test-first, Step 4 rerun.
- [ ] **Step 7:** Coordinator commits.

### Task 4: The online driver on jobs

**Files:** Modify: `game/scripts/match/sim_pump.gd` (`Job` :12-17, `Note` :19-31, `run_job` :144-146), `game/scripts/net/lockstep.gd` (`set_protocol_error` beside `set_relay_lost` :162-164), `game/scripts/match/online_driver.gd` (`adopt` :72-79, `start` :81-84, `step` :96-115, `drain` :117-123, `_report` :258-261), `tools/test_sim_boundary.py` (`LIVE_ALLOWLIST` :46-51, `test_live_allowlist_is_exact_path` :153-155). Test: `game/tests/test_sim_pump.gd`, the Task 2 guards, `tools/test_sim_boundary.py`.

**Interfaces:**
- `sim_pump.gd`: `Job` gains `var want_ring: bool = false`; `Note` gains `var ring: PackedStringArray = PackedStringArray()`; in `run_job` after the `want_digest` block: `if job.want_ring: note.ring = sim.hash_ring()`.
- `lockstep.gd` (Q13): `func set_protocol_error(reason: String) -> void:` with `if _ended(): return` then `_end("ended_protocol", reason)`, shaped like `set_relay_lost`; the existing `ended_protocol` status and the HUD's "Protocol error: …" line (`OnlineDriver.notice`, `online_driver.gd:293`) are reused, no new status string.
- `online_driver.gd` new fields: `var _taken: Array[int] = []` (the tick each posted, undrained job took, in post order) and `var _next_tick: int = 0`. In `adopt`, after `_last = first_note`: `_next_tick = first_note.tick` and `_taken = []`.
- `start` before (`:81-84`): `_lockstep.start(pump.live().snapshot()) # shortcut: …`. After (Q3 A):

```gdscript
func start() -> void:
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _own_faction})
	var job := SimPump.Job.new()
	job.step = false
	job.want_digest = true
	var note: SimPump.Note = pump.query(job)
	_lockstep.start(note.snapshot, note.digest)
```

- `step` before (`:96-115`): the loop calls `_lockstep.advance(pump.live())`, posts a `step = false` job, reads `pump.live().tick()` and `snapshot()` for `finish_tick`; after the loop it appends `_new_answers()`, checks `pump.live().match_over()` for `_finish` and checks the room. After:

```gdscript
func step() -> void:
	for text: Variant in _transport.poll(): _lockstep.receive(text)
	if not _finished and (_transport.closed() or _transport.silent(Time.get_ticks_usec())): _lockstep.set_relay_lost()
	_credit = mini(_credit + 1, MAX_CATCH_UP_CREDIT)
	var posted: bool = false
	for i in CATCH_UP_STEPS:
		if _credit < 1 or _last.over: break
		var commands: Variant = _lockstep.take(_next_tick, not _taken.is_empty())
		if commands == null: break
		_credit -= 1
		pump.post(_tick_job(commands))
		_taken.append(_next_tick)
		_next_tick += 1
		posted = true
	if posted: _preview_request = {}
	if _phase == "playing" and _lockstep.received_any(): _transport.patient = false

func _tick_job(commands: Array[Dictionary]) -> SimPump.Job:
	var job := SimPump.Job.new()
	job.commands = commands
	job.preview = _preview_request
	job.want_digest = _lockstep.wants_snapshot(_next_tick + 1)
	return job
```

- `drain` before (`:117-123`): preview answer and `_last` only. After:

```gdscript
# The last advance's preview answer wins, as the screen shows the last tick.
func drain() -> Array[SimPump.Note]:
	var notes: Array[SimPump.Note] = pump.drain()
	for note: SimPump.Note in notes:
		if not note.preview.is_empty(): _preview_answer = note.preview
		_finish_job(note)
	if not notes.is_empty(): _last = notes[-1]
	_answers.append_array(_new_answers())
	_settle()
	return notes

# No taken tick: a test's publish job. A tick that did not move on a finished match: taken past the end.
func _finish_job(note: SimPump.Note) -> void:
	if _taken.is_empty(): return
	var tick: int = _taken.pop_front()
	if note.over and note.tick <= tick: return
	if note.tick != tick + 1:
		# Pairing is by post order; a foreign job in between would record and send the wrong tick.
		_lockstep.set_protocol_error("note at tick %d for taken tick %d" % [note.tick, tick])
		_taken.clear()
		return
	_lockstep.record(tick, note.issued)
	# An end inside an earlier finish_tick of this drain sent nothing; a later packet would leave a tick gap.
	if not _ended(): _lockstep.finish_tick(note.tick, note.snapshot if not note.digest.is_empty() else null, note.digest)

func _settle() -> void:
	if not _finished and (_last.over or _ended()): _finish()
	if (_phase == "over" or _phase == "again") and _room_gone(): _close_room()
```

- `_report` before (`:258-261`): `_lockstep.desync_report(pump.live())`. After (Q4 A):

```gdscript
func _report() -> Dictionary:
	var job := SimPump.Job.new()
	job.step = false
	job.want_ring = true
	var report: Dictionary = _lockstep.desync_report()
	report.hash_ring = pump.query(job).ring
	report.merge(MatchSettings.report_fields(_map_path.get_file().get_basename(), _seed, _starts))
	return report
```

- Every `# shortcut: live read, SB4 moves it into jobs` comment goes with its line. Unchanged: `submit`, `take_answers`, `_new_answers` (only its call site moves), `_finish`, `_room_gone`, `_close_room`, `take_rematch`, the phases, `notice`, `match_log`, `record()`, `match_stats`, `leave`, `detach`, `request_preview`, `preview_answer`. `match_screen.gd` is not touched: `_step_frame` still calls `driver.step()` then `take_rematch()` (`:197-205`), `_drain_notes` still calls `driver.drain()` then `_take_answers()` (`:207-215`).
- `tools/test_sim_boundary.py`: delete `"game/scripts/match/online_driver.gd",  # until SB4 moves lockstep into jobs` from `LIVE_ALLOWLIST`; `test_live_allowlist_is_exact_path` becomes:

```python
    def test_live_allowlist_is_exact_path(self):
        self.assertEqual(live_reads("game/scripts/presentation/sim_pump.gd", "driver.sim.tick()"), [".sim"])
        self.assertEqual(live_reads("game/scripts/match/sim_pump.gd", "driver.sim.tick()"), [])
```

- [ ] **Step 1: Write the failing tests:** the static check edit above, and `test_sb4_ring_query` in `test_sim_pump.gd` (a pump around an online-style sim, 40 posted jobs; `query(Job{step = false, want_ring = true}).ring == live().hash_ring()` with 40 rows; `current()` and the note queue unchanged; without `want_ring` the ring is empty). `test_sb4_no_send_after_end` in `test_online_scene.gd`: seat 2, the three-callback fixture of `test_sb4_three_callbacks_one_drain` up to the peer packets (`_run(main, 10)`, `_peer_packets(transport, 1, 4, PEER_TICKS)`); keep `_sent_ticks(transport)`; push one command larger than `Wire.MAX_FRAME_BYTES` into `driver._lockstep._queue` (as L20 does, `test_lockstep.gd:618`) **before** the three bare `main._physics_process(1.0 / 30.0)` calls; then `main._drain_notes()`. Old path (Task 3's tree): the first callback's `finish_tick` inside `step` ends `ended_protocol` (`lockstep.gd:146-148`) and `advance` refuses after it (`:108`). New path: the drain's first note ends it in `finish_tick`, the later notes record only. Checks: status `ended_protocol` with a reason starting `own frame`; `_sent_ticks(transport)` equals the kept list (nothing sent after the failing frame, so no gap); `command_log()` holds every recorded tick's commands.
  `test_sb4_foreign_note_ends_match` in `test_online_scene.gd` (Q13): seat 2; `_peer_packets(transport, 1, 4, PEER_TICKS)`; `_run(main, 8)` (steady: each physics callback then takes one tick); keep `t := driver.current().tick` and `_sent_ticks(transport)`; one bare `main._physics_process(1.0 / 30.0)` (takes t; check `driver._next_tick == t + 1`, so no leftover catch-up credit took t+1 already); `driver.pump.post(job)` with a `SimPump.Job` whose `step = false` (the foreign job, as `BaseScene.publish` posts); a second bare `main._physics_process(1.0 / 30.0)` (takes t+1, quiet); then `main._drain_notes()`. Checks: status `ended_protocol` and `end_reason()` begins with `note at tick`; `command_log()` has no entry with `tick == t + 1`; `_sent_ticks(transport)` is the kept list plus one packet (from `finish_tick(t + 1)`); `_sent_types(transport, "over") == 0`; `driver.notice()` begins with `Protocol error`. Fails without the guard: the foreign note (tick t+1, `over` false) passes the old `note.tick != tick + 1` return as if taken past the end, so tick t+1 is never recorded or sent and the status stays `running`.
- [ ] **Step 2:** `sh tools/run_python_tests.sh > <abs $L>/t4red-py.log 2>&1; echo "exit=$?"` → exit 1, `test_screen_reads_no_live_sim` names `online_driver.gd`; `ONLY(t4red, sb4_ring)` → exit 1 (no `want_ring`); `ONLY(t4red2, sb4_foreign)` → exit 1 (Task 3's driver drains the foreign note without a check, status `running`); `ONLY(t4g, sb4_no_send)` green on Task 3's tree: the old path calls `advance`, which refuses after an end, so the case is a guard that Step 5 proves. Record.
- [ ] **Step 3:** Implement as in Interfaces.
- [ ] **Step 4:** `sh tools/run_python_tests.sh` → `PYTHON TESTS PASSED`; `rg -n 'pump\.live\(\)|shortcut: live read' game/scripts/match` no hits outside `sim_pump.gd` (`rg` exits 1 when nothing matches: exit 1 with empty output is the pass, any printed line outside `sim_pump.gd` the failure); `ONLY(t4, sb4_)` exit 0, 15 cases; `ONLY(t4o, test_online_scene)` exit 0 with `ONLY(base-o, …)`'s case count plus 9 (62 + 9 = 71); `ONLY(t4s, test_desync_report_names)` (SK23 builds a driver without a scene, `test_skirmish.gd:692-697`) exit 0; `SUITE(t4)` exit 0 with base cases + 15; `NET(t4, match)`, `NET(t4, rematch)`; `EQUAL(t4)`; lint, warnings exit 0; `sh tools/run_checks.sh` → `CHECKS PASSED 5`.
- [ ] **Step 5:** `git add game/scripts/match/online_driver.gd game/scripts/match/sim_pump.gd game/scripts/net/lockstep.gd`; mutation proofs, each reverted and proven by `git diff --exit-code -- <file>`: `_finish_job` without the empty-queue return → `ONLY(t4m1, sb4_publish)` exit 1; without the `note.over and note.tick <= tick` return → `ONLY(t4m2, sb4_take_ahead)` exit 1 (the past-end note hits the pairing check: `ended_protocol`, no longer `running`); `take(_next_tick)` loud always → `ONLY(t4m3, sb4_)` exit 1 (`leave_on_end_tick_catch_up`, `no_waiting_after_end`, `three_callbacks_one_drain`); the start query without `want_digest` → `ONLY(t4m4, sb4_rematch)` exit 1; `want_ring` not set in `_report` → `ONLY(t4m5, sb4_desync)` exit 1; `_settle` without its room-gone line → `ONLY(t4m6, test_room_gone)` exit 1; `finish_tick` without its `if not _ended()` guard → `ONLY(t4m7, sb4_no_send)` exit 1 (packet after the failing one sent, its predecessor missing); a `pump.live().tick()` read added to `notice` → `sh tools/run_python_tests.sh > <abs $L>/t4m8-py.log 2>&1` exit 1; the pairing check's `set_protocol_error` call removed (the mismatch only returns, as the old `note.tick != tick + 1` return did) → `ONLY(t4m9, sb4_foreign)` exit 1 (status `running`). Record.
- [ ] **Step 6: Review:** the coordinator dispatches the per-task Opus (high) reviewer (Model routing) on the task's diff; fixes test-first, Step 4 rerun.
- [ ] **Step 7:** Coordinator commits.

### Task 5: Docs

**Files:** `docs/guide/01-big-picture.md` (call chain `:50`, `:92`, `:105`, `:128`, `:131`, footer `:148`), `04-the-tick.md` (mermaid `:36`, `:118`, `:148`, `:165`, footer `:181`), `05-presentation.md` (recorder sentence `:161`, footer `:231`), `10-determinism-and-replays.md` (mermaid `:13` "finish_tick hashes the snapshot": the job digests it now, `:76`, `:80`, `:82`, `:84`, `:144-145`, footer `:168`), `11-multiplayer.md` (overview mermaid `:13`, walk-through `:39-50` and its mermaid `:54`, "Advancing" `:79-87`, "Ending" `:93`, the leave rule `:178`, `:184`, the slow-peer table `:196` ("nothing in `advance` times out": now `take`), `:235`, file list `:240`, footer `:262`), `12-performance-and-platforms.md` (`:158` "online still reads the live simulation until SB4", footer `:215`), `13-testing-and-tooling.md` (`:100`, footer `:255`); `docs/reference/sim-interface.md` (`:42`, `:62`); spec SB4 row status (`2026-11-15-sim-boundary-design.md:196`); `docs/STATUS.md` night-6 row (`:36`); `python3 tools/roadmap.py` only if the STATUS change touches the generated block.

- [ ] **Step 1:** Write in the guide's style (payoff first, terms where they appear), linking the spec instead of copying it: the online tick is a job like offline's; `take` and `record` around it, `advance` kept for the headless client and replays; `finish_tick` after the drain with the job's digest; quiet takes and why (the match may have ended in the undrained job; Zero Hour also decides a leave in logic-frame order, `Network.cpp:619-631` at `0a05454`); the end of the match handled in `drain`; tick 0 and the desync ring from query jobs; the static check now exempts only `sim_pump.gd`; online commands also pass the pump's recorder (Q8 A). Footers name the SB4 branch commit.
- [ ] **Step 2:** There is no link checker in `tools/` (`rg --files tools | rg -i link`: none), so links are checked by hand: `rg -o '\]\(([^)#]+)' <each changed doc> > <abs $L>/t5-links.log`, and each relative target resolved against the doc's folder and confirmed with the Glob tool (record the count checked and any miss). Then `sh tools/check_public.sh > <abs $L>/t5-public.log 2>&1; echo "exit=$?"` (`PUBLIC CHECK PASSED`) and `sh tools/run_checks.sh > <abs $L>/t5-checks.log 2>&1; echo "exit=$?"` (`CHECKS PASSED 5`); fresh Opus docs review of the code claims (it also re-checks the links) before the commit.
- [ ] **Step 3:** Coordinator commits.

### Task 6: Gate checks and measurements

Each step is its own short subagent (Model routing); briefs pass the resume record and this step's heading.

- [ ] **Step 1 (checks, Sonnet):** On the clean branch tip: `SUITE(gate)`; `EQUAL(gate)`; `sh tools/run_checks.sh`; `sh tools/run_team_match.sh`; `NET(gate, <s>)` for the 15 scenarios of the CI loop (`.github/workflows/ci.yml:156`: `match rematch left-mid perturb relay-down maps map-mismatch kill stall spike version proxy-clean proxy-burst proxy-reset proxy-blackhole`) plus `silent`, which ends lockstep matches another way (16 runs, about 5 minutes); `sh tools/run_conformance.sh` (`CONFORMANCE PASSED 69`); `git diff <base> --stat -- <untouched list>` empty; record each with the tree.
- [ ] **Step 2 (benchmark, Sonnet):** `uptime` (Global Constraints, Benchmarks), then `PERF_LABEL="Sim boundary SB4" sh tools/run_benchmark.sh > <abs $L>/gate-bench.log 2>&1; echo "exit=$?"` (its lockstep row is in this log, `run_benchmark.sh:25`; no separate lockstep run); compare with Task 1; exceeded budgets reported, never loosened. The labelled run writes tracked files (`docs/reference/perf-history.csv`, the generated status blocks): coordinator commits them, then reruns `git diff <base> --stat -- <untouched list>` (still empty). No Steam Deck row (answer 10: SB4 adds no field to the published view; `Note.ring` is filled only by the desync query).
- [ ] **Step 3 (reviews):** the coordinator dispatches the gate reviewers (Model routing: Opus whole-branch, Grok normal, `silent-failure-hunter`, `pr-test-analyzer`, the player-experience reviewer (Q15 B)), then `/ponytail-review` on Sonnet; one fix subagent applies the findings test-first; Step 1 reruns as its own subagent.
- [ ] **Step 4 (docs, Sonnet):** guide footers name the final tip when the fixes moved it; resume record and ledger rows final; `sh tools/check_public.sh` → `PUBLIC CHECK PASSED`; coordinator commits.
- [ ] **Step 5:** Stop. Merge, push and the rendered rerun (owed because `game/scripts/match/` changed, AGENTS.md "Verification and desktop use": `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, `python3 tools/perf_record.py <log> --label "Sim boundary SB4"`, `python3 tools/perf_chart.py`) are the owner's, in the morning window. Before the merge decision, the owner's manual online check (Q11 A; visible windows, never at night; about 15-20 minutes, not measured, played to a normal win, Q17 A redone), on the branch tip in `$W`, recorded in the verification file's "Owner checks":
  1. Local relay, in its own terminal: `cd <abs $W>/relay && PORT=18600 go run .` (the relay listens on `":" + PORT`, `relay/main.go:225`; `run_netplay.sh:39-41` builds and starts it the same way); `curl -sf http://127.0.0.1:18600/health` answers (`run_netplay.sh:45`).
  2. Two windows, each from its own terminal in `$W`: `sh tools/run_game.sh` (opens the launcher, `docs/development.md:96`). Window 1: Play, opponent Friend, open Advanced and set the relay URL to `ws://127.0.0.1:18600/ws` (the form `run_netplay.sh:11` uses; the field shows on `-dev` builds, `launcher.gd:150`, `PlaytestSettings.prerelease`; the version is `0.14.0-dev`, `game/project.godot:5`; left alone it is the hosted relay, `join_link.gd:3`), Dry Wells, the smallest map the launcher offers (81 x 108 cells; `MatchSettings.PLAY_MAPS`, `game/scripts/match_settings.gd:6`; Skirmish is the test map, `TEST_MAP`, not selectable), Create. Window 2: Join, the same relay URL under Advanced, the code, Join.
  3. Look at: one seat rushes the other's victory buildings so the match ends normally (Q17; not by closing a window, which tests opponent-left instead) (one seat loses its last building that counts for victory, `Simulation._survives`, `simulation.gd:178-181`), result panel on both; Play again in one window, Accept rematch in the other (`result_panel.gd:110`) starts a second match on both; in both matches no "Waiting for player N" line that stays on the HUD status line or behind the result panel (a short one during a window drag is normal); no desync: no "Desync" notice and no new `desync-seat<N>.json` in the `desync` folder of the user data directory (`docs/playing-online.md:42`). Then Back to menu in both and stop the relay.
  A failure here is a stop before the merge; the result (pass, or what was seen) goes into "Owner checks" with the tree.

## Risks

- **Waiting line one frame later (Q2 B):** inside a catch-up or multi-callback frame a quiet take does not set `waiting`; the next frame's loud take does. 33 ms at most inline; longer in SB5 while jobs stay in flight.
- **Three-callback frames defer a tick (J):** the sixth take of such a frame waits for the drain that sends its own packet; pacing only, every tick runs with the same commands.
- **Relay guards edits (F):** `finish_tick` and the `test_online_scene.gd` `cases()` line already carry Relay guards' code; SB4 edits beside it (RG2, RG4).
- **Recorder copy online (Q8 A):** the pump's recorder keeps every accepted online command, unused; memory only.
- **Note pairing by order (J, Q13 A):** `_finish_job` pairs drained notes with `_taken` in post order. No caller posts between two driver jobs today (`BaseScene.publish` runs after a full tick, `test_base_scene.gd:35-45`); if one did, the guard ends the match `ended_protocol` instead of recording and sending the wrong tick: a note is accepted only with `note.tick == tick + 1`, or skipped as taken past the end with `note.over and note.tick <= tick` (`test_sb4_foreign_note_ends_match`). Limit: a foreign job that steps the simulation passes the check (its note's tick is one ahead), but it advances the sim without the tick's commands, which the hash check reports as a desync at the next hash tick.

## Night-run preparation (Q9 A; done 2026-11-17)

At `/prepare-night-run` (attended; Relay guards is on `main`): commit this plan as `docs/superpowers/plans/2026-11-17-sim-boundary-sb4.md` after `sh tools/check_public.sh` passes on it; create the worktree, `git -C <abs ~/projects/wargrid> worktree add <abs $W> -b sim-boundary-sb4 main`, and write the start line so the run's session starts in `$W` (P2-1 of the first readiness review: subagent shells reset to the session's folder). Missing from `~/projects/wargrid-overnight-work/night-settings.json` (read 2026-11-16) for this plan: `mkdir -p` for `~/projects/wargrid-overnight-work/sb4*`; `WARGRID_REPLAY_TRACE=` and `NETPLAY_OUT=` for `~/projects/wargrid-overnight-work/sb4/`; `Edit` for the worktree folder `~/projects/wargrid-wt-sb4/**`; `cd ~/projects/wargrid-wt-sb4*` (the start line's `cd`, as Relay guards had). The rules themselves, with the absolute paths the permission check needs, are only in `~/projects/wargrid-overnight-work/sb4/plan/night-settings.proposed.json` (outside the repository, never copied in); the user installs it with `! cp ~/projects/wargrid-overnight-work/sb4/plan/night-settings.proposed.json ~/projects/wargrid-overnight-work/night-settings.json` (2026-11-17). Already allowed: `sh tools/run_tests.sh`, `WARGRID_TEST_ONLY=*`, `sh tools/run_netplay.sh`, `sh tools/run_conformance.sh`, `sh tools/run_team_match.sh`, `sh tools/run_checks.sh`, `sh tools/check_public.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_tests.sh`, `python3 tools/compare_replays.py`, `python3 tools/roadmap.py`, `cmp`, `godot` (also the Task 1 frame-order probe, `godot --headless --path … --script <abs $L>/…`; its script is written under `~/projects/wargrid-overnight-work/`, which the `Edit` rule there covers), `sh tools/run_benchmark.sh`, `PERF_LABEL=*`, `uptime`, `git diff` (also `--exit-code` for mutation proofs), `git log`, `git rev-parse`, `git add`, `git commit`, `rg`. Not needed: `cp`, `PERF_RECORD=`, `sleep`, `gh`, `fly`, `git push`, `run_game.sh`, `ssh`. Every `ask` rule is a deny at night; the plan uses none.

## Stop gates

1. Task 1 Step 1: the session is not in `$W` on `sim-boundary-sb4`, or Relay guards' Task 4 symbols are missing (Q1 A).
2. Task 1 Step 6: `FRAME ORDER FAILED` (Q12 A): physics callbacks of one iteration do not all run before its `_process`, so the take-ahead and three-callback cases and their fixtures rest on a wrong order.
3. Task 2 Step 2: a guard red on the base.
4. Any pinned value, trace, `s1.cmd`, IC1 or IC2 row or existing test moving; any untouched path in the diff.
5. Task 6 Step 2: a budget newly exceeded by a branch row (report, never loosen).
6. End of Task 6 (Step 5): owner review; the owner's manual online check (Q11 A: local relay, two windows, one match plus a rematch; never at night); merge decision; rendered rerun.

## Review record

- Fresh Opus (high) readiness review (2026-11-16 night, `review.md`, private): P1 0, P2 4, P3 11; all 15 applied, logged in `changes.md`: worktree made at preparation and checked in Task 1; mutation proofs by `git diff --exit-code`, no `PERF_RECORD=0`; a named docs link check; no `finish_tick` after an end inside the same drain (`test_sb4_no_send_after_end`); plus counts, docs lines, evidence scope, typed seats, symbol-based Relay guards check, Opus routing reason, load wait, perf-file commit, Q2 wording, pairing risk, log tags.
- Fable readiness review (2026-11-17, `review-fable.md`, private, against `main` `1be405a`): READY AFTER FIXES, P1 1, P2 2, P3 6 plus a drift list; all applied, logged in `changes.md` "Fable round": `<abs $W>`/`<abs $L>` instead of typed home paths and `check_public.sh` before the Task 1 commit; `test_sb4_no_send_after_end` pushes the oversized command before the physics calls; `test_sb4_desync_report_ring` reads the web download, no file; night-run review routing and Task 6 split; guide 12; one same-tick row; base filter counts; settled Relay guards conditionals dropped; line drift re-anchored on `1be405a`.
- Opus review of the questionnaire edits (2026-11-17, `review-questionnaire.md`, private, against `main` `0140d47`): READY AFTER FIXES, P1 1 (Skirmish not selectable: Q17 redone, Dry Wells), P2 1 (player-experience reviewer missing from Task 6 Step 3), P3 5; all applied (`changes.md`). `--path` with an absolute `--script` checked by hand on Godot 4.7.2 (exit 0).
- Questionnaire round (user, 2026-11-17, Q10-Q13 A; logged in `changes.md`): Opus implementers cited; the owner's manual online check before the merge (Task 6 Step 5, stop gate 6); frame order probe in Task 1 (Step 6, stop gate 2); pairing guard in `_finish_job` with `Lockstep.set_protocol_error` and `test_sb4_foreign_note_ends_match` (15 `sb4_` cases, online scene 62 + 9 = 71).

## Self-review notes

- Spec coverage for SB4: lockstep split (Task 3); `advance` kept and lockstep tests untouched (Tasks 3, 6); `finish_tick` with a given digest (Task 3); online driver on jobs with no live read (Task 4 and its static check); `Lockstep.start` without a live read (Task 4, Q3); desync ring by query job (Task 4, Q4); rematch re-creates the pump and the lockstep starts from it (Task 2 guard, Task 4); loopback test of two drivers (Task 2); `run_netplay.sh` match and rematch (Tasks 3, 4, 6; headless clients, so lockstep evidence only, the driver is covered by Task 2); vectors and conformance untouched (Task 6); agent call 2 (a tick taken past the end logs nothing, Task 2 guard) refined by Q2.
- Left to later packages on purpose: worker mode (SB5): `query` from `start`, `_report` and `record()` must wait for an idle pump, and quiet takes become the common case while jobs are in flight; bot seats in the online scene client (M9; `run_job` would collect `bot_commands` for `Lockstep.submit`); fog and minimap online (the row's "later packages get").
- Verified in Task 1 (Step 6, Q12 A): that Godot runs every physics callback of an iteration before its `_process` (spec "Not verified"; `test_sb4_three_callbacks_one_drain` stages that order by hand); a different order stops the run (stop gate 2).
- Not verified: that input events never arrive between physics and process (Godot's default with agile event flushing off; not re-read in Godot 4.7.2 source here); entity ids 3, 4 and 6 on the default test map as the existing N1 and `_end_match` use them (`test_online_scene.gd:96`, `:169-170`).
