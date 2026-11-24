extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const ResultPanel = preload("res://scripts/match/result_panel.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CATCH_UP_STEPS: int = 2
const MAX_CATCH_UP_CREDIT: int = 4
const DESYNC_DIR: String = "user://desync"
const LATENCY_FILE: String = "user://netplay-latency.txt"
const TOO_MANY_ORDERS: String = "Too many orders at once; wait a moment"
const START_LINE_TICKS: int = 150
const HOST_LEFT: String = "The host left. The match is over."
const RELAY_LOST: String = "Connection to relay lost"

var pump: SimPump
var first_note: SimPump.Note
var _last: SimPump.Note
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
var _left: bool = false
var _stopped: bool = false
var _credit: int = 0
var _rejections_seen: int = 0
var _log_seen: int = 0
var _answers: Array[Dictionary] = []
var _pings: Array[Dictionary] = []
var _preview_request: Dictionary = {}
var _preview_answer: Dictionary = {}
var _seat: int
var _phase: String = "playing"
var _friend_again: bool = false
var _rematch_seed: int = -1
var _taken: Array[int] = []
var _next_tick: int = 0
var _start_tick: int = -1

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

func create(map_path: String, starts: Array[int], factions: Dictionary, match_seed: int) -> void:
	_map_path = map_path
	_starts = starts
	_seed = match_seed
	_finished = false
	_friend_again = false
	_rejections_seen = 0
	_log_seen = 0
	_credit = 0
	var bots: Array[int] = _lockstep.bots()
	var bot_factions := {}
	for bot: int in bots:
		if factions.has(bot): bot_factions[bot] = factions[bot]
	adopt(Skirmish.create(true, "human", bot_factions, map_path, starts, _lockstep.seat_ids().size() + bots.size(), teams()))

func adopt(value: Simulation) -> void:
	if pump != null: pump.stop()
	_stopped = false
	pump = SimPump.new(value)
	first_note = pump.start()
	_last = first_note
	_next_tick = first_note.tick
	_taken = []
	_start_tick = -1
	_answers = []
	_pings = []
	_preview_request = {}
	_preview_answer = {}

func start() -> void:
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _own_faction})
	var job := SimPump.Job.new()
	job.step = false
	job.want_digest = true
	var note: SimPump.Note = pump.query(job)
	_lockstep.start(note.snapshot, note.digest)

func stop() -> void:
	_stopped = true
	pump.stop()

func detach() -> void:
	if _lockstep != null: _lockstep.send = Callable()

func leave() -> void:
	_left = true
	_finished = true
	_phase = "done"
	_lockstep.set_relay_lost()
	_transport.close()

func step() -> void:
	for text: Variant in _transport.poll(): _lockstep.receive(text)
	if not _finished and _transport.refused(): _lockstep.set_send_refused()
	if not _finished and (_transport.closed() or _transport.silent(Time.get_ticks_usec())): _lockstep.set_relay_lost()
	_credit = mini(_credit + 1, MAX_CATCH_UP_CREDIT)
	for i in CATCH_UP_STEPS:
		if _credit < 1 or _last.over or _stopped: break
		var commands: Variant = _lockstep.take(_next_tick, not _taken.is_empty(), _last.survivors if _last.tick == _next_tick else null)
		if commands == null: break
		_credit -= 1
		# The tick's packets are already consumed, so a refused job cannot be retried.
		if not pump.post(_tick_job(commands)):
			_lockstep.set_protocol_error("sim pump refused tick %d" % _next_tick)
			break
		_taken.append(_next_tick)
		_next_tick += 1
	if _phase == "playing" and _lockstep.received_any(): _transport.patient = false

func _tick_job(commands: Array[Dictionary]) -> SimPump.Job:
	var job := SimPump.Job.new()
	job.commands = commands
	job.bots.assign(_lockstep.allowed(_seat).filter(func(player: int) -> bool: return player != _seat))
	job.plan_bots = true
	job.preview = _preview_request
	job.want_digest = _lockstep.wants_snapshot(_next_tick + 1)
	return job

# The last drained note's preview answer wins, as the screen shows the last tick.
func drain() -> Array[SimPump.Note]:
	var notes: Array[SimPump.Note] = pump.drain()
	for note: SimPump.Note in notes:
		if not note.preview.is_empty(): _preview_answer = note.preview
		_finish_job(note)
	if not notes.is_empty(): _last = notes[-1]
	_pings.append_array(_new_pings(notes))
	if _start_tick < 0 and teammate() != 0 and current().view.players.all(func(player: Dictionary) -> bool: return player.has("faction")): _start_tick = current().tick
	_answers.append_array(_new_answers())
	_settle()
	return notes

func _finish_job(note: SimPump.Note) -> void:
	# Publish jobs (tests) are not ticks.
	if _taken.is_empty(): return
	var tick: int = _taken.pop_front()
	# Taken past the end: the sim did not move.
	if note.over and note.tick <= tick: return
	if note.tick != tick + 1:
		# Pairing is by post order; a foreign job in between would record and send the wrong tick.
		_lockstep.set_protocol_error("note at tick %d for taken tick %d" % [note.tick, tick])
		return
	_lockstep.record(tick, note.issued)
	for command: Dictionary in note.bot_commands: _lockstep.submit(command, command.player)
	_lockstep.finish_tick(note.tick, note.snapshot if not note.digest.is_empty() else null, note.digest)

func _settle() -> void:
	if not _finished and (_last.over or _ended()): _finish()
	if (_phase == "over" or _phase == "again") and _room_gone(): _close_room()

func take_answers() -> Array[Dictionary]:
	var answers: Array[Dictionary] = _answers
	_answers = []
	return answers

func current() -> SimPump.Slot:
	return pump.current()

func record() -> Dictionary:
	return pump.record()

func match_stats() -> Array[Dictionary]:
	return _last.stats

func _ended() -> bool:
	return _lockstep.status().begins_with("ended")

func _room_gone() -> bool:
	return _transport.closed() or _transport.silent(Time.get_ticks_usec()) or _lockstep.left_seat() != 0 or _ended()

func _close_room() -> void:
	if not _ended() and _lockstep.left_seat() == 0: _lockstep.set_relay_lost()
	_transport.close()
	_phase = "done"

func request_preview(request: Dictionary) -> void:
	_preview_request = request
	if request.is_empty(): _preview_answer = {}

func preview_answer() -> Dictionary:
	return _preview_answer

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

# Accepted team pings: the result rows say which were applied, the command log holds their targets (plan T2-8); read before _new_answers moves the cursor.
func _new_pings(notes: Array[SimPump.Note]) -> Array[Dictionary]:
	var applied: Dictionary = {}
	for note: SimPump.Note in notes:
		for result: Dictionary in note.results:
			if result.ok: applied[[result.player, result.sequence]] = true
	var pings: Array[Dictionary] = []
	var played: Array = _lockstep.command_log()
	for i in range(_log_seen, played.size()):
		var command: Dictionary = played[i]
		if command.type == "ping" and (command.player == _seat or command.player == teammate()) and applied.has([command.player, command.sequence]):
			pings.append({"player": command.player, "target": Vector2(command.target[0], command.target[1]), "tick": command.tick})
	return pings

# Not teammate() itself: the leave lines and result rows still name a teammate who left.
func can_ping() -> bool:
	return teammate() != 0 and _lockstep.left_seat() != teammate()

func take_pings() -> Array[Dictionary]:
	var pings: Array[Dictionary] = _pings
	_pings = []
	return pings

func submit(payload: Dictionary) -> Dictionary:
	if _lockstep.submit(payload): return {"ok": true, "error": ""}
	# The screen reads refusals from take_answers, not from this return.
	_answers.append({"command": payload, "ok": false, "error": TOO_MANY_ORDERS})
	return {"ok": false, "error": TOO_MANY_ORDERS}

func pauses_sim() -> bool:
	return false

func closes_placement_on_click() -> bool:
	return true

func confirm_leave() -> bool:
	return true

func can_restart() -> bool:
	return false

func leave_heading() -> String:
	if _lockstep.opponent_left(): return "Victory"
	return ResultPanel.MATCH_ENDED if teammate() != 0 and _lockstep.status() == "ended_left" and not _lockstep.left_before_start() else ""

func leave_question() -> String:
	return _team_question("Leave the match?", "Leaving")

func quit_question() -> String:
	return _team_question("Quit the game?", "Quitting")

func _team_question(ask: String, doing: String) -> String:
	if teammate() == 0: return ""
	if _lockstep.left_seat() == teammate(): return ask + " Your friend already left."
	if _lockstep.allowed(_seat).size() > 1: return "%s You run the bots. %s ends the match for your friend." % [ask, doing]
	return ask + (" The match ends for your friend too." if _last.survivors.has(_seat) else " Your friend plays on against the bots.")

func rematch_pending() -> bool:
	return _phase == "again"

func friend_wants_rematch() -> bool:
	return _friend_again

func rematch_line() -> String:
	var left: int = _lockstep.left_seat()
	if left != 0: return HOST_LEFT if left == 1 and teammate() != 0 and leave_heading() == ResultPanel.MATCH_ENDED else "%s left the match" % ResultPanel.player_name(left, _faction(left))
	if _phase == "done": return "The room closed"
	if _friend_again: return "Your friend wants a rematch"
	return "Waiting for your friend…" if _phase == "again" else ""

func can_play_again() -> bool:
	return _phase == "over"

func play_again() -> void:
	if _phase != "over": return
	_transport.send_text(Wire.encode({"type": "again"}))
	_phase = "again"

func teammate() -> int:
	if _lockstep.bots().is_empty(): return 0
	for seat: int in _lockstep.seat_ids():
		if seat != _seat: return seat
	return 0

func bot_players() -> Array[int]:
	return _lockstep.bots()

func teams() -> Array[int]:
	return MatchSettings.teams(_lockstep.seat_ids().size(), _lockstep.bots().size())

func take_rematch() -> int:
	var match_seed: int = _rematch_seed
	_rematch_seed = -1
	if _stopped or match_seed < 0: return -1
	if _room_gone():
		_close_room()
		return -1
	return match_seed

func over() -> bool:
	return _finished

func match_header() -> Dictionary:
	var players: Array = current().view.players
	var bots: Array = players.filter(func(player: Dictionary) -> bool: return bot_players().has(player.id)).map(func(player: Dictionary) -> Dictionary: return {"player": player.id, "faction": player.get("faction", "")})
	return {"mode": "online", "factions": players.map(func(player: Dictionary) -> String: return player.get("faction", "")), "teams": teams(), "bots": bots}

func match_log() -> Dictionary:
	return match_header().merged({"commands": Lockstep.log_lines(_lockstep.command_log()), "end": (_lockstep.status() + " " + _lockstep.end_reason()).strip_edges()})

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
	var job := SimPump.Job.new()
	job.step = false
	job.want_ring = true
	var report: Dictionary = _lockstep.desync_report()
	report.hash_ring = pump.query(job).ring
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

# After the start a leave's line is the result panel's, so it shows once.
func notice() -> String:
	if _left: return "" # leave() ends the lockstep through set_relay_lost, which is no relay loss
	match _lockstep.status():
		"waiting": return "Waiting for your teammate…" if teammate() != 0 else "Waiting for player %d" % _lockstep.waiting_for()[0]
		"ended_left": return "Opponent left before the start (a different map or version, or their game tab was hidden)" if _lockstep.left_before_start() else ""
		"ended_relay": return RELAY_LOST if _lockstep.end_reason() == "connection to relay lost" else "Relay: " + _lockstep.end_reason()
		"ended_send": return RELAY_LOST
		"ended_desync": return ("Desync — report downloaded as %s" if web else "Desync — report saved to %s") % _report_path
		"ended_protocol": return "Match stopped: game error. Please report it."
	if teammate() == 0: return ""
	var out: bool = not _last.over and not _last.survivors.has(_seat)
	if out and _lockstep.allowed(_seat).size() == 1: return "You are out. Your teammate plays on: watch, or leave from the menu (Esc)."
	# The host runs the bots, so its leave would end the friend's match.
	if out and _lockstep.left_seat() != teammate(): return "You are out. Keep this window open: it runs the bots for your teammate."
	return _start_line()

func _start_line() -> String:
	if _start_tick < 0 or current().tick >= _start_tick + START_LINE_TICKS: return ""
	var tags := PackedStringArray(bot_players().map(func(bot: int) -> String: return Registry.faction(_faction(bot)).get("short_name", "?")))
	return "You and %s vs %d bots (%s)" % [ResultPanel.player_name(teammate(), _faction(teammate())), tags.size(), ", ".join(tags)]

func _faction(player: int) -> String:
	for row: Dictionary in current().view.players:
		if row.id == player: return row.get("faction", "")
	return ""
