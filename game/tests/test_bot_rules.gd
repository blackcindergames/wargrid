@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

func cases() -> Array[Callable]:
	return [test_bot_collector_quota_per_supply_centre, test_bot_seat_idle_unit_ignores_enemy_beyond_reach]

func _collectors_after(faction: String, kind: String, ticks: int) -> int:
	var sim: RefCounted = Skirmish.create(true, "ai", {1: "usa", 2: faction})
	for tick in range(ticks):
		Skirmish.issue_opponent(sim, 2)
		sim.step()
	return sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.owner == 2 and u.kind == kind).size()

func test_bot_collector_quota_per_supply_centre(runner) -> bool:
	runner.check(Registry.faction("usa").bot_collectors_per_supply_center == 3 and Registry.faction("china").bot_collectors_per_supply_center == 4 and Registry.faction("frc").bot_collectors_per_supply_center == 6, "BR1 quota per supply centre is USA 3, China 4, FRC 6")
	var usa: int = _collectors_after("usa", "usa_collector", 5400)
	runner.check(usa == 3, "BR1 a USA bot with one supply centre runs three collectors, got %d" % usa)
	var china: int = _collectors_after("china", "china_collector", 5400)
	runner.check(china == 4, "BR1 a China bot with one supply centre runs four collectors, got %d" % china)
	return true

func test_bot_seat_idle_unit_ignores_enemy_beyond_reach(runner) -> bool:
	var sim: RefCounted = Skirmish.create(true)
	var seat: Dictionary = sim.snapshot().players[1]
	runner.check(seat.controller == "human", "UR1 the default second seat runs human unit rules, got %s" % seat.controller)
	var guard: int = sim.spawn(2, Vector2(20.5, 10.5), "usa_rifle_infantry")
	var prey: int = sim.spawn(1, Vector2(25.5, 10.5), "usa_builder")
	runner.check(guard >= 0 and prey >= 0, "UR1 both units spawn")
	sim.step()
	var unit: Dictionary = sim.snapshot().entities.filter(func(entity: Dictionary) -> bool: return entity.id == guard)[0]
	runner.check(unit.combat.target_id == null, "UR1 an idle guard of the bot seat ignores an enemy 5 cells away, beyond its weapon reach, got target %s" % [unit.combat.target_id])
	var near_sim: RefCounted = Skirmish.create(true)
	var near_guard: int = near_sim.spawn(2, Vector2(20.5, 10.5), "usa_rifle_infantry")
	var near_prey: int = near_sim.spawn(1, Vector2(23.5, 10.5), "usa_builder")
	near_sim.step()
	var near_unit: Dictionary = near_sim.snapshot().entities.filter(func(entity: Dictionary) -> bool: return entity.id == near_guard)[0]
	runner.check(near_unit.combat.target_id == near_prey, "UR1 an idle guard of the bot seat takes an enemy 3 cells away, inside its weapon reach, got target %s" % [near_unit.combat.target_id])
	return true
