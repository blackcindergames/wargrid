extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")

class Job:
	var commands: Array[Dictionary] = []
	var bots: Array[int] = []
	var step: bool = true
	var want_digest: bool = false
	var preview: Dictionary = {}

class Note:
	var done: bool = true
	var tick: int = 0
	var over: bool = false
	var events: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	var issued: Array[Dictionary] = []
	var bot_commands: Array[Dictionary] = []
	var snapshot: Dictionary = {}
	var digest: String = ""
	var preview: Dictionary = {}
	var starts: Dictionary = {}
	var stats: Array[Dictionary] = []

class Slot:
	var tick: int = 0
	var view: Dictionary = {}

var _sim: Simulation
var _recorder: CommandRecorder
var _notes: Array[Note] = []
var _write := Slot.new()
var _ready := Slot.new()
var _current: Slot
var _previous: Slot
var _published: bool = false
var _stopped: bool = false

func _init(sim: Simulation) -> void:
	_sim = sim
	_recorder = CommandRecorder.new(sim)

func start() -> Note:
	var job := Job.new()
	job.step = false
	var note: Note = run_job(_sim, _recorder, job, _write)
	_publish()
	_rotate()
	var map: Dictionary = _sim.map_data()
	if not map.is_empty():
		for player: Dictionary in _current.view.players: note.starts[player.id] = MapData.start_cell(map, player.id)
	return note

func post(job: Job) -> bool:
	if _stopped: return false
	_notes.append(run_job(_sim, _recorder, job, _write))
	_publish()
	return true

func drain() -> Array[Note]:
	var notes: Array[Note] = _notes
	_notes = []
	if _published: _rotate()
	return notes

func current() -> Slot:
	return _current

func previous() -> Slot:
	return _previous

func query(job: Job) -> Note:
	return run_job(_sim, _recorder, job, null)

func busy() -> bool:
	return false

func stop() -> void:
	_stopped = true

func live() -> Simulation:
	return _sim

func recorder() -> CommandRecorder:
	return _recorder

func _publish() -> void:
	var written: Slot = _write
	_write = _ready
	_ready = written
	_published = true

func _rotate() -> void:
	var free: Slot = _previous if _previous != null else Slot.new()
	_previous = _current
	_current = _ready
	_ready = free
	_published = false

static func run_job(sim: Simulation, command_recorder: CommandRecorder, job: Job, slot: Slot) -> Note:
	var note := Note.new()
	for payload: Dictionary in job.commands:
		var command: Dictionary = payload.duplicate(true)
		if not command.has("tick"): command.tick = sim.tick()
		if not command.has("sequence"): command.sequence = sim.last_sequence(command.player) + 1
		var result: Dictionary = command_recorder.issue_command(command)
		note.issued.append({"command": command, "ok": result.ok, "error": result.error})
	var recorded: int = command_recorder.commands().size()
	Skirmish.issue_opponents(command_recorder, job.bots)
	note.bot_commands.assign(command_recorder.commands().slice(recorded).duplicate(true))
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
	if slot != null:
		slot.tick = sim.tick()
		slot.view = sim.view_state()
	note.over = sim.match_over()
	note.tick = sim.tick()
	note.stats = sim.match_stats()
	return note
