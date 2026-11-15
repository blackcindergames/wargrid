extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")

var sim: Simulation
var recorder: CommandRecorder
var _player: int
var _sequence: int = 0
var _factions: Dictionary = {}
var _held: Array[Dictionary] = []
var _preview_request: Dictionary = {}
var _preview_answer: Dictionary = {}

func _init(player: int) -> void:
	_player = player

func create(map_path: String, starts: Array[int], factions: Dictionary, _match_seed: int) -> void:
	_factions = factions
	_sequence = 0
	_held = []
	_preview_request = {}
	_preview_answer = {}
	recorder = null
	sim = Skirmish.create(true, "ai", factions, map_path, starts)

func start() -> void:
	pass

# Tests swap `driver.sim` directly; a recorder left on the old one would swallow commands.
func _recording() -> CommandRecorder:
	if recorder == null or not is_same(recorder.simulation(), sim): recorder = CommandRecorder.new(sim)
	return recorder

# Answers wait for the next step so offline shows them when online would.
func step(after_tick: Callable) -> Array[Dictionary]:
	Skirmish.issue_opponent(_recording())
	sim.step()
	after_tick.call()
	_answer_preview()
	var answers: Array[Dictionary] = _held
	_held = []
	return answers

func step_results() -> Array:
	return sim.command_results().duplicate(true)

# shortcut: duplicated in both drivers, SB3's run_job takes it over
func request_preview(request: Dictionary) -> void:
	_preview_request = request
	if request.is_empty(): _preview_answer = {}

func preview_answer() -> Dictionary:
	return _preview_answer

func _answer_preview() -> void:
	if _preview_request.is_empty(): return
	var request: Dictionary = _preview_request
	_preview_request = {}
	_preview_answer = {"kind": request.kind, "origin": request.origin, "ok": sim.preview_build(request.player, request.builder_id, request.kind, request.origin).ok}

func submit(payload: Dictionary) -> Dictionary:
	var command: Dictionary = payload.duplicate(true)
	command.tick = command.get("tick",sim.tick())
	command.player = _player
	command.sequence = _sequence
	var result: Dictionary = _recording().issue_command(command)
	if result.ok: _sequence += 1
	_held.append({"command": command, "ok": result.ok, "error": result.error})
	return {"ok": true, "error": ""}

func notice() -> String:
	return ""

func pauses_sim() -> bool:
	return true

func closes_placement_on_click() -> bool:
	return false

func confirm_leave() -> bool:
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
	return sim.match_over()

func leave() -> void:
	pass

func detach() -> void:
	pass

func match_log() -> Dictionary:
	return {"mode": "offline", "factions": [_factions[1], _factions[2]], "commands": Lockstep.log_lines(_recording().commands())}
