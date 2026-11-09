extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const Production = preload("res://scripts/simulation/production.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")

const DRY_WELLS := "res://data/maps/dry_wells.json"
const FIXED_TICKS: int = 2100
const CAP_TICKS: int = 6000
const WINDOW_START: int = 300
const CHOKE_LEAD: int = 12
const CROSS_MARGIN: int = 5
const SEARCH_RADIUS: int = 30
const NAMES: Array[String] = ["move_open", "move_dense", "docks", "docks_traffic", "hordes300", "dw_exits", "dw_docks", "dw_choke", "dw_group50"]
# fixed: run FIXED_TICKS. legs: movement-benchmark legs for FIXED_TICKS, then drain. settle: run until every unit has stopped.
const PLANS := {
	"move_open": {"kind": "legs", "window": true}, "move_dense": {"kind": "legs", "window": true},
	"docks": {"kind": "fixed", "window": true}, "docks_traffic": {"kind": "fixed", "window": false},
	"hordes300": {"kind": "fixed", "window": true}, "dw_exits": {"kind": "settle", "window": false},
	"dw_docks": {"kind": "fixed", "window": false}, "dw_choke": {"kind": "settle", "window": false},
	"dw_group50": {"kind": "settle", "window": false},
}

static func plan(scenario: String) -> Dictionary:
	return PLANS[scenario]

static func create(scenario: String) -> Simulation:
	var sim: Simulation
	match scenario:
		"move_open", "move_dense": sim = MovementWorkload.create(scenario.trim_prefix("move_"))
		"docks", "hordes300": sim = CombatWorkload.create(scenario)
		"docks_traffic": sim = _docks_traffic()
		"dw_exits": sim = _dw_exits()
		"dw_docks": sim = _dw_docks()
		"dw_choke": sim = _dw_choke()
		"dw_group50": sim = _dw_group50()
		_: return null
	if not sim.has_meta("ctx"): sim.set_meta("ctx", _new_ctx())
	return sim

static func ctx(sim: Simulation) -> Dictionary:
	return sim.get_meta("ctx")

static func _new_ctx() -> Dictionary:
	return {"leg": -1, "setup": [], "errors": [], "groups": {}, "goals": {}, "shuttle": []}

# Called before each sim.step(); issues whatever commands the scenario scripts for this tick.
static func orders(sim: Simulation, scenario: String, tick: int) -> void:
	var state: Dictionary = ctx(sim)
	match scenario:
		"move_open", "move_dense": _legs(sim, state, tick)
		"docks_traffic", "dw_docks": _shuttle(sim, state)
		"dw_exits", "dw_choke", "dw_group50": _group_orders(sim, state, tick)

# Settle scenarios end when nothing is moving or waiting for a route.
static func done(sim: Simulation) -> bool:
	return settled(sim, sim._entities.keys())

static func settled(sim: Simulation, ids: Array) -> bool:
	if not sim._pending.is_empty() or not sim._path_queue.is_empty():
		return false
	for id: int in ids:
		if sim._entities.has(id) and sim._entities[id].status in ["moving", "path_pending"]:
			return false
	return true

static func _legs(sim: Simulation, state: Dictionary, tick: int) -> void:
	if tick >= FIXED_TICKS:
		return
	if state.leg == -1 or MovementWorkload.settled(sim):
		state.leg += 1
		MovementWorkload.issue_leg(sim, state.leg)

# Records the first move of every ordered group at tick 0 and the destinations the allocation chose at tick 1.
static func _group_orders(sim: Simulation, state: Dictionary, tick: int) -> void:
	if tick == 0:
		for entry: Dictionary in state.groups.values():
			_command(sim, state, "move", entry.ids, entry.target)
	elif tick == 1:
		for entry: Dictionary in state.groups.values():
			for id: int in entry.ids:
				if sim._entities[id].destination != null:
					state.goals[id] = sim._entities[id].destination.duplicate()

static func _shuttle(sim: Simulation, state: Dictionary) -> void:
	var tanks: Array = state.shuttle[0]
	if not settled(sim, tanks):
		return
	state.shuttle[2] = 1 - state.shuttle[2]
	var point: Vector2 = state.shuttle[1][state.shuttle[2]]
	_command(sim, state, "move", tanks, [point.x, point.y])

static func _command(sim: Simulation, state: Dictionary, type: String, ids: Array, target: Variant, extra: Dictionary = {}) -> void:
	var command := {"tick": sim.tick(), "player": 1, "sequence": sim._last_sequences.get(1, -1) + 1, "type": type, "entity_ids": ids}
	if target != null:
		command.target = target
	command.merge(extra)
	var result: Dictionary = sim.issue_command(command)
	if not result.ok:
		state.errors.append(type + " rejected: " + result.error)

static func _note(state: Dictionary, line: String) -> void:
	state.setup.append(line)

# Cells sorted by Manhattan distance to origin (then y, x) that are walkable, not taken and in origin's component (the nearest candidate's when origin itself is blocked).
static func _nearest_free(sim: Simulation, origin: Vector2i, count: int, taken: Dictionary, state: Dictionary) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for y in range(origin.y - SEARCH_RADIUS, origin.y + SEARCH_RADIUS + 1):
		for x in range(origin.x - SEARCH_RADIUS, origin.x + SEARCH_RADIUS + 1):
			var cell := Vector2i(x, y)
			if not taken.has(cell) and sim._navigation.is_walkable(_centre(cell)):
				found.append(cell)
	found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(a.x - origin.x) + absi(a.y - origin.y)
		var db: int = absi(b.x - origin.x) + absi(b.y - origin.y)
		return da < db if da != db else a.y < b.y or (a.y == b.y and a.x < b.x))
	var component: int = sim._navigation.component_at(_centre(origin))
	if component < 0 and not found.is_empty():
		component = sim._navigation.component_at(_centre(found[0]))
	var near: Array[Vector2i] = found.filter(func(cell: Vector2i) -> bool: return sim._navigation.component_at(_centre(cell)) == component)
	if near.size() < count:
		state.errors.append("only %d free cells near %s, need %d" % [near.size(), origin, count])
	return near.slice(0, count)

static func _spawn_at(sim: Simulation, state: Dictionary, taken: Dictionary, cell: Vector2i, kind: String, owner: int = 1) -> int:
	var id: int = sim.spawn(owner, Vector2(cell) + Vector2(0.5, 0.5), kind, taken)
	if id < 0:
		state.errors.append("spawn failed: %s at %s" % [kind, cell])
		return -1
	sim._entities[id].combat = null
	taken[cell] = true
	return id

# Spawns the mix on the free cells nearest to origin, tanks first; returns the ids.
static func _spawn_mix(sim: Simulation, state: Dictionary, origin: Vector2i, taken: Dictionary, mix: Array) -> Array:
	var total: int = 0
	for part: Array in mix:
		total += part[1]
	var cells: Array[Vector2i] = _nearest_free(sim, origin, total, taken, state)
	var ids: Array = []
	var next: int = 0
	for part: Array in mix:
		for i in range(part[1]):
			if next < cells.size():
				ids.append(_spawn_at(sim, state, taken, cells[next], part[0]))
				next += 1
	return ids

static func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(point.floor())

static func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)

static func _walkable_near(sim: Simulation, point: Vector2) -> Vector2:
	var found: Array[Vector2i] = _nearest_free(sim, _cell_of(point), 1, {}, {"errors": []})
	return _centre(found[0]) if not found.is_empty() else point

static func _dry_wells_base() -> Simulation:
	var map: Dictionary = MapData.load(DRY_WELLS)
	var sim: Simulation = MapData.create(map, [])
	sim.add_player(1, 0)
	for kind: String in MovementWorkload.ASHFALL_BASE:
		CombatWorkload._building(sim, kind, MapData.slot(map, 1, kind))
	return sim

static func _building_of(sim: Simulation, kind: String) -> Dictionary:
	for building: Dictionary in sim._buildings.values():
		if building.kind == kind:
			return building
	return {}

# Ten idle tanks fill the factory's and barracks' rally cells and the exit cells nearest to them; the movers start further inside.
static func _dw_exits() -> Simulation:
	var sim: Simulation = _dry_wells_base()
	var state: Dictionary = _new_ctx()
	sim.set_meta("ctx", state)
	var taken: Dictionary = sim.occupied_cells()
	var parked: Array = []
	for kind: String in ["usa_factory", "usa_barracks"]:
		var building: Dictionary = _building_of(sim, kind)
		var origin := Vector2i(building.origin[0], building.origin[1])
		var rally: Array = Production.default_rally(sim, kind, origin)
		var rally_cell: Vector2i = _cell_of(Vector2(rally[0], rally[1]))
		var exits: Array[Vector2i] = Construction.perimeter(kind, origin)
		exits.append(rally_cell)
		exits.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = absi(a.x - rally_cell.x) + absi(a.y - rally_cell.y)
			var db: int = absi(b.x - rally_cell.x) + absi(b.y - rally_cell.y)
			return da < db if da != db else a.y < b.y or (a.y == b.y and a.x < b.x))
		var placed: Array[Vector2i] = []
		for cell: Vector2i in exits:
			if placed.size() < 5 and not taken.has(cell) and sim._navigation.is_walkable(_centre(cell)):
				_spawn_at(sim, state, taken, cell, "usa_tank")
				placed.append(cell)
		parked.append("%s rally=%s parked=%s" % [kind, rally_cell, placed])
	_note(state, "parked " + "; ".join(parked))
	var map: Dictionary = sim.map_data()
	var start: Vector2i = MapData.start_cell(map, 1)
	var ids: Array = _spawn_mix(sim, state, start, taken, [["usa_tank", 10], ["usa_rifle_infantry", 10], ["usa_builder", 1]])
	var target: Vector2 = _outside_point(sim, start)
	state.groups["movers"] = {"ids": ids, "target": [target.x, target.y]}
	_note(state, "movers=%d start=%s target=%s" % [ids.size(), start, target])
	return sim

# A point 15 cells past the base buildings on the side of the map centre.
static func _outside_point(sim: Simulation, start: Vector2i) -> Vector2:
	var low: int = 1 << 20
	var high: int = -(1 << 20)
	for building: Dictionary in sim._buildings.values():
		var footprint: Vector2i = Registry.building_view(building.kind).footprint
		low = mini(low, building.origin[1])
		high = maxi(high, building.origin[1] + footprint.y)
	var size: Vector2i = sim._navigation.size()
	var down: bool = start.y * 2 < size.y
	var y: int = high + 15 if down else low - 1 - 15
	return _walkable_near(sim, Vector2(start.x + 0.5, y + 0.5))

static func _dw_group50() -> Simulation:
	var sim: Simulation = _dry_wells_base()
	var state: Dictionary = _new_ctx()
	sim.set_meta("ctx", state)
	var map: Dictionary = sim.map_data()
	var start: Vector2i = MapData.start_cell(map, 1)
	var goal: Vector2i = MapData.start_cell(map, 2)
	var ids: Array = _spawn_mix(sim, state, start, sim.occupied_cells(), [["usa_tank", 30], ["usa_rifle_infantry", 19], ["usa_builder", 1]])
	state.groups["group"] = {"ids": ids, "target": [goal.x + 0.5, goal.y + 0.5]}
	_note(state, "group=%d start=%s target=%s" % [ids.size(), start, goal])
	return sim

# Seat 1's supply depot and the nearest 400-box pile; five trucks gather while ten tanks shuttle along the pile's depot-side dock row.
static func _dw_docks() -> Simulation:
	var map: Dictionary = MapData.load(DRY_WELLS)
	var sim: Simulation = MapData.create(map, [])
	sim.add_player(1, 0)
	var state: Dictionary = _new_ctx()
	sim.set_meta("ctx", state)
	var depot: Vector2i = MapData.slot(map, 1, "china_supply_center")
	CombatWorkload._building(sim, "china_supply_center", depot)
	var pile: Dictionary = _nearest_pile(sim, depot)
	var taken: Dictionary = sim.occupied_cells()
	var trucks: Array = _spawn_mix(sim, state, depot, taken, [["china_collector", 5]])
	_command(sim, state, "gather", trucks, null, {"source_id": pile.id})
	_add_shuttle(sim, state, pile, "south", 10, taken)
	_note(state, "depot=%s pile=%s trucks=%d" % [depot, pile.origin, trucks.size()])
	return sim

static func _nearest_pile(sim: Simulation, depot: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = 1 << 30
	for source: Dictionary in sim._sources.values():
		var distance: int = absi(source.origin[0] - depot.x) + absi(source.origin[1] - depot.y)
		if source.boxes == 400 and distance < best_distance:
			best = source
			best_distance = distance
	return best

# Two points a few cells beyond the ring on opposite sides, joined by a straight line along the ring row or column on the depot side.
static func _add_shuttle(sim: Simulation, state: Dictionary, pile: Dictionary, side: String, count: int, taken: Dictionary) -> void:
	var footprint: Vector2i = Registry.source_footprint(pile)
	var origin := Vector2i(pile.origin[0], pile.origin[1])
	var points: Array[Vector2] = []
	if side == "east":
		var x: int = origin.x + footprint.x
		points = [_centre(Vector2i(x, origin.y - 1 - CROSS_MARGIN)), _centre(Vector2i(x, origin.y + footprint.y + CROSS_MARGIN))]
	else:
		var y: int = origin.y + footprint.y
		points = [_centre(Vector2i(origin.x - 1 - CROSS_MARGIN, y)), _centre(Vector2i(origin.x + footprint.x + CROSS_MARGIN, y))]
	points = [_walkable_near(sim, points[0]), _walkable_near(sim, points[1])]
	var tanks: Array = _spawn_mix(sim, state, _cell_of(points[0]), taken, [["usa_tank", count]])
	state.shuttle = [tanks, points, 0]
	_note(state, "shuttle %d usa_tank between %s and %s (%s side of pile)" % [count, points[0], points[1], side])

static func _docks_traffic() -> Simulation:
	var sim: Simulation = CombatWorkload.create("docks")
	var state: Dictionary = _new_ctx()
	sim.set_meta("ctx", state)
	var pile: Dictionary = {}
	for source: Dictionary in sim._sources.values():
		if source.origin[0] == 18 and source.origin[1] == 30:
			pile = source
	_add_shuttle(sim, state, pile, "east", 20, sim.occupied_cells())
	return sim

# The narrowest walkable cross-section along the route between the start cells; two mixed groups start CHOKE_LEAD route cells either side and swap.
static func _dw_choke() -> Simulation:
	var map: Dictionary = MapData.load(DRY_WELLS)
	var sim: Simulation = MapData.create(map, [])
	sim.add_player(1, 0)
	var state: Dictionary = _new_ctx()
	sim.set_meta("ctx", state)
	var route: Array[Vector2i] = _route_cells(sim, MapData.start_cell(map, 1), MapData.start_cell(map, 2))
	var choke: Dictionary = _narrowest(sim, route)
	var before: int = clampi(choke.index - CHOKE_LEAD, 0, route.size() - 1)
	var after: int = clampi(choke.index + CHOKE_LEAD, 0, route.size() - 1)
	var taken: Dictionary = sim.occupied_cells()
	var mix: Array = [["usa_tank", 15], ["usa_rifle_infantry", 10]]
	var west: Array = _spawn_mix(sim, state, route[before], taken, mix)
	var east: Array = _spawn_mix(sim, state, route[after], taken, mix)
	state.groups["before"] = {"ids": west, "target": [route[after].x + 0.5, route[after].y + 0.5]}
	state.groups["after"] = {"ids": east, "target": [route[before].x + 0.5, route[before].y + 0.5]}
	_note(state, "choke cell=%s width=%d route_index=%d of %d; groups at %s and %s" % [route[choke.index], choke.width, choke.index, route.size(), route[before], route[after]])
	return sim

static func _route_cells(sim: Simulation, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	for point: Vector2 in sim._navigation.route(_centre(from), _centre(to)):
		var cell: Vector2i = _cell_of(point)
		if cell != cells.back():
			cells.append(cell)
	return cells

static func _narrowest(sim: Simulation, route: Array[Vector2i]) -> Dictionary:
	var best := {"index": 0, "width": 1 << 20}
	for index in range(route.size()):
		var step: Vector2i = route[index + 1] - route[index] if index + 1 < route.size() else route[index] - route[index - 1]
		var across := Vector2i(0, 1) if step.x != 0 else Vector2i(1, 0)
		var width: int = 1 + _run(sim, route[index], across) + _run(sim, route[index], -across)
		if width < best.width:
			best = {"index": index, "width": width}
	return best

static func _run(sim: Simulation, from: Vector2i, step: Vector2i) -> int:
	var length: int = 0
	while sim._navigation.is_walkable(_centre(from + step * (length + 1))):
		length += 1
	return length
