@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

func cases() -> Array[Callable]:
	return [test_bot_collector_quota_per_supply_centre]

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
