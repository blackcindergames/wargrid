extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const PumpLogger = preload("res://scripts/match/pump_logger.gd")

const MAX_QUEUED: int = 3
const STALL_FRAMES: int = 90
const STALL_MSEC: int = 3000
const WAIT_MSEC: int = 5000
const TIMING_CAP: int = 4000

class Job:
	var commands: Array[Dictionary] = []
	var bots: Array[int] = []
	var plan_bots: bool = false
	var step: bool = true
	var want_digest: bool = false
	var want_ring: bool = false
	var want_tick_hash: bool = false
	var want_log: bool = false
	var want_bot_lines: bool = false
	var preview: Dictionary = {}
	var stamp_sequence: bool = false

class PlanRecorder extends CommandRecorder:
	func issue_command(command: Dictionary) -> Dictionary:
		var error: String = _sim.check_command(command)
		if error.is_empty(): _commands.append(command.duplicate(true))
		return {"ok": error.is_empty(), "error": error}

class Note:
	var done: bool = true
	var tick: int = 0
	var over: bool = false
	var survivors: Array[int] = []
	var events: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	var issued: Array[Dictionary] = []
	var bot_commands: Array[Dictionary] = []
	var snapshot: Dictionary = {}
	var digest: String = ""
	var ring: PackedStringArray = PackedStringArray()
	var tick_hash: String = ""
	@warning_ignore("shadowed_global_identifier")
	var log: Array[Dictionary] = []
	var bot_lines: PackedStringArray = PackedStringArray()
	var preview: Dictionary = {}
	var starts: Dictionary = {}
	var stats: Array[Dictionary] = []

class Slot:
	var tick: int = 0
	var view: Dictionary = {}

# A queue entry for query(): the reply semaphore lives here, never on Job.
class Query extends RefCounted:
	var job: Job
	var note: Note
	var reply := Semaphore.new()
	func _init(asked: Job) -> void:
		job = asked

var _sim: Simulation
var _recorder: CommandRecorder
var _notes: Array[Note] = []
var _current: Slot
var _previous: Slot
var _ready: Slot = null
var _stopped: bool = false
var _failure: String = ""
var _mode: String
var frame_source: Callable = Engine.get_physics_frames
var clock: Callable = Time.get_ticks_msec

var _mutex := Mutex.new()
var _work := Semaphore.new()
var _started := Semaphore.new()
var _thread: Thread
# The queue, counts and flags below are shared with the worker, under _mutex.
var _queue: Array[RefCounted] = []
var _unpublished: int = 0
var _quit: bool = false
var _exited: bool = false
var _marker: String = ""
var _owner_id: int = OS.get_thread_caller_id()
var _abandoned: bool = false
var _cap_test: int = 0
var _gate: Semaphore
var _gate_where: String = ""
var _stall_frame: int = 0
var _stall_msec: int = 0
var _last_refusal_frame: int = -2
var _stats: Dictionary = _zero_stats()
# Worker only: the running job's clock stamps, then (under _mutex) the published jobs not yet drained.
var _timing: Dictionary = {}
var _unread: Array[Dictionary] = []

# A failed pump turns every later pump inline for the rest of the process.
static var _latched: bool = false
static var _forced: String = ""
# Pumps built per way of getting their mode, for the suite's SIM PUMPS line.
static var _counts: Dictionary = {"worker": 0, "forced": 0, "fallback": 0, "inline": 0}
# Pumps whose thread is started and not joined, abandoned ones included; the reference keeps a running pump alive.
static var _threads: Array[RefCounted] = []
# Installed once, on main, before the first worker starts; Godot has no lock around its logger list, so it is never removed.
static var _logger: PumpLogger

func _init(sim: Simulation) -> void:
	_sim = sim
	_mode = _mode_for()
	_recorder = CommandRecorder.new(sim)

func start() -> Note:
	_reap_abandoned()
	_warm_and_freeze()
	var job := Job.new()
	job.step = false
	_current = Slot.new()
	var note: Note = _run_owned(job, _current)
	if note == null: return _failed_start()
	var map: Dictionary = _sim.map_data()
	if not map.is_empty():
		for player: Dictionary in _current.view.players: note.starts[player.id] = MapData.start_cell(map, player.id)
	if _mode == "worker": _spawn()
	return note

func _failed_start() -> Note:
	_current.tick = _sim.tick()
	_current.view = _sim.view_state()
	_fail("start")
	var note := Note.new()
	note.tick = _current.tick
	return note

func post(job: Job) -> bool:
	if _stopped or not _failure.is_empty(): return false
	if _mode == "worker": return _post_queued(job)
	var slot := Slot.new()
	var note: Note = _run_owned(job, slot)
	if note == null:
		_fail("post")
		return false
	_stats.accepted += 1
	_notes.append(note)
	_ready = slot
	return true

func drain() -> Array[Note]:
	# An abandoned worker's late note stays in the abandoned pump, which nothing reads again.
	if _abandoned: return []
	_mutex.lock()
	var notes: Array[Note] = _notes
	_notes = []
	var read: Array[Dictionary] = _unread
	if not read.is_empty(): _unread = []
	if _ready != null:
		_previous = _current
		_current = _ready
		_ready = null
	var marker: String = _marker
	var unpublished: int = _unpublished
	_mutex.unlock()
	if not read.is_empty(): _stamp_drained(read)
	if not marker.is_empty(): _fail(marker)
	else: _watch(notes.size(), unpublished)
	return notes

func current() -> Slot:
	return _current

func previous() -> Slot:
	return _previous

func query(job: Job) -> Note:
	if not _failure.is_empty(): return null
	var note: Note = _query_worker(job) if _thread != null else _run_owned(job, null)
	if note == null and _failure.is_empty(): _fail("query")
	return note

func record() -> Dictionary:
	if _failure.is_empty():
		var job := Job.new()
		job.step = false
		job.want_digest = true
		job.want_log = true
		var note: Note = query(job)
		if note != null: return {"tick": note.tick, "digest": note.digest, "match": note.snapshot.match, "commands": note.log}
	# A failed simulation cannot be trusted for a digest, so the record keeps what was last shown; a living worker may still write the log.
	var commands: Array[Dictionary] = []
	if _thread == null or _worker_gone(): commands.assign(_recorder.commands().duplicate(true))
	return {"tick": _current.tick, "digest": "", "match": _current.view.match, "commands": commands}

func failure() -> String:
	return _failure

func mode() -> String:
	return _mode

static func _switch_on() -> bool:
	return OS.get_environment("WARGRID_SIM_THREAD") == "1" and OS.has_feature("threads")

static func worker_wanted() -> bool:
	return _switch_on() and not _latched

static func _mode_for() -> String:
	if not _forced.is_empty(): return _counted("forced", _forced)
	if worker_wanted(): return _counted("worker", "worker")
	if _switch_on(): return _counted("fallback", "inline-fallback")
	return _counted("inline", "inline")

static func _counted(kind: String, named: String) -> String:
	_counts[kind] += 1
	return named

static func force_mode_for_test(forced: String) -> void:
	_forced = forced

static func reset_process_latch_for_test() -> void:
	_latched = false

func _fail(kind: String) -> void:
	match kind:
		"fault": _set_failure("fault: a job logged an error at tick %d" % (_current.tick + 1))
		"owner thread": _set_failure("owner thread: a job ran off its thread at tick %d" % (_current.tick + 1))
		_: _set_failure("%s job returned no note after tick %d" % [kind, _current.tick])

func _set_failure(reason: String) -> void:
	_latched = true
	if _failure.is_empty(): _failure = reason

static func _zero_stats() -> Dictionary:
	return {"accepted": 0, "room_refusals": 0, "streak": 0, "streak_max": 0, "depth_max": 0, "cap_hits": 0, "wait_count": 0, "wait_total": 0, "wait_max": 0, "jobs": []}

func _cap() -> int:
	return _cap_test if _cap_test > 0 else MAX_QUEUED

func busy() -> bool:
	if _mode != "worker" or not _failure.is_empty(): return false
	_mutex.lock()
	var pending: int = _unpublished
	_mutex.unlock()
	return pending > 0

func has_room() -> bool:
	if _stopped or not _failure.is_empty(): return true
	var room: bool = _room()
	if not room: _count_refusal()
	return room

func _room() -> bool:
	if _mode != "worker": return _cap_test <= 0 or _notes.size() < _cap_test
	_mutex.lock()
	var room: bool = _unpublished < _cap()
	_mutex.unlock()
	return room

func _count_refusal() -> void:
	var frame: int = frame_source.call()
	_stats.room_refusals += 1
	if frame != _last_refusal_frame:
		_stats.streak = _stats.streak + 1 if frame == _last_refusal_frame + 1 else 1
		_stats.streak_max = maxi(_stats.streak_max, _stats.streak)
		_last_refusal_frame = frame

func queue_stats() -> Dictionary:
	var accepted: int = _stats.accepted
	return {
		"posts_attempted": accepted + _stats.room_refusals,
		"room_refusals": _stats.room_refusals,
		"refusal_streak_max": _stats.streak_max,
		"depth_max": _stats.depth_max,
		"depth_at_cap_share": float(_stats.cap_hits) / accepted if accepted > 0 else 0.0,
		"queue_cap": _cap(),
		"main_wait_count": _stats.wait_count,
		"main_wait_total_ms": _stats.wait_total,
		"main_wait_max_ms": _stats.wait_max,
		"jobs": _stats.jobs.duplicate(),
	}

func reset_queue_stats() -> void:
	_stats = _zero_stats()
	_mutex.lock()
	_unread = []
	_mutex.unlock()
	_last_refusal_frame = -2

func cap_for_test(cap: int) -> void:
	_cap_test = cap

func gate_publish_for_test(gate: Semaphore, where: String) -> void:
	_mutex.lock()
	_gate = gate
	_gate_where = where
	_mutex.unlock()

static func live_workers() -> int:
	return _threads.size()

static func stop_live_for_test() -> int:
	var stopped: int = 0
	for pump: RefCounted in _threads.duplicate():
		if pump.get("_abandoned"): continue
		pump.call("stop")
		stopped += 1
	return stopped

static func pump_counts() -> Dictionary: return _counts.duplicate()

func _spawn() -> void:
	assert(OS.has_feature("threads") and not Profiler.enabled, "a worker needs threads and no profiler")
	_install_logger()
	_thread = Thread.new()
	_thread.start(_run_worker)
	_threads.append(self)
	var began: int = Time.get_ticks_msec()
	var running: bool = _started.try_wait()
	while not running and Time.get_ticks_msec() - began < WAIT_MSEC:
		OS.delay_usec(200)
		running = _started.try_wait()
	_note_wait(began)
	if not running: _abandon("stall: worker did not start")

static func _install_logger() -> void:
	if _logger != null or not OS.is_debug_build(): return
	_logger = PumpLogger.new()
	OS.add_logger(_logger)

static func _reap_abandoned() -> void:
	for pump: RefCounted in _threads.duplicate(): pump.call("_reap")

func _reap() -> void:
	if _abandoned and _worker_gone(): _join()

func _stamp_drained(read: Array[Dictionary]) -> void:
	var now: int = Time.get_ticks_usec()
	for row: Dictionary in read:
		if _stats.jobs.size() >= TIMING_CAP: return
		_stats.jobs.append({"tag": row.tag, "job_usec": row.ended - row.began, "handoff_usec": row.ended - row.stepped, "age_usec": now - row.published})

func _note_wait(began: int) -> void:
	var waited: int = Time.get_ticks_msec() - began
	_stats.wait_count += 1
	_stats.wait_total += waited
	_stats.wait_max = maxi(_stats.wait_max, waited)

func _run_worker() -> void:
	_owner_id = OS.get_thread_caller_id()
	_started.post()
	while _run_next(): pass

func _run_next() -> bool:
	_work.wait()
	_mutex.lock()
	if _quit or _queue.is_empty():
		_exited = _quit
		_mutex.unlock()
		return not _exited
	var entry: RefCounted = _queue.pop_front()
	_mutex.unlock()
	if entry is Query: return _answer(entry)
	var job: Job = entry
	var slot := Slot.new()
	_timing = {"began": Time.get_ticks_usec(), "tag": "snapshot+digest" if job.want_digest else "plain"}
	var note: Note = _run_owned(job, slot)
	_timing.ended = Time.get_ticks_usec()
	if note != null: _wait_gate("before_publish")
	return _publish(note, slot)

func _answer(asked: Query) -> bool:
	_timing = {}
	asked.note = _run_owned(asked.job, null)
	_mutex.lock()
	if asked.note == null:
		if _marker.is_empty(): _marker = "query"
		_unpublished -= _drop_waiting()
		_exited = true
	_mutex.unlock()
	asked.reply.post()
	return asked.note != null

# Under the lock: forgets the waiting entries, answers any query among them with null, returns how many jobs it dropped.
func _drop_waiting() -> int:
	var dropped: int = 0
	for entry: RefCounted in _queue:
		if entry is Query: (entry as Query).reply.post()
		else: dropped += 1
	_queue.clear()
	return dropped

func _publish(note: Note, slot: Slot) -> bool:
	_mutex.lock()
	if note == null:
		if _marker.is_empty(): _marker = "post"
		_unpublished -= _drop_waiting() + 1
		_exited = true
		_mutex.unlock()
		return false
	_notes.append(note)
	_wait_gate("inside_publish")
	_ready = slot
	if _unread.size() < TIMING_CAP:
		_timing.published = Time.get_ticks_usec()
		_unread.append(_timing)
	_unpublished -= 1
	_mutex.unlock()
	return true

func _wait_gate(where: String) -> void:
	if _gate == null or _gate_where != where: return
	var end: int = Time.get_ticks_msec() + 2 * WAIT_MSEC
	while not _gate.try_wait() and Time.get_ticks_msec() < end: OS.delay_usec(200)

func _post_queued(job: Job) -> bool:
	_mutex.lock()
	var marker: String = _marker
	var room: bool = marker.is_empty() and _unpublished < _cap()
	if room:
		_queue.append(job)
		_unpublished += 1
	var depth: int = _unpublished
	_mutex.unlock()
	if not marker.is_empty(): _fail(marker)
	if not room: return false
	_work.post()
	_stats.accepted += 1
	_stats.depth_max = maxi(_stats.depth_max, depth)
	if depth == _cap(): _stats.cap_hits += 1
	if depth == 1: _set_stall_clock()
	return true

# Main blocks here, so the worker is the only other thread and the queue holds at most this one query.
func _query_worker(job: Job) -> Note:
	var asked := Query.new(job)
	_mutex.lock()
	var marker: String = _marker
	if marker.is_empty(): _queue.append(asked)
	_mutex.unlock()
	if not marker.is_empty():
		_fail(marker)
		return null
	_work.post()
	var began: int = Time.get_ticks_msec()
	var answered: bool = asked.reply.try_wait()
	while not answered and Time.get_ticks_msec() - began < WAIT_MSEC:
		OS.delay_usec(200)
		answered = asked.reply.try_wait()
	_note_wait(began)
	if not answered:
		_abandon("stall: query waited %d ms" % WAIT_MSEC)
		return null
	if asked.note == null and not _read_marker().is_empty(): _fail(_read_marker())
	return asked.note

func _read_marker() -> String:
	_mutex.lock()
	var marker: String = _marker
	_mutex.unlock()
	return marker

func _set_stall_clock() -> void:
	_stall_frame = frame_source.call()
	_stall_msec = clock.call()

# Runs after drain took its notes, outside the lock.
func _watch(took: int, unpublished: int) -> void:
	if _thread == null or _abandoned or unpublished == 0 or not _failure.is_empty(): return
	if took > 0:
		_set_stall_clock()
		return
	if not _thread.is_alive(): _set_failure("dead thread")
	elif int(frame_source.call()) >= _stall_frame + STALL_FRAMES and int(clock.call()) >= _stall_msec + STALL_MSEC:
		_abandon("stall: job at tick %d ran over %d frames" % [_current.tick + 1, STALL_FRAMES])

# The worker may still own the simulation, so nothing reads it again and the thread is never joined.
func _abandon(cause: String) -> void:
	_mutex.lock()
	_quit = true
	_mutex.unlock()
	_work.post()
	_set_failure(cause)
	_abandoned = true

func _worker_gone() -> bool:
	_mutex.lock()
	var gone: bool = _exited
	_mutex.unlock()
	return gone or not _thread.is_alive()

func _join() -> void:
	_thread.wait_to_finish()
	_thread = null
	_threads.erase(self)
	_owner_id = OS.get_thread_caller_id()

func stop() -> void:
	_stopped = true
	if _thread == null or _abandoned: return
	_mutex.lock()
	_quit = true
	_unpublished -= _drop_waiting()
	_mutex.unlock()
	_work.post()
	var began: int = Time.get_ticks_msec()
	while not _worker_gone() and Time.get_ticks_msec() - began < WAIT_MSEC: OS.delay_usec(200)
	_note_wait(began)
	if _worker_gone(): _join()
	else: _abandon("stall: stop waited %d ms" % WAIT_MSEC)

func live() -> Simulation:
	assert(not busy() and not _abandoned, "live() while a worker may own the simulation")
	return _sim

# The one place a job runs: on its owner thread, and a worker's job must log no error; either failure becomes a marker, not a note.
func _run_owned(job: Job, slot: Slot) -> Note:
	var id: int = OS.get_thread_caller_id()
	if id != _owner_id:
		push_error("sim pump job ran on thread %d, owner is %d" % [id, _owner_id])
		_set_marker("owner thread")
		return null
	var watched: bool = _thread != null and _logger != null
	var before: int = _logger.count_for(id) if watched else 0
	var note: Note = _note_for(job, slot)
	if watched and note != null and _logger.count_for(id) > before:
		_set_marker("fault")
		return null
	return note

func _set_marker(cause: String) -> void:
	_mutex.lock()
	if _marker.is_empty(): _marker = cause
	_mutex.unlock()

func _note_for(job: Job, slot: Slot) -> Note:
	return run_job(_sim, _recorder, job, slot, _timing)

static func _warm_reach(id: String) -> void:
	if not CombatDefinitions.weapon(CombatDefinitions.profile(id).get("weapon", "")).is_empty(): Combat.reach_of(id)

static func _warmers() -> Dictionary:
	return {"unit": Registry.unit_view, "building": Registry.building_view, "profile": Registry.profile_view, "radius": CombatDefinitions.radius, "reach": _warm_reach}

func _warm_and_freeze() -> void:
	var warmers: Dictionary = _warmers()
	for name: String in Registry.cache_names():
		for id: String in Registry.units() + Registry.buildings(): warmers[name].call(id)
	Registry.freeze_caches()
	Skirmish.freeze_map()

# A shot's building target may be gone by the next displayed view; its row travels with the shot.
static func _attach_targets(events: Array[Dictionary], buildings: Array) -> void:
	var rows: Dictionary = {}
	for building: Dictionary in buildings: rows[building.id] = building
	for event: Dictionary in events:
		if event.type == "shot" and rows.has(event.target_id): event.target_building = rows[event.target_id]

static func run_job(sim: Simulation, command_recorder: CommandRecorder, job: Job, slot: Slot, timing: Dictionary = {}) -> Note:
	var note := Note.new()
	for payload: Dictionary in job.commands:
		var command: Dictionary = payload.duplicate(true)
		if not command.has("tick"): command.tick = sim.tick()
		if job.stamp_sequence and not command.has("sequence"): command.sequence = sim.last_sequence(command.player) + 1
		var result: Dictionary = command_recorder.issue_command(command)
		note.issued.append({"command": command, "ok": result.ok, "error": result.error})
	var planner: RefCounted = PlanRecorder.new(sim) if job.plan_bots else command_recorder
	var recorded: int = planner.commands().size()
	Skirmish.issue_opponents(planner, job.bots)
	note.bot_commands.assign(planner.commands().slice(recorded).duplicate(true))
	if job.step: sim.step()
	timing.stepped = Time.get_ticks_usec()
	note.events = sim.combat_events().duplicate(true)
	note.results = sim.command_results().duplicate(true)
	if not job.preview.is_empty():
		var request: Dictionary = job.preview
		var preview: Dictionary = sim.preview_build(request.player, request.builder_id, request.kind, request.origin)
		note.preview = {"kind": request.kind, "origin": request.origin, "ok": preview.ok, "error": preview.error, "tick": sim.tick()}
	if job.want_digest:
		note.snapshot = sim.snapshot()
		note.digest = StateHash.digest(note.snapshot)
	if job.want_ring: note.ring = sim.hash_ring()
	if job.want_tick_hash: note.tick_hash = sim.tick_hash()
	if job.want_log: note.log.assign(command_recorder.commands().duplicate(true))
	if job.want_bot_lines: note.bot_lines = Skirmish.debug_lines(sim, job.bots)
	if slot != null:
		slot.tick = sim.tick()
		slot.view = sim.view_state()
		_attach_targets(note.events, slot.view.buildings)
	note.over = sim.match_over()
	note.survivors = sim.survivors()
	note.tick = sim.tick()
	note.stats = sim.match_stats()
	return note
