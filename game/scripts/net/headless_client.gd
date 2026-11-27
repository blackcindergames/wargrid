extends Node

const Lockstep = preload("res://scripts/net/lockstep.gd")
const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const SeatSim = preload("res://scripts/net/seat_sim.gd")
const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const ScriptedHuman = preload("res://scripts/simulation/scripted_human.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const UNCAPPED_STEPS: int = 64
const CAPPED_STEPS: int = 2
const CLOSE_WAIT_MSEC: int = 1000
const ORACLE_MAX_TICKS: int = 30000

var _args: Dictionary = {}
var _transport: RefCounted
var _lockstep: RefCounted
var _driver: OnlineDriver
var _hooked_tick: int = -1
var _present: int = 1
var _joins: int = 0
var _asked: bool = false
var _picked: Dictionary = {}
# Guests' --start picks by seat, folded into the host's last settings before its start_request.
var _picked_starts: Dictionary = {}
var _pending_code: String = ""
var _pongs_before: int = 0
var _sim: Simulation
var _seat: int = 0
var _hello_sent: bool = false
var _stalled: bool = false
var _status: String = ""
var _reason: String = ""
var _closing_since: int = 0
var _ending: bool = false
var _connect_msec: int = 0
var _match_map: String = MatchSettings.TEST_MAP
var _chosen: Array[int] = []
var _match_seed: int = 0
var _rematch_state: String = ""
var _defeats: Dictionary = {}
var state_rows := PackedStringArray()

func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	var arg_error: String = _faction_error()
	if arg_error == "": arg_error = _defeat_error()
	if arg_error == "": arg_error = _controller_error()
	if arg_error == "": arg_error = _bots_error()
	if arg_error == "": arg_error = _lobby_error()
	if arg_error != "":
		printerr(arg_error)
		get_tree().quit(2)
		return
	if _args.has("replay-log"):
		_replay_oracle()
		return
	_defeats = _parse_defeats(str(_args.get("defeat", "")))
	_transport = RelayTransport.new()
	var url: String = _args.get("relay", _args.get("probe-relay", ""))
	_connect_msec = Time.get_ticks_msec()
	if url == "" or _transport.connect_to(url) != OK:
		_finish("ended_relay", "cannot connect")

func _process(_delta: float) -> void:
	if _transport == null: return
	if _closing_since != 0:
		_transport.poll()
		if _transport.closed() or Time.get_ticks_msec() - _closing_since > CLOSE_WAIT_MSEC: _exit()
		return
	if _ending: return
	_receive(_transport.poll())
	if _lockstep == null:
		_pre_start()
	elif _args.has("uncapped"):
		_run_steps(UNCAPPED_STEPS)
	if _lockstep != null and not _ending: _receive(_transport.poll())

func _physics_process(_delta: float) -> void:
	if _lockstep != null and not _ending and not _args.has("uncapped"): _run_steps(CAPPED_STEPS)

func _pre_start() -> void:
	# Two pongs: a periodic ping sent before the change may answer first; frames on one socket stay in order.
	if _pending_code != "" and _transport.rtt_samples().size() > _pongs_before + 1:
		_write_code(_pending_code)
		_pending_code = ""
	if _transport.closed():
		_finish("ended_relay", "connection to relay lost")
	elif _transport.is_open() and not _hello_sent:
		_hello_sent = true
		_transport.send_text(Wire.encode(_hello()))

func _hello() -> Dictionary:
	var hello: Dictionary = {"type": "hello", "protocol": Wire.PROTOCOL, "build": _args.get("build", PlaytestSettings.hello_build()), "match": "" if _args.get("match", "new") == "new" else _args["match"]}
	if _args.get("match", "new") == "new": hello["settings"] = MatchSettings.for_map(_map_id(), _bots_arg())
	return hello

func _receive(frames: PackedStringArray) -> void:
	for text in frames:
		if _ending: return
		if _lockstep != null:
			_lockstep.receive(text)
			continue
		var decoded: Dictionary = Wire.decode(text)
		if not decoded.ok:
			_finish("ended_protocol", decoded.error)
			return
		var message: Dictionary = decoded.message
		match message.type:
			"welcome": _welcome(message)
			"joined": _seat_change(message.seat, 1)
			"left": _seat_change(message.seat, -1)
			"settings": _room_map(message.settings)
			"pick": _take_pick(message)
			"start": _start(message)
			"error": _finish("ended_relay", message.reason)
			_: _finish("ended_protocol", "unexpected " + message.type)

func _welcome(message: Dictionary) -> void:
	_seat = message.seat
	print("NETCLIENT WELCOME SEAT ", _seat, " CODE ", message.match, " AT ", _now_ms())
	if _args.has("probe-relay"):
		print("RELAY WELCOME ", Time.get_ticks_msec() - _connect_msec)
		_finish("probed", "")
		return
	if _seat == 1 and _lobby_maps().size() > 0:
		_send_settings(_lobby_maps()[0])
		# The code file waits for a pong after the change, so a friend started on that file joins after the relay read it.
		_pending_code = message.match
		_pongs_before = _transport.rtt_samples().size()
		_transport.send_text(Wire.encode({"type": "ping", "t": Time.get_ticks_usec()}))
	else:
		_write_code(message.match)
	if _seat > 1:
		_room_map(message.get("settings", {}))
		var pick: Dictionary = {"faction": _args.get("faction", Skirmish.default_faction())}
		if _args.has("start"): pick.merge({"start": _int_arg("start"), "map": message.get("settings", {}).get("map")})
		_transport.send_text(Wire.encode({"type": "pick", "pick": pick}))
		if _args.has("leave-on-welcome"): _finish("left", "")

func _write_code(match_code: String) -> void:
	if not _args.has("code-file"): return
	var temp: String = str(_args["code-file"]) + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	file.store_string(match_code)
	file.close()
	DirAccess.rename_absolute(temp, _args["code-file"])

# --lobby-maps A[,B]: the host sends map A after its welcome and B just before it asks to start.
func _lobby_maps() -> PackedStringArray:
	return str(_args.get("lobby-maps", "")).split(",", false)

func _send_settings(id: String) -> void:
	_transport.send_text(Wire.encode({"type": "settings", "settings": MatchSettings.for_map(id, _bots_arg()).merged(_placement())}))
	print("NETCLIENT SENT MAP ", id)

# --start N on the host is its own pick; a guest's arrives in its pick.
func _placement() -> Dictionary:
	var rows: Array = []
	if _args.has("start"): rows.append({"player": 1, "start": _int_arg("start")})
	for seat: int in _picked_starts: rows.append({"player": seat, "start": _picked_starts[seat]})
	return {"chosen": rows} if not rows.is_empty() else {}

func _room_map(settings: Dictionary) -> void:
	print("NETCLIENT ROOM MAP ", settings.get("map", "-"))

func _seat_change(seat: int, step: int) -> void:
	print("NETCLIENT ", "JOINED" if step > 0 else "LEFT", " SEAT ", seat)
	if _seat != 1: return
	_present += step
	if step > 0: _joins += 1
	else:
		_asked = false # the relay ignored an ask sent before the room was full
		_picked.erase(seat)
		_picked_starts.erase(seat)
	_try_start()

func _take_pick(message: Dictionary) -> void:
	print("NETCLIENT PICK SEAT ", message.get("seat", 0), " ", message.pick.get("faction", "-"))
	_picked[int(message.get("seat", 0))] = message.pick.get("faction")
	if message.pick.has("start"): _picked_starts[int(message.get("seat", 0))] = int(message.pick.start)
	_try_start()

# The host asks to start once --seats seats are in, --joins friends have joined in all and every guest's pick arrived:
# the relay refuses a pick after the start, and each guest sends one on its welcome.
func _try_start() -> void:
	var seats: int = _int_arg_or("seats", 2)
	if _asked or _present < seats or _joins < _int_arg_or("joins", seats - 1) or _picked.size() < _present - 1: return
	_asked = true
	if _lobby_maps().size() > 1: _send_settings(_lobby_maps()[1])
	elif not _placement().is_empty(): _send_settings(_map_id())
	_transport.send_text(Wire.encode({"type": "start_request"}))

func _map_id() -> String:
	return _args.get("map", MatchSettings.TEST_MAP)

func _start(message: Dictionary) -> void:
	var settings: Dictionary = message.settings.duplicate()
	if _args.has("perturb-map-hash") and _seat == 2: settings["map_hash"] = str(settings.get("map_hash", "")) + "x"
	var reason: String = MatchSettings.refusal(settings, message.seats.size())
	if not reason.is_empty():
		_finish("ended_settings", reason)
		return
	var id: String = message.settings.map
	_match_map = id
	_match_seed = _int_arg("seed") if _args.has("seed") else message.seed
	var count: int = message.seats.size()
	var bots: Dictionary = _bot_factions(settings.get("bots", []))
	_chosen = MatchSettings.starts(id, _match_seed, MatchSettings.teams(count, bots.size()), settings)
	print("NETCLIENT MAP ", id, " SEED ", _match_seed, " STARTS ", ",".join(_chosen.map(str)) if not _chosen.is_empty() else "-")
	_sim = _match_sim(id, _chosen, count, bots)
	_lockstep = Lockstep.for_start(_seat, message)
	if _args.has("pump"):
		_driver = OnlineDriver.new(_transport, _lockstep, _args.get("faction", Skirmish.default_faction()), _seat)
		_driver.adopt(_sim)
		_driver.start()
		return
	_lockstep.session_handler = _on_session
	_lockstep.send = _transport.send_text
	_lockstep.submit({"type": "choose_faction", "faction": _args.get("faction", Skirmish.default_faction())})
	_lockstep.start(_sim.snapshot())

func _on_session(message: Dictionary) -> bool:
	if message.type == "again":
		if message.get("seat", _seat) != _seat: print("NETCLIENT AGAIN SEAT ", message.seat)
		return true
	if _rematch_state != "waiting": return false
	_rematch_state = "done"
	_start(message) # swap now so the peer's tick 4 in the same poll batch reaches the new lockstep
	return true

func _match_sim(id: String, chosen: Array[int], count: int = 2, bots: Dictionary = {}) -> Simulation:
	return Skirmish.create(true, "human", bots, MatchSettings.map_path(id), chosen, count + bots.size(), MatchSettings.teams(count, bots.size()))

func _bot_factions(rows: Array) -> Dictionary:
	var factions: Dictionary = {}
	for row: Dictionary in rows: factions[int(row.player)] = row.faction
	return factions

func _bots_arg() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in str(_args.get("bots", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		rows.append({"player": int(parts[0]), "faction": parts[1]})
	return rows

func _oracle_sim() -> Simulation:
	var id: String = _map_id()
	var match_seed: int = int(_args.get("seed", "0"))
	var bots: Dictionary = _bot_factions(_bots_arg())
	if not _args.has("factions"): return _match_sim(id, _oracle_starts(id, match_seed, MatchSettings.teams(2, bots.size())), 2, bots)
	# An offline record lists every seat: you, then the bots on team 2.
	var names: PackedStringArray = str(_args["factions"]).split(",")
	var factions: Dictionary = {}
	for i in names.size(): factions[i + 1] = names[i]
	var teams: Array[int] = MatchSettings.teams(1, names.size() - 1)
	return Skirmish.create(true, str(_args.get("controller", "ai")), factions, MatchSettings.map_path(id), _oracle_starts(id, match_seed, teams), names.size(), teams)

# --starts A,B,... replays a record's starts as played; records from before start pick have none and follow the rule.
func _oracle_starts(id: String, match_seed: int, teams: Array[int]) -> Array[int]:
	if not _args.has("starts"): return MatchSettings.starts(id, match_seed, teams)
	var starts: Array[int] = []
	for seat: String in str(_args.starts).split(","): starts.append(seat.to_int())
	return starts

func _run_steps(limit: int) -> void:
	if _driver != null:
		_pump_steps(limit)
		return
	for i in limit:
		if _ending: return
		if _transport.closed() or _transport.silent(Time.get_ticks_usec()): _lockstep.set_relay_lost()
		if _sim.match_over():
			if _rematch_step(): return
			_finish("match_over", "")
			return
		if _lockstep.status().begins_with("ended"):
			_finish(_lockstep.status(), _lockstep.end_reason())
			return
		if not _step_once(): break

func _pump_steps(limit: int) -> void:
	for i in limit:
		if _ending: return
		if _driver.over():
			var ended: bool = _lockstep.status().begins_with("ended")
			_finish(_lockstep.status() if ended else "match_over", _lockstep.end_reason() if ended else "")
			return
		var tick: int = _sim.tick()
		if tick != _hooked_tick and _lockstep.can_step(tick):
			_hooked_tick = tick
			if _test_hooks(tick): return
			_run_script()
		# step() polls before it takes, so it may take only the tick whose hooks and script just ran.
		_driver._credit = 0 if tick == _hooked_tick else -1
		_driver.step()
		_driver.drain()
		if _sim.tick() == tick and (tick == _hooked_tick or not _lockstep.can_step(tick)): return

func _rematch_step() -> bool:
	if not _args.has("rematch") or _rematch_state == "done": return false
	if _rematch_state == "":
		_rematch_state = "waiting"
		print("NETCLIENT OVER TICK ", _sim.tick())
		_transport.send_text(Wire.encode({"type": "over"}))
		_transport.send_text(Wire.encode({"type": "again"}))
	if _lockstep.left_seat() != 0 or _lockstep.status().begins_with("ended"):
		_finish(_lockstep.status() if _lockstep.status().begins_with("ended") else "ended_left", _lockstep.end_reason())
	return true

func _step_once() -> bool:
	var tick: int = _sim.tick()
	if _lockstep.can_step(tick):
		if _test_hooks(tick): return false
		_run_script()
	if not _lockstep.advance(_sim):
		if _lockstep.status().begins_with("ended"): _finish(_lockstep.status(), _lockstep.end_reason())
		return false
	var after: int = _sim.tick()
	_lockstep.finish_tick(after, _sim.snapshot() if _lockstep.wants_snapshot(after) else null)
	return true

func _run_script() -> void:
	var seat_sim: RefCounted = SeatSim.new(_sim, _lockstep)
	match _args.get("seat-script", "idle"):
		"human":
			if _seat == 1: ScriptedHuman.issue(seat_sim)
			else: _finish("ended_protocol", "human script needs seat 1")
		"opponent": Skirmish.issue_opponent(seat_sim, _seat)

func _test_hooks(tick: int) -> bool:
	if _int_arg("perturb-at-tick") == tick: _sim._players[_seat].credits += 1
	_apply_defeats(tick)
	if _int_arg("stop-at-tick") == tick:
		_finish("stopped", "")
		return true
	if _int_arg("exit-at-tick") == tick:
		_transport.poll()
		OS.kill(OS.get_process_id())
	if _int_arg("stall-at-tick") == tick and not _stalled:
		_stalled = true
		print("NETCLIENT STALL AT ", _now_ms())
		OS.delay_msec(int(float(_args.get("stall-seconds", "1")) * 1000.0))
		_receive(_transport.poll())
	return false

func _apply_defeats(tick: int) -> void:
	for seat: int in _defeats.get(tick, []):
		while _remove_owned(seat): pass
		print("NETCLIENT DEFEAT ", seat, " AT ", tick)
	_defeats.erase(tick)

# Repeated because removed FRC buildings open rebuild holes, which count for victory; units go too so no builder can fill one.
func _remove_owned(seat: int) -> bool:
	var removed: bool = false
	var state: Dictionary = _sim.snapshot()
	for row: Dictionary in state.buildings + state.entities:
		if row.owner == seat:
			_sim.remove_object(row.id)
			removed = true
	return removed

func _parse_defeats(spec: String) -> Dictionary:
	var parsed: Dictionary = {}
	for entry in spec.split(",", false):
		var parts: PackedStringArray = entry.split("@")
		if parts.size() != 2: continue
		var tick: int = int(parts[1])
		parsed[tick] = parsed.get(tick, []) + [int(parts[0])]
	return parsed

func _finish(status: String, reason: String) -> void:
	if _ending: return
	_ending = true
	_status = status
	_reason = reason
	if _lockstep != null and _lockstep.opponent_left(): print("NETCLIENT VICTORY left")
	if _lockstep != null:
		_write_logs()
		_lockstep.send = Callable()
	if _transport != null and _transport.is_open():
		_transport.close()
		_closing_since = maxi(Time.get_ticks_msec(), 1)
	else:
		_exit()

func _exit() -> void:
	_closing_since = 0
	var tick: int = _sim.tick() if _sim != null else 0
	print("NETCLIENT TIME ", _now_ms())
	print("NETCLIENT END ", _status, " TICK ", tick, " WINNER ", _winner(), " REASON ", _reason)
	get_tree().quit(0)

func _winner() -> String:
	if _sim == null: return "-"
	var state: Variant = _sim.snapshot().get("match")
	if state is not Dictionary or state.winner == null: return "-"
	return str(state.winner)

func _write_logs() -> void:
	if _args.has("hash-log"): _write_lines(_args["hash-log"], _lockstep.hash_rows())
	if _args.has("command-log"): _write_lines(_args["command-log"], Lockstep.log_lines(_lockstep.command_log()))
	if _status == "ended_desync" and _args.has("report-dir"):
		var file := FileAccess.open("%s/desync-seat%d.json" % [_args["report-dir"], _seat], FileAccess.WRITE)
		if file == null: return
		var report: Dictionary = _lockstep.desync_report(_sim)
		report.merge(MatchSettings.report_fields(_match_map, _match_seed, _chosen))
		file.store_string(JSON.stringify(report, "", true, true))
		file.close()

func _replay_oracle() -> void:
	var by_tick: Dictionary = {}
	for line in FileAccess.get_file_as_string(_args["replay-log"]).split("\n", false):
		var decoded: Dictionary = Wire.decode(line)
		if not decoded.ok:
			_status = "ended_protocol"
			_reason = decoded.error
			_exit()
			return
		by_tick[decoded.message.tick] = decoded.message.commands
	var every: int = _int_arg("hash-every") if _args.has("hash-every") else 30
	var max_ticks: int = _int_arg("oracle-ticks") if _args.has("oracle-ticks") else ORACLE_MAX_TICKS
	var sim: Simulation = _oracle_sim()
	_sim = sim
	var rows := PackedStringArray(["0\t" + StateHash.digest(sim.snapshot())])
	var ring_rows := PackedStringArray()
	var state_ticks: PackedStringArray = str(_args.get("state-ticks", "")).split(",", false)
	while not sim.match_over() and sim.tick() < max_ticks:
		if state_ticks.has(str(sim.tick())): _state_row(sim)
		for command: Variant in by_tick.get(sim.tick(), []): sim.issue_command(command)
		sim.step()
		if _args.has("ring-log"): ring_rows.append(sim.hash_ring()[-1])
		if sim.tick() % every == 0: rows.append("%d\t%s" % [sim.tick(), StateHash.digest(sim.snapshot())])
	if state_ticks.has(str(sim.tick())): _state_row(sim)
	if _args.has("hash-log"): _write_lines(_args["hash-log"], rows)
	if _args.has("ring-log"): _write_lines(_args["ring-log"], ring_rows)
	_status = "match_over" if sim.match_over() else "oracle_overrun"
	print("ORACLE FINAL %d %s" % [sim.tick(), StateHash.digest(sim.snapshot())])
	_exit()

func _state_row(sim: Simulation) -> void:
	var state: Dictionary = sim.snapshot()
	var row: String = "ORACLE STATE %d %s %s" % [state.tick, StateHash.digest(state), state_summary(state)]
	state_rows.append(row)
	print(row)
	if not _args.has("snapshot-dir"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_args["snapshot-dir"]))
	var file := FileAccess.open("%s/tick-%d.json" % [_args["snapshot-dir"], state.tick], FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(state, "", true, true))
	file.close()

static func state_summary(snapshot: Dictionary) -> String:
	var units: Dictionary = {}
	var buildings: Dictionary = {}
	for unit: Dictionary in snapshot.entities: units[str(unit.owner)] = units.get(str(unit.owner), 0) + 1
	for building: Dictionary in snapshot.buildings: buildings[str(building.owner)] = buildings.get(str(building.owner), 0) + 1
	var players: Array = snapshot.players.map(func(player: Dictionary) -> Dictionary: return {"id": player.id, "credits": player.credits})
	return JSON.stringify({"match": snapshot.match.status, "players": players, "units": units, "buildings": buildings}, "", true)

func _write_lines(path: String, lines: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_string("\n".join(lines) + "\n")
	file.close()

func _factions_error() -> String:
	if not _args.has("factions"): return ""
	var names: PackedStringArray = str(_args["factions"]).split(",")
	var known: String = ", ".join(Registry.Factions.FACTIONS.keys())
	if names.size() < 2: return "--factions needs two or more entries A,B[,C...]; expected each of: %s" % known
	for entry in names:
		if Registry.faction(entry).is_empty(): return "Unknown --factions entry '%s'; expected one of: %s" % [entry, known]
	return ""

func _int_arg(key: String) -> int:
	return _int_arg_or(key, -1)

func _int_arg_or(key: String, fallback: int) -> int:
	return int(_args[key]) if _args.has(key) else fallback

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func _faction_error() -> String:
	var listed: String = _factions_error()
	if listed != "": return listed
	var faction: String = _args.get("faction", Skirmish.default_faction())
	return "" if not Registry.faction(faction).is_empty() else "Unknown --faction '%s'; expected one of: %s" % [faction, ", ".join(Registry.Factions.FACTIONS.keys())]

func _controller_error() -> String:
	var controller: String = str(_args.get("controller", "ai"))
	return "" if controller in ["human", "ai"] else "Unknown --controller '%s'; expected human or ai" % controller

func _bots_error() -> String:
	if not _args.has("bots"): return ""
	if _args.has("factions"): return "--bots cannot be combined with --factions"
	var known: String = ", ".join(Registry.Factions.FACTIONS.keys())
	var seen: Array[int] = []
	for entry in str(_args.bots).split(","):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int(): return "Bad --bots entry '%s'; expected PLAYER:FACTION[,PLAYER:FACTION]" % entry
		# Contiguous from 3 like MatchSettings: the oracle makes seats 1..N and would drop a gap's bot.
		if parts[0].to_int() != 3 + seen.size(): return "Bad --bots player '%s'; bots are players 3, 4, ... in order, each once" % parts[0]
		seen.append(parts[0].to_int())
		if Registry.faction(parts[1]).is_empty(): return "Unknown --bots faction '%s'; expected one of: %s" % [parts[1], known]
	return ""

func _lobby_error() -> String:
	for key: String in ["seats", "joins", "start"]:
		if _args.has(key) and (not str(_args[key]).is_valid_int() or int(_args[key]) < 1): return "Bad --%s '%s'; expected a whole number above 0" % [key, _args[key]]
	for id: String in _lobby_maps():
		if not FileAccess.file_exists(MatchSettings.map_path(id)): return "Unknown --lobby-maps map '%s'" % id
	if not _args.has("starts"): return ""
	var starts: PackedStringArray = str(_args.starts).split(",", false)
	var seats: int = str(_args.factions).split(",").size() if _args.has("factions") else 2 + _bots_arg().size()
	if starts.size() != seats or Array(starts).any(func(seat: String) -> bool: return not seat.is_valid_int() or seat.to_int() < 1):
		return "Bad --starts '%s'; expected %d start seats above 0, one per seat" % [_args.starts, seats]
	return ""

func _defeat_error() -> String:
	if not _args.has("defeat"): return ""
	var entry := RegEx.create_from_string("^[1-9][0-9]*@[1-9][0-9]*$")
	for spec: String in str(_args.defeat).split(","):
		if entry.search(spec) == null: return "Bad --defeat entry '%s'; expected SEAT@TICK[,SEAT@TICK] with seat and tick above 0" % spec
	return ""

func _parse(raw: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	var i: int = 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		if i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
			parsed[key] = raw[i + 1]
			i += 2
		else:
			parsed[key] = "true"
			i += 1
	return parsed
