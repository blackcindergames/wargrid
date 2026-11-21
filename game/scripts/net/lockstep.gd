extends RefCounted

const Wire = preload("res://scripts/net/wire.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const MAX_QUEUED_TICKS: int = 300 # a legitimate peer queues at most about 2 * input delay + 2 ticks; raise this if the relay delay nears 150
const FRAME_RESERVE_BYTES: int = 256 # the tick envelope and hash around the commands, with room to spare

var send: Callable = func(_frame: String) -> void: pass
var session_handler: Callable

var _seat: int
var _seats: Array[int]
var _delay: int
var _hash_interval: int
var _clock: Callable
var _status: String = "running"
var _next_tick: int = 0
var _packets: Dictionary = {}
var _last_received: Dictionary = {}
var _last_sent: int = 0
var _queue: Array = []
var _queue_bytes: int = 0
var _sequence: int = 0
var _submit_times: Dictionary = {}
var _own_hashes: Dictionary = {}
var _hash_order: Array[int] = []
var _hash_snapshot: Dictionary = {}
var _command_log: Array[Dictionary] = []
var _latency: PackedInt64Array = PackedInt64Array()
var _left: Dictionary = {} # seat -> after_tick
var _played_on: Dictionary = {}
var _ended_by: int = 0
var _end_reason: String = ""
var _desync_tick: int = -1
var _rejections: Array[Dictionary] = []
var _received_any: bool = false

func _init(seat: int, seats: Array[int], delay: int = 4, hash_interval: int = 30, clock: Callable = Time.get_ticks_usec) -> void:
	_seat = seat
	_seats = seats.duplicate()
	_seats.sort()
	_last_sent = delay - 1
	_delay = delay
	_hash_interval = hash_interval
	_clock = clock
	for s in _seats:
		_packets[s] = {}
		_last_received[s] = delay - 1
		for tick in delay:
			_packets[s][tick] = {"commands": []}

static func for_start(seat: int, message: Dictionary) -> RefCounted:
	var seats: Array[int] = []
	seats.assign(message.seats)
	return new(seat, seats, message.delay)

func received_any() -> bool:
	return _received_any

func start(state: Dictionary, digest: String = "") -> void:
	_last_sent = _delay - 1
	finish_tick(0, state, digest)

func submit(payload: Dictionary) -> bool:
	var command: Dictionary = payload.duplicate(true)
	command.tick = _last_sent + 1
	command.player = _seat
	command.sequence = _sequence
	var size: int = Wire.encode(command).to_utf8_buffer().size() + 1
	if _queue_bytes + size > Wire.MAX_FRAME_BYTES - FRAME_RESERVE_BYTES: return false
	_submit_times[_sequence] = _clock.call()
	_sequence += 1
	_queue_bytes += size
	_queue.append(command)
	return true

func receive(text: String) -> void:
	if _ended(): return
	var zone: int = Profiler.begin()
	var decoded: Dictionary = Wire.decode(text)
	Profiler.end(&"lockstep.decode", zone)
	if not decoded.ok:
		_end("ended_protocol", decoded.error)
		return
	var message: Dictionary = decoded.message
	match message.type:
		"tick": _receive_tick(message)
		"left": _receive_left(message)
		"error": _end("ended_relay", message.reason)
		"again", "start":
			if not session_handler.is_valid() or not session_handler.call(message): _end("ended_protocol", "unexpected " + message.type)
		_: _end("ended_protocol", "unexpected " + message.type)

func can_step(sim_tick: int) -> bool:
	return waiting_for_tick(sim_tick).is_empty()

func waiting_for() -> Array[int]:
	return waiting_for_tick(_next_tick)

func waiting_for_tick(sim_tick: int) -> Array[int]:
	var missing: Array[int] = []
	for s in _seats:
		if _counts(s, sim_tick) and not _packets[s].has(sim_tick): missing.append(s)
	return missing

# quiet: the caller cannot tell yet whether the tick before ended the match, so a wait, leave or hash refusal keeps the status; a wrong tick always ends.
# survivors: match players owning a victory building after step(tick - 1); null means the caller cannot tell, so a leave ends the match.
func take(tick: int, quiet: bool = false, survivors: Variant = null) -> Variant:
	if _ended(): return null
	if tick != _next_tick:
		_end("ended_protocol", "take tick %d, expected %d" % [tick, _next_tick])
		return null
	for s in _seats:
		if not _left.has(s) or _played_on.has(s) or (tick <= _left[s] and _packets[s].has(tick)): continue
		if quiet: return null
		if _defeated(s, tick, survivors):
			_played_on[s] = true
			continue
		_ended_by = s
		_end("ended_left", "player %d disconnected" % s)
		return null
	if not can_step(tick):
		if not quiet: _status = "waiting"
		return null
	if not _verify_hashes(tick, quiet): return null
	var commands: Array[Dictionary] = []
	for s in _seats:
		if not _counts(s, tick): continue
		for command: Dictionary in _packets[s][tick].commands: commands.append(command)
		_packets[s].erase(tick)
	_next_tick = tick + 1
	_status = "running"
	return commands

func record(tick: int, issued: Array[Dictionary]) -> void:
	var now: int = _clock.call()
	for entry: Dictionary in issued:
		var command: Dictionary = entry.command
		_command_log.append(command)
		if command.player != _seat: continue
		_latency.append(now - _submit_times[command.sequence])
		_submit_times.erase(command.sequence)
		if not entry.ok: _rejections.append({"tick": tick, "sequence": command.sequence, "error": entry.error})

func advance(sim: Simulation) -> bool:
	if sim.match_over(): return false
	var tick: int = sim.tick()
	var commands: Variant = take(tick, false, sim.survivors() if _left.values().has(tick - 1) else null)
	if commands == null: return false
	var issued: Array[Dictionary] = []
	for command: Dictionary in commands:
		var result: Dictionary = sim.issue_command(command)
		issued.append({"command": command, "ok": result.ok, "error": result.error})
	record(tick, issued)
	sim.step()
	return true

func finish_tick(tick: int, state: Variant, digest: String = "") -> void:
	if _ended(): return
	if tick + _delay != _last_sent + 1:
		_end("ended_protocol", "own tick %d after %d" % [tick + _delay, _last_sent])
		return
	var hash_entry: Variant = null
	if state != null and tick % _hash_interval == 0:
		var value: String = digest if not digest.is_empty() else StateHash.digest(state)
		_own_hashes[tick] = value
		_hash_order.append(tick)
		_hash_snapshot = state
		hash_entry = {"tick": tick, "value": value}
	var packet_tick: int = tick + _delay
	var commands: Array = _queue
	_queue = []
	_queue_bytes = 0
	var zone: int = Profiler.begin()
	var text: String = Wire.encode(Wire.tick_message(_seat, packet_tick, commands, hash_entry))
	var own: Dictionary = Wire.decode(text)
	Profiler.end(&"lockstep.encode", zone)
	if not own.ok:
		_end("ended_protocol", "own frame: " + own.error)
		return
	_packets[_seat][packet_tick] = own.message
	_last_sent = packet_tick
	send.call(text)

func wants_snapshot(tick: int) -> bool:
	return tick % _hash_interval == 0

func rejections() -> Array[Dictionary]:
	return _rejections

func status() -> String:
	return _status

func set_relay_lost() -> void:
	if _ended(): return
	_end("ended_relay", "connection to relay lost")

func set_protocol_error(reason: String) -> void:
	if _ended(): return
	_end("ended_protocol", reason)

func left_before_start() -> bool:
	return left_seat() != 0 and _left[left_seat()] < _delay

func opponent_left() -> bool:
	return _status == "ended_left" and not left_before_start() and _seats.size() == 2

func left_seat() -> int:
	if _ended_by != 0: return _ended_by
	for s in _seats:
		if _left.has(s): return s
	return 0

func end_reason() -> String:
	return _end_reason

func hash_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for tick in _hash_order: rows.append("%d\t%s" % [tick, _own_hashes[tick]])
	return rows

# formerly in headless_client.gd
static func log_lines(rows: Array[Dictionary]) -> PackedStringArray:
	var by_tick: Dictionary = {}
	var order: Array[int] = []
	for command in rows:
		if not by_tick.has(command.tick):
			by_tick[command.tick] = []
			order.append(command.tick)
		by_tick[command.tick].append(command)
	var lines := PackedStringArray()
	for tick in order: lines.append(Wire.encode(Wire.tick_message(0, tick, by_tick[tick], null)))
	return lines

func command_log() -> Array[Dictionary]:
	return _command_log

func latency_samples() -> PackedInt64Array:
	return _latency

func desync_report(sim: Simulation = null) -> Dictionary:
	var report := {"seat": _seat, "tick": _desync_tick, "hash_rows": hash_rows(), "command_log": _command_log, "snapshot": _hash_snapshot}
	if sim != null: report.hash_ring = sim.hash_ring()
	return report

func _ended() -> bool:
	return _status.begins_with("ended")

func _end(final_status: String, reason: String) -> bool:
	_status = final_status
	_end_reason = reason
	if final_status == "ended_protocol": printerr("NETPLAY PROTOCOL END ", reason) # the HUD shows plain text, so the reason lives only here and in the playtest record
	return false

func _receive_tick(message: Dictionary) -> void:
	var s: int = message.seat
	if s == _seat or not _seats.has(s):
		_end("ended_protocol", "bad seat")
		return
	if message.tick != _last_received[s] + 1:
		_end("ended_protocol", "tick out of order")
		return
	for command: Dictionary in message.commands:
		if command.get("player") != s or command.get("tick") != message.tick:
			_end("ended_protocol", "bad command stamp")
			return
	if _packets[s].size() >= MAX_QUEUED_TICKS:
		_end("ended_protocol", "peer too far ahead")
		return
	_last_received[s] = message.tick
	_packets[s][message.tick] = message
	_received_any = true

func _receive_left(message: Dictionary) -> void:
	if message.seat == _seat or not _seats.has(message.seat):
		_end("ended_protocol", "bad left seat")
		return
	if _left.has(message.seat):
		_end("ended_protocol", "repeated left for seat %d" % message.seat)
		return
	_left[message.seat] = message.after_tick

func _verify_hashes(tick: int, quiet: bool = false) -> bool:
	for s in _seats:
		if not _counts(s, tick): continue
		var packet: Dictionary = _packets[s][tick]
		if not packet.has("hash"): continue
		var hash_entry: Dictionary = packet.hash
		if _own_hashes.get(hash_entry.tick) != hash_entry.value:
			if quiet: return false
			_desync_tick = hash_entry.tick
			_end("ended_desync", "hash mismatch at tick %d (seat %d)" % [hash_entry.tick, s])
			return false
	return true

func _counts(s: int, tick: int) -> bool:
	return not _left.has(s) or tick <= _left[s]

func _defeated(s: int, tick: int, survivors: Variant) -> bool:
	return tick == _left[s] + 1 and _left[s] >= _delay and survivors is Array and not (survivors as Array).has(s)
