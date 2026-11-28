# Sim boundary: design (night lane, after P2.2)

Status: approved in substance by the owner (2026-11-15); drafted by Fable 5.2 from the inputs it cites, revised the same day after a builder check against `main` 32748c8 and two plan reviews (owner answers and agent calls in the last two sections). Labels: **F** fact (path:line or report read), **J** judgment, **U** unknown. Paths are relative to `~/projects/wargrid` unless they start with `ow/` (`~/projects/wargrid-overnight-work/`) or `spike/` (`~/projects/wargrid-wt-worker/`). Owner decisions of 2026-11-15 (`docs/reference/design-answers-2026-11-08.md:816-824`) are taken as fixed. Line numbers are `main` before P2.2; each package refreshes them on its base.

## Why

- **F** On Steam Deck Firefox the team load misses 49 % of frames inline and 0 % with the simulation on a worker; worker job p95 26.84 ms of a 33.3 ms tick (`ow/worker-threads/results.md:70-77`). The Mac shows no problem to fix (PARK, `ow/worker-threads/morning/decide.txt`).
- **F** `driver.sim` appears 32 times under `game/scripts` and 219 times in tests; 10 are full `snapshot()` calls per input event (`game/scripts/match/orders.gd:151, 232, 247, 259, 291, 322, 332, 339, 359, 364`). P2.3a, order controls, P5 and P6 would add more.
- **J** Seam first, or the reader audit is redone later. The thread is a small addition once one owner touches the simulation.

## Goals

1. One owner of the `Simulation` per match (`SimPump`); one published result per tick; no main-thread reference to the live simulation in match or presentation code.
2. Inline and worker are one code path; the worker-only part is the queue, about 60 lines, behind an off-by-default flag; that figure holds for the queue only, SB5a also inherits the [list below](#sb5a-inherits).
3. Snapshot, digest and other heavy reads happen only on request.
4. A result shape later packages extend without re-opening the boundary: state in tick-stamped slots (a fresh `Slot` per job since Pump hardening, answer 11), per-tick events and command results in a drained queue.
5. Digests, traces and netplay pins unchanged by every step.

## Non-goals

- Turning the worker on by default (decision row on the Deck, then a day release).
- P4's interpolation choice; this package only keeps a previous slot available.
- Fog, minimap, the bot read function, launch rules: named here only as consumers.
- A wire or digest change (`protocol/vectors` fixed); Wargrid's own digest (`docs/reference/determinism-rules.md:42`).
- Bot seats in the online scene client (M9); packed simulation state (P5).
- Headless client: it keeps `Lockstep.advance(sim)` (`game/scripts/net/headless_client.gd:180`); the replay oracle steps its own simulation without lockstep ([guide chapter 10](../../guide/10-determinism-and-replays.md)).

## Anti-goals

- No third driver, no `PublishedSim` facade (the spike's facade serves a snapshot up to 29 ticks stale, `spike/game/scripts/match/published_sim.gd`).
- No mutex around the live simulation.
- No generic job system, message bus or delta protocol; no field in the result without a reader in the same change.
- No second set of scene tests for worker mode.

## Where the inputs disagree

- **F** The "7.7 ms every 30th tick" (snapshot 3.3 + digest 4.4 ms, `ow/worker-threads/deck-profile/run1.log`) is the spike driver's own cadence (`spike/game/scripts/match/worker_driver.gd:72,114`). On `main`, offline has no periodic snapshot (`game/scripts/match/offline_driver.gd:31-35`); online has one per hash tick (`online_driver.gd:63`). So SB1's content is the per-input reads.
- **F** `ow/worker-threads/simpump-design.md` §3.4 advises "no reused arrays"; the owner decided reused slots, which was the state through SB4 (Slot objects rotated and were reused). Answer 11, closed 2026-11-18, replaced that with a fresh `Slot` per job (Pump hardening, on branch `pump-hardening`, not merged); in-place reuse of unit columns is closed.
- **F** The same report says online rematch does not exist; P2.2 adds it (`wargrid-wt-rematch` plan, Task 6: `_phase`, `take_rematch`, `create` re-entered). The pump must be re-creatable per match in both drivers.
- **F** "A rejection is lost when two ticks run before one refresh" is merged on `main` (`match_screen.gd:187`, `hud.gd:50`); the drain keeps that merge.
- **F** OpenRA's hash check finds writes by unsynced code (`ow/sim-boundary/research-openra.md` §3); Wargrid's hazard is reads ("Guard").

## Approaches considered

**Boundary shape**

| Option | For | Against |
|---|---|---|
| Mutex around the live sim | smallest diff | an input event blocks a frame for a whole tick; an unlocked read is an untestable crash |
| Third driver + facade (spike) | exists | two code paths; stale reads; refuses orders (`worker_driver.gd:210`) |
| Pump under both drivers, fresh result per tick (`simpump-design.md`) | simplest | allocation per tick; no previous state for P4 |
| **Pump under both drivers, a slot per job + note queue** | decided; P4 gets current and previous; events never latest-wins | a stale slot reference is a new bug class (Risks) |
| Previous and current inside the sim (0 A.D., `ow/sim-boundary/research-0ad.md` §2) | no copy | touches hashed state |

**Where bots run**

| Option | Determinism | Cost | Verdict |
|---|---|---|---|
| **A. In the job, before `step`, reading the live sim through a seat filter** | as today (`offline_driver.gd:32-33`) | decision p95 4.4 ms, `bot_state` 0.9 ms Deck native stay in the job | chosen |
| B. In the job, reading the published slot | same | saves 0.9 ms; the published view is global (`Simulation.view_state()` takes no viewer, `simulation.gd:784` at `d108b90`), a bot seat needs its own filter; traces move | rejected (`wargrid-private/docs/bot-launch-report.md:125`) |
| C. Separate job, commands N ticks later (OpenRA, 0 A.D.'s TODO) | deterministic if sequenced | no gain without idle time; one trace re-pin | not built; A keeps it a call-site move |
| D. Main thread, published view | worker mode: the landing tick depends on thread timing | 4.4 ms spikes on the Deck's bottleneck thread (main p95 15.7 ms, `results.md:71`) | rejected |

**F** Zero Hour updates AI inside the logic frame on the logic thread (`GeneralsMD/Code/GameEngine/Source/GameLogic/System/GameLogic.cpp:3766-3768`, the call `TheAI->UPDATE()` at 3768, `~/projects/CnC_Generals_Zero_Hour` 0a05454); 0 A.D. rejected a per-turn state copy for AI as too slow (`research-0ad.md` §6). A matches both.

**Hashing**: OpenRA and 0 A.D. hash a cheap tier often and a full one rarely (`research-openra.md` §5, `research-0ad.md` §5). **F** Wargrid has both tiers: a per-tick ring over raw live words (`game/scripts/simulation/simulation.gd:641-676`, 0.24 ms Deck native, not on the wire) and the full digest every 30 ticks on the wire (`game/scripts/net/lockstep.gd:112-119`). **J** No new hash; schedule the two that exist.

## Design

### Ownership and API

New `game/scripts/match/sim_pump.gd` (`RefCounted`; outside `simulation/` because it uses `Thread`). It owns the `Simulation` and the `CommandRecorder` from `start()` to `stop()`. Drivers keep protocol state (online `Lockstep`, transport, P2.2 phases). The screen keeps nothing but what `drain` hands it. `driver.sim` is removed in SB3.

```gdscript
class Job:    # one per tick, or a query (step = false)
    var commands: Array[Dictionary]   # seat order; a missing `tick` is stamped by run_job, a missing `sequence` only with stamp_sequence (offline)
    var bots: Array[int]              # seats that may decide in this job; [2] offline 1v1, the host's bot seats online, empty for a guest
    var plan_bots: bool = false       # check the bots' orders with check_command and return them in note.bot_commands, issue nothing (the online driver, every tick job)
    var step: bool = true
    var want_digest: bool             # snapshot + digest; online hash ticks, tick 0, final record
    var want_ring: bool               # desync report
    var want_tick_hash: bool          # the note carries tick_hash(); offline every 30 ticks
    var want_log: bool                # the note carries the recorded command log
    var want_bot_lines: bool          # the note carries the F3 bot lines
    var stamp_sequence: bool = false  # offline: a missing sequence becomes last accepted plus one
    var preview: Dictionary           # {player, builder_id, kind, origin} or empty

class Note:   # queue entry, exactly one per job, drained in order
    var done: bool = true             # never set false today: a script error in a job does not clear it
    var tick: int
    var over: bool
    var survivors: Array[int]
    var events: Array[Dictionary]     # combat_events copy
    var results: Array[Dictionary]    # command_results copy
    var issued: Array[Dictionary]     # per job command: {command, ok, error}
    var bot_commands: Array[Dictionary]
    var snapshot: Dictionary          # only with want_digest
    var digest: String
    var ring: PackedStringArray       # only with want_ring
    var tick_hash: String             # only with want_tick_hash
    var log: Array[Dictionary]        # only with want_log
    var bot_lines: PackedStringArray  # only with want_bot_lines
    var preview: Dictionary
    var starts: Dictionary            # job 0 only: seat -> start cell
    var stats: Array[Dictionary]      # match_stats() after the job

class Slot:   # state, latest wins
    var tick: int
    var view: Dictionary              # view_state(): rows, buildings, sources, players, match, map

func _init(sim: Simulation) -> void   # also creates the CommandRecorder; the mode (below) is fixed here from the environment switch
func mode() -> String                 # "worker", "inline" or "inline-fallback" (switch on, threads, but an earlier pump failed in this process)
func start() -> Note                  # warm and freeze caches, job 0 on the caller, then (worker) install the logger, spawn and wait for the start signal
func post(job: Job) -> bool           # false after stop(), on a failed pump, or (worker) when MAX_QUEUED jobs are unpublished
func has_room() -> bool               # worker: fewer than MAX_QUEUED jobs unpublished; true when stopped or failed; the drivers ask before they build a job or take a tick
func drain() -> Array[Note]           # worker: under the lock, takes all notes and rotates slots; reads the failure marker; nothing from an abandoned pump
func current() -> Slot                # worker: main only, never written after publishing
func previous() -> Slot               # worker: main only; null until two ticks were taken
func query(job: Job) -> Note          # worker: queue entry with its own reply, waits up to WAIT_MSEC; null on a failed pump or a timeout; inline: runs on the caller
func record() -> Dictionary           # {tick, digest, match, commands} from a query job with want_digest and want_log; worker: through query
func failure() -> String              # why the pump failed, "" while healthy or stopped (full queue and ordinary stop keep it empty); main thread only
func busy() -> bool                   # worker: jobs unpublished and no failure; inline: false
func queue_stats() -> Dictionary      # refusals, depth, main waits and per-job timing rows; reset_queue_stats() zeroes them
func stop() -> void                   # inline: sets a flag, later posts return false; worker: drops the waiting jobs, joins only after the worker's exit acknowledgement (at most the running job), else abandons the pump
func live() -> Simulation            # tests and pre-start setup; worker: asserts not busy() and not abandoned
static func worker_wanted() -> bool   # switch, threads feature and no failed pump
static func run_job(sim, recorder, job, slot, timing := {}) -> Note   # slot null for a query
```

`done` cannot see a script error, and release builds raise none (engine claim from the sim boundary critique (private), not re-checked here). Online, the 30-tick digest is the backstop for a job that went wrong; offline there is none. A null `run_job` result fails the pump (Pump hardening), and in a debug build a worker job whose thread logged an error fails it as `fault` (SB5a, `pump_logger.gd`). `MAX_QUEUED` is 3 in `sim_pump.gd` and counts the executing job, so at most one executing and two waiting jobs are unpublished (user, 2026-11-22).

`run_job` is the only function that touches the simulation. Order, same as today (**F** `offline_driver.gd:32-33,48`): issue `commands`, run `bots` through `Skirmish.issue_opponents(recorder, job.bots)` (exists, `skirmish.gd:67`; today the offline driver calls `issue_opponent(_recording())`, seat 2 only, `offline_driver.gd:32`, `skirmish.gd:64-65`; the `bots` field is new), `step()` unless over, copy events and results, write the view into `slot`, then the extras. Application order is `(tick, player, sequence)` anyway (`simulation.gd:325`).

### Slots and notes

Through SB4 the pump had four recycled `Slot` objects (roles WRITE, READY, CURRENT, PREVIOUS); since Pump hardening every job gets a new `Slot`. Publish, under one lock: append the note and make the new slot READY (a newer READY replaces an undrained one). Drain, under one lock: take all notes; if a READY slot is waiting, CURRENT becomes PREVIOUS and READY becomes CURRENT. A slot is never written after it is published, so neither thread writes a slot the other can read. The inline pump does this without a lock (`sim_pump.gd` `post`, `drain`).

- Invariant (tested): after `drain`, `current().tick` equals the last note's tick.
- A READY slot overwritten before a drain is correct for state (latest wins) and is why events are not in it.
- Answer 11 is closed (user, 2026-11-18): the pump publishes a fresh `Slot` per job and never writes one after publishing, so main may keep any number of slots, for example a ring of poses for P4. The recycled slots (`_publish`, `_rotate`) went in Pump hardening (user, 2026-11-18); `post` now creates the slot and `drain` swaps `current()` and `previous()`.
- `previous().tick` can be two behind after a skipped tick; `world_view.gd:242` already drops its blend then.
- `run_job` assigns a fresh `view_state()` into the slot (a stale reader sees old values, never a resize).
- **Viewer** (agent proposal). The published view is global. A read that depends on a viewer (the local player's fog, a bot's seat filter) rides on the job like the preview's player and comes back in the note, never as a per-player slot.
- **Request and answer** (agent proposal). A request (preview, query) rides on the job; its answer comes in that job's note, not in the slot. Today each driver plumbs its own request (`request_preview` in `offline_driver.gd` and `online_driver.gd`).

### One code path

Both modes: `_physics_process` calls `driver.step()`, which posts; `_process` calls `driver.drain()`, which feeds every note in order to `collect_step` (sound, visuals), rejections and lockstep, then shows `current()` once. Inline, `post` runs `run_job` at once, so the same frame's `_process` drains it: today's latency. Tests that drive only `_physics_process` (`match_screen.gd:188`) drain there.

| | Inline | Worker |
|---|---|---|
| queue | result stored directly | `Mutex` + `Semaphore`, `MAX_QUEUED = 3`, running job counted (user, 2026-11-22, [SB5a plan](../plans/2026-11-22-sim-boundary-sb5a.md#owner-answers-user-2026-11-22)) |
| backlog | never | `post` false, game time slows |
| stall, dead thread | n/a | `STALL_MSEC` check, `is_alive()` |
| stop | nothing | the running job finishes (at most one job), then a join, and only after the worker's exit acknowledgement |
| `live()`, Profiler | allowed | only while idle (asserted) / refused |
| `PresentationClock` split | SB3 moved the view build into the step frame, so the split no longer divides it | bypassed |

**Thread lifecycle and a failed pump (built in SB5a).** `Thread.wait_to_finish()` has no timeout, so every bounded wait is a poll on main (a deadline from `Time.get_ticks_msec()`, `try_wait()` or a flag read under the lock, `OS.delay_usec(200)` between reads) and a join happens only after the worker has acknowledged its exit (`_exited`, set under the lock as its last act). `stop()` sets quit under the lock, drops the waiting jobs and polls for that acknowledgement for at most `WAIT_MSEC` (5000 ms); the worker re-checks quit after every job, so the running job finishes and publishes, the waiting ones never run. A worker that does not acknowledge (a stalled job, found by `drain` after 90 frames and 3000 ms, a `query` or `stop` that timed out, or a start that never signalled) is abandoned through one helper, `_abandon(cause)`: quit set, the worker woken, the first failure reason and the process latch set, the pump marked abandoned. An abandoned pump is never read again and never joined while its worker may still run (the next `start()` joins it once the worker has exited); `stop()` on it returns at once, `query` returns null, `record()` uses its main-side copies, and a job that finishes late publishes into the dead pump, sees quit and exits without taking the next job. The static `_threads` list keeps every pump with a started, unjoined thread alive (a `Thread`'s callable does not keep its `RefCounted` owner alive), and the static list is what that `start()` walks. The latch makes every later pump inline for the process. An abandoned worker still inside a job at process exit can abort the process on macOS (open owner question, [verification](../../reference/sim-boundary-verification.md#sb5a)).

Tests: scene, order, HUD and sound suites run once, inline, through the same `run_job` and drain. One `test_sim_pump.gd` runs each case in both modes: 900-tick bot match digests equal to a direct run; two notes in one drain; error one tick later; preview answer; pause posts nothing; restart; stop with a job in flight; injected fault; stall (worker only). At SB5a the scene suite runs once more under `WARGRID_SIM_THREAD=1` with a `tick_scene` helper (physics, bounded `busy()` wait, process).

### Offline, online, restart

- **Offline.** `submit` stamps `player`, queues the command without a `sequence` and returns `{ok: true}`, as online already does (`online_driver.gd:79-81`); from SB3, `run_job` gives a command without a `sequence` the simulation's last accepted sequence for that player plus one, as the bots do (`skirmish.gd:105-111`), so no counter exists outside the simulation and refusals leave no gap (answer 21). Online keeps stamping at submit (`lockstep.gd:67-69`). **F** Gaps in sequences are legal: `_validate` only requires an increase (`simulation.gd:210`). The real `{ok, error}` arrives with the next tick and goes down online's `rejected` path (`match_screen.gd:142-146`), text `"Rejected: " + error`. SB2 gets there before the pump: the driver still issues at `submit` and holds the answer until its next `step()`, which returns own answers in the `Note.issued` shape to both drivers' callers; SB3 moves the issue into the job. Offline, placement stays after a click until that build's answer and stays on after a refusal; online, the click closes placement at once and a refusal reopens it with the same building; placement clicks are ignored while a build answer is pending; only accepted orders tick the playtest checklist; an accepted result no longer clears a refusal note (answers 13, 15, 18-20). The placement ghost moves at once in the colour of the last preview answer, refused before a placement's first answer; the answer for the new origin comes with the next tick (today synchronous, `orders.gd:283-287`).
- **Online.** **F** Today `Lockstep.advance(sim)` (`lockstep.gd:135-146` at `d108b90`) checks, issues, logs and steps; `finish_tick(tick, state)` (`:148-169`) is a separate call after it (`online_driver.gd:63`, `headless_client.gd:163`, before SB4) that digests a hash tick's snapshot (`:151-153`) and sends the own packet. SB4 splits `advance` into `take(tick)` (today's checks; the commands or null) and `record(tick, issued)` (log, latency, rejections); `advance(sim)` stays as take, issue, record, step. `finish_tick(tick, state, digest: String = "")` uses a given digest instead of computing one, so `test_lockstep.gd` and `run_lockstep.gd` stay untouched. Safe because `finish_tick(h)` sends the packet for `h + delay` (`lockstep.gd:157`); worker mode delays it by up to a frame after the job ends, plus the jobs queued ahead (33-63 ms from the Deck job times, [packages](../../packages.md#night-lane)), against a 133 ms delay. Desync: `desync_report(ring)`, the ring from a query job. **F** Today `_finish` (`online_driver.gd:267` at `d108b90`) writes the report in the same frame, built in `_report` (`:297`); in worker mode it is written when that job's note is drained.
- **Restart, rematch, leave.** A pump lives for one match. P2.2's `_restart_world` and the online `create` both: `stop()`, drop notes, new simulation, new pump, `start()`. Job 0 runs on the caller and fills CURRENT; its note carries `starts` (`MapData.start_cell(sim.map_data(), seat)`), so `_reset_camera` reads the map size from `current().view.map.size` (`simulation.gd:753`) and the start cell from that note instead of `match_screen.gd:117,121`, and `Lockstep.start` gets tick 0 without a live read. The playtest record (`match_screen.gd:137-139`) is a query job with `want_digest`. `_exit_tree` calls `stop()`.

### Bots and the read function

Bots run inside the job (option A). Their memory stays on the simulation object (`skirmish.gd:175-178`), touched only by the owner thread. The read function changes what `decide` reads, not where: `sim.bot_state()` grows into the seat filter inside the same job. Rule: `decide` reads only its view, the map and its own memory and writes only through the command sink, so option C later is a call-site move.

- **F** No collision with hash ticks: seat k decides on `tick % 30 == k` (`skirmish.gd:75-76`), digests on `tick % 30 == 0`.
- **J** The 4.4 ms decision spikes are not fixed here. Worker mode moves them off the main thread.
- Online: the scene client has no bot seat (`online_driver.gd:37`). When M9 adds one, `run_job` runs it with a collecting sink and the driver submits `bot_commands` through the lockstep, as the headless client does (`game/scripts/net/seat_sim.gd:18-20`). Not built now.

### Snapshot, digest, ring

**F** Main-thread reads of the live simulation on `main`, outside the driver's step path:

- per input event: `orders.gd:31` (`match_over`), the 10 `snapshot()` calls, `:283` (`tick`) and `:286` (`preview_build`) per preview update; `match_screen.gd:131` (`tick`, marker), `:152` (`match_over`), `:263` (`tick`) per submit, and `:265` and the selection paths in `orders.gd` through `_refresh` to a full `view_state()` (`:241`); `offline_driver.gd:41` (`snapshot()` per command);
- per refresh: `hud.gd:163` (`team_of`, once the match is won);
- per match: `match_screen.gd:117,121` (camera reset), `:138` (`_match_record` snapshot), `online_driver.gd:96` (`view_state()` in `match_log`);
- step path (SB3): `match_screen.gd:182-191, 281-282`, `offline_driver.gd:38,65`, `online_driver.gd:42,58-65`.

| Read | Today | After |
|---|---|---|
| input events, refresh, offline `submit` | live reads above | shown view (SB1), CURRENT slot (SB3); own counter |
| preview, offline refusal | synchronous | with the next tick (SB2) |
| online hash tick | snapshot + digest on main | `want_digest`, same ticks, same value |
| tick 0, camera, match record, match log, desync ring | live reads | job 0 note / CURRENT / query jobs |
| offline periodic | none | none; asserted by a test |
| per-tick ring | every tick, every mode | off in offline matches; on online, in headless replays and in direct-sim tests (answer 5, agent call 3) |

### What enters the result later

One rule per kind of data, so the hand-over (view build 1.6 ms per tick Deck native on team, `deck-profile/run1.log`) does not grow per package: per unit, a packed column in `ViewRows` (`sim-interface.md:48`); per tick and not to be lost (alerts), an event in the note; large and slow-changing (local fog grid, minimap terrain), a versioned block in the slot, copied only on a new version; the minimap reads rows and the fog block.

**J** The 1.6 ms is mostly per-unit reads of entity dictionaries (Mac fit: 0.006 ms + 1.28 µs per unit, `results.md:38`), so it falls when P5 packs movement state. **U** The Deck split between rows and building copies; SB3 measures it.

### Guard against live reads

1. Structural: nothing outside the pump holds the simulation; `live()` asserts in worker mode.
2. Static: `tools/test_sim_boundary.py` gains a check that no file under `game/scripts/match/` or `presentation/` names `.sim` or `live()` (allowlist: the pump).
3. The worker-mode suite at SB5a: a missed read has no object to read.
4. Caches (`Definitions`, `CombatDefinitions.radius`, `Registry.reach_cache`, `Skirmish._skirmish_map`) are warmed and `make_read_only()` in both modes. A late insert from the HUD is then two error lines and a default value, which fails the suite (`tools/run_tests.sh`) but nothing in a running game; `freeze_caches` freezes nested values, and the pump derives its warm-up from the same list (`definitions.gd` `cache_names()`, `sim_pump.gd` `_warm_and_freeze`), since Pump hardening. The freeze coexists with `Registry.add_test_kind` / `clear_test_kinds` (`definitions.gd:56-61`, `_reset` `:137-143`, at `d108b90`): those test helpers reset to unfrozen copies, and `_reset` also clears `reach_cache`, which `Combat._reach` fills and reads (`combat.gd:83-85`).

OpenRA's hash check is not adopted (answer 8).

## Package cut

Night packages, each one fresh subagent per task, each resumable from its verification file. All start after P2.2 merges and refresh path:line then; the plans build on `main` plus the P2.2 plan's contracts (`online_driver` phases, rematch, `Lockstep.for_start`, `Lockstep.session_handler`).

| # | Scope | Exit evidence | Later packages get |
|---|---|---|---|
| SB1 Reads on request | the per-input and per-refresh reads above go to the shown view (`match_screen.shown_state`) or a counter; input paths re-show it instead of building a `view_state()`; no pump | `snapshot` and `view_state` zone counts 0 per input event; `snapshot` 0 over 300 idle offline ticks, 1 per online hash tick; digests, traces, pins equal; `game/scripts/simulation` diff empty | P2.3a selection panel and hover on view fields |
| SB2 Answers one tick later | own-command answers (both drivers) and the placement preview arrive with the next tick; placement and checklist follow the answer | listed order, HUD and sound tests gain one physics call; same error strings behind `Rejected: `, same sounds; two-tick merge test green; IC1 rows re-pinned only in the fields of answer 17; IC2 unchanged | P2.3a refused-order line; alerts |
| SB3 Pump inline, offline (done 2026-11-16, merged to local `main` in `6333249`) | `sim_pump.gd`, slots, notes, bots in the job, cache freeze, static check, camera from job 0; tests move to `pump.live()` | pump against direct digests over 900 ticks; skirmish and team traces equal; slot invariant tests; ledger row; view-build split reported | P4 current and previous; P5, P6 behind the pump; bot read function |
| SB4 Online on the pump (done: merged to local `main` 2026-11-18, fast-forward `14e254d`, not pushed, owner check still owed; [verification](../../reference/sim-boundary-verification.md#sb4)) | lockstep split, rematch re-creates the pump, ring by query job | lockstep tests untouched and green; loopback test of two drivers; `run_netplay.sh` match and rematch; vectors untouched | fog and minimap online |
| Pump hardening (implemented on branch `pump-hardening`, 2026-11-18, not merged; gate result in its [verification](../../reference/sim-boundary-verification.md#pump-hardening); night package before SB5a; its slot at the next night-run preparation and its name were agent proposals) | the inline-testable part of the critique: a fresh `Slot` per job (answer 11); offline keeps its queue and preview request on a refused post (folds in STATUS F32's `post` part); a null `run_job` result publishes nothing and fails the pump; one "end the match" call that stops the pump on every exit path (leave, quit, window close) before it records; `record()` returns the command log, `recorder()` goes, `playtest_header()` stops building the log; static check widened to any member access on a pump outside the two drivers, with per-file counts; nested cache freeze with the warm-up derived from the freeze list; SB4 leftovers (`Lockstep.finish_tick` refuses to send after the lockstep ended or for a tick that is not the last sent plus one; a reference test of a scene driver against a plain `advance(sim)` peer with hashes through the match end; `FakeTransport` applies the relay's frame-order rule; the preview request on one job per step call; STATUS F35, the sequence stamp only on request); SB4 review riders (`take` checks `tick == _next_tick`; a test for a receive that ends the lockstep while a job is undrained); one profiled team-load row through `SimPump.post` and `drain` beside the direct row; update the SB5 comments at `offline_driver.gd:149` and `definitions.gd:120` (the first went with the `recorder()` shortcut, the second with the shallow freeze) ([critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)) | all inline tests; digests, traces and pins equal | SB5a shrinks back to the queue |
| SB5a Worker mode: the thread (flag off) (implemented on branch `sim-boundary-sb5a` 2026-11-27, local commits only, not pushed or merged; Tasks 1 to 15 done, gate and owner checks pending; [verification](../../reference/sim-boundary-verification.md#sb5a)) | thread, native and headless behind an environment switch, `MAX_QUEUED`, both-mode tests, fault and stall, `worker_ab.py` into `tools/` with its test; the [inherits list](#sb5a-inherits) | digests equal on four loads in both modes; scene suite green under the flag; fault ends the match within 5 s; loopback online with one worker client | SB5b, the decision row |
| SB5b Worker mode: the web half | threaded Web preset, COOP/COEP in `web/sws.toml`, the preset-and-headers pairing check in `tools/test_deploy_web.py`, pause-menu toggle with a headless layout test; on the test app only until a GO | pairing check goes red on a mismatch; before production switches to the threaded build, the threaded test app opens from a link in each chat app friends use, and one listen check | the decision row |
| SB6 Decision rows (attended; after SB5b, probing the threaded test app, because SB5b keeps the threaded web build there until a GO: agent proposal) | Deck Firefox, 3+ interleaved runs per arm; mixed online match; fault probe in the release web build; one attended look at offline placement with the worker on. Bench: scripted input; the quality the automatic pick chooses and Low; offline rows without the 30-tick digest; the online cadence as its own row; arms worker, no-threads inline, and inline with the `Engine.max_physics_steps_per_frame` cap. An attended Deck session without threads (inline arm at the picked quality, at Low, and with the cap at 1 or 2) comes before the SB5a plan | the go rule, whole: `tick_rate` at least 29.7 (tolerance and a test); refused posts and the longest run of refusals (limits not yet set) replace the backlog guard, which cannot exceed the queue cap; pace judged on the worst two-second window as well as the average; report-only rows for tick arrival spread and answer latency; a no-harm row on a fast machine. PARK or DROP: production stays on the no-threads build, the flag code stays and the suite runs under the flag in CI. GO: the worker is on by default on desktop builds too (user, 2026-11-18); re-measured at the P6 and fog gates and at P9, the switch stays until then ([critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)) | the day release that turns it on |

### SB5a inherits

Each line has its source: a change number of the sim boundary critique (private) with its finding, or a code comment. Items without a note are in the user's list of 2026-11-18 ([critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)). Ticked at `86d4eb36` (SB5a, branch `sim-boundary-sb5a`, not merged) with the case that pins each item; `test_sb5a_*` cases live in `test_sim_pump.gd` unless a file is named, and the fault cases run through `tools/run_pump_faults.sh`.

- [x] `query()` goes through the worker and waits, bounded by the stall limit (change 21, A2; `record()` is a query job and the offline `match_log` reads its log through it). `test_sb5a_query_waits_behind_jobs`, `test_sb5a_record_waits_for_queue`, `test_sb5a_query_never_touches_slots`, `test_sb5a_query_null_on_failed_pump`; fault case `stall_query`.
- [x] `stop()` joins only after the worker's exit acknowledgement (reworded from "never joins after a failure"); the stall is counted in frames; the loop re-checks the quit flag after each job (change 22, A5). `test_sb5a_stop_with_job_in_flight`, `test_sb5a_stop_idle_worker`, `test_sb5a_stop_is_idempotent`, `test_sb5a_idle_is_no_stall`, `test_sb5a_suspend_is_no_stall`, `test_sb5a_abandoned_worker_takes_no_more_jobs`; fault cases `stall_stop`, `stall_leave`, `stall_restart`.
- [x] An owner-thread check in `run_job` in every build: `push_error` and fail the pump (change 23, A6). This is not the debug hash check answer 8 declined. `test_sb5a_worker_runs_off_main`; fault case `wrong_thread`; `tools/test_sim_boundary.py` `test_only_the_pump_defines_run_owned`.
- [x] A fault flag from an error-count `Logger` in debug and test builds; fault and stall cases run as their own process (change 24, A3). Fault cases `logged_error`, `main_error_control`, `fault_in_query` and the other nine, twelve in all (`PUMP FAULTS PASSED 12`). Blind spot: with `Engine.print_error_messages` off no logger is called.
- [x] One free-running case that does not wait for idle and compares notes and view hashes with inline, plus one case that enumerates publish and drain orders; removing the lock turns a named case red (change 25, A6). `test_sb5a_free_running_equals_inline`, `test_sb5a_publish_orders`, `test_sb5a_lock_guards_publish` (red without the lock, 3 of 3). Known limit: swapping the ready slot after the unlock cannot be proven red from outside (13 of 13 green; a window of nanoseconds).
- [x] Profiler: the ten Profiler cases of the scene suites run with inline pumps under the flag (reworded from "the five ticking cases named as skipped"; the Profiler is not thread-safe, `start()` asserts it is off in worker mode, change 26, A6). `test_sb5a_runner_inline_list_and_pump_counts` (`test_runner.gd`; `INLINE_UNDER_SWITCH` holds them beside eleven batching cases).
- [x] The effective mode is: setting on, the build has threads, and no pump failed in this process (change 27, A7). `test_sb5a_mode_from_switch`; fault case `next_match_inline`.
- [x] A pump failure online ends the lockstep and closes the transport; a loopback test checks the peer's `left`, and the peer sees the leave (change 28, A8). The 1v1 text is now "<name> left the match" (P7 part 2 T2-6), not "Your opponent left". `test_sb5a_online_failure_ends_and_closes`, `test_sb5a_relay_loss_and_pump_failure_same_frame`; fault case `stall_online`. The explicit transport close on the step path is pinned by `test_sb5a_failure_between_room_and_post` (`closes == 1` right after `step()`); the same-frame case stays green without it, because `_finish()` closes any lockstep end in the same drain, so the close is made twice (a second `close()` on a closing socket is an engine no-op, not re-checked).
- [x] Every terminal cause (null result, owner-thread check, fault flag, stall, dead thread) writes the same main-side reason into `failure()`, never read across threads; queue-full and stopped keep `failure()` empty. `test_sb5a_null_job_marker_fails_pump`, `test_sb5a_query_null_job_fails_worker_pump`, `test_sb5a_job_zero_null_fails_pump`, `test_sb5a_post_refused_when_full`; every fault case. The tick in the text can lag by the number of undrained notes when the marker is read in `post` or `query`.
- [x] The offline driver also checks `failure()` after `drain()`; the online driver reads `failure()` for change 28 instead of treating every refused post as terminal. `test_sb5a_job_zero_null_ends_match` (`test_skirmish_scene.gd`), `test_sb5a_job_zero_null_ends_online_match`, `test_sb5a_online_start_null_query` (dropped in SB5b Task 4: the start reads job zero's digest and sends no query), `test_sb5a_failure_between_room_and_post`; fault case `stall_offline`.
- [x] The running mode in the playtest header, the desync report and the F3 overlay (change 29, C4). `test_sb5a_header_names_mode` (`test_skirmish_scene.gd`), `test_sb5a_online_header_and_report_name_mode` (`test_online_scene.gd`), `test_sb5a_f3_shows_mode` (`test_perf_overlay.gd`).
- [x] The suite runs under the flag in CI for as long as the flag exists (change 30, A6). The `Test with the simulation on a worker thread` and `Pump fault processes` steps of `.github/workflows/ci.yml` (first CI run owed at the gate); `tools/run_tests.sh` fails a flagged run unless `SIM PUMPS` shows `worker > 0`, `inline == 0` and `LIVE 0` (`test_sb5a_runner_flags_live_worker`).
- [x] A bench scene running the real match screen on the pump in both modes, printing the go-rule metrics (change 31, D9). `game/scenes/match_bench.tscn` (`match_bench.gd`, `match_bench_screen.gd`, `bench_loads.gd`) with `tools/worker_ab.py` and `tools/test_worker_ab.py`; `test_sb5a_offline_digest_every_and_bots` covers the driver hunk it needs. Digests equal on four loads in both modes: `sh tools/run_worker_digests.sh` (`WORKER DIGESTS MATCHED 4`).
- [x] The pairing guard accepts any note while `_taken` is empty, and catch-up is bounded at input delay + 1 ticks per rendered frame, because own packets are sent from `drain` (SB4 review riders, [packages](../../packages.md#night-lane) item 6); the bound is an accepted limit, measured, not fixed (user, 2026-11-22). `test_sb5a_pairing_rejects_foreign_note`, `test_sb5a_catch_up_bound_per_frame` (`test_online_scene.gd`), `test_sb5a_two_notes_one_frame_pair_in_order`, `test_sb5a_waiting_line_after_drain` (`test_online_scene.gd`).
- [x] Room before `take` (user, 2026-11-18; agent finding from the critique check): a refused post ends an online match (`test_sb4_refused_post_ends_match`), so with a queue cap the driver checks room before `take`; the pending-build flag is cleared by the **first failure, offline only** (reworded from "when a pump stops or fails"; online the selection stays as at every other online end, Owner answers 8). `test_sb5a_full_pump_leaves_next_tick_in_lockstep`, `test_sb5a_preview_waits_for_room`, `test_sb5a_offline_waits_for_room` (`test_skirmish_scene.gd`), `test_sb5a_failure_clears_pending_build` (`test_skirmish_scene.gd`), `test_sb5a_online_failure_keeps_selection` (`test_online_scene.gd`).

## Verification

Per package: `sh tools/run_checks.sh`, the full suite, `PERF_LABEL="Sim boundary SBn" sh tools/run_benchmark.sh`; SB4 and SB5a also the `sh tools/run_netplay.sh` scenarios and `sh tools/run_conformance.sh`. Docs in the same branch: guide chapters `01-big-picture`, `04-the-tick`, `05-presentation`, `11-multiplayer` (SB4), `12-performance-and-platforms`, `13-testing-and-tooling`; `docs/reference/sim-interface.md`; `determinism-rules.md:14` reworded at SB5a ("one owner thread").

## Risks

- **Stale slot reference** (J): a reader holding an old slot sees old values, not a torn one, because no slot is written after publishing (answer 11).
- **Deck headroom** (F): job p95 26.84 of 33.3 ms before P5, P6 and fog; worker main p95 15.7 ms on team, 19.0 on hordes300. The seam creates no headroom.
- **P2.2 overlap** (F): both rewrite `online_driver.gd` and `match_screen.gd`; P2.2 adds tests on `driver.sim` identity (Task 6).
- **Input reads the shown tick** (U): in a split frame the shown view is one tick behind the live simulation; an order built from it can name a unit that died since, which the simulation refuses (`ow/worker-threads/reader-inventory-grok.md` §2).
- **Visible change** (J): offline, a refused order plays the order voice, then the refusal one tick later, as online (answers 7, 16); online, a refused placement reopens placement with the same building after about the input delay (answers 13, 18).
- **Threads tax on every web player** (F): about 4.7 % in Firefox on combat open p50, 8.3 % on dense (`docs/reference/perf-spike-verification.md:42`), paid from SB5b while the worker is off, on the test app only until a GO.
- **Infinite loop in a job** (U): Godot cannot cancel a thread; the stall error shows and the thread leaks.
- **Not verified**: Godot's physics-before-process order inside one iteration; packed-array copy-on-write across threads; fault behaviour in a release web build.

## Owner answers (user, 2026-11-15)

Questionnaire on the draft's nine questions plus two from the coordinator; recommendations were given first, and each answer below is the owner's.

1. **First task:** SB1 "reads on request" (the per-input `snapshot()` reads in `orders.gd` and the one per offline command) replaces the earlier "snapshot and digest only when read", which rested on the spike's cadence, not `main`'s.
2. **Bots run inside the job** before `step`, reading through the seat filter; an own bot job is revisited when the bot work needs it, with a measured reason.
3. **Offline bot commands apply on the same tick, as today** (Zero Hour's AI also runs inside the logic frame, `GameLogic.cpp:3768` at 0a05454).
4. **The bot read function lands after SB3.**
5. **The per-tick hash ring is off in offline matches**, on online, in headless replays and in tests; one condition at simulation creation, no trace change.
6. **No faster desync tier planned:** the 30-tick digest stays; revisit only if a real desync shows the window too coarse.
7. **Offline refused orders arrive one tick later, as online.**
8. **No OpenRA-style debug hash check:** the static check, frozen caches and the worker-mode suite guard reads.
9. **Worker mode is switched by a hidden toggle in the pause menu** while it is off by default (against the recommendation of URL and command line only), so Deck playtesters can flip it without a link; it is removed or becomes the setting when the worker goes on.
10. **A report-only Deck row** "view build ms, team, Deck native" on packages that add fields to the published result; no budget.
11. **Slots rotate; unit columns are fresh each tick.** Closed (user, 2026-11-18, [critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)): reuse would save about 1 % of the unit rows and brings torn reads on a kept column, so a published view is never refilled; the pump publishes a fresh `Slot` per job.
12. **The worker toggle exists in the release web build too.** (This reversed the 2026-11-11 header decision, headers only after a measured browser win, in the [worker thread design](2026-11-12-worker-thread-design.md). The 2026-11-18 split replaces "Both land in SB5" below: SB5a is the thread behind an environment switch, SB5b the threaded Web preset, headers and pause-menu toggle, on the test app only until a GO; see the [critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18).) The release Web preset switches to threaded with COOP/COEP headers in `web/sws.toml`; every web player pays the threads tax while the worker is off (Risks), accepted because only the owner and a few friends play; rollback is one redeploy of a no-threads build. The toggle takes effect at the next match or restart and the menu says so ("Takes effect after a restart"); it is remembered with the other settings and allowed offline and online. Both land in SB5.
13. **Offline placement:** a click before the answer keeps placement mode until the answer arrives; if the answer is a refusal, placement stays on.
14. **Online placement:** the same rule; a refused placement keeps you placing (replaced by answer 18).
15. **Playtest checklist:** only accepted orders tick it; a refused gather does not (the screen waits for the answer).
16. **Offline refused order:** the order voice plays at submit, the refusal beep one tick later, as online.
17. **IC1/IC2 re-pin approved**, exactly in these fields: row 11's `place=` and command list; from step 11 on the command tick stamps, the `Tick:` and `Credits:` status values, row 19's inspected-enemy HP and order text (user, 2026-11-15) and row 21's `tick=`. Anything else changing stops the run.
18. **Online placement** (replaces answer 14): the click closes placement at once and a refusal reopens it with the same building, so no ghost lingers for the input delay. Offline keeps answer 13, so IC1 is unaffected by this answer.
19. **While a build answer is pending, further placement clicks are ignored** (agent call, confirmed).
20. **HUD note:** an accepted result no longer clears a refusal note; it stays until the next own message, offline and online (agent call, confirmed).
21. **Offline sequence numbers come from the simulation** (user, 2026-11-16): `run_job` stamps a command without a `sequence` with the player's last accepted sequence plus one at issue time; the offline driver's counter and the `sync_sequence` test helper go; traces, digests, IC1/IC2 and OD1/S3 stay unchanged. Chosen over per-submit stamping (digests change for sessions with refusals) and a pump-owned counter (a second counter that can drift); research private (`research/sb3-sequence-2026-11-16.md`).
22. **The screen drains in `_process` from SB3** (user, 2026-11-16, against the recommendation to drain inside `driver.step()` until SB5): scene tests use a tick helper (physics, then the drain) from SB3.
23. **Online gets a thin pump in SB3** (user, 2026-11-16): it owns a pump, keeps its lockstep on `pump.live()` (allowlisted until SB4) and publishes a slot per tick, so `driver.sim` leaves the screen in SB3; SB4 splits the lockstep.
24. **Caches freeze in all builds; the Deck view-build row is taken at the SB3 gate** (user, 2026-11-16).

## Agent calls (coordinator, 2026-11-15)

Not owner decisions unless marked; each open one can be overruled.

1. **Tests in worker mode:** `pump.live()` only while the pump is idle (`busy()` false, asserted); tests mutate the simulation between drains through one helper; the whole scene suite runs under `WARGRID_SIM_THREAD=1` at the SB5a gate.
2. **Online job taken ahead of the match end:** commands are logged when their note is drained, so a tick that never steps logs nothing; match log and desync report are equal across an inline and a worker peer.
3. **Hash ring "on in tests"** means the direct-sim suites, headless replays and the ring's own tests; scene tests run offline with the ring off, as a real offline match; a ring test turns it on explicitly.
4. **Cache freeze** coexists with `Registry.add_test_kind` (Guard 4).
5. **Placement ghost:** after an origin change it shows the last preview answer's colour (refused before a placement's first answer). While a build answer is pending, further placement clicks are ignored (confirmed as answer 19). Refused offline orders show online's text, `Rejected: <error>`.
6. **Plan base:** `main` plus the P2.2 plan's contracts (`~/projects/wargrid-wt-rematch/docs/superpowers/plans/2026-11-15-p2.2-quick-rematch-slice-1.md`); SB packages start after P2.2 merges.
7. **HUD note** (confirmed as answer 20): an accepted command's result no longer clears the note (`hud.gd:50-54`); only a failure sets it and a submit clears it, so a refusal delivered with an accepted result in the same step stays readable (review fix).
8. **Repaint on input** (`_reshow`) never updates sound and never consumes the step results, so each step's sound events are consumed once, against that step's rows (`sound_director.gd:57`; review fix).
