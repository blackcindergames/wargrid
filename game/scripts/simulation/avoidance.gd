extends RefCounted

# Unit avoidance spike prototype (evidence only). Shared grids, pass-through rules, side cells, last resort.
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Containers = preload("res://scripts/simulation/containers.gd")
const Yield = preload("res://scripts/simulation/avoid_yield.gd")
const Reserve = preload("res://scripts/simulation/avoid_reserve.gd")

const VEHICLE: int = 1
const INFANTRY: int = 2
const CLASS_MASK: int = 3
const BUILDER: int = 4
const CRUSHER: int = 8
const BLOCKED_LIMIT: int = 150
const GHOST_TICKS: int = 60
const REROUTES_PER_TICK: int = 8
const REROUTE_FAIL_WAIT: int = 30
const CRUSHERS: Array[String] = ["usa_tank", "china_tank", "frc_tank", "china_collector", "usa_builder", "china_builder"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const STATS: Array[String] = ["step_asides", "sidesteps", "nudges", "reroutes", "reroute_fail", "gave_up", "would_crush", "blocked_ticks", "cell_checks", "goal_ignores"]

static var mode: String = ""
static var vehicle_at := PackedInt32Array()
static var infantry_at := PackedInt32Array()
static var reserved := PackedInt32Array()
static var width: int = 0
static var height: int = 0
static var reroutes_left: int = 0
static var _info: Dictionary = {}

static func set_mode(m: String) -> void:
	mode = m

static func info(kind: String) -> int:
	var cached: Variant = _info.get(kind)
	if cached != null: return cached
	var bits: int = 0
	match Registry.kind(kind)["class"]:
		"vehicle": bits = VEHICLE
		"infantry": bits = INFANTRY
	if Registry.is_builder(kind): bits |= BUILDER
	if CRUSHERS.has(kind): bits |= CRUSHER
	_info[kind] = bits
	return bits

static func begin_tick(sim: Simulation, ids: Array[int]) -> bool:
	if mode == "": return false
	var size: Vector2i = sim._navigation.size()
	width = size.x
	height = size.y
	if vehicle_at.size() != size.x * size.y:
		vehicle_at.resize(size.x * size.y)
		infantry_at.resize(size.x * size.y)
		reserved.resize(size.x * size.y)
	vehicle_at.fill(0)
	infantry_at.fill(0)
	reserved.fill(0)
	reroutes_left = REROUTES_PER_TICK
	if not sim._avoid.has("stats"):
		var stats: Dictionary = {}
		for key in STATS: stats[key] = 0
		sim._avoid["stats"] = stats
	for id in ids:
		var unit: Dictionary = sim._entities[id]
		var bits: int = info(unit.kind) & CLASS_MASK
		if bits == 0 or unit.has("container_id"): continue
		var position: Array = unit.position
		var index: int = floori(position[1]) * width + floori(position[0])
		if bits == VEHICLE:
			if vehicle_at[index] == 0: vehicle_at[index] = id + 1
		elif infantry_at[index] == 0:
			infantry_at[index] = id + 1
		var destination: Variant = unit.destination
		if destination != null:
			index = floori(destination[1]) * width + floori(destination[0])
			if reserved[index] == 0: reserved[index] = id + 1
	if mode == "reserve": Reserve.begin_tick(sim, ids)
	return true

static func index_of(point: Array) -> int:
	return floori(point[1]) * width + floori(point[0])

static func cell_of(point: Array) -> Vector2i:
	return Vector2i(floori(point[0]), floori(point[1]))

static func record(sim: Simulation, id: int) -> Dictionary:
	var found: Variant = sim._avoid.get(id)
	if found != null: return found
	var fresh := {"blocked": 0, "ghost_until": 0, "resume": null, "retry_tick": 0, "order": null, "side_route": null, "claim": -1, "stage": 0, "wait_until": 0}
	sim._avoid[id] = fresh
	return fresh

static func count(sim: Simulation, key: String) -> void:
	sim._avoid.stats[key] += 1

static func standing(unit: Dictionary) -> bool:
	var status: String = unit.status
	return status == "idle" or status == "arrived" or status == "blocked"

static func friendly(sim: Simulation, a: Dictionary, b: Dictionary) -> bool:
	return sim.team_of(a.owner) == sim.team_of(b.owner)

static func busy(unit: Dictionary) -> bool:
	if unit.combat != null and unit.combat.target_id != null: return true
	if unit.construction_id != null or unit.has("hole_id"): return true
	var collection: Variant = unit.collection
	if collection != null and collection.enabled: return true
	return Containers.entering(unit)

static func advance(sim: Simulation, unit: Dictionary) -> void:
	if mode == "reserve":
		Reserve.advance(sim, unit)
		return
	var id: int = unit.id
	var kind_bits: int = info(unit.kind)
	if kind_bits & CLASS_MASK == 0:
		sim._advance(unit)
		return
	var rec: Variant = sim._avoid.get(id)
	if rec != null and rec.resume != null and not is_same(unit.order, rec.resume): rec.resume = null
	var old_position: Array = unit.position
	var old_route: Array = unit.route
	var old_status: String = unit.status
	var old_order: Variant = unit.order
	sim._advance(unit)
	var old_index: int = index_of(old_position)
	var new_index: int = index_of(unit.position)
	if new_index == old_index:
		_resume(sim, unit, rec)
		return
	count(sim, "cell_checks")
	var other: int = 0
	if rec == null or sim._tick >= rec.ghost_until: other = _blocker(sim, unit, kind_bits, new_index)
	if other == 0:
		_enter(unit, kind_bits, old_index, new_index)
		if rec != null: rec.blocked = 0
		_resume(sim, unit, rec)
		return
	unit.position = old_position
	unit.route = old_route
	unit.status = old_status
	unit.order = old_order
	unit.speed = 0.0
	if rec == null: rec = record(sim, id)
	if not is_same(old_order, rec.order):
		rec.order = old_order
		rec.blocked = 0
	rec.blocked += 1
	count(sim, "blocked_ticks")
	if rec.blocked == BLOCKED_LIMIT + 1: rec.ghost_until = sim._tick + 1 + GHOST_TICKS
	Yield.blocked(sim, unit, rec, sim._entities[other])

static func _enter(unit: Dictionary, kind_bits: int, old_index: int, new_index: int) -> void:
	var grid: PackedInt32Array = vehicle_at if kind_bits & CLASS_MASK == VEHICLE else infantry_at
	var mark: int = unit.id + 1
	if grid[old_index] == mark: grid[old_index] = 0
	if grid[new_index] == 0: grid[new_index] = mark

static func _resume(sim: Simulation, unit: Dictionary, rec: Variant) -> void:
	if rec == null or rec.resume == null or unit.status != "arrived": return
	unit.order = rec.resume
	unit.status = "path_pending"
	rec.resume = null
	sim._path_queue.append(unit.id)

# Returns the id of the first solid unit in the cell the mover would enter, or 0.
static func _blocker(sim: Simulation, unit: Dictionary, kind_bits: int, index: int) -> int:
	var vehicle: int = vehicle_at[index]
	var infantry: int = infantry_at[index]
	if vehicle != 0 and vehicle - 1 != unit.id and not _passes(sim, unit, kind_bits, sim._entities[vehicle - 1]): return vehicle - 1
	if infantry != 0 and infantry - 1 != unit.id and not _passes(sim, unit, kind_bits, sim._entities[infantry - 1]): return infantry - 1
	return 0

static func _passes(sim: Simulation, unit: Dictionary, kind_bits: int, other: Dictionary) -> bool:
	var other_bits: int = info(other.kind)
	if kind_bits & CLASS_MASK == INFANTRY and other_bits & CLASS_MASK == INFANTRY: return true
	var collection: Variant = unit.collection
	if collection != null and collection.enabled and collection.phase.begins_with("flying_"): return true
	if unit.order != null and unit.order.type == "enter" and unit.order.target_id == other.id: return true
	if kind_bits & CRUSHER != 0 and other_bits & CLASS_MASK == INFANTRY and not friendly(sim, unit, other):
		count(sim, "would_crush")
		return true
	if mode == "yield" and Yield.ignores(unit):
		count(sim, "goal_ignores")
		return true
	return false

# Cell centre for u to step to: neighbours first, then straight cells two away; never the other unit's cell or its next 3 route cells.
static func side_cell(sim: Simulation, u: Dictionary, other: Dictionary) -> Variant:
	var from: Vector2i = cell_of(u.position)
	var avoid: Array[Vector2i] = [cell_of(other.position)]
	var route: Array = other.route
	for i in range(mini(3, route.size())): avoid.append(cell_of(route[i]))
	for step in DIRS:
		if _free_side(sim, u, from + step, avoid): return from + step
	for step in DIRS:
		if _empty(sim, from + step) and _free_side(sim, u, from + step * 2, avoid): return from + step * 2
	return null

static func _empty(sim: Simulation, cell: Vector2i) -> bool:
	if not sim._navigation._open(cell): return false
	var index: int = cell.y * width + cell.x
	return vehicle_at[index] == 0 and infantry_at[index] == 0

static func _free_side(sim: Simulation, u: Dictionary, cell: Vector2i, avoid: Array[Vector2i]) -> bool:
	if not _empty(sim, cell) or avoid.has(cell): return false
	var held: int = reserved[cell.y * width + cell.x]
	return held == 0 or held == u.id + 1

# Moves u to a free side cell. A moving unit keeps its destination and resumes its order after; a standing unit's destination becomes the side cell.
static func sidestep(sim: Simulation, u: Dictionary, other: Dictionary, was_moving: bool) -> bool:
	var rec: Dictionary = record(sim, u.id)
	if u.status == "moving" and is_same(u.route, rec.side_route): return true
	var found: Variant = side_cell(sim, u, other)
	if found == null: return false
	var cell: Vector2i = found
	var centre: Array = [cell.x + 0.5, cell.y + 0.5]
	u.route = [sim._frozen(centre.duplicate())]
	rec.side_route = u.route
	u.status = "moving"
	if u.speed == 0.0: u.move_after = sim._tick + sim.START_DELAY_TICKS
	reserved[cell.y * width + cell.x] = u.id + 1
	if was_moving:
		if rec.resume == null: rec.resume = u.order
		count(sim, "sidesteps")
	else:
		u.destination = centre
		count(sim, "step_asides")
	return true

# Local re-route around the blocker and standing units near u; false when over budget (wait for next tick) or no route.
static func reroute(sim: Simulation, unit: Dictionary, rec: Dictionary, blocker: Dictionary) -> bool:
	if reroutes_left <= 0 or unit.destination == null or sim._tick < rec.retry_tick: return false
	reroutes_left -= 1
	var from := Vector2(unit.position[0], unit.position[1])
	var points: Array[Vector2] = sim._navigation.route_avoiding(from, Vector2(unit.destination[0], unit.destination[1]), _standing_near(sim, unit, blocker))
	if points.is_empty():
		count(sim, "reroute_fail")
		rec.retry_tick = sim._tick + REROUTE_FAIL_WAIT
		return false
	var route: Array = []
	for point in points: route.append(sim._frozen([point.x, point.y]))
	if route.size() > 1 and sim._behind(from, route[0], route[1]): route.pop_front()
	unit.route = route
	unit.status = "moving"
	count(sim, "reroutes")
	return true

# The blocker's cell plus every standing unit within two cells of u, minus u's own and destination cells.
static func _standing_near(sim: Simulation, u: Dictionary, blocker: Dictionary) -> Array[Vector2i]:
	var here: Vector2i = cell_of(u.position)
	var goal: Vector2i = cell_of(u.destination)
	var cells: Array[Vector2i] = [cell_of(blocker.position)]
	for y in range(maxi(here.y - 2, 0), mini(here.y + 3, height)):
		for x in range(maxi(here.x - 2, 0), mini(here.x + 3, width)):
			var index: int = y * width + x
			if _is_standing_other(sim, u, vehicle_at[index]) or _is_standing_other(sim, u, infantry_at[index]): cells.append(Vector2i(x, y))
	return cells.filter(func(cell: Vector2i) -> bool: return cell != here and cell != goal)

static func _is_standing_other(sim: Simulation, u: Dictionary, held: int) -> bool:
	return held != 0 and held - 1 != u.id and standing(sim._entities[held - 1])
