extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const BOTS: Array[int] = [2]
const FREEZE_NOTICE := "Match stopped"
const HASH_EVERY: int = 30
const BOT_LINES_EVERY: int = 30

var pump: SimPump
var show_bots: bool = false:
	set(value):
		show_bots = value
		if not value: _bot_lines = PackedStringArray()
var first_note: SimPump.Note
var _player: int
var _factions: Dictionary = {}
var _queue: Array[Dictionary] = []
var _flushed: Array[Dictionary] = []
var _answers: Array[Dictionary] = []
var _last: SimPump.Note
var _preview_request: Dictionary = {}
var _preview_answer: Dictionary = {}
var _failure: String = ""
var _next_tick: int = 0
var _tick_hashes := PackedStringArray()
var _bot_lines := PackedStringArray()
# printerr, not push_error: the test runner fails the suite on ERROR lines.
var log_error: Callable = func(line: String) -> void: printerr(line)

func _init(player: int) -> void:
	_player = player

func create(map_path: String, starts: Array[int], factions: Dictionary, _match_seed: int) -> void:
	_factions = factions
	adopt(Skirmish.create(true, "human", factions, map_path, starts))

func adopt(value: Simulation) -> void:
	if pump != null: pump.stop()
	value.set_hash_ring(false)
	pump = SimPump.new(value)
	first_note = pump.start()
	_last = first_note
	_next_tick = first_note.tick
	_tick_hashes = PackedStringArray()
	_bot_lines = PackedStringArray()
	_queue = []
	_flushed = []
	_answers = []
	_preview_request = {}
	_preview_answer = {}
	_failure = ""

func start() -> void:
	pass

func step() -> void:
	# A finished match would otherwise re-copy its last results every frame.
	if over() and _queue.is_empty() and _preview_request.is_empty(): return
	var job := SimPump.Job.new()
	job.commands = _queue
	job.bots = BOTS
	job.preview = _preview_request
	job.stamp_sequence = true
	job.want_tick_hash = (_next_tick + 1) % HASH_EVERY == 0
	job.want_bot_lines = show_bots and (_next_tick + 1) % BOT_LINES_EVERY == 0
	if not pump.post(job):
		_read_failure()
		return
	_next_tick += 1
	_queue = []

func drain() -> Array[SimPump.Note]:
	var notes: Array[SimPump.Note] = pump.drain()
	if notes.is_empty(): return notes
	# Flushed answers wait for the next job so a paused or idle drain does not hand them out early.
	_answers.append_array(_flushed)
	_flushed = []
	for note: SimPump.Note in notes:
		_answers.append_array(note.issued)
		if not note.preview.is_empty(): _preview_answer = note.preview
		if show_bots and not note.bot_lines.is_empty(): _bot_lines = note.bot_lines
		# A post after the end leaves the tick standing; only a note whose tick moved is a row.
		if not note.tick_hash.is_empty() and note.tick > _last.tick: _tick_hashes.append("%d\t%s" % [note.tick, note.tick_hash])
		_last = note
	return notes

func bot_line() -> String:
	return "\n".join(_bot_lines)

func take_answers() -> Array[Dictionary]:
	var answers: Array[Dictionary] = _answers
	_answers = []
	return answers

func queued() -> Array[Dictionary]:
	return _queue

func flush() -> void:
	if _queue.is_empty() or not _failure.is_empty(): return
	var job := SimPump.Job.new()
	job.commands = _queue
	job.step = false
	job.stamp_sequence = true
	_queue = []
	var note: SimPump.Note = pump.query(job)
	if note == null:
		_queue = job.commands
		_read_failure()
		return
	_flushed.append_array(note.issued)

func current() -> SimPump.Slot:
	return pump.current()

func record() -> Dictionary:
	var played: Dictionary = pump.record()
	_read_failure()
	played.tick_hashes = _tick_hashes.duplicate()
	return played

func failure() -> String:
	return _failure

func _read_failure() -> void:
	var reason: String = pump.failure()
	if reason.is_empty() or not _failure.is_empty(): return
	_failure = reason
	log_error.call("SIM PUMP FAILED " + _failure)

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
	return FREEZE_NOTICE if not _failure.is_empty() else ""

func pauses_sim() -> bool:
	return true

func closes_placement_on_click() -> bool:
	return false

func confirm_leave() -> bool:
	return false

func leave_heading() -> String:
	return ""

func leave_question() -> String:
	return ""

func quit_question() -> String:
	return ""

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

func teammate() -> int:
	return 0

func bot_players() -> Array[int]:
	return BOTS

func take_rematch() -> int:
	return -1

func can_restart() -> bool:
	return true

func over() -> bool:
	return _last.over

func leave() -> void:
	pass

func stop() -> void:
	pump.stop()

func detach() -> void:
	pass

func match_header() -> Dictionary:
	return {"mode": "offline", "factions": [_factions[1], _factions[2]], "teams": [1, 2], "bots": []}

func match_log() -> Dictionary:
	var played: Dictionary = pump.record()
	_read_failure()
	var logged: Dictionary = match_header().merged({"commands": Lockstep.log_lines(played.commands)})
	if not _failure.is_empty(): logged.end = "sim pump failed: " + _failure
	return logged
