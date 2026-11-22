extends SceneTree
# Bot lab probe: one headless match, one "BOTLAB <json>" row. Reads the simulation and drives the bots through Skirmish.issue_opponents; changes nothing.
# godot --headless --path game --script res://benchmarks/bot_lab.gd -- map=dry_wells starts=1,2 factions=usa,china bots=1,2 seed=0 cap=45000
# Arguments: map, starts (map start numbers, renumbered to seats 1..n), factions (one per seat), bots (seats a bot plays; the others idle),
# teams (one per seat, default 1..n), seed (0 keeps the built-in RNG start value), cap, label, tower (idle China seat that gets a power plant and one Rotary Gun Tower).
# winner is a team number (-1 for a draw or no result by the cap). Run it through tools/run_bot_lab.sh; tools/bot_lab_summary.py reads the rows.

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Fixture = preload("res://tests/economy_fixture.gd")

const MINUTE_TICKS: int = 1800
const SLOW_UNITS: int = 3

var _sim: Simulation
var _seats: Dictionary = {}
var _unit_wave: Dictionary = {}
var _wave_ids: Array = []
var _tower_id: int = -1
var _tower_died: int = -1
var _tower_shots: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	var code: int = 1
	if args.has("map") and args.has("starts") and args.has("factions") and args.has("bots"):
		var row: Dictionary = _play(args)
		if not row.is_empty():
			print("BOTLAB ", JSON.stringify(row))
			code = 0
	else:
		print("BOTLAB_ERROR needs map, starts, factions and bots")
	quit(code)

func _ints(text: String) -> Array[int]:
	var result: Array[int] = []
	for part: String in text.split(","):
		if not part.is_empty(): result.append(int(part))
	return result

func _play(args: Dictionary) -> Dictionary:
	var map: Dictionary = MapData.with_starts(MapData.load("res://data/maps/" + args.map + ".json"), _ints(args.starts))
	var factions: PackedStringArray = args.factions.split(",")
	if map.is_empty() or map.starts.size() != factions.size():
		print("BOTLAB_ERROR map or starts do not fit the factions")
		return {}
	var count: int = factions.size()
	var teams: Array[int] = _ints(args.get("teams", ""))
	if teams.is_empty():
		for k in count: teams.append(k + 1)
	var bots: Array[int] = _ints(args.bots)
	var seats: Array[Dictionary] = []
	var ids: Array[int] = []
	for k in count:
		ids.append(k + 1)
		seats.append({"seat": k + 1, "team": teams[k], "controller": "human", "faction": factions[k], "credits": Skirmish.START_CREDITS})
	_sim = MapData.create(map, seats)
	var seed_value: int = int(args.get("seed", "0"))
	if seed_value != 0:
		var value: int = (Simulation.RNG_SEED ^ (seed_value * 0x9E3779B1)) & 0xFFFFFFFF
		_sim._rng = value if value != 0 else 1
	_sim.set_hash_ring(false)
	_sim.start_match(ids)
	for seat: int in bots: _seats[seat] = _seat_row(seat, factions[seat - 1], teams[seat - 1])
	if args.has("tower") and not _place_tower(map, int(args.tower), factions[int(args.tower) - 1]): return {}
	_loop(bots, int(args.get("cap", "45000")))
	return _row(args, map, factions, teams, bots)

func _seat_row(seat: int, faction: String, team: int) -> Dictionary:
	return {"seat": seat, "faction": faction, "team": team, "waves": [], "cred_sum": 0, "cred_n": 0, "cred_min_sum": {}, "cred_min_n": {},
		"factory_up": false, "factory_had": false, "factory_lost": [], "factory_back": []}

func _place_tower(map: Dictionary, seat: int, faction: String) -> bool:
	if faction != "china":
		print("BOTLAB_ERROR the tower seat must be China")
		return false
	# The tower is powered (-3), so it needs the plant to fire; both stand on the seat's own start slots.
	Fixture.add_completed(_sim, seat, "china_power_plant", MapData.slot(map, seat, "china_power_plant"))
	_tower_id = Fixture.add_completed(_sim, seat, "china_defence", MapData.slot(map, seat, "china_defence"))
	return true

func _loop(bots: Array[int], cap: int) -> void:
	while _sim.tick() < cap and not _sim.match_over():
		var tick: int = _sim.tick()
		var deciding: Array[int] = bots.filter(func(seat: int) -> bool: return Skirmish.decides(tick, seat))
		var state: Dictionary = _sim.bot_state() if not deciding.is_empty() else {}
		for seat: int in deciding: _observe(state, _seats[seat], tick)
		Skirmish.issue_opponents(_sim, bots)
		if not deciding.is_empty(): _count_stops(tick)
		for seat: int in deciding: _record_new_waves(state, _seats[seat], tick)
		_sim.step()
		_watch_events(_sim.tick())

func _observe(state: Dictionary, row: Dictionary, tick: int) -> void:
	var credits: int = 0
	for player: Dictionary in state.players:
		if player.id == row.seat: credits = player.credits
	if _team_wave(row.team) > 0:
		row.cred_sum += credits
		row.cred_n += 1
	var minute: String = str(floori(tick / float(MINUTE_TICKS)))
	row.cred_min_sum[minute] = row.cred_min_sum.get(minute, 0) + credits
	row.cred_min_n[minute] = row.cred_min_n.get(minute, 0) + 1
	_observe_factory(state, row, tick)

func _observe_factory(state: Dictionary, row: Dictionary, tick: int) -> void:
	var up: bool = state.buildings.any(func(b: Dictionary) -> bool: return b.owner == row.seat and b.completed and not b.has("hole_id") and _is_factory(row.faction, b.kind))
	if up: row.factory_had = true
	if row.factory_up and not up: row.factory_lost.append(tick)
	if up and not row.factory_up and not row.factory_lost.is_empty() and row.factory_back.size() < row.factory_lost.size(): row.factory_back.append(tick)
	row.factory_up = up

# BR8's stop-go: every stop order naming a unit counts on its wave; read-only look at this tick's queued commands.
func _count_stops(tick: int) -> void:
	for command: Dictionary in _sim._pending:
		if command.type != "stop" or command.tick != tick: continue
		for id: int in command.entity_ids:
			var entry: Variant = _unit_wave.get(id)
			if entry != null: entry.stops += 1

func _team_wave(team: int) -> int:
	return int(Skirmish.team_memory(_sim, team).get("wave", 0))

# A wave record is marked once seen; bot memory lives outside the simulation state and its hash.
func _record_new_waves(state: Dictionary, row: Dictionary, tick: int) -> void:
	var units := {}
	for unit: Dictionary in state.entities: units[unit.id] = unit
	for wave: Dictionary in _sim.get_meta(Skirmish.BOT_META, {}).get(row.seat, {"waves": []}).waves:
		if wave.has("lab_seen"): continue
		wave["lab_seen"] = true
		var ids: Array = wave.ids.filter(func(id: int) -> bool: return units.has(id))
		var entry := {"uid": _wave_ids.size(), "wave": _team_wave(row.team) - 1, "tick": tick, "units": ids.size(), "kinds": {}, "value": 0, "veh_value": 0, "factory_up": row.factory_up,
			"launch": _spread(ids, units), "contact_tick": -1, "contact": null, "stops": 0}
		for id: int in ids:
			var kind: String = units[id].kind
			var value: int = Skirmish.unit_cost(kind)
			entry.kinds[kind] = entry.kinds.get(kind, 0) + 1
			entry.value += value
			if _is_vehicle(kind): entry.veh_value += value
			_unit_wave[id] = entry
		_wave_ids.append(ids)
		row.waves.append(entry)

# Distance from the centroid to the farthest unit, and to the mean position of the three slowest units.
func _spread(ids: Array, units: Dictionary) -> Variant:
	var alive: Array = ids.filter(func(id: int) -> bool: return units.has(id))
	if alive.is_empty(): return null
	var centre := Vector2.ZERO
	for id: int in alive: centre += _at(units[id])
	centre /= alive.size()
	var far: float = 0.0
	for id: int in alive: far = maxf(far, centre.distance_to(_at(units[id])))
	alive.sort_custom(func(a: int, b: int) -> bool: return _speed(units[a].kind) < _speed(units[b].kind) or (_speed(units[a].kind) == _speed(units[b].kind) and a < b))
	var slow: Array = alive.slice(0, SLOW_UNITS)
	var slow_centre := Vector2.ZERO
	for id: int in slow: slow_centre += _at(units[id])
	slow_centre /= slow.size()
	return {"n": alive.size(), "farthest": snappedf(far, 0.01), "slowest": snappedf(centre.distance_to(slow_centre), 0.01),
		"slow_units": slow.map(func(id: int) -> Array: return [units[id].kind, _speed(units[id].kind)])}

func _at(unit: Dictionary) -> Vector2:
	return Vector2(unit.position[0], unit.position[1])

func _speed(kind: String) -> float:
	return float(Registry.kind(kind).get("speed", 0.0))

func _watch_events(tick: int) -> void:
	var state: Dictionary = {}
	for event: Dictionary in _sim.combat_events():
		if event.type == "death" and event.object_id == _tower_id and _tower_died < 0:
			_tower_died = tick
		elif event.type == "shot" and event.damage > 0:
			if event.attacker_id == _tower_id: _tower_shots += 1
			for id: int in [event.attacker_id, event.target_id]:
				var entry: Variant = _unit_wave.get(id)
				if entry == null or entry.contact_tick >= 0: continue
				if state.is_empty(): state = _units_by_id()
				entry.contact_tick = tick
				entry.contact = _spread(_wave_ids[entry.uid], state)

func _units_by_id() -> Dictionary:
	var units := {}
	for unit: Dictionary in _sim.bot_state().entities: units[unit.id] = unit
	return units

func _row(args: Dictionary, map: Dictionary, factions: PackedStringArray, teams: Array[int], bots: Array[int]) -> Dictionary:
	var end: Dictionary = _sim.snapshot()
	var won: bool = end.match.status == "won"
	var idle: Array[Dictionary] = []
	for k in factions.size():
		if bots.has(k + 1): continue
		idle.append({"seat": k + 1, "faction": factions[k], "team": teams[k], "defeat_tick": end.tick if won and int(end.match.winner) != teams[k] else -1})
	var seats: Array = _seats.values()
	for seat: Dictionary in seats: _close_seat(seat)
	return {"label": args.get("label", ""), "map": args.map, "starts": args.starts, "factions": args.factions, "teams": teams, "bots": bots, "seed": int(args.get("seed", "0")),
		"cap": int(args.get("cap", "45000")), "end_tick": end.tick, "ended": end.match.status != "ongoing", "winner": int(end.match.winner) if won else -1, "idle": idle, "seats": seats,
		"tower": {"seat": int(args.tower), "died_tick": _tower_died, "shots": _tower_shots} if _tower_id >= 0 else null}

func _close_seat(seat: Dictionary) -> void:
	seat.credits_mean_after_wave0 = roundi(seat.cred_sum / float(seat.cred_n)) if seat.cred_n > 0 else -1
	var by_minute := {}
	for minute: String in seat.cred_min_sum: by_minute[minute] = roundi(seat.cred_min_sum[minute] / float(seat.cred_min_n[minute]))
	seat.credits_by_minute = by_minute
	for key: String in ["cred_sum", "cred_n", "cred_min_sum", "cred_min_n", "factory_up"]: seat.erase(key)

func _is_vehicle(kind: String) -> bool:
	return _is_army(kind) and Registry.kind(kind).get("class", "") == "vehicle"

func _is_army(kind: String) -> bool:
	return Registry.kind(kind).has("class") and not Registry.is_builder(kind) and Registry.collects(kind).is_empty()

func _is_factory(faction: String, kind: String) -> bool:
	return Registry.faction(faction).units_for.get(kind, []).any(_is_vehicle)
