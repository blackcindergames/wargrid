extends RefCounted

# Approach A (spike): Zero Hour style yielding. Rules cite AIUpdate.cpp / AIPathfind.cpp in the spike plan.
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Avoidance = preload("res://scripts/simulation/avoidance.gd")

const WAIT_BEFORE_REROUTE: int = 60

static func ignores(unit: Dictionary) -> bool:
	var destination: Variant = unit.destination
	if destination == null: return false
	var here: Vector2i = Avoidance.cell_of(unit.position)
	var goal: Vector2i = Avoidance.cell_of(destination)
	return absi(here.x - goal.x) <= 1 and absi(here.y - goal.y) <= 1

static func blocked(sim: Simulation, mover: Dictionary, rec: Dictionary, other: Dictionary) -> void:
	var other_standing: bool = Avoidance.standing(other)
	var movable: bool = Avoidance.friendly(sim, mover, other) and not Avoidance.busy(other)
	var mover_bits: int = Avoidance.info(mover.kind)
	var other_bits: int = Avoidance.info(other.kind)
	if mover_bits & Avoidance.CLASS_MASK == Avoidance.VEHICLE and other_bits & Avoidance.CLASS_MASK == Avoidance.INFANTRY and movable:
		if Avoidance.sidestep(sim, other, mover, not other_standing): return
	elif other_standing:
		if movable and Avoidance.sidestep(sim, other, mover, false): return
	if other_standing:
		Avoidance.reroute(sim, mover, rec, other)
		return
	if _head_on(mover, other):
		var other_yields: bool = _has_priority(mover, mover_bits, other, other_bits)
		if Avoidance.sidestep(sim, other if other_yields else mover, mover if other_yields else other, true): return
	if rec.blocked % WAIT_BEFORE_REROUTE == 0: Avoidance.reroute(sim, mover, rec, other)

static func _head_on(mover: Dictionary, other: Dictionary) -> bool:
	var route: Array = other.route
	return other.status == "moving" and not route.is_empty() and Avoidance.cell_of(route[0]) == Avoidance.cell_of(mover.position)

# hasHigherPathPriority: builder over non-builder, vehicle over infantry, then who is ahead along the shared heading, then lower id.
static func _has_priority(a: Dictionary, a_bits: int, b: Dictionary, b_bits: int) -> bool:
	if (a_bits ^ b_bits) & Avoidance.BUILDER != 0: return a_bits & Avoidance.BUILDER != 0
	if (a_bits ^ b_bits) & Avoidance.CLASS_MASK != 0: return a_bits & Avoidance.CLASS_MASK == Avoidance.VEHICLE
	var ha: Array = a.heading
	var hb: Array = b.heading
	if ha[0] * hb[0] + ha[1] * hb[1] <= 0.0: return a.id < b.id
	var pa: Array = a.position
	var pb: Array = b.position
	var ahead: float = (ha[0] + hb[0]) * (pb[0] - pa[0]) + (ha[1] + hb[1]) * (pb[1] - pa[1])
	if ahead == 0.0: return a.id < b.id
	return ahead < 0.0
