extends RefCounted

# Approach B (spike): OpenRA style reservation. A mover claims the cell it is about to enter, a blocked mover nudges, waits, re-routes or gives up (Move.cs:298-345 in the spike plan).
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Avoidance = preload("res://scripts/simulation/avoidance.gd")

const WAIT_TICKS: int = 40
const WINDOW: int = 10

static var vehicle_claim := PackedInt32Array()
static var infantry_claim := PackedInt32Array()

static func begin_tick(sim: Simulation, ids: Array[int]) -> void:
	var cells: int = Avoidance.width * Avoidance.height
	if vehicle_claim.size() != cells:
		vehicle_claim.resize(cells)
		infantry_claim.resize(cells)
	vehicle_claim.fill(0)
	infantry_claim.fill(0)
	for id in ids:
		var rec: Variant = sim._avoid.get(id)
		if rec == null or rec.claim < 0: continue
		var unit: Dictionary = sim._entities[id]
		var route: Array = unit.route
		if unit.status != "moving" or route.is_empty() or Avoidance.index_of(route[0]) != rec.claim:
			rec.claim = -1
			continue
		_mark(Avoidance.info(unit.kind), rec.claim, id)

static func _mark(kind_bits: int, index: int, id: int) -> void:
	var grid: PackedInt32Array = vehicle_claim if kind_bits & Avoidance.CLASS_MASK == Avoidance.VEHICLE else infantry_claim
	if grid[index] == 0: grid[index] = id + 1

static func advance(sim: Simulation, unit: Dictionary) -> void:
	var kind_bits: int = Avoidance.info(unit.kind)
	if kind_bits & Avoidance.CLASS_MASK == 0:
		sim._advance(unit)
		return
	var rec: Dictionary = Avoidance.record(sim, unit.id)
	if not is_same(unit.order, rec.order):
		rec.order = unit.order
		rec.blocked = 0
		rec.stage = 0
		rec.claim = -1
	if rec.resume != null and not is_same(unit.order, rec.resume): rec.resume = null
	var old_index: int = Avoidance.index_of(unit.position)
	var next: int = _next_cell(unit, old_index)
	if next >= 0 and next != rec.claim:
		Avoidance.count(sim, "cell_checks")
		var other: int = 0
		if sim._tick >= rec.ghost_until: other = _holder(sim, unit, kind_bits, next)
		if other != 0:
			_blocked(sim, unit, rec, sim._entities[other - 1])
			return
		rec.claim = next
		_mark(kind_bits, next, unit.id)
	sim._advance(unit)
	var new_index: int = Avoidance.index_of(unit.position)
	if new_index != old_index:
		Avoidance._enter(unit, kind_bits, old_index, new_index)
		rec.claim = -1
		rec.blocked = 0
		rec.stage = 0
	Avoidance._resume(sim, unit, rec)

# The cell the unit must leave its own cell for, or -1 while the next waypoint is still inside it.
static func _next_cell(unit: Dictionary, here: int) -> int:
	var route: Array = unit.route
	if route.is_empty(): return -1
	var index: int = Avoidance.index_of(route[0])
	return index if index != here else -1

# Id + 1 of the first solid unit holding or claiming the cell, or 0.
static func _holder(sim: Simulation, unit: Dictionary, kind_bits: int, index: int) -> int:
	var me: int = unit.id + 1
	var held: int = Avoidance.vehicle_at[index]
	if held != 0 and held != me and not Avoidance._passes(sim, unit, kind_bits, sim._entities[held - 1]): return held
	held = Avoidance.infantry_at[index]
	if held != 0 and held != me and not Avoidance._passes(sim, unit, kind_bits, sim._entities[held - 1]): return held
	held = vehicle_claim[index]
	if held != 0 and held != me and not Avoidance._passes(sim, unit, kind_bits, sim._entities[held - 1]): return held
	held = infantry_claim[index]
	if held != 0 and held != me and not Avoidance._passes(sim, unit, kind_bits, sim._entities[held - 1]): return held
	return 0

# rec.stage: 0 = block just seen, 1 = first wait running, 2 = extra wait for an evacuating cell.
static func _blocked(sim: Simulation, unit: Dictionary, rec: Dictionary, other: Dictionary) -> void:
	unit.speed = 0.0
	rec.blocked += 1
	Avoidance.count(sim, "blocked_ticks")
	if rec.blocked == Avoidance.BLOCKED_LIMIT + 1: rec.ghost_until = sim._tick + 1 + Avoidance.GHOST_TICKS
	if sim._tick < rec.wait_until: return
	if rec.stage == 0:
		if Avoidance.standing(other):
			var movable: bool = Avoidance.friendly(sim, unit, other) and not Avoidance.busy(other)
			if movable and Avoidance.sidestep(sim, other, unit, false):
				sim._avoid.stats.step_asides -= 1
				Avoidance.count(sim, "nudges")
			else:
				_go_around(sim, unit, rec, [Avoidance.cell_of(other.position)])
				return
		rec.stage = 1
		rec.wait_until = sim._tick + WAIT_TICKS
	elif rec.stage == 1 and other.status == "moving":
		rec.stage = 2
		rec.wait_until = sim._tick + WAIT_TICKS
	else:
		_go_around(sim, unit, rec, _solid_cells(sim, unit))

static func _go_around(sim: Simulation, unit: Dictionary, rec: Dictionary, cells: Array[Vector2i]) -> void:
	var done: int = _repath(sim, unit, cells)
	if done > 0:
		rec.stage = 0
		rec.claim = -1
	elif done < 0:
		_stuck(sim, unit, rec)

# 1 = new route, 0 = wait for next tick (over budget), -1 = no route.
static func _repath(sim: Simulation, unit: Dictionary, cells: Array[Vector2i]) -> int:
	if Avoidance.reroutes_left <= 0 or unit.destination == null: return 0
	Avoidance.reroutes_left -= 1
	var from := Vector2(unit.position[0], unit.position[1])
	var here: Vector2i = Avoidance.cell_of(unit.position)
	var goal: Vector2i = Avoidance.cell_of(unit.destination)
	var points: Array[Vector2] = sim._navigation.route_avoiding(from, Vector2(unit.destination[0], unit.destination[1]), cells.filter(func(cell: Vector2i) -> bool: return cell != here and cell != goal))
	if points.is_empty():
		Avoidance.count(sim, "reroute_fail")
		return -1
	var route: Array = []
	for point in points: route.append(sim._frozen([point.x, point.y]))
	if route.size() > 1 and sim._behind(from, route[0], route[1]): route.pop_front()
	unit.route = route
	unit.status = "moving"
	Avoidance.count(sim, "reroutes")
	return 1

# Every cell within WINDOW of the unit that holds a unit solid to it (shortcut: not the whole map, to bound the scan).
static func _solid_cells(sim: Simulation, unit: Dictionary) -> Array[Vector2i]:
	var kind_bits: int = Avoidance.info(unit.kind)
	var here: Vector2i = Avoidance.cell_of(unit.position)
	var cells: Array[Vector2i] = []
	for y in range(maxi(here.y - WINDOW, 0), mini(here.y + WINDOW + 1, Avoidance.height)):
		for x in range(maxi(here.x - WINDOW, 0), mini(here.x + WINDOW + 1, Avoidance.width)):
			var index: int = y * Avoidance.width + x
			var held: int = Avoidance.vehicle_at[index]
			if held == 0 or held == unit.id + 1 or Avoidance._passes(sim, unit, kind_bits, sim._entities[held - 1]):
				held = Avoidance.infantry_at[index]
				if held == 0 or held == unit.id + 1 or Avoidance._passes(sim, unit, kind_bits, sim._entities[held - 1]): continue
			cells.append(Vector2i(x, y))
	return cells

# No route: step out of a cell someone else has claimed, else give up (destination left as is).
static func _stuck(sim: Simulation, unit: Dictionary, rec: Dictionary) -> void:
	var index: int = Avoidance.index_of(unit.position)
	var claimant: int = vehicle_claim[index]
	if claimant == 0: claimant = infantry_claim[index]
	if claimant != 0 and claimant != unit.id + 1 and Avoidance.sidestep(sim, unit, sim._entities[claimant - 1], true):
		rec.stage = 0
		return
	unit.order = null
	unit.route = []
	unit.status = "arrived"
	unit.speed = 0.0
	rec.resume = null
	rec.claim = -1
	rec.stage = 0
	Avoidance.count(sim, "gave_up")
