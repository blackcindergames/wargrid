extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")

const LOADS: Array[String] = ["skirmish3v3", "team", "hordes300", "late_game_3v3"]
# Worker spike Task 0 rule: first 300-tick mark with at least 210 units (the goal row).
const TEAM_START_TICK: int = 6300
const WARMUP: int = 300
const WINDOW: int = 1800

static func create(load_name: String) -> Simulation:
	assert(LOADS.has(load_name))
	if load_name == "team": return TeamMatch.create()
	return CombatWorkload.create(load_name)

static func advance(load_name: String, sim: Simulation) -> void:
	if load_name == "team": TeamMatch.step(sim)
	else: sim.step()

static func start_tick(load_name: String) -> int:
	return TEAM_START_TICK if load_name == "team" else 0

# The seats the pump's job asks to decide; the same seats advance() steps, so digests match the fast-forward path.
static func bots(load_name: String) -> Array[int]:
	var seats: Array[int] = []
	if load_name == "team":
		for entry: Dictionary in TeamMatch.SEATS: seats.append(entry.seat)
	return seats
