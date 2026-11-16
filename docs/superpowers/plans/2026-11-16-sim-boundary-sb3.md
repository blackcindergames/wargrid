# Sim boundary SB3 "Pump inline, offline": Implementation Plan

**Status:** approved (user, 2026-11-16) after three readiness reviews (Review record). Attended run: coordinator plus one fresh subagent per task (user, 2026-11-16), not a night run. SB4 gets its own plan after SB3 merges.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md): one fresh subagent per task, each starting from the SB3 resume record in `docs/reference/sim-boundary-verification.md`.

**Goal:** A `SimPump` owns the simulation for both drivers and runs every tick as one job inline, so the match screen and presentation read only published slots and notes, with digests, traces and pins unchanged.

**Architecture:** New `game/scripts/match/sim_pump.gd` holds the `Simulation` and its `CommandRecorder`; `run_job` is the only function that touches them. The offline driver queues submits and posts one job per physics step (own commands, bots `[2]`, preview); the online driver keeps its lockstep loop on `pump.live()` until SB4 and posts a publish job (`step = false`) after each advanced tick. `_physics_process` calls `driver.step()`, which only posts; `_process` calls the screen's `_drain_notes()`, which takes `driver.drain()` and the drivers' answers and does what `_step_frame` does after a step today (sound, visuals, rejections, stepped results, refresh). Inline the job ran at post, so the same frame's `_process` shows it: today's latency (spec "One code path"). `driver.sim` is gone from `match/` and `presentation/`.

**Tech Stack:** Godot 4.7.2 typed GDScript, suite runner `game/tests/run_tests.gd`, Python check `tools/test_sim_boundary.py`, POSIX sh tools.

**Spec:** [sim boundary design](../specs/2026-11-15-sim-boundary-design.md) (package row SB3, "Ownership and API", "Slots and notes", "One code path", "Offline, online, restart", "Snapshot, digest, ring", "Guard against live reads", owner answers 2-5, 10, 11, 21-24; agent calls 1, 3, 4). Outline: [SB1-SB2 plan](2026-11-15-sim-boundary-sb1-sb2.md) "Later packages", SB3 row. Read with it: [simulation interface](../../reference/sim-interface.md), [determinism rules](../../reference/determinism-rules.md).

## Global Constraints

- **Base:** `main` once `wrapup-2026-11-16` is merged (docs only on top of `d820773`). Path:line below is `ad89a1c`; Task 1 refreshes them and records the map. Branch `sim-boundary-sb3` in the worktree `~/projects/wargrid-wt-sb3`.
- **Nothing pinned moves:** digests, replay traces, team-match pins, netplay traces, IC1 and IC2 rows, OD1 (`test_skirmish_scene.gd:1165-1167`) and S3 (`test_scene.gd:121`) stay byte-equal. Any of them moving is a stop; never re-pin.
- **Offline sequence (answer 21):** `run_job` stamps a command without `sequence` with `sim.last_sequence(player) + 1` at issue time; without `tick`, with `sim.tick()`. No sequence counter exists outside the simulation. Online keeps stamping at submit (`lockstep.gd:67-69`).
- **Bots in the job (answers 2-3):** offline jobs carry `bots = [2]` and run `Skirmish.issue_opponents(recorder, job.bots)` after own commands, before `step()`, as today (`offline_driver.gd:39-40`).
- **Ring (answer 5, agent call 3):** the per-tick hash ring is off in offline matches only (offline driver, at creation); on online, in headless replays and in direct-sim tests.
- **Fresh views (answer 11):** `run_job` assigns a fresh `view_state()` into the slot; no in-place reuse in SB3.
- **Inline only:** no `Thread`, no `Mutex`, no flag. `run_job` stays a static function of `(sim, recorder, job, slot)` so SB5 can call it from a thread.
- **Drain in `_process` from SB3** (user, 2026-11-16, against the recommendation to drain inside `driver.step()` until SB5): scene tests that drive only `_physics_process` (95 call sites at `ad89a1c`) switch to `BaseScene.tick(main)` = `_physics_process(1.0 / 30.0)` then `_drain_notes()`, never the whole `_process` (it pans, draws and auto-picks quality). No expected value changes.
- **Owner calls (user, 2026-11-16):** a temporary `sim` bridge in Tasks 4-5, tests migrated in Task 6; a restart drops queued orders silently; online gets the thin pump in SB3 (below); caches freeze in all builds; the Steam Deck row is taken at the SB3 gate (Deck free to use; its address lives in the private notes, never in tracked files).
- **Online shortcut until SB4:** `online_driver.gd` keeps `_lockstep.advance(pump.live())`, `finish_tick`, `desync_report` and `Lockstep.start` on `pump.live()`, each marked `shortcut: live read, SB4 moves it into jobs`. The static check allowlists `sim_pump.gd`, `online_driver.gd` and, until Task 6 removes the test bridge, `offline_driver.gd`.
- **Tests:** new cases named `test_sb3_*` (`WARGRID_TEST_ONLY=sb3_`); use only the [simulation interface](../../reference/sim-interface.md) plus the pump; an existing assertion changes only where a task names it; record each filtered run's case count.
- Typed GDScript; comments one line, WHY only; edits with the Edit tool or asserted replacements only.
- **Subagents never commit, push, merge, deploy or open a window.** The coordinator commits locally (milestone prompt). `world_view.gd` is not touched; `match/` changes, so a rendered rerun is owed at the gate (Task 8, ask for the window).
- Every suite, lint, warnings and benchmark call: `timeout: 600000`, output under `build/sb3/`, judged by exit code and marker (`TESTS PASSED <n>`, `CHECKS PASSED 5`); on failure `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`. Full suite at Tasks 3, 4, 5, 6 and 8. Per GDScript task `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` exit 0.

## Model routing

- Implementers: Opus (high) for Tasks 2, 4 and 5; Sonnet for Tasks 1, 3, 6, 7 and 8.
- Per-task review: one fresh-context reviewer per code task (Codex; Opus if unavailable), diff plus task text; findings checked against the source and fixed test-first before the commit.
- Gate: Grok 4.7 high plus an Opus whole-branch pass (Opus alone if Grok is missing). Then `/ponytail-review` on the branch diff.

## Review Focus

1. **Tests that read pending commands right after a submit** (IC1 `_ic_row` `test_skirmish_scene.gd:1008-1013`, OD1 `:1163-1167` and `:1207-1210`, S3 `test_scene.gd:120-121`, Bs2 `test_base_scene.gd:103-106`): after SB3 the commands sit unstamped in the driver queue, and a physics step would move row 21's `tick=` and clear placement. They call `driver.flush()` (Task 4, tests only) first, which issues the queue without stepping; rows stay byte-equal. If one still cannot, stop and ask (answer 17 allows no further re-pin). IC2 reads lockstep sends (`test_online_scene.gd:1380-1384`) and is not on this path.
2. **A finished offline match keeps posting:** notes stop advancing the tick, so the screen must not refresh every frame. Test `test_sb3_over_stops_refreshing` (Task 4).
3. **Refused command between two accepted ones in one job:** answers in submit order with sequences `0, 1 (refused), 1`, and the bot's commands after them. Test OD1 unchanged plus `test_sb3_sequence_stamp` (Task 2).
4. **Restart with a posted but undrained job:** nothing from the old pump shows after `create`/`adopt`. Test `test_sb3_restart_drops_old_notes` (b) (Task 4).
5. **A late lazy cache insert after the freeze** (HUD or bot looks up a kind not warmed): loud error, not a silent miss; warm covers every registered kind. Test `test_sb3_freeze_covers_match` (Task 3).
6. **Online two-tick catch-up frame:** two notes, sound and visuals collect both ticks in order, CURRENT is the second tick. `stepped_results` holds both ticks' results (N27, `test_online_scene.gd:546-561`). Test `test_sb3_online_two_notes` (Task 4).

## Files

| File | Change |
|---|---|
| `game/scripts/match/sim_pump.gd` | new: `Job`, `Note`, `Slot`, `run_job`, pump |
| `game/scripts/simulation/simulation.gd` | `last_sequence(player)`, `set_hash_ring(enabled)` |
| `game/scripts/simulation/definitions/definitions.gd`, `combat.gd`, `skirmish.gd` | `reach_cache` moved into Registry, `freeze_caches()`, `cache_sizes()`, `freeze_map()` |
| `game/scripts/simulation/simulation.gd` (Task 8) | two Profiler zones in `view_state` (`view.rows`, `view.buildings`), kept after SB3 |
| `game/scripts/match/offline_driver.gd`, `online_driver.gd` | on the pump; screen-facing API below |
| `game/scripts/match/match_screen.gd`, `hud.gd` | read notes and slots, no `driver.sim` |
| `tools/test_sim_boundary.py` | live-read check |
| `game/tests/test_sim_pump.gd` (new), scene tests | pump cases; `driver.sim` → `driver.pump.live()` / `adopt` |
| docs | guide `01-big-picture`, `04-the-tick`, `05-presentation`, `13-testing-and-tooling`; `docs/reference/sim-interface.md`; spec row SB3 status |

---

### Task 1: Base, verification file and base evidence

**Files:** Modify: `docs/reference/sim-boundary-verification.md` (new `## SB3` section with its own resume record, ledger and line map)

- [ ] **Step 1:** Create the worktree and branch from the base; record `<base>` as the ledger's first line.
- [ ] **Step 2:** Refresh every path:line in this plan on `<base>`; write the map into the line map. A cited line that no longer exists is a stop.
- [ ] **Step 3:** Base evidence into the ledger: `mkdir -p build/sb3/base`, then the full suite with traces, `WARGRID_REPLAY_TRACE=<wt>/build/sb3/base/replay.tsv WARGRID_ECONOMY_REPLAY_TRACE=<wt>/build/sb3/base/economy.tsv WARGRID_COMBAT_REPLAY_TRACE=<wt>/build/sb3/base/combat.tsv WARGRID_TEAM_REPLAY_TRACE=<wt>/build/sb3/base/team.tsv sh tools/run_tests.sh` (`TESTS PASSED <n>`); `NETPLAY_OUT=<wt>/build/sb3/base/netplay sh tools/run_netplay.sh match` (`NETPLAY PASSED match`); `sh tools/run_team_match.sh` (exit 0); `sh tools/run_checks.sh` (`CHECKS PASSED 5`); `PERF_RECORD=0 sh tools/run_benchmark.sh` timings as the comparison base. "Traces equal" below means: the same commands into `build/sb3/<task>/`, then `python3 tools/compare_replays.py` base against branch for replay, economy and combat, `--interval 200 --rows 100` for team, `--interval 30 --rows 0` for `netplay/s1.tsv` → `REPLAYS MATCHED` each (SB1-SB2 plan, Task 1 and Task 8 pattern).
- [ ] **Step 4:** Count, for the ledger: `rg -c 'driver\.sim' game/tests` per file, `rg -c 'driver\.sim\s*=' game/tests`, `rg -c 'driver\.recorder' game/tests`, `rg -n 'sync_sequence|driver\._sequence|driver\._held' game/tests`, `rg -n 'pending_commands' game/tests`, `rg -c '\._physics_process\(|\._step_frame\(' game/tests` (95 calls at `ad89a1c`; 113 with the `set_physics_process(` lines), and the tests that change the live sim and then call `_refresh()` or send input (Task 5; `rg -c '\._refresh\(\)' game/tests` is 71 at `ad89a1c`). Tasks 4-6 compare against these.
- [ ] **Step 5:** Coordinator commits the verification file.

### Task 2: The pump

**Files:** Create: `game/scripts/match/sim_pump.gd`, `game/tests/test_sim_pump.gd`. Modify: `game/scripts/simulation/simulation.gd` (one accessor), the `SUITES` list in `game/tests/run_tests.gd:6` (in Step 1, so Step 2 really fails). Every new `test_sb3_*` case in any suite is also appended to that suite's `cases()` list (`test_skirmish_scene.gd:27`, `test_online_scene.gd:41`): the runner only filters listed cases (`run_tests.gd:87`).

**Interfaces:**
- Produces in `simulation.gd`: `func last_sequence(player: int) -> int` (`_last_sequences.get(player, -1)`).
- Produces `sim_pump.gd` (`extends RefCounted`), the spec's API with these SB3 decisions:
  - `class Job`: `commands: Array[Dictionary]`, `bots: Array[int]`, `step: bool = true`, `want_digest: bool`, `preview: Dictionary`. (`want_ring` waits for SB4.)
  - `class Note`: spec fields minus `ring`; `done` is always `true` inline (fault detection is SB5); `starts` filled only by job 0, `seat -> MapData.start_cell(sim.map_data(), seat)` for each player in `view.players`, and left empty when `sim.map_data()` is empty (fixture worlds, `economy_fixture.gd:18`; today's guard `match_screen.gd:132`); new `stats: Array[Dictionary]` = `sim.match_stats()` in every note (one row per player, at most six), since the result table also shows when the opponent left a running match (`hud.gd:67,79-81`, N29 `test_online_scene.gd:1042-1053`).
  - `class Slot`: `tick: int`, `view: Dictionary`.
  - `func _init(sim: Simulation) -> void` (no `threaded` parameter until SB5), `func start() -> Note` (runs job 0 = `Job` with `step = false` on the caller, rotates, returns its note; Task 3 adds the cache warm and freeze before it), `func post(job: Job) -> bool` (runs `run_job` at once into WRITE, appends the note, swaps WRITE and READY; `false` only after `stop()`), `func drain() -> Array[Note]` (takes notes; when READY is newer: PREVIOUS returns to the pool, CURRENT becomes PREVIOUS, READY becomes CURRENT, spec "Slots and notes"), `func current() -> Slot`, `func previous() -> Slot` (null until two ticks were taken), `func query(job: Job) -> Note` (runs `run_job` with no slot: no rotation, no queue; match record and `flush`), `func busy() -> bool` (always false inline), `func stop() -> void`, `func live() -> Simulation`, `func recorder() -> CommandRecorder`.
  - `static func run_job(sim: Simulation, recorder: CommandRecorder, job: Job, slot: Slot) -> Note`: in order: for each command stamp a missing `tick` (`sim.tick()`) and missing `sequence` (`sim.last_sequence(command.player) + 1`), issue through `recorder`, append `{command, ok, error}` to `issued`; record the recorder's command count, run `Skirmish.issue_opponents(recorder, job.bots)`, copy the new recorder entries into `bot_commands`; `sim.step()` if `job.step` and not over; copy `combat_events()` and `command_results()` (`duplicate(true)`); preview answer `{kind, origin, ok, error, tick}` from `sim.preview_build(...)` when `job.preview` is set (same shape as `offline_driver.gd:63`); snapshot plus `StateHash.digest` when `want_digest`; `slot.tick`/`slot.view = sim.view_state()` when `slot != null`; `over`, `tick` (`sim.tick()` after the optional step), `stats`. Events and results are copied in every job: online's publish job (`step = false`) carries the tick its `advance` just stepped.

- [ ] **Step 1: Write the failing tests** in `test_sim_pump.gd` (scene-free; build sims with `Skirmish.create(true, "ai", factions, MAP_PATH, starts)` as `offline_driver.gd:24`):
  - `test_sb3_pump_digests_equal_direct`: a direct sim running `Skirmish.issue_opponent(rec); sim.step()` and a pump posting `Job{bots=[2]}` for 900 ticks; `StateHash.digest(snapshot)` equal every 30 ticks and at 900.
  - `test_sb3_two_notes_one_drain`: after `start()` (CURRENT tick 0), two posts, one drain → 2 notes in tick order (1, 2); `current().tick == 2`; `previous().tick == 0` (CURRENT before the drain became PREVIOUS).
  - `test_sb3_slot_invariant`: over 60 single post/drain pairs, after each drain `current().tick` equals the last note's tick and `current() != previous()` as objects; at most four distinct `Slot` objects seen.
  - `test_sb3_sequence_stamp`: one job with a valid move, a refused move (unknown entity id), a valid stop for player 1 → `issued` sequences `[0, 1, 1]`, oks `[true, false, true]`; `sim.last_sequence(1) == 1`; commands given an explicit `sequence` keep it.
  - `test_sb3_refusal_one_tick_later`: the refusal is in the note of the job that issued it, not before (pump never issues at post time without a job).
  - `test_sb3_preview_answer`: a job with `preview` → `note.preview` has `{kind, origin, ok, error, tick}`; no preview → `{}`.
  - `test_sb3_query_leaves_slots`: `query(Job{step=false, want_digest=true})` returns a digest equal to `StateHash.digest(live().snapshot())` and leaves `current()` and the note queue as they were.
  - `test_sb3_job0_starts`: `start()` returns a note with `starts[1]` and `starts[2]` equal to `MapData.start_cell` and `current().tick == 0`; a pump around a fixture world (empty map) starts with `starts == {}` and no script error.
- [ ] **Step 2:** `WARGRID_TEST_ONLY=sb3_ sh tools/run_tests.sh > build/sb3/t2.log 2>&1; echo exit=$?` → FAIL (no `sim_pump.gd`).
- [ ] **Step 3:** Implement `sim_pump.gd` and `last_sequence` as in Interfaces.
- [ ] **Step 4:** Same command → exit 0, 8 cases on the `CASES` line. Lint and warnings exit 0.
- [ ] **Step 5:** Coordinator commits.

### Task 3: Frozen caches and the offline ring switch

**Files:** Modify: `game/scripts/simulation/definitions/definitions.gd`, `game/scripts/simulation/combat.gd:80-84`, `game/scripts/simulation/skirmish.gd:21,40-41`, `game/scripts/simulation/simulation.gd:664-665`, `sim_pump.gd` (`start`). Test: `game/tests/test_sim_pump.gd`.

**Interfaces:**
- `Combat._reach_by_kind` moves into Registry as `static var reach_cache: Dictionary` next to `radius_cache` (`definitions.gd:19`); `combat.gd:82-84` reads and fills `Registry.reach_cache`; `_reset()` (`definitions.gd:117-122`) assigns it fresh with the others. No `Combat` call from `definitions.gd` (it would close a preload cycle with the static initializer at `definitions.gd:20`).
- Produces `static func freeze_caches() -> void` in `definitions.gd`: `make_read_only()` on `_unit_cache`, `_building_cache`, `_profile_cache`, `radius_cache`, `reach_cache`. Idempotent. `_extra`, presentation and profiler dictionaries are not frozen.
- Produces `static func cache_sizes() -> Dictionary` in `definitions.gd` (`{name: size}` for the five) so tests stay on public names (`tools/test_sim_boundary.py:52-82`).
- Produces `static func freeze_map() -> void` in `skirmish.gd`: loads `_skirmish_map` if empty, then `make_read_only()` (`MapData.with_starts` duplicates it, `map_data.gd:38`).
- `SimPump.start()` warms before job 0: for every id in `Registry.units()` and `Registry.buildings()` call `unit_view`, `building_view`, `profile_view`, `CombatDefinitions.radius`, and `Combat.reach_of(id)` (the public form of `combat.gd:82`) only for kinds with a known, non-empty weapon; then `Registry.freeze_caches()` and `Skirmish.freeze_map()`.
- Produces `func set_hash_ring(enabled: bool) -> void` in `simulation.gd`; when off, `step()` skips the write at `:665` but still closes the Profiler zone opened at `:664`; ring reads return an empty range. Default on.

- [ ] **Step 1: Write the failing tests:**
  - `test_sb3_freeze_rejects_late_insert`: after a pump `start()`, `Registry.radius_cache.is_read_only()` and the other four are read-only; `add_test_kind("sb3_probe", row)` then `CombatDefinitions.radius("sb3_probe")` works (fresh cache) and `clear_test_kinds()` leaves unfrozen caches.
  - `test_sb3_freeze_covers_match`: pump `start()`, then a 900-tick bot match on the skirmish map and 300 ticks of the team-load match (`scripts/debug/team_match.gd:13`) through the pump → `Registry.cache_sizes()` equal to the sizes right after `start()` (the runner counts only `check` failures, `run_tests.gd:110-113`, so a read-only write error is invisible to it).
  - `test_sb3_ring_off_same_digest`: two sims, one `set_hash_ring(false)`, 300 bot ticks → equal digests every 30 ticks.
- [ ] **Step 2:** Run `sb3_` → the three new cases FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `sb3_` exit 0 (11 cases); full suite exit 0 with base cases + 11; `python3 tools/test_sim_boundary.py` exit 0; traces equal (Task 1 Step 3).
- [ ] **Step 5:** Coordinator commits.

### Task 4: Both drivers on the pump, drain in `_process`

**Files:** Modify: `game/scripts/match/offline_driver.gd`, `game/tests/test_graphics_settings.gd` (Q12 call form only, if needed), `game/scripts/match/online_driver.gd:57-68,85-104,118-133`, `game/scripts/match/match_screen.gd:151-158,194-221,318-321`, `game/tests/test_base_scene.gd` (helpers, `sync_sequence`, `_held` reads `:283,290,300,521`), `game/tests/test_skirmish_scene.gd` (`:155,164`, OD1 `:1163-1167,1207-1210`, OD2 `:1189`, `_ic_row` `:1008-1013`), `game/tests/test_scene.gd:120-121`, `game/tests/test_playtest_overlay.gd:730`, and the scene tests that drive only `_physics_process`. Test: `game/tests/test_skirmish_scene.gd`, `test_online_scene.gd`.

**Interfaces (both drivers, screen-facing):**
- `var pump: SimPump`; `var sim: Simulation` becomes a property with `get: return pump.live()` and `set(value): adopt(value)`, and `var recorder` likewise returns `pump.recorder()`. Bridge for tests until Task 6; marked `shortcut: test bridge, Task 6 removes it`.
- `func adopt(sim: Simulation) -> void`: `stop()` the old pump, new pump around `sim`, `start()`, keep the job-0 note as `first_note`; clear the queue, preview request and answer, the answer buffer and the accepted log; offline also `sim.set_hash_ring(false)`. Both `create`s build through `adopt`; online's `create` still resets `_credit`, `_log_seen` and `_rejections_seen` as today (`online_driver.gd:57-68`).
- `func step() -> void`. Offline: posts `Job{commands = queued, bots = [2], preview = pending request}` and clears the queue and the request; posts nothing when the match is over and the queue and request are empty (a finished match would otherwise re-copy its last results into `stepped_results` every frame, `simulation.gd:589-591`; K4's `Rejected: Match ended`, `test_skirmish_scene.gd:148-152`, still posts). Online: today's loop (`online_driver.gd:85-104`) with `_lockstep.advance(pump.live())` (it steps, `lockstep.gd:111-119`), then `pump.post(Job{step = false, preview = request})` per advance, `finish_tick(tick, pump.live().snapshot() if wants_snapshot else null)` once per advance as today; after the loop the request is cleared if any advance ran, and `_new_answers()` once, buffered for `take_answers()`. `shortcut: live read, SB4 moves it into jobs` on each `pump.live()` use.
- `func drain() -> Array[SimPump.Note]`: `pump.drain()`; keeps the last non-empty `note.preview` as the preview answer (online: so the last advance's answer wins, RP8), offline also each note's `issued` for `take_answers()` and its accepted commands plus `bot_commands` in the log.
- `func take_answers() -> Array[Dictionary]`: own answers since the last call. `step_results()` goes: the screen reads `note.results`.
- `func submit(payload: Dictionary) -> Dictionary` (offline): duplicates, stamps `player`, appends to the queue, returns `{ok: true, error: ""}`. No `tick`, no `sequence`, no `_sequence` field. Online `submit` unchanged.
- `func queued() -> Array[Dictionary]` (offline, tests): the commands waiting for the next job; replaces the tests' `driver._held` reads where they count or inspect waiting orders.
- `func flush() -> void` (offline, tests only): when the queue is not empty, `pump.query(Job{commands = queued, step = false})`, clear the queue, keep the note's accepted commands in the log and hold its `issued` until the next posted job's notes are drained (today's `_held` rule, `offline_driver.gd:37-45`), so a paused or idle drain does not hand them out early. Same tick and order as the next job would issue them (own commands before bots). Not called from production code.
- `func current() -> SimPump.Slot`, `var first_note: SimPump.Note`, `func record() -> Dictionary` (`pump.query(Job{step = false, want_digest = true})` → `{tick, digest, match}`; queued orders stay out of both digest and log, so the record replays to its digest), `func match_stats() -> Array[Dictionary]` (the last drained note's `stats`, seeded from `first_note`, so a driver that never drained, like R5's stub `test_skirmish_scene.gd:707`, still has rows). Offline `over()` returns the last drained note's `over` (CURRENT's `view.match` status before the first step), not `live()`.
- `match_log()`: offline from the accepted log through `Lockstep.log_lines` (equal to `recorder().commands()` by construction; tested). Online unchanged.
- Screen: `_physics_process` → `_step_frame()` calls `driver.step()` and checks `take_rematch()` as today (pause still returns first, `match_screen.gd:200`); `_process` calls `_drain_notes() -> bool` (true when it refreshed) first and adds its elapsed time to `_auto_tick_usec` only when true, as `_present_if_due` does (`match_screen.gd:221`; keeps RF4 `test_skirmish_scene.gd:956-970` and Q12's exact `[5.0]`, `test_graphics_settings.gd:145-151`); `_present_if_due` then runs after it in `_process`, not inside it. `_drain_notes()`: `tick_before = driver.current().tick`; for each note `_collect_note(note)` (`_sound.collect_step(note.tick, note.events, note.results)`, visuals likewise) and append `note.results` to `stepped_results`; handle `take_answers()` exactly as `_step_simulation` does today (`match_screen.gd:152-158`); then today's refresh decision (`match_screen.gd:210-212`) with `advanced = driver.current().tick != tick_before` (a finished match keeps posting non-advancing notes and must not refresh every frame); `_present_if_due` after it. `_perf.record_step` still times `_step_frame` (the inline job runs inside `post`). Until Task 5, `_refresh` still reads `driver.sim.view_state()` through the bridge.
- Test helpers in `test_base_scene.gd`: `static func tick(main) -> void` = `main._physics_process(1.0 / 30.0)` then `main._drain_notes()` (never `_present_if_due`). Scene tests run with `set_process(false)` (`test_skirmish_scene.gd:33-34`), so `not is_processing()` refreshes on every drain, including paused `tick` calls (today `match_screen.gd:200` skips it); no pinned value depends on that.
- Unchanged on both drivers: `request_preview` and `preview_answer`; `adopt` tolerates a null old pump (`test_skirmish_scene.gd:715-717`); online `step()` keeps its live `match_over()` read for `_finish` (`online_driver.gd:102`); the online answer buffer appends across steps until taken. `_exit_tree` calling `stop()` waits for SB5 (inline `stop()` has nothing to join).

- [ ] **Step 1: Write the failing tests** (in `test_skirmish_scene.gd` and `test_online_scene.gd`, registered in `cases()`):
  - `test_sb3_submit_queues`: after one offline submit, `driver.queued().size() == 1` and `driver.pump.live().snapshot().pending_commands.is_empty()`; after `BaseScene.tick(main)`, the queue is empty and `driver.pump.live().last_sequence(1) == 0`.
  - `test_sb3_match_log_equals_recorder`: 300 ticks with a refused and two accepted own orders plus the bot → `match_log().commands == Lockstep.log_lines(driver.pump.recorder().commands())`.
  - `test_sb3_restart_drops_old_notes`: (a) submit a refusable order, restart before a physics frame; (b) submit it, `_physics_process` (posted, not drained), `_restart()`, then `BaseScene.tick(main)` → in both no `Rejected:` note, no beep, queue empty, `current().tick == 1` of the new match.
  - `test_sb3_paused_posts_nothing`: with the pause menu open over 10 frames (`BaseScene.tick`), `current().tick` unchanged and no note drained.
  - `test_sb3_over_stops_refreshing`: with `main.set_process(true)`, an offline match forced over, 10 `BaseScene.tick` frames → `Profiler.calls(&"refresh.hud")` (`match_screen.gd:293`) 0 after the first, and `stepped_results` not growing.
  - `test_sb3_online_two_notes`: loopback online scene with credit for two ticks in one frame → one `_drain_notes()` collects two notes in tick order, `current().tick` is the second, the sound director collected both ticks, and `stepped_results` holds both ticks' results in order (N27, `test_online_scene.gd:546-561`).
- [ ] **Step 2:** Run `sb3_` → new cases FAIL.
- [ ] **Step 3:** Implement the drivers and the screen changes in Interfaces.
- [ ] **Step 4: Test call sites, no expected value changes.**
  - Replace every scene-test `main._physics_process(...)` / `_step_frame()` call that expects the step's effects with `BaseScene.tick(main)` (asserted count against Task 1's); a test that checks the pre-drain moment keeps the bare physics call.
  - Delete `sync_sequence` and its 7 call sites (no counter left to sync), the `driver._sequence` line at `test_skirmish_scene.gd:155` and K4's `main.driver._sequence == 0` clause (`:164`).
  - `driver._held` reads become `driver.queued()`; OD1 and OD2 call `driver.flush()` or `driver.step(); driver.drain()` and read `driver.take_answers()` instead of `step()`'s return (call form only).
  - Tests that read `pending_commands` straight after a submit: `driver.queued()` when they check type or payload; `driver.flush()` first when they check `tick` or `sequence` (`_ic_row`, OD1 both cases, S3, Bs2); never an extra physics step.
  - "Nothing was sent" checks (`snapshot() == before`, `pending_commands == before`, unchanged `playtest_match().commands.size()`; e.g. PO4 `test_playtest_overlay.gd:181`, S7 `test_scene.gd:265`, `test_skirmish_scene.gd:150,729`, `test_base_scene.gd:90`) also assert `driver.queued().is_empty()`, or they pass vacuously. The `_pending` helper (`test_skirmish_scene.gd:38-39`) counts live pending plus `queued()`, so mixed sites (IC1 `:1074`, Bs4 `test_base_scene.gd:192`) need no per-site call.
  - IC1 and IC2 byte-equal; if a row moves, stop and ask with that row's diff.
- [ ] **Step 5:** `sb3_` exit 0; full suite green (base cases + 17) except exactly RF6 (`test_base_scene.gd:393`, gets 20 for 10) and RB7 (`test_skirmish_scene.gd:1181`, 600 for 300): until Task 5 each tick builds its view twice, in the job and in the bridged `_refresh`. Their values stay untouched; they go green in Task 5, and any other red is a stop. OD1, OD2, S3, Bs2, IC1, IC2, K4, RA7, RF4, Q12 and every online scene test green; traces equal (Task 1 Step 3).
- [ ] **Step 6:** Coordinator commits.

### Task 5: The screen reads slots, not `driver.sim`

**Files:** Modify: `game/scripts/match/match_screen.gd:126-134,147-149,202-215,264-266`, `game/scripts/match/hud.gd:79`, `game/scripts/match/online_driver.gd:205`, `tools/test_sim_boundary.py`, the scene tests that change the live sim and then refresh or click (Task 1 count), `test_base_scene.gd:378` (RF1), `test_skirmish_scene.gd:938` (RF2). Test: `tools/test_sim_boundary.py` (its unittest), the scene suites.

**Interfaces:**
- Screen: `_refresh` shows `driver.current().view`; `_reset_camera` reads the size from `driver.current().view.map.size` and the start from `driver.first_note.starts.get(local_player, Vector2i(-1, -1))` (centre when missing, as `match_screen.gd:133`); `_match_record` takes `driver.record()`; `_present_if_due` and `_step_frame` read ticks from `driver.current().tick`; `hud._result_rows` reads `_screen.driver.match_stats()`; online `match_log` reads factions from `current().view.players`.
- Test helper `static func publish(main) -> void` in `test_base_scene.gd`: `main.driver.pump.post(SimPump.Job` with `step = false)`, `main.driver.drain()` with the result dropped (no sound, no `stepped_results`; the driver's `over` and stats stay right), then `main._refresh()`. Every test that changes the live sim directly (`Fixture.*`, `spawn`, `remove_object`, `driver.sim.*` writes) and then calls `_refresh()` or sends input calls `BaseScene.publish(main)` instead of the bare `_refresh()` (about 58 of the 71 `\._refresh\(\)` sites, e.g. Bs3 `test_base_scene.gd:160-161`, Bs4 `:180-184`, Bs5 `:203-207`, H6 `:341-351`).
- Pinned counts that change, by name: RF1 (`test_base_scene.gd:378`) and RF2 (`test_skirmish_scene.gd:938`) count view states per refresh; after this task a refresh builds 0 (the job built it). Their expected value becomes 0, and the job's build is counted in a new assertion `test_sb3_one_view_per_tick` (one `view_state` per posted job). RF2 (`test_skirmish_scene.gd:929-938`) builds a barracks on the live sim: it calls `BaseScene.publish(main)` before `Profiler.reset()` and keeps the bare `_refresh()` inside the window; RF1 needs no publish. No other expected value changes. RF6 and RB7 are green again.
- `tools/test_sim_boundary.py`: new check that no `.gd` under `game/scripts/match/` or `game/scripts/presentation/` matches `\.sim\b` or `\blive\(\)` after stripping `#` comments; allowlist `sim_pump.gd`, `online_driver.gd` (comment: until SB4) and `offline_driver.gd` (comment: test bridge, Task 6 removes it). Its unittest gets a positive and a negative fixture.

- [ ] **Step 1: Write the failing tests:** `test_sb3_one_view_per_tick` (10 offline `BaseScene.tick` frames → Profiler `view_state` calls 10, and 0 inside `_refresh`); `tools/test_sim_boundary.py`: `test_live_read_flagged` (a fixture line `driver.sim.tick()` under `match/` is a hit) and `test_live_read_allowlist` (the same text in `sim_pump.gd`, or behind `#`, is not).
- [ ] **Step 2:** Run `sb3_` and `python3 tools/test_sim_boundary.py` → new cases FAIL.
- [ ] **Step 3:** Implement the screen changes, the helper and the call-site swaps; RF1 and RF2 as named.
- [ ] **Step 4:** `python3 tools/test_sim_boundary.py` exit 0 on the real tree; `sb3_` exit 0; full suite exit 0; traces equal (Task 1 Step 3, netplay included; the netplay scenarios run the headless client, so `test_online_scene` is Task 5's online evidence).
- [ ] **Step 5:** Coordinator commits.

### Task 6: Tests off the bridge

**Files:** Modify: every `game/tests/*.gd` that names `driver.sim` or `driver.recorder` (Task 1 counts), `offline_driver.gd`, `online_driver.gd` (delete the bridge properties), `tools/test_sim_boundary.py` (allowlist).

- [ ] **Step 1:** Replace each read `main.driver.sim` / `driver.sim` with `.pump.live()`, each assignment `driver.sim = X` with `driver.adopt(X)`, and `driver.recorder` with `driver.pump.recorder()` (word-boundary replacement, asserted counts equal to Task 1's plus Task 4-5 additions); delete the `sim` and `recorder` bridge properties and their `shortcut:` lines from both drivers; drop `offline_driver.gd` from the static check's allowlist.
- [ ] **Step 2:** `rg -n 'driver\.(sim|recorder)\b' game` → no hits. Full suite exit 0 with the Task 5 count; `sh tools/run_checks.sh` → `CHECKS PASSED 5`.
- [ ] **Step 3:** Coordinator commits.

### Task 7: Docs

**Files:** `docs/guide/01-big-picture.md`, `04-the-tick.md`, `05-presentation.md`, `13-testing-and-tooling.md` (each `Checked against` footer), `docs/reference/sim-interface.md` (pump, slots, notes, `last_sequence`, `set_hash_ring`, `driver.pump.live()` in tests), spec row SB3 marked done with the merge commit later, `docs/STATUS.md` night-6 row.

- [ ] **Step 1:** Write the changes in the guide's style (payoff first, terms where they appear); link, don't copy, the spec.
- [ ] **Step 2:** Links and paths resolve (`sh tools/run_checks.sh` public and link parts); fresh Opus docs review (code claims) before the commit.
- [ ] **Step 3:** Coordinator commits.

### Task 8: Gate checks and measurements

- [ ] **Step 1:** Full suite with traces equal (Task 1 Step 3), `sh tools/run_checks.sh`, `sh tools/run_team_match.sh`, netplay `match` and `rematch`, `sh tools/run_conformance.sh` (`CONFORMANCE PASSED`); all on the branch tip, recorded with the tree.
- [ ] **Step 2:** Add the two Profiler zones (`view.rows`, `view.buildings`) in `view_state`; full suite and traces equal again. Then `PERF_LABEL="Sim boundary SB3" sh tools/run_benchmark.sh` (load ≤ 2.5, else wait); compare with Task 1; exceeded budgets are reported, never loosened.
- [ ] **Step 3 (ask first, one batch):** the rendered rerun (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, record with `python3 tools/perf_record.py <log> --label "Sim boundary SB3"`) and the Steam Deck native team row: view build ms (answer 10, report-only), split into unit rows and building copies with two Profiler zones in `view_state` (`view.rows`, `view.buildings`), plus fresh `view_state()` against filling a kept slot dictionary (answer 11, scratch script outside the repo). Record numbers in the verification file. The two zones stay in `view_state` (user, 2026-11-16) so answer 10's row reruns on later packages; the fill comparison stays a scratch script (user, 2026-11-16).
- [ ] **Step 4:** Gate review (Model routing), then `/ponytail-review`; fixes test-first; reruns of Step 1.
- [ ] **Step 5:** Stop. Merge, push and the release are the owner's.

## Stop gates

1. After Task 2 (pump API): coordinator posts the task table; continue unless a pinned value moved.
2. Task 4 Step 4 if IC1/IC2 cannot stay byte-equal.
3. Task 8 Step 3: the window and Deck batch waits for the owner.
4. End of Task 8: owner reviews, decides merge.

## Review record

- Grok 4.7 high readiness review (2026-11-16, private, `~/projects/wargrid-overnight-work/sim-boundary/reviews/sb3-plan-grok.md`): NOT READY with 4 P1, 4 P2, 3 P3; all merged here: `flush()` for pending-read tests and `record()`, both catch-up ticks' results, the bridge in the static allowlist, the SB1 trace pattern and `CONFORMANCE PASSED`, resets on `create`, case registration, the key-set freeze assert, the ring's Profiler zone. Its drain remarks predate answer 22.
- Opus high fresh-context readiness review (2026-11-16, second pass): NOT READY with 3 P1, 10 P2, 11 P3; all merged: online gets the screen API in Task 4 (was Task 5); `BaseScene.publish` for the ~58 tests that change the live sim then refresh; RF1/RF2 re-pinned by name; `flush()` out of production `record()` (RA7; record replays to its digest); `_held` and OD2 mapped; `driver.recorder` in Task 6; offline `over()` off `live()`; job 0 guard on empty maps; `advanced` from the tick; preview on every publish, last wins; `previous()` per spec; the undrained-restart case; `cache_sizes()` for the boundary check; `reach_cache` in Registry (no preload cycle); drain timed for RF4; nits (7 `sync_sequence` calls, `CASES` line, `:63`, team fixture, `want_ring` cut, duplicate RP8 case dropped, netplay is headless-client evidence only, zones under Files).
- Fable 5.2 fresh-context review of Tasks 4-5 (2026-11-16, third pass): NOT READY with 2 P1, 5 P2, 7 P3; all merged: RF6 and RB7 named as the only reds at Task 4's gate (double view build until Task 5); stats in every note for the opponent-left table (N29); drain timed only when it refreshed (Q12); the over-match test probes `refresh.hud`; an over offline match posts nothing idle; "nothing was sent" checks also assert an empty queue, `_pending` counts the queue; RF2's publish placement; corrected counts (95, 71); `flush()` answers held to the next job; publish uses `driver.drain()`; unchanged driver behaviours listed; `test_sb3_submit_queues` reads `last_sequence`. Ledger note for Task 8: an online catch-up frame builds two views and two previews where today it builds one (answer 23).

## Self-review notes

- Spec coverage for SB3: pump and slots (Task 2), notes and bots in the job (Task 2, 4), cache freeze (Task 3), static check (Task 5), camera from job 0 (Task 5), match record as query (Tasks 2, 5), ring off offline (Task 3), tests on `pump.live()` (Task 6), 900-tick digest equality (Task 2), skirmish and team traces equal (Tasks 3-6 suite), slot invariants (Task 2), ledger row and view-build split (Task 8).
- Left to later packages on purpose: `Thread`, `MAX_QUEUED`, stall and fault (`Note.done = false`), the bounded `busy()` wait in the tick helper (SB5); lockstep split, ring and desync by query job, `Lockstep.start` without a live read (SB4); bot read function (after SB3, answer 4).
