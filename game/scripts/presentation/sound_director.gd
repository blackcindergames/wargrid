extends RefCounted

const Cues = preload("res://scripts/presentation/sound_cues.gd")
const Announcer = preload("res://scripts/presentation/announcer.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Shared = preload("res://scripts/simulation/definitions/shared.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const UnitVoice = preload("res://scripts/presentation/unit_voice.gd")
const MAX_PENDING := 120
const MAX_CONSUMED := 64
const FUNDS_ERROR := "Insufficient credits"

var _local_player: int
var _rng: RandomNumberGenerator
var _pending: Array[Dictionary] = []
var _consumed: Array[int] = []
var _queued: Array[Dictionary] = []
var _last_collected: int = -1
var _previous: Dictionary = {}
var _rows: RefCounted = ViewRows.new()
var _previous_rows: RefCounted = ViewRows.new()
var _previous_status: String = ""
var _has_previous: bool = false
var _last_shot: Dictionary = {}
var _last_play: Dictionary = {}
var _funds_rejected: bool = false
var _was_low_power: bool = false
var _tick: int = 0
var _own_hit: Dictionary = {}
var _allied_hit: Dictionary = {}
var _alert: String = ""
var _alert_tick: int = -1
var announcer := Announcer.new()

func _init(local_player: int, rng: RandomNumberGenerator = null) -> void:
	_local_player = local_player
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

func collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void:
	if tick <= _last_collected: return
	_last_collected = tick
	_pending.append({"tick": tick, "events": events.duplicate(true), "results": results.duplicate(true)})
	if _pending.size() > MAX_PENDING: _pending.pop_front()

func collected_ticks() -> Array[int]:
	var ticks: Array[int] = []
	for step: Dictionary in _pending: ticks.append(step.tick)
	return ticks

func consumed_ticks() -> Array[int]:
	return _consumed

func pending_step(index: int) -> Dictionary:
	return _pending[index]

# A local refusal's sound: "error" beeps, "funds" asks for the voice, "disabled" clicks short and asks for it (3-8).
func rejected(sound: String) -> void:
	if sound in ["error", "disabled"]: _queued.append(ui_request(sound))
	if sound in ["funds", "disabled"]: _funds_rejected = true

# Simulation refusals keep their raw words until P2.3a2, so their sound is read off them.
static func refusal_sound(error: String) -> String:
	return "funds" if error == FUNDS_ERROR else "error"

func update(state: Dictionary) -> Array[Dictionary]:
	var requests: Array[Dictionary] = _queued.duplicate()
	_queued.clear()
	var current: Dictionary = _records(state)
	var teams: Dictionary = _teams(state)
	_tick = state.get("tick", 0)
	_rows = state.units
	var match_state: Variant = state.get("match")
	var status: String = match_state.status if match_state is Dictionary else ""
	if _has_previous:
		for step: Dictionary in _pending:
			_consume(step, current, teams, requests)
			_consumed.append(step.tick)
		if _consumed.size() > MAX_CONSUMED: _consumed = _consumed.slice(-MAX_CONSUMED)
		_placements(current, status, requests)
		_triggers(state, current, status)
	if _funds_rejected: announcer.request("insufficient_funds", _tick)
	_funds_rejected = false
	_was_low_power = _low_power(state)
	_pending.clear()
	for id: Variant in _last_shot.keys():
		if not current.has(id) and _rows.index_of(id) == -1:
			_last_shot.erase(id)
			_last_play.erase(id)
	_previous = current
	_previous_rows = _rows
	_previous_status = status
	_has_previous = true
	return requests

func order_voice(payload: Dictionary, busy: bool) -> String:
	var line: String = UnitVoice.ORDER_LINE.get(payload.get("type"), "")
	if busy or line.is_empty(): return ""
	for id: int in UnitVoice.speakers(payload):
		var i: int = _rows.index_of(id)
		if i == -1 or _rows.owner[i] != _local_player: continue
		var role: String = UnitVoice.role(_rows.kinds[_rows.kind[i]])
		if line in UnitVoice.LINES[role]: return UnitVoice.path(role, line, _rng.randi_range(1, UnitVoice.VARIANTS))
	return ""

func reset() -> void:
	_pending.clear()
	_queued.clear()
	_consumed.clear()
	_last_shot.clear()
	_last_play.clear()
	_own_hit = {}
	_allied_hit = {}
	_alert = ""
	_alert_tick = -1
	_tick = 0
	announcer.clear()
	_funds_rejected = false
	_was_low_power = false
	_previous = {}
	_previous_rows = ViewRows.new()
	_rows = ViewRows.new()
	_previous_status = ""
	_has_previous = false
	_last_collected = -1

func _records(state: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for building: Dictionary in state.get("buildings", []): records[building.id] = _building_record(building)
	return records

static func _building_record(building: Dictionary) -> Dictionary:
	var footprint: Vector2i = Registry.kind(building.kind).get("footprint", Vector2i.ONE)
	return {"kind": building.kind, "owner": building.owner, "position": Vector2(building.origin[0], building.origin[1]) + Vector2(footprint) / 2.0, "tier": 0, "building": true, "completed": building.get("completed", true), "hole": building.has("rebuild"), "site": building.has("hole_id"), "queue": building.get("queue", [])}

func _lookup(id: int, current: Dictionary) -> Dictionary:
	if current.has(id): return current[id]
	var unit: Dictionary = _unit_record(_rows, id)
	if not unit.is_empty(): return unit
	if _previous.has(id): return _previous[id]
	return _unit_record(_previous_rows, id)

# The kind is read through the rows' own table: its indices differ between ticks.
func _unit_record(rows: RefCounted, id: int) -> Dictionary:
	var i: int = rows.index_of(id)
	if i == -1: return {}
	return {"kind": rows.kinds[rows.kind[i]], "owner": rows.owner[i], "position": Vector2(rows.x[i], rows.y[i]), "tier": rows.tier[i], "building": false, "completed": true, "hole": false, "site": false, "queue": []}

func _consume(step: Dictionary, current: Dictionary, teams: Dictionary, requests: Array[Dictionary]) -> void:
	for event: Dictionary in step.events:
		if event.type == "shot": _shot(event, current, teams, requests)
		elif event.type == "death": _death(event, current, requests)
	for result: Dictionary in step.results:
		if result.player != _local_player or result.ok: continue
		if result.error == FUNDS_ERROR: announcer.request("insufficient_funds", result.tick)
		else: requests.append(ui_request("error"))

# Any building that is not a rebuild hole, defences included (not `counts_for_victory`); an ally is on the local team.
func _base_hit(record: Dictionary, teams: Dictionary, allied: bool) -> bool:
	if record.is_empty() or not record.building or record.hole: return false
	if not allied: return record.owner == _local_player
	return record.owner != _local_player and teams.has(record.owner) and teams.get(record.owner) == teams.get(_local_player)

func _own_base(id: int, current: Dictionary) -> bool:
	return _base_hit(_lookup(id, current), {}, false)

# The pump copies the target's row onto the shot: a site can be placed, hit and gone between two displayed views.
func _base_attack(event: Dictionary, current: Dictionary, teams: Dictionary) -> void:
	var target: Dictionary = _building_record(event.target_building) if event.has("target_building") else _lookup(event.target_id, current)
	var own: bool = _base_hit(target, teams, false)
	if not own and not _base_hit(target, teams, true): return
	var hit := {"tick": event.tick, "position": target.position}
	if own:
		announcer.request("base_under_attack", event.tick)
		_own_hit = hit
	else:
		announcer.request("allied_base_under_attack", event.tick)
		_allied_hit = hit
	if event.tick > _alert_tick or (own and event.tick == _alert_tick):
		_alert = "Base under attack" if own else "Allied base under attack"
		_alert_tick = event.tick

# Where Space jumps: the own base while its voice is still fresh, else the newest hit, any age; null before the first.
func last_attack() -> Variant:
	if not _own_hit.is_empty() and _tick - _own_hit.tick < Announcer.COOLDOWN_TICKS.base_under_attack: return _own_hit.position
	var newest: Dictionary = _own_hit if _allied_hit.is_empty() or (not _own_hit.is_empty() and _own_hit.tick >= _allied_hit.tick) else _allied_hit
	return newest.get("position")

func take_alert() -> String:
	var text: String = _alert
	_alert = ""
	_alert_tick = -1
	return text

func _shot(event: Dictionary, current: Dictionary, teams: Dictionary, requests: Array[Dictionary]) -> void:
	_base_attack(event, current, teams)
	var attacker: Dictionary = _lookup(event.attacker_id, current)
	if attacker.is_empty() or event.splash: return
	var weapon: String = Cues.weapon_id(attacker.kind, attacker.tier)
	var cue: String = Cues.shot_cue(weapon, Cues.faction(attacker.kind))
	var definition: Dictionary = Shared.WEAPONS.get(weapon, {})
	var last: int = _last_shot.get(event.attacker_id, -1000000)
	_last_shot[event.attacker_id] = event.tick
	if cue.is_empty(): return
	var new_burst: bool = event.tick - last > definition.delay_ticks + 1
	var held: bool = event.tick - _last_play.get(event.attacker_id, -1000000) < Cues.hold_ticks(cue)
	# shortcut: a hold starts even when the player drops the voice (cap, distance), so a shooter can stay silent up to one hold; feed slots back if that is heard.
	if (new_burst or not Cues.CUES[cue].get("burst", false)) and not held:
		_last_play[event.attacker_id] = event.tick
		requests.append(_world(cue, attacker.position))
	var target: Dictionary = _lookup(event.target_id, current)
	if not definition.affects.is_empty() and not target.is_empty(): requests.append(_world("impact", target.position))

func _death(event: Dictionary, current: Dictionary, requests: Array[Dictionary]) -> void:
	var dead: Dictionary = _lookup(event.object_id, current)
	if dead.is_empty(): return
	if _own_base(event.object_id, current): announcer.request("building_lost", event.tick)
	var cue: String = Cues.death_cue(dead.kind, dead.building)
	var request: Dictionary = _world(cue, dead.position)
	if dead.building: request.sound = Cues.building_sound(dead.kind)
	var jitter: float = Cues.CUES[cue].jitter
	if jitter > 0.0: request.pitch = 1.0 + _rng.randf_range(-jitter, jitter)
	requests.append(request)

func _placements(current: Dictionary, status: String, requests: Array[Dictionary]) -> void:
	if status != "ongoing" or _previous_status != "ongoing": return
	for id: Variant in current:
		var record: Dictionary = current[id]
		if record.building and record.owner == _local_player and not record.hole and not record.site and not _previous.has(id):
			requests.append(ui_request("placement"))

func _world(cue: String, position: Vector2) -> Dictionary:
	return {"cue": cue, "sound": Cues.sound(cue), "pitch": Cues.pitch(cue), "position": position}

func ui_request(cue: String) -> Dictionary:
	return {"cue": cue, "sound": Cues.sound(cue), "pitch": Cues.pitch(cue), "position": null}

func _teams(state: Dictionary) -> Dictionary:
	var teams: Dictionary = {}
	for row: Dictionary in state.get("players", []): teams[row.id] = row.team
	return teams

func _low_power(state: Dictionary) -> bool:
	for row: Dictionary in state.get("players", []):
		if row.id == _local_player: return row.power_demand > row.power_supply
	return false

func _triggers(state: Dictionary, current: Dictionary, status: String) -> void:
	if status != "ongoing" and not (status == "won" and _previous_status == "ongoing"): return
	var tick: int = state.get("tick", 0)
	if status == "won":
		announcer.clear()
		announcer.request("victory" if state.match.winner == _teams(state).get(_local_player) else "defeat", tick)
		return
	if _previous_status != "ongoing": return
	if _low_power(state) and not _was_low_power: announcer.request("low_power", tick)
	for id: Variant in current:
		var record: Dictionary = current[id]
		if not record.building or record.owner != _local_player or not _previous.has(id): continue
		var before: Dictionary = _previous[id]
		if record.completed and not before.completed: announcer.request("construction_complete", tick)
		if _unit_ready(before, record): announcer.request("unit_ready", tick)

func _unit_ready(before: Dictionary, record: Dictionary) -> bool:
	if before.queue.is_empty(): return false
	var head: Dictionary = before.queue[0]
	for entry: Dictionary in record.queue:
		if entry.id == head.id: return false
	for i: int in _rows.size():
		if _rows.owner[i] == _local_player and _rows.kinds[_rows.kind[i]] == head.kind and _previous_rows.index_of(_rows.id[i]) == -1: return true
	return false
