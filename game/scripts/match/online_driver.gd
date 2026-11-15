extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const CATCH_UP_STEPS: int = 2
const MAX_CATCH_UP_CREDIT: int = 4
const DESYNC_DIR: String = "user://desync"
const LATENCY_FILE: String = "user://netplay-latency.txt"

var sim: Simulation
var web: bool = OS.has_feature("web")
var download: Callable = JavaScriptBridge.download_buffer
var _transport: RefCounted
var _lockstep: RefCounted
var _own_faction: String
var _map_path: String = ""
var _starts: Array[int] = []
var _seed: int = 0
var _report_path: String = ""
var _finished: bool = false
var _credit: int = 0
var _rejections_seen: int = 0
var _log_seen: int = 0
var _step_results: Array = []
var _seat: int
var _phase: String = "playing"
var _friend_again: bool = false
var _rematch_seed: int = -1

func _init(transport: RefCounted, lockstep: RefCounted, faction: String, seat: int) -> void:
	_transport = transport
	_own_faction = faction
	_seat = seat
	_own(lockstep)

func _own(lockstep: RefCounted) -> void:
	_lockstep = lockstep
	_lockstep.session_handler = _on_session

func _on_session(message: Dictionary) -> bool:
	if message.type == "again" and message.get("seat", _seat) != _seat:
		_friend_again = true
		return true
	if message.type != "start" or _phase != "again": return false
	_own(Lockstep.for_start(_seat, message))
	_rematch_seed = message.seed
	_phase = "playing"
	return true

func create(map_path: String, starts: Array[int], _factions: Dictionary, match_seed: int) -> void:
	_map_path = map_path
	_starts = starts
	_seed = match_seed
	_finished = false
	_friend_again = false
	_rejections_seen = 0
	_log_seen = 0
	_credit = 0
	sim = Skirmish.create(true, "human", {}, map_path, starts)

func start() -> void:
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _own_faction})
	_lockstep.start(sim.snapshot())

func detach() -> void:
	if _lockstep != null: _lockstep.send = Callable()

func leave() -> void:
	_finished = true
	_phase = "done"
	_lockstep.set_relay_lost()
	_transport.close()

func step(after_tick: Callable) -> Array[Dictionary]:
	for text: Variant in _transport.poll(): _lockstep.receive(text)
	if not _finished and (_transport.closed() or _transport.silent(Time.get_ticks_usec())): _lockstep.set_relay_lost()
	_credit = mini(_credit + 1, MAX_CATCH_UP_CREDIT)
	_step_results = []
	for i in CATCH_UP_STEPS:
		if _credit < 1 or not _lockstep.advance(sim): break
		_credit -= 1
		after_tick.call()
		_step_results.append_array(sim.command_results().duplicate(true))
		var tick: int = sim.tick()
		_lockstep.finish_tick(tick, sim.snapshot() if _lockstep.wants_snapshot(tick) else null)
	if _phase == "playing" and _lockstep.received_any(): _transport.patient = false
	var answers: Array[Dictionary] = _new_answers()
	if not _finished and (sim.match_over() or _ended()): _finish()
	if (_phase == "over" or _phase == "again") and _room_gone(): _close_room()
	return answers

func _ended() -> bool:
	return _lockstep.status().begins_with("ended")

func _room_gone() -> bool:
	return _transport.closed() or _transport.silent(Time.get_ticks_usec()) or _lockstep.left_seat() != 0 or _ended()

func _close_room() -> void:
	if not _ended() and _lockstep.left_seat() == 0: _lockstep.set_relay_lost()
	_transport.close()
	_phase = "done"

func step_results() -> Array:
	return _step_results

func _new_answers() -> Array[Dictionary]:
	var errors: Dictionary = {}
	var rejections: Array = _lockstep.rejections()
	for i in range(_rejections_seen, rejections.size()): errors[rejections[i].sequence] = rejections[i].error
	_rejections_seen = rejections.size()
	var answers: Array[Dictionary] = []
	var played: Array = _lockstep.command_log()
	for i in range(_log_seen, played.size()):
		var command: Dictionary = played[i]
		if command.player != _seat or command.type == "choose_faction": continue
		answers.append({"command": command, "ok": not errors.has(command.sequence), "error": errors.get(command.sequence, "")})
		errors.erase(command.sequence)
	_log_seen = played.size()
	# Injected rejections (tests, a refused faction choice) have no logged command of ours.
	for sequence: Variant in errors: answers.append({"command": {}, "ok": false, "error": errors[sequence]})
	return answers

func submit(payload: Dictionary) -> Dictionary:
	_lockstep.submit(payload)
	return {"ok": true, "error": ""}

func pauses_sim() -> bool:
	return false

func closes_placement_on_click() -> bool:
	return true

func confirm_leave() -> bool:
	return true

func can_restart() -> bool:
	return false

func rematch_line() -> String:
	if _lockstep.left_seat() != 0: return "Your friend left"
	if _phase == "done": return "The room closed"
	if _friend_again: return "Your friend wants to play again"
	return "Waiting for your friend…" if _phase == "again" else ""

func can_play_again() -> bool:
	return _phase == "over"

func play_again() -> void:
	if _phase != "over": return
	_transport.send_text(Wire.encode({"type": "again"}))
	_phase = "again"

func take_rematch() -> int:
	var match_seed: int = _rematch_seed
	_rematch_seed = -1
	if match_seed < 0: return -1
	if _room_gone():
		_close_room()
		return -1
	return match_seed

func over() -> bool:
	return _finished

func match_log() -> Dictionary:
	var seats: Array = sim.view_state().players.map(func(player: Dictionary) -> String: return player.get("faction", ""))
	return {"mode": "online", "factions": seats, "commands": Lockstep.log_lines(_lockstep.command_log())}

func _finish() -> void:
	_finished = true
	if _lockstep.status() == "ended_desync": _report_path = _write_report()
	_write_latency()
	if not _ended():
		_transport.patient = true
		_transport.send_text(Wire.encode({"type": "over"}))
		_phase = "over"
		return
	_transport.close()
	_phase = "done"

func _write_report() -> String:
	var report: Dictionary = _report()
	var file_name: String = "desync-seat%d.json" % report.seat
	if web:
		download.call(JSON.stringify(report, "", true, true).to_utf8_buffer(), file_name, "application/json")
		return file_name
	DirAccess.make_dir_recursive_absolute(DESYNC_DIR)
	var path: String = "%s/%s" % [DESYNC_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(JSON.stringify(report, "", true, true))
	file.close()
	return ProjectSettings.globalize_path(path)

func _report() -> Dictionary:
	var report: Dictionary = _lockstep.desync_report(sim)
	report.merge(MatchSettings.report_fields(_map_path.get_file().get_basename(), _seed, _starts))
	return report

func net_line() -> String:
	var latency: Dictionary = TimingStats.summary(_ms(_lockstep.latency_samples()))
	var rtt: Dictionary = TimingStats.summary(_ms(_transport.rtt_samples()))
	return "Cmd latency p95 %.0f ms | RTT p95 %.0f ms" % [latency.p95, rtt.p95]

func _write_latency() -> void:
	var line: String = latency_line()
	print(line)
	var file := FileAccess.open(LATENCY_FILE, FileAccess.WRITE)
	if file == null: return
	file.store_string(line + "\n")
	file.close()

func latency_line() -> String:
	var latency: Dictionary = TimingStats.summary(_ms(_lockstep.latency_samples()))
	var rtt: Dictionary = TimingStats.summary(_ms(_transport.rtt_samples()))
	return "NETPLAY LATENCY command n=%d p50=%.1f ms p95=%.1f ms | RTT n=%d p95=%.1f ms" % [latency.n, latency.p50, latency.p95, rtt.n, rtt.p95]

func _ms(microseconds: PackedInt64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for value in microseconds: out.append(float(value) / 1000.0)
	return out

func notice() -> String:
	match _lockstep.status():
		"waiting": return "Waiting for player %d" % _lockstep.waiting_for()[0]
		"ended_left": return "Opponent left before the start (a different map or version, or their game tab was hidden)" if _lockstep.left_before_start() else "Player %d disconnected" % _lockstep.left_seat()
		"ended_relay": return "Connection to relay lost" if _lockstep.end_reason() == "connection to relay lost" else "Relay: " + _lockstep.end_reason()
		"ended_desync": return ("Desync — report downloaded as %s" if web else "Desync — report saved to %s") % _report_path
		"ended_protocol": return "Protocol error: " + _lockstep.end_reason()
	return ""
