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

const MAX_QUEUED: int = 3
const STALL_FRAMES: int = 90
const STALL_MSEC: int = 3000
const WAIT_MSEC: int = 5000

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
var _queue: Array[Job] = []
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

# A failed pump turns every later pump inline for the rest of the process.
static var _latched: bool = false
static var _forced: String = ""
# Pumps whose thread is started and not joined, abandoned ones included; the reference keeps a running pump alive.
static var _threads: Array[RefCounted] = []

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
	var note: Note = _note_for(job, _current)
	var map: Dictionary = _sim.map_data()
	if not map.is_empty():
		for player: Dictionary in _current.view.players: note.starts[player.id] = MapData.start_cell(map, player.id)
	if _mode == "worker": _spawn()
	return note

func post(job: Job) -> bool:
	if _stopped or not _failure.is_empty(): return false
	if _mode == "worker": return _post_queued(job)
	var slot := Slot.new()
	var note: Note = _note_for(job, slot)
	if note == null:
		_fail("post")
		return false
	_stats.accepted += 1
	_notes.append(note)
	_ready = slot
	return true

func drain() -> Array[Note]:
	_mutex.lock()
	var notes: Array[Note] = _notes
	_notes = []
	if _ready != null:
		_previous = _current
		_current = _ready
		_ready = null
	var marker: String = _marker
	var unpublished: int = _unpublished
	_mutex.unlock()
	if not marker.is_empty(): _fail(marker)
	else: _watch(notes.size(), unpublished)
	return notes

func current() -> Slot:
	return _current

func previous() -> Slot:
	return _previous

func query(job: Job) -> Note:
	var note: Note = _note_for(job, null)
	if note == null: _fail("query")
	return note

func record() -> Dictionary:
	if _failure.is_empty():
		var job := Job.new()
		job.step = false
		job.want_digest = true
		job.want_log = true
		var note: Note = query(job)
		if note != null: return {"tick": note.tick, "digest": note.digest, "match": note.snapshot.match, "commands": note.log}
	# A failed simulation cannot be trusted for a digest, so the record keeps what was last shown.
	return {"tick": _current.tick, "digest": "", "match": _current.view.match, "commands": _recorder.commands().duplicate(true)}

func failure() -> String:
	return _failure

func mode() -> String:
	return _mode

static func _switch_on() -> bool:
	return OS.get_environment("WARGRID_SIM_THREAD") == "1" and OS.has_feature("threads")

static func worker_wanted() -> bool:
	return _switch_on() and not _latched

static func _mode_for() -> String:
	if not _forced.is_empty(): return _forced
	if worker_wanted(): return "worker"
	return "inline-fallback" if _switch_on() else "inline"

static func force_mode_for_test(forced: String) -> void:
	_forced = forced

static func reset_process_latch_for_test() -> void:
	_latched = false

func _fail(kind: String) -> void:
	_set_failure("%s job returned no note after tick %d" % [kind, _current.tick])

func _set_failure(reason: String) -> void:
	_latched = true
	if _failure.is_empty(): _failure = reason

static func _zero_stats() -> Dictionary:
	return {"accepted": 0, "room_refusals": 0, "streak": 0, "streak_max": 0, "depth_max": 0, "cap_hits": 0, "wait_count": 0, "wait_total": 0, "wait_max": 0}

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
	}

func reset_queue_stats() -> void:
	_stats = _zero_stats()
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

static func pump_counts() -> Dictionary: return {}

func _spawn() -> void:
	assert(OS.has_feature("threads") and not Profiler.enabled, "a worker needs threads and no profiler")
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

static func _reap_abandoned() -> void:
	for pump: RefCounted in _threads.duplicate(): pump.call("_reap")

func _reap() -> void:
	if _abandoned and _worker_gone(): _join()

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
	var job: Job = _queue.pop_front()
	_mutex.unlock()
	var slot := Slot.new()
	var note: Note = _note_for(job, slot)
	if note != null: _wait_gate("before_publish")
	return _publish(note, slot)

func _publish(note: Note, slot: Slot) -> bool:
	_mutex.lock()
	if note == null:
		_marker = "post"
		_unpublished -= _queue.size() + 1
		_queue.clear()
		_exited = true
		_mutex.unlock()
		return false
	_notes.append(note)
	_wait_gate("inside_publish")
	_ready = slot
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
	_unpublished -= _queue.size()
	_queue.clear()
	_mutex.unlock()
	_work.post()
	var began: int = Time.get_ticks_msec()
	while not _worker_gone() and Time.get_ticks_msec() - began < WAIT_MSEC: OS.delay_usec(200)
	_note_wait(began)
	if _worker_gone(): _join()
	else: _abandon("stall: stop waited %d ms" % WAIT_MSEC)

func live() -> Simulation:
	return _sim

func _note_for(job: Job, slot: Slot) -> Note:
	return run_job(_sim, _recorder, job, slot)

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

static func run_job(sim: Simulation, command_recorder: CommandRecorder, job: Job, slot: Slot) -> Note:
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
