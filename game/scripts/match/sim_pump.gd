extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")

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

func _init(sim: Simulation) -> void:
	_sim = sim
	_recorder = CommandRecorder.new(sim)

func start() -> Note:
	_warm_and_freeze()
	var job := Job.new()
	job.step = false
	_current = Slot.new()
	var note: Note = _note_for(job, _current)
	var map: Dictionary = _sim.map_data()
	if not map.is_empty():
		for player: Dictionary in _current.view.players: note.starts[player.id] = MapData.start_cell(map, player.id)
	return note

func post(job: Job) -> bool:
	if _stopped or not _failure.is_empty(): return false
	var slot := Slot.new()
	var note: Note = _note_for(job, slot)
	if note == null:
		_fail("post")
		return false
	_notes.append(note)
	_ready = slot
	return true

func drain() -> Array[Note]:
	var notes: Array[Note] = _notes
	_notes = []
	if _ready != null:
		_previous = _current
		_current = _ready
		_ready = null
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

func _fail(kind: String) -> void:
	if _failure.is_empty(): _failure = "%s job returned no note after tick %d" % [kind, _current.tick]

func busy() -> bool:
	return false

func stop() -> void:
	_stopped = true

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
