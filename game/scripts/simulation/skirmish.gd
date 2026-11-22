extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Definitions = preload("res://scripts/simulation/economy_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

const START_CREDITS: int = 10000
const DECISION_TICKS: int = 30
const DEFENCE_RADIUS: float = 10.0
const FIRST_WAVE_TICK: int = 5400
const WAVE_GAPS: Array[int] = [2700, 2700, 1800]
const WAVE_WAIT: int = 1800
const WAVE_SIZES: Array[int] = [8, 12, 16, 20, 24, 28, 32]
const WAVE0_UNITS: int = 16
const DEF_UNITS: int = 4
const DEF_REACH: float = 8.0
const ROUTE_STEP: float = 8.0
const DEFENCE_STRIDE: int = 7
const RALLY_RADIUS: float = 6.0
const DISTANCE_STEP: float = 4.0
const DETOUR_REACH: float = 10.0
const DETOUR_CALM: int = 90
const LET_GO_TICKS: int = 300
const HOLD_LAPSE: int = 1800
const BOT_META := &"skirmish_bot"
const BOT_TEAM_META := &"skirmish_bot_team"
const MAP_PATH := "res://data/maps/skirmish.json"

static var _skirmish_map: Dictionary = {}

# Cost per unit: a quantity order (Militia) pays for several units at once.
static func unit_cost(kind: String) -> int:
	var row: Dictionary = Registry.kind(kind)
	@warning_ignore("integer_division")
	return int(row.get("cost", 0)) / int(row.get("quantity", 1))

# Integer mean over the faction's build list, never scaled.
static func faction_unit_cost(faction_id: String) -> int:
	var kinds: Array = []
	var producers: Dictionary = Registry.faction(faction_id).units_for
	for producer: String in producers: kinds.append_array(producers[producer])
	@warning_ignore("integer_division")
	return _cost_sum(kinds) / kinds.size()

static func team_memory(seat_or_sim: RefCounted, team: int) -> Dictionary:
	return _real(seat_or_sim).get_meta(BOT_TEAM_META, {}).get(team, {}).duplicate(true)

static func default_faction() -> String:
	return Registry.Factions.DEFAULT_FACTION

static func build_order(faction: String) -> Array:
	return Registry.faction(faction).build_order

static func unit_for(faction: String, producer: String, owned: Array = []) -> String:
	var units: Array = Registry.faction(faction).units_for.get(producer, [])
	var pick: String = ""
	for kind: String in units:
		if pick.is_empty() or owned.count(kind) < owned.count(pick): pick = kind
	return pick

static func origin(kind: String, player: int) -> Vector2i:
	return MapData.slot(_default_map(), player, kind)

static func freeze_map() -> void:
	_default_map().make_read_only()

static func map_frozen() -> bool:
	return _skirmish_map.is_read_only()

static func _default_map() -> Dictionary:
	if _skirmish_map.is_empty(): _skirmish_map = MapData.load(MAP_PATH)
	return _skirmish_map

static func _slot(sim: RefCounted, kind: String, player: int) -> Vector2i:
	var map: Dictionary = sim.map_data()
	return MapData.slot(map if not map.is_empty() else _default_map(), player, kind)

static func create(with_match: bool = true, second_controller: String = "human", factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH, map_path: String = MAP_PATH, starts: Array[int] = [], seat_count: int = 2) -> Simulation:
	var ids: Array[int] = []
	var seats: Array[Dictionary] = []
	for seat in range(1, seat_count + 1):
		ids.append(seat)
		seats.append({"seat": seat, "team": seat, "controller": "human" if seat == 1 else second_controller, "credits": START_CREDITS})
	for seat in seats:
		if factions.has(seat.seat): seat.faction = factions[seat.seat]
		seat.defer = factions.is_empty()
	var map: Dictionary = _default_map() if map_path == MAP_PATH else MapData.load(map_path)
	if not starts.is_empty():
		map = MapData.with_starts(map, starts)
		if map.is_empty(): push_error("Chosen starts not on map: " + str(starts))
	var sim: Simulation = MapData.create(map, seats)
	if not with_match: return sim
	if factions.is_empty(): sim.begin_setup(ids)
	else: sim.start_match(ids)
	return sim

static func issue_opponent(sim: RefCounted, player: int = 2, attack_tick: int = FIRST_WAVE_TICK) -> void:
	issue_opponents(sim, [player], attack_tick)

static func issue_opponents(sim: RefCounted, players: Array[int], attack_tick: int = FIRST_WAVE_TICK) -> void:
	for player in players:
		if not decides(sim.tick(), player): continue
		var zone: int = Profiler.begin()
		decide(sim, player, attack_tick)
		Profiler.end(&"opponent.decide", zone)

# Seat k decides on ticks k, k + 30, ...: six seats on one tick made the team match's worst tick.
static func decides(tick: int, player: int) -> bool:
	return tick % DECISION_TICKS == player % DECISION_TICKS

static func next_decision(tick: int, player: int) -> int:
	return tick + 1 + posmod(player - tick - 1, DECISION_TICKS)

static func decide(sim: RefCounted, player: int, attack_tick: int = FIRST_WAVE_TICK) -> void:
	_decide(sim, player, attack_tick, _real(sim).bot_state())

# A seat wrapper or command recorder is rebuilt every decision; memory and state live on the simulation.
static func _real(seat_or_sim: RefCounted) -> RefCounted:
	return seat_or_sim.simulation() if seat_or_sim.has_method("simulation") else seat_or_sim

static func _decide(sim: RefCounted, player: int, attack_tick: int, state: Dictionary) -> void:
	var sequence: int = -1
	for entry: Variant in state.last_sequences:
		if entry.player == player: sequence = entry.sequence
	var credits: int = 0
	for entry: Dictionary in state.players:
		if entry.id == player: credits = entry.credits
	var teams := {}
	for entry: Dictionary in state.players: teams[entry.id] = entry.team
	var ctx := {"sim": sim, "player": player, "tick": state.tick, "sequence": sequence, "credits": credits, "teams": teams}
	_bot(sim, player)
	var wave_clock: Dictionary = _team_entry(sim, teams.get(player, player), attack_tick)
	var buildings: Array = state.buildings.filter(func(building: Dictionary) -> bool: return building.owner == player)
	var faction: String = _faction(state, player)
	_build(ctx, state, buildings, faction)
	_produce(ctx, state, buildings, faction, wave_clock)
	var defending: Dictionary = _defend(ctx, state, buildings)
	if wave_clock.wave > 0 or state.tick >= wave_clock.due: _attack(ctx, state, defending, wave_clock)
	wave_clock.prev = state.tick

static func _send(ctx: Dictionary, payload: Dictionary) -> bool:
	payload.tick = ctx.tick
	payload.player = ctx.player
	payload.sequence = ctx.sequence + 1
	if not ctx.sim.issue_command(payload).ok: return false
	ctx.sequence += 1
	return true

static func _build(ctx: Dictionary, state: Dictionary, buildings: Array, faction: String) -> void:
	var builder: int = -1
	for unit: Dictionary in state.entities:
		if unit.owner == ctx.player and Registry.is_builder(unit.kind) and not unit.has("hole_id"):
			builder = unit.id
			break
	if builder == -1: return
	for building: Variant in buildings:
		if building.completed or building.has("hole_id"): continue
		if building.builder_id == null: _send(ctx, {"type": "resume_build", "builder_id": builder, "building_id": building.id})
		return
	var kind: String = _first_missing(buildings, faction)
	if kind.is_empty(): return
	var cost: int = Definitions.building(kind).cost
	var site: Vector2i = _slot(ctx.sim, kind, ctx.player)
	if ctx.credits >= cost and _send(ctx, {"type": "build", "builder_id": builder, "building_kind": kind, "origin": [site.x, site.y]}): ctx.credits -= cost

static func _first_missing(buildings: Array, faction: String) -> String:
	for kind: String in build_order(faction):
		if not buildings.any(func(building: Dictionary) -> bool: return building.kind == kind or building.get("rebuild", {}).get("kind") == kind): return kind
	return ""

static func _produce(ctx: Dictionary, state: Dictionary, buildings: Array, faction: String, clock: Dictionary) -> void:
	var mine: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == ctx.player and not unit.has("hole_id"))
	var replace_builder: bool = not mine.any(func(unit: Dictionary) -> bool: return Registry.is_builder(unit.kind))
	var has_builder: bool = not replace_builder
	var rest: Array = []
	var start_unit: String = Registry.faction(faction).start_unit
	var per_depot: int = Registry.faction(faction).bot_collectors_per_supply_center
	var depots: int = buildings.filter(func(building: Dictionary) -> bool: return building.completed and not building.has("hole_id") and Registry.kind(building.kind).receives_supply).size()
	var owned: Array = mine.map(func(unit: Dictionary) -> String: return unit.kind)
	var queued: Array = []
	for building: Variant in buildings: queued.append_array(building.queue.map(func(entry: Dictionary) -> String: return entry.kind))
	for building: Variant in buildings:
		if not building.completed or not building.queue.is_empty(): continue
		var row: Dictionary = Registry.kind(building.kind)
		var kind: String = unit_for(faction, building.kind, owned)
		var collector: String = _collector_kind(row)
		if row.produces.has(start_unit) and replace_builder: kind = start_unit
		elif not collector.is_empty() and owned.count(collector) + queued.count(collector) < per_depot * depots: kind = collector
		elif clock.wave > 0:
			rest.append(building)
			continue
		if kind.is_empty(): continue
		_buy(ctx, building, kind, owned)
		if kind == start_unit: replace_builder = false
	if clock.wave > 0: _spend_rest(ctx, rest, buildings, faction, owned, queued, has_builder)

static func _buy(ctx: Dictionary, building: Dictionary, kind: String, owned: Array) -> bool:
	var cost: int = Definitions.unit(kind).cost
	if ctx.credits < cost or not _send(ctx, {"type": "produce", "building_id": building.id, "unit_kind": kind}): return false
	ctx.credits -= cost
	owned.append(kind)
	return true

# BR7, from wave 1: an idle factory holds the credits while vehicles are short of the faction's share of army value, and a lost factory is saved for while the builder lives; either hold lapses after HOLD_LAPSE until a factory buys again.
static func _spend_rest(ctx: Dictionary, rest: Array, buildings: Array, faction: String, owned: Array, queued: Array, has_builder: bool) -> void:
	var bot: Dictionary = _bot(ctx.sim, ctx.player)
	var share: int = Registry.faction(faction).bot_vehicle_share
	var army: int = 0
	var vehicles: int = 0
	# A queued order is worth its full price: a quantity order yields several units.
	var priced: Array = owned.map(func(kind: String) -> Array: return [kind, unit_cost(kind)]) + queued.map(func(kind: String) -> Array: return [kind, Definitions.unit(kind).cost])
	for entry: Array in priced:
		if not _is_army(entry[0]): continue
		army += entry[1]
		if _is_vehicle(entry[0]): vehicles += entry[1]
	var lapsed: bool = bot.get("hold_lapsed", false)
	var held: bool = not lapsed and has_builder and _is_factory(faction, _first_missing(buildings, faction))
	var bought := {}
	for building: Dictionary in rest:
		if held or lapsed or vehicles * 100 >= share * army: break
		if not _is_factory(faction, building.kind): continue
		var pick: String = unit_for(faction, building.kind, owned)
		if not _buy(ctx, building, pick, owned):
			held = true
			break
		army += Definitions.unit(pick).cost
		vehicles += Definitions.unit(pick).cost
		bought[building.id] = true
		bot.erase("hold_since")
	if held:
		var since: int = bot.get_or_add("hold_since", ctx.tick)
		if ctx.tick - since < HOLD_LAPSE: return
		bot.hold_lapsed = true
	bot.erase("hold_since")
	for building: Dictionary in rest:
		if bought.has(building.id): continue
		var kind: String = unit_for(faction, building.kind, owned)
		if not kind.is_empty() and _buy(ctx, building, kind, owned) and _is_factory(faction, building.kind): bot.hold_lapsed = false

static func _is_army(kind: String) -> bool:
	return not Registry.is_builder(kind) and Registry.collects(kind).is_empty()

static func _is_vehicle(kind: String) -> bool:
	return Registry.kind(kind).get("class", "") == "vehicle"

static func _is_factory(faction: String, kind: String) -> bool:
	return Registry.faction(faction).units_for.get(kind, []).any(_is_vehicle)

static func _collector_kind(row: Dictionary) -> String:
	if not row.receives_supply: return ""
	for kind: String in row.produces:
		if not Registry.collects(kind).is_empty(): return kind
	return ""

static func _faction(state: Dictionary, player: int) -> String:
	for entry: Dictionary in state.players:
		if entry.id == player: return entry.get("faction", Registry.Factions.DEFAULT_FACTION)
	return Registry.Factions.DEFAULT_FACTION

static func _attack(ctx: Dictionary, state: Dictionary, skip: Dictionary, clock: Dictionary) -> void:
	var enemies: Array = state.entities.filter(func(unit: Dictionary) -> bool: return _hostile(ctx, unit.owner) and not Registry.air_kinds.has(unit.kind) and not unit.has("container_id"))
	enemies.append_array(state.buildings.filter(func(building: Dictionary) -> bool: return _hostile(ctx, building.owner) and not Combat.masked(building)))
	var mine := {}
	for unit: Dictionary in state.entities:
		if unit.owner == ctx.player: mine[unit.id] = unit
	var bot: Dictionary = _bot(ctx.sim, ctx.player)
	_drive_waves(ctx, bot, mine, enemies, skip, clock)
	_gather(ctx, state, bot, mine, enemies, skip, clock)

static func _memory(seat_or_sim: RefCounted, key: StringName) -> Dictionary:
	var sim: RefCounted = _real(seat_or_sim)
	if not sim.has_meta(key): sim.set_meta(key, {})
	return sim.get_meta(key)

# Creating the entry is what makes a seat a live bot, so it happens before any gate.
static func _bot(seat_or_sim: RefCounted, player: int) -> Dictionary:
	return _memory(seat_or_sim, BOT_META).get_or_add(player, {"waves": []})

# left_units is -1 after wave 0: only the first wave has a unit cap.
static func _team_entry(seat_or_sim: RefCounted, team: int, first_due: int) -> Dictionary:
	return _memory(seat_or_sim, BOT_TEAM_META).get_or_add(team, {"wave": 0, "due": first_due, "prev": -1, "released_by": "", "launched_at": -1, "objective": null, "attacked_at": {}, "left_cost": 0, "left_units": 0, "joiners": []})

static func _drive_waves(ctx: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, skip: Dictionary, clock: Dictionary) -> void:
	var live: Array = []
	for wave: Dictionary in bot.waves:
		var hurt: Variant = _hurt(wave, mine)
		wave.ids = wave.ids.filter(func(id: int) -> bool: return mine.has(id))
		if wave.ids.is_empty(): continue
		var centre: Vector2 = _centre(wave.ids, mine)
		if hurt != null: wave.hit_at = ctx.tick
		_end_detour(wave, mine, enemies, ctx.tick)
		if hurt != null and wave.detour == null: wave.detour = _detour(wave, centre if hurt.is_empty() else _centre(hurt, mine), enemies, ctx.tick)
		var hits: Array = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.id == wave.target)
		var switched: bool = false
		if wave.detour != null or hits.is_empty() or wave.diverted:
			var target: Variant = wave.detour if wave.detour != null else _follow(clock, centre, enemies)
			wave.diverted = wave.detour != null
			if target == null: continue
			switched = not hits.is_empty() and target != wave.target
			wave.target = target
		live.append(wave)
		var pool: Array = wave.ids.filter(func(id: int) -> bool: return not skip.has(id) and (switched or _idle(mine[id])))
		if not pool.is_empty(): _send(ctx, {"type": "attack", "entity_ids": pool, "target_id": wave.target})
	bot.waves = live

static func _new_wave(ids: Array, target: Variant, mine: Dictionary) -> Dictionary:
	return {"ids": ids, "target": target, "detour": null, "diverted": false, "hit_at": -1, "let_go": {}, "hp": _hp_of(ids, mine)}

static func _hp_of(ids: Array, mine: Dictionary) -> Dictionary:
	var hp := {}
	for id: int in ids: hp[id] = mine[id].hp
	return hp

static func _hurt(wave: Dictionary, mine: Dictionary) -> Variant:
	var before: Dictionary = wave.hp
	var hurt: Array = before.keys().filter(func(id: int) -> bool: return mine.has(id) and mine[id].hp < before[id])
	var died: bool = before.keys().any(func(id: int) -> bool: return not mine.has(id))
	wave.hp = _hp_of(wave.ids.filter(func(id: int) -> bool: return mine.has(id)), mine)
	return hurt if died or not hurt.is_empty() else null

static func _end_detour(wave: Dictionary, mine: Dictionary, enemies: Array, tick: int) -> void:
	if wave.detour == null: return
	var found: Array = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.id == wave.detour)
	if found.is_empty():
		wave.detour = null
	elif not wave.ids.any(func(id: int) -> bool: return _reach_squared(mine[id].position[0], mine[id].position[1], found[0]) <= DETOUR_REACH * DETOUR_REACH):
		wave.let_go[wave.detour] = tick
		wave.detour = null
	elif tick - wave.hit_at >= DETOUR_CALM:
		wave.detour = null

static func _detour(wave: Dictionary, at: Vector2, enemies: Array, tick: int) -> Variant:
	return _best(at, enemies.filter(func(enemy: Dictionary) -> bool:
		if Registry.kind(enemy.kind).get("weapon", "").is_empty(): return false
		if wave.let_go.has(enemy.id) and tick - wave.let_go[enemy.id] < LET_GO_TICKS: return false
		return _reach_squared(at.x, at.y, enemy) <= DETOUR_REACH * DETOUR_REACH))

# Squared distance from a point to an enemy unit or to the nearest cell of an enemy building, on plain floats.
static func _reach_squared(x: float, y: float, enemy: Dictionary) -> float:
	var near: Array = enemy.get("position", [])
	if enemy.has("origin"):
		var size: Vector2i = Definitions.building(enemy.kind).footprint
		near = [clampf(x, enemy.origin[0], enemy.origin[0] + size.x), clampf(y, enemy.origin[1], enemy.origin[1] + size.y)]
	return (x - near[0]) * (x - near[0]) + (y - near[1]) * (y - near[1])

# The team objective while it stands; a dead one is replaced once, by the first wave that notices.
static func _follow(clock: Dictionary, centre: Vector2, enemies: Array) -> Variant:
	if enemies.any(func(enemy: Dictionary) -> bool: return enemy.id == clock.objective): return clock.objective
	var target: Variant = _pick(centre, enemies)
	if target != null: clock.objective = target
	return target

static func _gather(ctx: Dictionary, state: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, skip: Dictionary, clock: Dictionary) -> void:
	var waving := {}
	for wave: Dictionary in bot.waves:
		for id: int in wave.ids: waving[id] = true
	var rally: Vector2 = _rally(ctx.sim, ctx.player)
	var ready: Array = []
	var walking: Array = []
	for id: int in mine:
		if waving.has(id) or skip.has(id) or not _idle(mine[id]): continue
		(ready if _at_rally(mine[id].position, rally) else walking).append(id)
	if not walking.is_empty(): _send(ctx, {"type": "move", "entity_ids": walking, "target": [rally.x, rally.y]})
	_wave(ctx, state, bot, mine, enemies, ready, clock)

static func _wave(ctx: Dictionary, state: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, ready: Array, clock: Dictionary) -> void:
	var live: Array[int] = _live_bots(ctx, state)
	if not live.has(ctx.player): return
	if clock.joiners.has(ctx.player): _add_to_wave(ctx, bot, mine, enemies, ready, clock, live)
	elif ctx.tick >= clock.due: _form(ctx, state, bot, mine, enemies, ready, clock, live)

# The first live bot to see the team's ready cost reach the target (or the wait cap) forms the wave; the others join at their next decision.
static func _form(ctx: Dictionary, state: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, ready: Array, clock: Dictionary, live: Array[int]) -> void:
	var kinds: Array = ready.map(func(id: int) -> String: return mine[id].kind)
	kinds.append_array(_mates_ready(ctx, state, live))
	var worth: int = _cost_sum(kinds)
	var capped: bool = ctx.tick >= clock.due + WAVE_WAIT and not kinds.is_empty()
	# Defences only raise the target, so a wave short of the plain one waits without the scan.
	if worth < _wave_target(clock.wave, state, live, 0) and not capped: return
	var buildings: Array = enemies.filter(_is_building)
	var order: Array = _victims(buildings, clock)
	if order.is_empty(): return
	var rally: Vector2 = _mean_rally(ctx, live)
	var objective: Variant = _pick(rally, buildings.filter(func(building: Dictionary) -> bool: return building.owner == order[0]))
	var defences: PackedFloat64Array = _defence_rects(_armed(buildings))
	var guards: int = _guard_count(rally, _row(buildings, objective), defences, false)
	var target: int = _wave_target(clock.wave, state, live, guards)
	if worth < target and not capped: return
	if worth < target and guards > 0: objective = _softer(rally, order, buildings, defences, objective)
	@warning_ignore("integer_division")
	var share: int = target / live.size()
	@warning_ignore("integer_division")
	var limit: int = WAVE0_UNITS / live.size() if clock.wave == 0 else ready.size()
	var take: Array = _take(ready, mine, share, limit)
	if not take.is_empty():
		if not _send(ctx, {"type": "attack", "entity_ids": take, "target_id": objective}): return
		bot.waves.append(_new_wave(take, objective, mine))
	clock.released_by = "wait_cap" if worth < target else ("timer" if clock.prev < clock.due else "size")
	clock.launched_at = ctx.tick
	clock.objective = objective
	clock.attacked_at[_row(buildings, objective).owner] = ctx.tick
	clock.left_cost = maxi(target - _cost_sum(take.map(func(id: int) -> String: return mine[id].kind)), 0)
	clock.left_units = WAVE0_UNITS - take.size() if clock.wave == 0 else -1
	clock.joiners = _joiners(ctx, live)
	clock.due = ctx.tick + WAVE_GAPS[mini(clock.wave, WAVE_GAPS.size() - 1)]
	clock.wave += 1

# A joiner takes its share of what the launcher left; the last live one takes all of it.
static func _add_to_wave(ctx: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, ready: Array, clock: Dictionary, live: Array[int]) -> void:
	clock.joiners = clock.joiners.filter(func(player: int) -> bool: return live.has(player))
	var remaining: int = clock.joiners.size()
	clock.joiners.erase(ctx.player)
	@warning_ignore("integer_division")
	var share: int = clock.left_cost / remaining
	@warning_ignore("integer_division")
	var limit: int = ready.size() if clock.left_units < 0 else clock.left_units / remaining
	var take: Array = _take(ready, mine, share, limit)
	if take.is_empty(): return
	var objective: Variant = _follow(clock, _centre(take, mine), enemies)
	if objective == null or not _send(ctx, {"type": "attack", "entity_ids": take, "target_id": objective}): return
	bot.waves.append(_new_wave(take, objective, mine))
	clock.left_cost = maxi(clock.left_cost - _cost_sum(take.map(func(id: int) -> String: return mine[id].kind)), 0)
	if clock.left_units >= 0: clock.left_units -= take.size()

static func _joiners(ctx: Dictionary, live: Array[int]) -> Array:
	var others: Array = live.filter(func(player: int) -> bool: return player != ctx.player)
	others.sort_custom(func(a: int, b: int) -> bool: return next_decision(ctx.tick, a) < next_decision(ctx.tick, b))
	return others

# Ready units of the live teammates, counted before they decide; their own _defend may still take some at the join.
static func _mates_ready(ctx: Dictionary, state: Dictionary, live: Array[int]) -> Array:
	var rallies := {}
	var waving := {}
	for player: int in live:
		if player == ctx.player: continue
		rallies[player] = _rally(ctx.sim, player)
		for wave: Dictionary in _bot(ctx.sim, player).waves:
			for id: int in wave.ids: waving[id] = true
	var kinds: Array = []
	for unit: Dictionary in state.entities:
		if not rallies.has(unit.owner) or waving.has(unit.id) or not _idle(unit): continue
		if _at_rally(unit.position, rallies[unit.owner]): kinds.append(unit.kind)
	return kinds

static func _at_rally(position: Array, rally: Vector2) -> bool:
	var dx: float = position[0] - rally.x
	var dy: float = position[1] - rally.y
	return dx * dx + dy * dy <= RALLY_RADIUS * RALLY_RADIUS

# Enemies with a building that keeps them in the match, the one attacked least recently first (never: -1), ties lowest id.
static func _victims(buildings: Array, clock: Dictionary) -> Array:
	var owners: Array = []
	for building: Dictionary in buildings:
		if Registry.kind(building.kind).counts_for_victory and not owners.has(building.owner): owners.append(building.owner)
	owners.sort_custom(func(a: int, b: int) -> bool:
		var seen_a: int = clock.attacked_at.get(a, -1)
		var seen_b: int = clock.attacked_at.get(b, -1)
		return seen_a < seen_b or (seen_a == seen_b and a < b))
	return owners

static func _row(rows: Array, id: Variant) -> Dictionary:
	for row: Dictionary in rows:
		if row.id == id: return row
	return {}

static func _armed(buildings: Array) -> Array:
	return buildings.filter(func(building: Dictionary) -> bool: return building.completed and not Registry.kind(building.kind).get("weapon", "").is_empty())

# Per defence, DEFENCE_STRIDE floats: footprint min x, min y, max x, max y, centre x, centre y, route window.
static func _defence_rects(armed: Array) -> PackedFloat64Array:
	var rects := PackedFloat64Array()
	for defence: Dictionary in armed:
		var box: Vector2i = Definitions.building(defence.kind).footprint
		rects.append_array([defence.origin[0], defence.origin[1], defence.origin[0] + box.x, defence.origin[1] + box.y, defence.origin[0] + box.x / 2.0, defence.origin[1] + box.y / 2.0, DEF_REACH + sqrt(box.x * box.x + box.y * box.y) / 2.0 + 1.0])
	return rects

static func _rect_reach_squared(x: float, y: float, defences: PackedFloat64Array, at: int) -> float:
	var near_x: float = clampf(x, defences[at], defences[at + 2])
	var near_y: float = clampf(y, defences[at + 1], defences[at + 3])
	return (x - near_x) * (x - near_x) + (y - near_y) * (y - near_y)

static func _guard_count(rally: Vector2, goal: Dictionary, defences: PackedFloat64Array, stop_at_first: bool) -> int:
	if defences.is_empty(): return 0
	var size: Vector2i = Definitions.building(goal.kind).footprint
	var goal_x: float = goal.origin[0] + size.x / 2.0
	var goal_y: float = goal.origin[1] + size.y / 2.0
	var length: float = sqrt((goal_x - rally.x) * (goal_x - rally.x) + (goal_y - rally.y) * (goal_y - rally.y))
	var count: int = 0
	for at: int in range(0, defences.size(), DEFENCE_STRIDE):
		if not _guards(rally, goal_x, goal_y, length, defences, at): continue
		count += 1
		if stop_at_first: break
	return count

# A defence counts within DEF_REACH of the goal centre or of a point every ROUTE_STEP cells on the line of that length from the rally to it.
static func _guards(rally: Vector2, goal_x: float, goal_y: float, length: float, defences: PackedFloat64Array, at: int) -> bool:
	if _rect_reach_squared(goal_x, goal_y, defences, at) <= DEF_REACH * DEF_REACH: return true
	if length <= ROUTE_STEP: return false
	var centre_x: float = defences[at + 4]
	var centre_y: float = defences[at + 5]
	# A route point within reach of the footprint lies within reach plus half its diagonal of its centre, so farther steps cannot count; +1 absorbs rounding.
	var window: float = defences[at + 6]
	if absf((centre_x - rally.x) * (goal_y - rally.y) - (centre_y - rally.y) * (goal_x - rally.x)) > window * length: return false
	var near: float = ((centre_x - rally.x) * (goal_x - rally.x) + (centre_y - rally.y) * (goal_y - rally.y)) / length
	for step: int in range(maxi(ceili((near - window) / ROUTE_STEP), 1), floori((near + window) / ROUTE_STEP) + 1):
		var along: float = step * ROUTE_STEP
		if along >= length: return false
		if _rect_reach_squared(rally.x + (goal_x - rally.x) * along / length, rally.y + (goal_y - rally.y) * along / length, defences, at) <= DEF_REACH * DEF_REACH: return true
	return false

# The best building without a counted defence: the objective's player first, then the least recently attacked.
static func _softer(rally: Vector2, order: Array, buildings: Array, defences: PackedFloat64Array, objective: Variant) -> Variant:
	for owner: int in order:
		var open: Array = buildings.filter(func(building: Dictionary) -> bool: return building.owner == owner and _guard_count(rally, building, defences, true) == 0)
		if not open.is_empty(): return _best(rally, open)
	return objective

static func _mean_rally(ctx: Dictionary, live: Array[int]) -> Vector2:
	var sum := Vector2.ZERO
	for player: int in live: sum += _rally(ctx.sim, player)
	return sum / live.size()

# A seat is a live bot once it has decided and while it still owns a building that keeps it in the match.
static func _live_bots(ctx: Dictionary, state: Dictionary) -> Array[int]:
	var decided: Dictionary = _memory(ctx.sim, BOT_META)
	var live: Array[int] = []
	for entry: Dictionary in state.players:
		if ctx.teams[entry.id] != ctx.teams[ctx.player] or not decided.has(entry.id): continue
		if state.buildings.any(func(building: Dictionary) -> bool: return building.owner == entry.id and Registry.kind(building.kind).counts_for_victory): live.append(entry.id)
	return live

static func _wave_target(wave: int, state: Dictionary, live: Array[int], guards: int) -> int:
	var mean: int = 0
	for player in live: mean += faction_unit_cost(_faction(state, player))
	@warning_ignore("integer_division")
	return (WAVE_SIZES[mini(wave, WAVE_SIZES.size() - 1)] * live.size() + (DEF_UNITS * guards if wave > 0 else 0)) * (mean / live.size())

static func _cost_sum(kinds: Array) -> int:
	var sum: int = 0
	for kind: String in kinds: sum += unit_cost(kind)
	return sum

# Highest unit cost first, ties lowest id, until the summed cost first reaches the share.
static func _take(ready: Array, mine: Dictionary, share: int, limit: int) -> Array:
	var order: Array = ready.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var cost_a: int = unit_cost(mine[a].kind)
		var cost_b: int = unit_cost(mine[b].kind)
		return cost_a > cost_b or (cost_a == cost_b and a < b))
	var taken: Array = []
	var sum: int = 0
	for id: int in order:
		if sum >= share or taken.size() >= limit: break
		taken.append(id)
		sum += unit_cost(mine[id].kind)
	taken.sort()
	return taken

static func _rally(sim: RefCounted, player: int) -> Vector2:
	var map: Dictionary = sim.map_data()
	return Vector2(MapData.start_cell(map if not map.is_empty() else _default_map(), player)) + Vector2(0.5, 0.5)

static func _centre(ids: Array, mine: Dictionary) -> Vector2:
	var sum := Vector2.ZERO
	for id: int in ids: sum += Vector2(mine[id].position[0], mine[id].position[1])
	return sum / ids.size()

static func _hostile(ctx: Dictionary, owner: int) -> bool:
	return owner != ctx.player and ctx.teams.get(owner, 0) != ctx.teams.get(ctx.player, -1)

static func _idle(unit: Dictionary) -> bool:
	return unit.combat != null and unit.combat.mode == "guard" and unit.combat.target_id == null

static func _defend(ctx: Dictionary, state: Dictionary, buildings: Array) -> Dictionary:
	var intruders: Array = state.entities.filter(func(unit: Dictionary) -> bool:
		if not _hostile(ctx, unit.owner) or Registry.air_kinds.has(unit.kind) or unit.has("container_id"): return false
		var at := Vector2(unit.position[0], unit.position[1])
		return buildings.any(func(building: Dictionary) -> bool: return Combat.distance_squared(at, building) <= DEFENCE_RADIUS * DEFENCE_RADIUS))
	var sent := {}
	if intruders.is_empty(): return sent
	var groups := {}
	for unit: Dictionary in state.entities:
		if unit.owner != ctx.player or not _idle(unit): continue
		var target: Variant = _nearest(unit, intruders)
		if not groups.has(target): groups[target] = []
		groups[target].append(unit.id)
	var targets: Array = groups.keys()
	targets.sort()
	for target: Variant in targets:
		if not _send(ctx, {"type": "attack", "entity_ids": groups[target], "target_id": target}): continue
		for id: Variant in groups[target]: sent[id] = true
	return sent

static func _pick(position: Vector2, enemies: Array) -> Variant:
	var buildings: Array = enemies.filter(_is_building)
	return _best(position, enemies if buildings.is_empty() else buildings)

# Score = priority - one point per DISTANCE_STEP cells (min 1): the Zero Hour attack-priority rule, numbers in docs/reference/m7-verification-archive-research.md.
static func _best(position: Vector2, candidates: Array) -> Variant:
	var best: Variant = null
	var best_score: int = 0
	for enemy: Dictionary in candidates:
		var score: int = maxi(_priority(enemy.kind) - floori(sqrt(Combat.distance_squared(position, enemy)) / DISTANCE_STEP), 1)
		if best == null or score > best_score or (score == best_score and enemy.id < best):
			best = enemy.id
			best_score = score
	return best

static func _is_building(enemy: Dictionary) -> bool:
	return not Registry.kind(enemy.kind).has("class")

static func _priority(kind: String) -> int:
	var row: Dictionary = Registry.kind(kind)
	if Registry.is_builder(kind): return 28
	if row.has("class"): return 28 if row["class"] == "vehicle" else 27
	if not row.get("weapon", "").is_empty(): return 29
	var produces: Array = row.get("produces", [])
	if produces.any(Registry.is_builder): return 26
	return 27 if row.get("receives_supply", false) or row.get("power", 0) > 0 or not produces.is_empty() else 1

static func _nearest(unit: Dictionary, enemies: Array) -> int:
	var position := Vector2(unit.position[0], unit.position[1])
	var best: int = -1
	var best_distance: float = INF
	for enemy: Variant in enemies:
		var distance: float = Combat.distance_squared(position, enemy)
		if distance < best_distance or (distance == best_distance and enemy.id < best):
			best = enemy.id
			best_distance = distance
	return best
