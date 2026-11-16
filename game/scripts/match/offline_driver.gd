extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const BOTS: Array[int] = [2]

var pump: SimPump
# shortcut: test bridge, Task 6 removes it
var sim: Simulation:
	get: return pump.live()
	set(value): adopt(value)
# shortcut: test bridge, Task 6 removes it
var recorder: CommandRecorder:
	get: return pump.recorder()
var first_note: SimPump.Note
var _player: int
var _factions: Dictionary = {}
var _queue: Array[Dictionary] = []
var _flushed: Array[Dictionary] = []
var _answers: Array[Dictionary] = []
var _last: SimPump.Note
var _preview_request: Dictionary = {}
var _preview_answer: Dictionary = {}

func _init(player: int) -> void:
	_player = player

func create(map_path: String, starts: Array[int], factions: Dictionary, _match_seed: int) -> void:
	_factions = factions
	adopt(Skirmish.create(true, "ai", factions, map_path, starts))

func adopt(value: Simulation) -> void:
	if pump != null: pump.stop()
	value.set_hash_ring(false)
	pump = SimPump.new(value)
	first_note = pump.start()
	_last = first_note
	_queue = []
	_flushed = []
	_answers = []
	_preview_request = {}
	_preview_answer = {}

func start() -> void:
	pass

func step() -> void:
	# A finished match would otherwise re-copy its last results every frame.
	if over() and _queue.is_empty() and _preview_request.is_empty(): return
	var job := SimPump.Job.new()
	job.commands = _queue
	job.bots = BOTS
	job.preview = _preview_request
	_queue = []
	_preview_request = {}
	pump.post(job)

func drain() -> Array[SimPump.Note]:
	var notes: Array[SimPump.Note] = pump.drain()
	if notes.is_empty(): return notes
	# Flushed answers wait for the next job so a paused or idle drain does not hand them out early.
	_answers.append_array(_flushed)
	_flushed = []
	for note: SimPump.Note in notes:
		_answers.append_array(note.issued)
		if not note.preview.is_empty(): _preview_answer = note.preview
	_last = notes[-1]
	return notes

func take_answers() -> Array[Dictionary]:
	var answers: Array[Dictionary] = _answers
	_answers = []
	return answers

func queued() -> Array[Dictionary]:
	return _queue

func flush() -> void:
	if _queue.is_empty(): return
	var job := SimPump.Job.new()
	job.commands = _queue
	job.step = false
	_queue = []
	var note: SimPump.Note = pump.query(job)
	_flushed.append_array(note.issued)

func current() -> SimPump.Slot:
	return pump.current()

func record() -> Dictionary:
	var job := SimPump.Job.new()
	job.step = false
	job.want_digest = true
	var note: SimPump.Note = pump.query(job)
	return {"tick": note.tick, "digest": note.digest, "match": note.snapshot.match}

func match_stats() -> Array[Dictionary]:
	return _last.stats

func request_preview(request: Dictionary) -> void:
	_preview_request = request
	if request.is_empty(): _preview_answer = {}

func preview_answer() -> Dictionary:
	return _preview_answer

func submit(payload: Dictionary) -> Dictionary:
	var command: Dictionary = payload.duplicate(true)
	command.player = _player
	_queue.append(command)
	return {"ok": true, "error": ""}

func notice() -> String:
	return ""

func pauses_sim() -> bool:
	return true

func closes_placement_on_click() -> bool:
	return false

func confirm_leave() -> bool:
	return false

func opponent_left() -> bool:
	return false

func rematch_pending() -> bool:
	return false

func friend_wants_rematch() -> bool:
	return false

func rematch_line() -> String:
	return ""

func can_play_again() -> bool:
	return true

func play_again() -> void:
	pass

func take_rematch() -> int:
	return -1

func can_restart() -> bool:
	return true

func over() -> bool:
	return _last.over

func leave() -> void:
	pass

func detach() -> void:
	pass

# shortcut: reads the pump's recorder on the caller so log and record() share one state; SB5 moves it into the record query
func match_log() -> Dictionary:
	return {"mode": "offline", "factions": [_factions[1], _factions[2]], "commands": Lockstep.log_lines(pump.recorder().commands())}
