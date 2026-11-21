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
const RALLY_RADIUS: float = 6.0
const DISTANCE_STEP: float = 4.0
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

static func create(with_match: bool = true, second_controller: String = "human", factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH, map_path: String = MAP_PATH, starts: Array[int] = []) -> Simulation:
	var seats: Array[Dictionary] = [
		{"seat": 1, "team": 1, "controller": "human", "credits": START_CREDITS},
		{"seat": 2, "team": 2, "controller": second_controller, "credits": START_CREDITS}]
	for seat in seats:
		if factions.has(seat.seat): seat.faction = factions[seat.seat]
		seat.defer = factions.is_empty()
	var map: Dictionary = _default_map() if map_path == MAP_PATH else MapData.load(map_path)
	if not starts.is_empty():
		map = MapData.with_starts(map, starts)
		if map.is_empty(): push_error("Chosen starts not on map: " + str(starts))
	var sim: Simulation = MapData.create(map, seats)
	if not with_match: return sim
	if factions.is_empty(): sim.begin_setup([1, 2] as Array[int])
	else: sim.start_match([1, 2] as Array[int])
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
	var bot: Dictionary = _bot(sim, player)
	var wave_clock: Dictionary = _team_entry(sim, teams.get(player, player), attack_tick)
	var buildings: Array = state.buildings.filter(func(building: Dictionary) -> bool: return building.owner == player)
	var faction: String = _faction(state, player)
	_build(ctx, state, buildings, faction)
	_produce(ctx, state, buildings, faction)
	var defending: Dictionary = _defend(ctx, state, buildings)
	if wave_clock.wave > 0 or state.tick >= wave_clock.due: _attack(ctx, state, defending, wave_clock)
	bot.prev = state.tick

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
	for kind: String in build_order(faction):
		if buildings.any(func(building: Dictionary) -> bool: return building.kind == kind or building.get("rebuild", {}).get("kind") == kind): continue
		var cost: int = Definitions.building(kind).cost
		var site: Vector2i = _slot(ctx.sim, kind, ctx.player)
		if ctx.credits >= cost and _send(ctx, {"type": "build", "builder_id": builder, "building_kind": kind, "origin": [site.x, site.y]}): ctx.credits -= cost
		return

static func _produce(ctx: Dictionary, state: Dictionary, buildings: Array, faction: String) -> void:
	var mine: Array = state.entities.filter(func(unit: Dictionary) -> bool: return unit.owner == ctx.player and not unit.has("hole_id"))
	var replace_builder: bool = not mine.any(func(unit: Dictionary) -> bool: return Registry.is_builder(unit.kind))
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
		if kind.is_empty(): continue
		var cost: int = Definitions.unit(kind).cost
		if ctx.credits >= cost and _send(ctx, {"type": "produce", "building_id": building.id, "unit_kind": kind}):
			ctx.credits -= cost
			owned.append(kind)
		if kind == start_unit: replace_builder = false

static func _collector_kind(row: Dictionary) -> String:
	if not row.receives_supply: return ""
	for kind: String in row.produces:
		if not Registry.collects(kind).is_empty(): return kind
	return ""

static func _faction(state: Dictionary, player: int) -> String:
	for entry: Dictionary in state.players:
		if entry.id == player: return entry.get("faction", Registry.Factions.DEFAULT_FACTION)
	return Registry.Factions.DEFAULT_FACTION

static func _attack(ctx: Dictionary, state: Dictionary, skip: Dictionary, wave_clock: Dictionary) -> void:
	var enemies: Array = state.entities.filter(func(unit: Dictionary) -> bool: return _hostile(ctx, unit.owner) and not Registry.air_kinds.has(unit.kind) and not unit.has("container_id"))
	enemies.append_array(state.buildings.filter(func(building: Dictionary) -> bool: return _hostile(ctx, building.owner) and not Combat.masked(building)))
	var mine := {}
	for unit: Dictionary in state.entities:
		if unit.owner == ctx.player: mine[unit.id] = unit
	var bot: Dictionary = _bot(ctx.sim, ctx.player)
	_drive_waves(ctx, bot, mine, enemies, skip)
	_gather(ctx, state, bot, mine, enemies, skip, wave_clock)

static func _memory(seat_or_sim: RefCounted, key: StringName) -> Dictionary:
	var sim: RefCounted = _real(seat_or_sim)
	if not sim.has_meta(key): sim.set_meta(key, {})
	return sim.get_meta(key)

# Creating the entry is what makes a seat a live bot, so it happens before any gate.
static func _bot(seat_or_sim: RefCounted, player: int) -> Dictionary:
	return _memory(seat_or_sim, BOT_META).get_or_add(player, {"prev": -1, "waves": []})

static func _team_entry(seat_or_sim: RefCounted, team: int, first_due: int) -> Dictionary:
	return _memory(seat_or_sim, BOT_TEAM_META).get_or_add(team, {"wave": 0, "due": first_due, "released_by": "", "launched_at": -1, "objective": null, "attacked_at": {}, "left_cost": 0, "left_units": 0, "joiners": []})

static func _drive_waves(ctx: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, skip: Dictionary) -> void:
	var live: Array = []
	for wave: Dictionary in bot.waves:
		wave.ids = wave.ids.filter(func(id: int) -> bool: return mine.has(id))
		if wave.ids.is_empty(): continue
		var centre: Vector2 = _centre(wave.ids, mine)
		var hits: Array = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.id == wave.target)
		var switched: bool = false
		if hits.is_empty() or (_is_building(hits[0]) and _engaged(centre, enemies)):
			var target: Variant = _pick(centre, enemies)
			if target == null: continue
			switched = not hits.is_empty() and target != wave.target
			wave.target = target
		live.append(wave)
		var pool: Array = wave.ids.filter(func(id: int) -> bool: return not skip.has(id) and (switched or _idle(mine[id])))
		if not pool.is_empty(): _send(ctx, {"type": "attack", "entity_ids": pool, "target_id": wave.target})
	bot.waves = live

static func _gather(ctx: Dictionary, state: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, skip: Dictionary, wave_clock: Dictionary) -> void:
	var waving := {}
	for wave: Dictionary in bot.waves:
		for id: int in wave.ids: waving[id] = true
	var rally: Vector2 = _rally(ctx)
	var ready: Array = []
	var walking: Array = []
	for id: int in mine:
		if waving.has(id) or skip.has(id) or not _idle(mine[id]): continue
		var at := Vector2(mine[id].position[0], mine[id].position[1])
		(ready if at.distance_to(rally) <= RALLY_RADIUS else walking).append(id)
	if not walking.is_empty(): _send(ctx, {"type": "move", "entity_ids": walking, "target": [rally.x, rally.y]})
	if not ready.is_empty(): _launch(ctx, state, bot, mine, enemies, ready, wave_clock)

static func _launch(ctx: Dictionary, state: Dictionary, bot: Dictionary, mine: Dictionary, enemies: Array, ready: Array, wave_clock: Dictionary) -> void:
	var live: Array[int] = _live_bots(ctx, state)
	if not live.has(ctx.player) or ctx.tick < wave_clock.due: return
	@warning_ignore("integer_division")
	var share: int = _wave_target(wave_clock.wave, state, live) / live.size()
	var worth: int = _cost_sum(ready.map(func(id: int) -> String: return mine[id].kind))
	if worth < share and ctx.tick < wave_clock.due + WAVE_WAIT: return
	@warning_ignore("integer_division")
	var limit: int = WAVE0_UNITS / live.size() if wave_clock.wave == 0 else ready.size()
	var take: Array = _take(ready, mine, share, limit)
	var target: Variant = _pick(_centre(take, mine), enemies)
	if target == null or not _send(ctx, {"type": "attack", "entity_ids": take, "target_id": target}): return
	bot.waves.append({"ids": take, "target": target})
	wave_clock.released_by = "wait_cap" if worth < share else ("timer" if bot.prev < wave_clock.due else "size")
	wave_clock.launched_at = ctx.tick
	wave_clock.due = ctx.tick + WAVE_GAPS[mini(wave_clock.wave, WAVE_GAPS.size() - 1)]
	wave_clock.wave += 1

# A seat is a live bot once it has decided and while it still owns a building that keeps it in the match.
static func _live_bots(ctx: Dictionary, state: Dictionary) -> Array[int]:
	var decided: Dictionary = _memory(ctx.sim, BOT_META)
	var live: Array[int] = []
	for entry: Dictionary in state.players:
		if ctx.teams[entry.id] != ctx.teams[ctx.player] or not decided.has(entry.id): continue
		if state.buildings.any(func(building: Dictionary) -> bool: return building.owner == entry.id and Registry.kind(building.kind).counts_for_victory): live.append(entry.id)
	return live

static func _wave_target(wave: int, state: Dictionary, live: Array[int]) -> int:
	var mean: int = 0
	for player in live: mean += faction_unit_cost(_faction(state, player))
	@warning_ignore("integer_division")
	return WAVE_SIZES[mini(wave, WAVE_SIZES.size() - 1)] * live.size() * (mean / live.size())

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

static func _rally(ctx: Dictionary) -> Vector2:
	var map: Dictionary = ctx.sim.map_data()
	return Vector2(MapData.start_cell(map if not map.is_empty() else _default_map(), ctx.player)) + Vector2(0.5, 0.5)

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

# Score = priority - one point per DISTANCE_STEP cells (min 1): the Zero Hour attack-priority rule, numbers in docs/reference/m7-verification-archive-research.md.
static func _pick(position: Vector2, enemies: Array) -> Variant:
	var best: Variant = null
	var best_score: int = 0
	for enemy: Dictionary in _candidates(position, enemies):
		var score: int = maxi(_priority(enemy.kind) - floori(sqrt(Combat.distance_squared(position, enemy)) / DISTANCE_STEP), 1)
		if best == null or score > best_score or (score == best_score and enemy.id < best):
			best = enemy.id
			best_score = score
	return best

static func _is_building(enemy: Dictionary) -> bool:
	return not Registry.kind(enemy.kind).has("class")

# A wave heads for a building, not for a far unit it would trickle into, until an enemy unit comes within defence reach.
static func _engaged(position: Vector2, enemies: Array) -> bool:
	return enemies.any(func(enemy: Dictionary) -> bool: return not _is_building(enemy) and Combat.distance_squared(position, enemy) <= DEFENCE_RADIUS * DEFENCE_RADIUS)

static func _candidates(position: Vector2, enemies: Array) -> Array:
	var buildings: Array = enemies.filter(_is_building)
	return enemies if buildings.is_empty() or _engaged(position, enemies) else buildings

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
