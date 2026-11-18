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
4. A result shape later packages extend without re-opening the boundary: state in tick-stamped slots (four recycled ones today; answer 11 is closed: a fresh `Slot` per job, in Pump hardening), per-tick events and command results in a drained queue.
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
- **F** `ow/worker-threads/simpump-design.md` §3.4 advises "no reused arrays"; the owner decided reused slots, which is today's state (Slot objects rotate and are reused). Answer 11, closed 2026-11-18, replaces that with a fresh `Slot` per job (Pump hardening); in-place reuse of unit columns is closed.
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
| **Pump under both drivers, four slots + note queue** | decided; P4 gets current and previous; events never latest-wins | a stale slot reference is a new bug class (Risks) |
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
    var commands: Array[Dictionary]   # seat order; a missing `tick` and `sequence` is stamped by run_job
    var bots: Array[int]              # seats that may decide in this job; [2] offline 1v1, empty online
    var step: bool = true
    var want_digest: bool             # snapshot + digest; online hash ticks, tick 0, final record
    var want_ring: bool               # desync report
    var preview: Dictionary           # {player, builder_id, kind, origin} or empty

class Note:   # queue entry, exactly one per job, drained in order
    var done: bool = true             # never set false today: a script error in a job does not clear it
    var tick: int
    var over: bool
    var events: Array[Dictionary]     # combat_events copy
    var results: Array[Dictionary]    # command_results copy
    var issued: Array[Dictionary]     # per job command: {command, ok, error}
    var bot_commands: Array[Dictionary]
    var snapshot: Dictionary          # only with want_digest
    var digest: String
    var ring: PackedStringArray       # only with want_ring
    var preview: Dictionary
    var starts: Dictionary            # job 0 only: seat -> start cell
    var stats: Array[Dictionary]      # match_stats() after the job

class Slot:   # state, latest wins
    var tick: int
    var view: Dictionary              # view_state(): rows, buildings, sources, players, match, map

func _init(sim: Simulation) -> void   # also creates the CommandRecorder; no `threaded` argument: the mode is not built
func start() -> Note                  # worker: warm and freeze caches, run job 0 on the caller, then spawn
func post(job: Job) -> bool           # worker: false when the queue has no room or the pump failed; inline: false only after stop()
func drain() -> Array[Note]           # worker: under the lock, takes all notes and rotates slots; sets `failed`
func current() -> Slot                # worker: main only, never written after publishing
func previous() -> Slot               # worker: main only; null until two ticks were taken
func query(job: Job) -> Note          # worker: hands the job to the worker and waits, bounded by the stall limit (SB5a); inline: runs on the caller
func record() -> Dictionary           # {tick, digest, match} from a query job with want_digest; worker: through query
func recorder() -> CommandRecorder    # inline only; goes in Pump hardening, record() returns the command log instead
func busy() -> bool                   # worker: true while a job runs or is queued; inline: false
func stop() -> void                   # inline: sets a flag, later posts return false; worker: never joins after a failure, otherwise a bounded wait
func live() -> Simulation            # tests and pre-start setup; worker: asserts not busy()
static func run_job(sim, recorder, job, slot) -> Note   # slot null for a query
```

`done` cannot see a script error, and release builds raise none (engine claim from the sim boundary critique (private), not re-checked here). Online, the 30-tick digest is the backstop for a job that went wrong; offline there is none. Pump hardening fails the pump on a null `run_job` result; the error-count fault flag for debug and test builds is on the [SB5a list](#sb5a-inherits). `MAX_QUEUED` is not in `sim_pump.gd` yet, so whether it counts the running job is not decided; the SB5a plan fixes it before the thread lands.

`run_job` is the only function that touches the simulation. Order, same as today (**F** `offline_driver.gd:32-33,48`): issue `commands`, run `bots` through `Skirmish.issue_opponents(recorder, job.bots)` (exists, `skirmish.gd:67`; today the offline driver calls `issue_opponent(_recording())`, seat 2 only, `offline_driver.gd:32`, `skirmish.gd:64-65`; the `bots` field is new), `step()` unless over, copy events and results, write the view into `slot`, then the extras. Application order is `(tick, player, sequence)` anyway (`simulation.gd:325`).

### Slots and notes

Today four `Slot` objects with roles WRITE (owner thread), READY, CURRENT, PREVIOUS (main). Publish, under one lock: append the note, swap WRITE and READY. Drain, under one lock: take all notes; if READY is newer, PREVIOUS returns to the pool, CURRENT becomes PREVIOUS, READY becomes CURRENT. Neither thread ever writes a slot the other can read.

- Invariant (tested): after `drain`, `current().tick` equals the last note's tick.
- A READY slot overwritten before a drain is correct for state (latest wins) and is why events are not in it.
- Answer 11 is closed (user, 2026-11-18): the pump publishes a fresh `Slot` per job and never writes one after publishing, so main may keep any number of slots, for example a ring of poses for P4. Today's recycled slots (`sim_pump.gd` `_publish`, `_rotate`) change to this in Pump hardening (user, 2026-11-18).
- `previous().tick` can be two behind after a skipped tick; `world_view.gd:242` already drops its blend then.
- `run_job` assigns a fresh `view_state()` into the slot (a stale reader sees old values, never a resize).
- **Viewer** (agent proposal). The published view is global. A read that depends on a viewer (the local player's fog, a bot's seat filter) rides on the job like the preview's player and comes back in the note, never as a per-player slot.
- **Request and answer** (agent proposal). A request (preview, query) rides on the job; its answer comes in that job's note, not in the slot. Today each driver plumbs its own request (`request_preview` in `offline_driver.gd` and `online_driver.gd`).

### One code path

Both modes: `_physics_process` calls `driver.step()`, which posts; `_process` calls `driver.drain()`, which feeds every note in order to `collect_step` (sound, visuals), rejections and lockstep, then shows `current()` once. Inline, `post` runs `run_job` at once, so the same frame's `_process` drains it: today's latency. Tests that drive only `_physics_process` (`match_screen.gd:188`) drain there.

| | Inline | Worker |
|---|---|---|
| queue | result stored directly | `Mutex` + `Semaphore`, `MAX_QUEUED = 2` |
| backlog | never | `post` false, game time slows |
| stall, dead thread | n/a | `STALL_MSEC` check, `is_alive()` |
| stop | nothing | join, at most one job |
| `live()`, Profiler | allowed | only while idle (asserted) / refused |
| `PresentationClock` split | SB3 moved the view build into the step frame, so the split no longer divides it | bypassed |

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
4. Caches (`Definitions`, `CombatDefinitions.radius`, `Registry.reach_cache`, `Skirmish._skirmish_map`) are warmed and `make_read_only()` in both modes. A late insert from the HUD is then two error lines and a default value, which fails the suite (`tools/run_tests.sh`) but nothing in a running game; the freeze is shallow (top level only, `definitions.gd` `freeze_caches`) until Pump hardening freezes nested values and derives the warm-up from the freeze list. The freeze coexists with `Registry.add_test_kind` / `clear_test_kinds` (`definitions.gd:56-61`, `_reset` `:137-143`, at `d108b90`): those test helpers reset to unfrozen copies, and `_reset` also clears `reach_cache`, which `Combat._reach` fills and reads (`combat.gd:83-85`).

OpenRA's hash check is not adopted (answer 8).

## Package cut

Night packages, each one fresh subagent per task, each resumable from its verification file. All start after P2.2 merges and refresh path:line then; the plans build on `main` plus the P2.2 plan's contracts (`online_driver` phases, rematch, `Lockstep.for_start`, `Lockstep.session_handler`).

| # | Scope | Exit evidence | Later packages get |
|---|---|---|---|
| SB1 Reads on request | the per-input and per-refresh reads above go to the shown view (`match_screen.shown_state`) or a counter; input paths re-show it instead of building a `view_state()`; no pump | `snapshot` and `view_state` zone counts 0 per input event; `snapshot` 0 over 300 idle offline ticks, 1 per online hash tick; digests, traces, pins equal; `game/scripts/simulation` diff empty | P2.3a selection panel and hover on view fields |
| SB2 Answers one tick later | own-command answers (both drivers) and the placement preview arrive with the next tick; placement and checklist follow the answer | listed order, HUD and sound tests gain one physics call; same error strings behind `Rejected: `, same sounds; two-tick merge test green; IC1 rows re-pinned only in the fields of answer 17; IC2 unchanged | P2.3a refused-order line; alerts |
| SB3 Pump inline, offline (done 2026-11-16, merged to local `main` in `6333249`) | `sim_pump.gd`, slots, notes, bots in the job, cache freeze, static check, camera from job 0; tests move to `pump.live()` | pump against direct digests over 900 ticks; skirmish and team traces equal; slot invariant tests; ledger row; view-build split reported | P4 current and previous; P5, P6 behind the pump; bot read function |
| SB4 Online on the pump (done: merged to local `main` 2026-11-18, fast-forward `14e254d`, not pushed, owner check still owed; [verification](../../reference/sim-boundary-verification.md#sb4)) | lockstep split, rematch re-creates the pump, ring by query job | lockstep tests untouched and green; loopback test of two drivers; `run_netplay.sh` match and rematch; vectors untouched | fog and minimap online |
| Pump hardening (night package before SB5a; its slot at the next night-run preparation and its name are agent proposals) | the inline-testable part of the critique: a fresh `Slot` per job (answer 11); offline keeps its queue and preview request on a refused post (folds in STATUS F32's `post` part); a null `run_job` result publishes nothing and fails the pump; one "end the match" call that stops the pump on every exit path (leave, quit, window close) before it records; `record()` returns the command log, `recorder()` goes, `playtest_header()` stops building the log; static check widened to any member access on a pump outside the two drivers, with per-file counts; nested cache freeze with the warm-up derived from the freeze list; SB4 leftovers (`Lockstep.finish_tick` refuses to send after the lockstep ended or for a tick that is not the last sent plus one; a reference test of a scene driver against a plain `advance(sim)` peer with hashes through the match end; `FakeTransport` applies the relay's frame-order rule; the preview request on one job per step call; STATUS F35, the sequence stamp only on request); SB4 review riders (`take` checks `tick == _next_tick`; a test for a receive that ends the lockstep while a job is undrained); one profiled team-load row through `SimPump.post` and `drain` beside the direct row; update the SB5 comments at `offline_driver.gd:149` and `definitions.gd:120` (comments only) ([critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)) | all inline tests; digests, traces and pins equal | SB5a shrinks back to the queue |
| SB5a Worker mode: the thread (flag off) | thread, native and headless behind an environment switch, `MAX_QUEUED`, both-mode tests, fault and stall, `worker_ab.py` into `tools/` with its test; the [inherits list](#sb5a-inherits) | digests equal on four loads in both modes; scene suite green under the flag; fault ends the match within 5 s; loopback online with one worker client | SB5b, the decision row |
| SB5b Worker mode: the web half | threaded Web preset, COOP/COEP in `web/sws.toml`, the preset-and-headers pairing check in `tools/test_deploy_web.py`, pause-menu toggle with a headless layout test; on the test app only until a GO | pairing check goes red on a mismatch; before production switches to the threaded build, the threaded test app opens from a link in each chat app friends use, and one listen check | the decision row |
| SB6 Decision rows (attended; after SB5b, probing the threaded test app, because SB5b keeps the threaded web build there until a GO: agent proposal) | Deck Firefox, 3+ interleaved runs per arm; mixed online match; fault probe in the release web build; one attended look at offline placement with the worker on. Bench: scripted input; the quality the automatic pick chooses and Low; offline rows without the 30-tick digest; the online cadence as its own row; arms worker, no-threads inline, and inline with the `Engine.max_physics_steps_per_frame` cap. An attended Deck session without threads (inline arm at the picked quality, at Low, and with the cap at 1 or 2) comes before the SB5a plan | the go rule, whole: `tick_rate` at least 29.7 (tolerance and a test); refused posts and the longest run of refusals (limits not yet set) replace the backlog guard, which cannot exceed the queue cap; pace judged on the worst two-second window as well as the average; report-only rows for tick arrival spread and answer latency; a no-harm row on a fast machine. PARK or DROP: production stays on the no-threads build, the flag code stays and the suite runs under the flag in CI. GO: the worker is on by default on desktop builds too (user, 2026-11-18); re-measured at the P6 and fog gates and at P9, the switch stays until then ([critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)) | the day release that turns it on |

### SB5a inherits

Each line has its source: a change number of the sim boundary critique (private) with its finding, or a code comment. Items without a note are in the user's list of 2026-11-18 ([critique review](../../reference/design-answers-2026-11-08.md#sim-boundary-critique-review-user-2026-11-18)).

- `query()` goes through the worker and waits, bounded by the stall limit (change 21, A2; `offline_driver.gd` `match_log` shortcut comment).
- `stop()` never joins after a failure, otherwise a bounded wait; the stall is counted in frames; the loop re-checks the quit flag after each job (change 22, A5).
- An owner-thread check in `run_job` in every build: `push_error` and fail the pump (change 23, A6). This is not the debug hash check answer 8 declined.
- A fault flag from an error-count `Logger` in debug and test builds; fault and stall cases run as their own process (change 24, A3).
- One free-running case that does not wait for idle and compares notes and view hashes with inline, plus one case that enumerates publish and drain orders; removing the lock turns a named case red (change 25, A6).
- Profiler: one mutex when enabled, or the five ticking cases named as skipped under the flag (change 26, A6; the cases are `test_base_scene.gd:381,396` and `test_skirmish_scene.gd:934,1181,1206`).
- The effective mode is: setting on, the build has threads, and no pump failed in this process (change 27, A7).
- A pump failure online ends the lockstep and closes the transport; a loopback test checks the peer's `left`, and the peer sees "Your opponent left" (change 28, A8).
- The running mode in the playtest header, the desync report and the F3 overlay (change 29, C4).
- The suite runs under the flag in CI for as long as the flag exists (change 30, A6).
- A bench scene running the real match screen on the pump in both modes, printing the go-rule metrics (change 31, D9).
- The pairing guard accepts any note while `_taken` is empty, and catch-up is capped at input delay + 1 ticks per frame (SB4 review riders, [packages](../../packages.md#night-lane) item 6).
- Room before `take` (user, 2026-11-18; agent finding from the critique check): a refused post now ends an online match (`online_driver.gd`, `test_sb4_refused_post_ends_match`), so with a queue cap the driver needs room checked before `take` and the pending-build flag cleared when a pump stops or fails (changes 4 and 10, A1).

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
