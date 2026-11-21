@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Economy = preload("res://tests/economy_fixture.gd")

const RALLY := Vector2(43.5, 14.5)
const SEAT: int = 2

func cases() -> Array[Callable]:
	return [test_bot_collector_quota_per_supply_centre, test_bot_seat_idle_unit_ignores_enemy_beyond_reach, test_no_enemy_building_attack_before_first_wave, test_wave_gaps_90_then_60, test_wave_leaves_when_ready_cost_reaches_target, test_wave_size_counts_unit_cost_not_count, test_unit_cost_is_build_list_mean, test_wave_takes_highest_cost_first, test_wave_stops_at_exact_target, test_wave_capped_by_cost_rest_guards_home, test_wave_zero_takes_at_most_16, test_wave_leaves_at_wait_cap, test_nothing_ready_at_wait_cap_leaves_with_first_ready, test_late_arrival_waits_for_next_wave, test_wave_targets_grow_then_hold_at_32, test_attack_tick_gates_gather, test_released_by_timer_size_wait_cap, test_bot_without_building_launches_no_wave]

func _world() -> RefCounted:
	var sim = Simulation.new([], Vector2i(48, 32))
	sim.add_player(1, 10000)
	sim.add_player(SEAT, 0)
	sim.spawn(SEAT, Vector2(46.5, 28.5), "usa_builder")
	Economy.add_completed(sim, SEAT, "usa_command_center", Vector2i(40, 26))
	Economy.add_completed(sim, 1, "usa_command_center", Vector2i(4, 4))
	return sim

func _ready(sim: RefCounted, kind: String, count: int) -> Array:
	var ids: Array = []
	for i in range(63):
		if ids.size() == count: break
		var id: int = sim.spawn(SEAT, RALLY + Vector2(i % 9 - 4, floori(i / 9.0) - 4), kind)
		if id >= 0: ids.append(id)
	return ids

func _log() -> Dictionary:
	return {"seen": {}, "launches": []}

# A launch is an attack order that names a unit no earlier order named; launched units are removed so they never fight.
func _play(sim: RefCounted, rec: Dictionary, until: int, attack_tick: int = Skirmish.FIRST_WAVE_TICK) -> void:
	while sim.tick() < until:
		Skirmish.issue_opponent(sim, SEAT, attack_tick)
		var gone: Array = []
		if Skirmish.decides(sim.tick(), SEAT):
			for command in sim.snapshot().pending_commands:
				var fresh: Array = command.entity_ids.filter(func(id: int) -> bool: return not rec.seen.has(id)) if command.player == SEAT and command.type == "attack" else []
				if fresh.is_empty(): continue
				var ids: Array = command.entity_ids.duplicate()
				ids.sort()
				rec.launches.append({"tick": sim.tick(), "ids": ids})
				for id in ids: rec.seen[id] = true
				gone.append_array(ids)
		sim.step()
		for id in gone: sim.remove_object(id)

func _memory(sim: RefCounted) -> Dictionary:
	return Skirmish.team_memory(sim, SEAT)

func _first_decision_from(tick: int) -> int:
	return Skirmish.next_decision(tick - 1, SEAT)

func _attacking(sim: RefCounted, ids: Array) -> Array:
	var found: Array = []
	for unit in sim.snapshot().entities:
		if ids.has(unit.id) and unit.combat.mode == "attack": found.append(unit.id)
	return found

func _moving(sim: RefCounted) -> bool:
	return sim.snapshot().pending_commands.any(func(command: Dictionary) -> bool: return command.player == SEAT and command.type == "move")

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

func test_no_enemy_building_attack_before_first_wave(runner) -> bool:
	var sim = _world()
	_ready(sim, "usa_tank", 5)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.FIRST_WAVE_TICK)
	runner.check(rec.launches.is_empty(), "BR2 no attack order before tick %d, got %s" % [Skirmish.FIRST_WAVE_TICK, rec.launches])
	_play(sim, rec, Skirmish.FIRST_WAVE_TICK + Skirmish.DECISION_TICKS)
	runner.check(rec.launches.size() == 1 and rec.launches[0].tick == _first_decision_from(Skirmish.FIRST_WAVE_TICK), "BR2 wave 0 leaves at the first decision from tick 4500 once the ready cost reaches the target, got %s" % [rec.launches.map(func(row: Dictionary) -> int: return row.tick)])
	return true

func test_wave_gaps_90_then_60(runner) -> bool:
	var sim = _world()
	var rec: Dictionary = _log()
	_ready(sim, "usa_tank", 20)
	var restocked: int = 0
	while rec.launches.size() < 5 and sim.tick() < 20000:
		_play(sim, rec, sim.tick() + Skirmish.DECISION_TICKS)
		if rec.launches.size() > restocked:
			restocked = rec.launches.size()
			_ready(sim, "usa_tank", rec.launches[-1].ids.size())
	var ticks: Array = rec.launches.map(func(row: Dictionary) -> int: return row.tick)
	var gaps: Array = []
	for i in range(1, ticks.size()): gaps.append(ticks[i] - ticks[i - 1])
	runner.check(ticks.size() == 5 and ticks[0] == _first_decision_from(Skirmish.FIRST_WAVE_TICK), "BR2 five waves left, the first at the first decision from 4500, got %s" % [ticks])
	runner.check(gaps == [2700, 2700, 1800, 1800], "BR2 waves 0 and 1 are followed by 2700 ticks, later waves by 1800, got %s" % [gaps])
	return true

func test_wave_leaves_when_ready_cost_reaches_target(runner) -> bool:
	var sim = _world()
	_ready(sim, "usa_tank", 4)
	var rec: Dictionary = _log()
	_play(sim, rec, 300, 0)
	runner.check(rec.launches.is_empty(), "BR3 four tanks (3600) stay below the 4248 target")
	_ready(sim, "usa_tank", 1)
	_play(sim, rec, 600, 0)
	runner.check(rec.launches.size() == 1 and rec.launches[0].tick == _first_decision_from(300) and rec.launches[0].ids.size() == 5, "BR3 the wave leaves at the next decision once a fifth tank lifts the ready cost to 4500, got %s" % [rec.launches])
	return true

func test_wave_size_counts_unit_cost_not_count(runner) -> bool:
	var rifles = _world()
	_ready(rifles, "usa_rifle_infantry", 18)
	var rifle_log: Dictionary = _log()
	_play(rifles, rifle_log, Skirmish.WAVE_WAIT - Skirmish.DECISION_TICKS, 0)
	runner.check(rifle_log.launches.is_empty(), "BR3 eighteen riflemen (4050) stay below the 4248 target")
	var tanks = _world()
	_ready(tanks, "usa_tank", 5)
	var tank_log: Dictionary = _log()
	_play(tanks, tank_log, Skirmish.DECISION_TICKS, 0)
	runner.check(tank_log.launches.size() == 1, "BR3 five tanks (4500) reach the target at the first decision")
	var short = _world()
	_ready(short, "china_rifle_infantry", 28)
	var short_log: Dictionary = _log()
	_play(short, short_log, Skirmish.WAVE_WAIT - Skirmish.DECISION_TICKS, 0)
	runner.check(short_log.launches.is_empty(), "BR3 twenty-eight Militia count 150 each (4200), below 4248")
	var full = _world()
	_ready(full, "china_rifle_infantry", 29)
	var full_log: Dictionary = _log()
	_play(full, full_log, Skirmish.DECISION_TICKS, 0)
	runner.check(full_log.launches.size() == 1, "BR3 twenty-nine Militia (4350) reach the target")
	return true

func test_unit_cost_is_build_list_mean(runner) -> bool:
	runner.check(Skirmish.faction_unit_cost("usa") == 531 and Skirmish.faction_unit_cost("china") == 512 and Skirmish.faction_unit_cost("frc") == 387, "BR3 unit cost is USA 531, China 512, FRC 387, got %d, %d, %d" % [Skirmish.faction_unit_cost("usa"), Skirmish.faction_unit_cost("china"), Skirmish.faction_unit_cost("frc")])
	for faction: String in ["usa", "china", "frc"]:
		var kinds: Array = []
		for producer: String in Registry.faction(faction).units_for: kinds.append_array(Registry.faction(faction).units_for[producer])
		var sum: int = 0
		for kind: String in kinds: sum += floori(Registry.kind(kind).cost / float(Registry.kind(kind).get("quantity", 1)))
		runner.check(Skirmish.faction_unit_cost(faction) == floori(sum / float(kinds.size())), "BR3 %s unit cost is the integer mean over its units_for kinds" % faction)
	runner.check(Skirmish.unit_cost("china_rifle_infantry") == 150 and Skirmish.unit_cost("usa_tank") == 900, "BR3 a Militia order of two costs 150 per unit, a tank 900")
	return true

func test_wave_takes_highest_cost_first(runner) -> bool:
	var sim = _world()
	var rifles: Array = _ready(sim, "usa_rifle_infantry", 5)
	var rockets: Array = _ready(sim, "usa_rocket_infantry", 2)
	var light: Array = _ready(sim, "usa_light_vehicle", 1)
	var tanks: Array = _ready(sim, "usa_tank", 3)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.DECISION_TICKS, 0)
	var expected: Array = tanks + light + rockets + rifles.slice(0, 2)
	expected.sort()
	runner.check(rec.launches.size() == 1 and rec.launches[0].ids == expected, "BR3 the wave takes tanks, scout car, rockets, then the two lowest-id riflemen (4450 first reaches 4248), got %s, expected %s" % [rec.launches, expected])
	return true

func test_wave_stops_at_exact_target(runner) -> bool:
	var row: Dictionary = Registry.kind("usa_tank").duplicate(true)
	row.cost = 531
	Registry.add_test_kind("test_exact_unit", row)
	var sim = _world()
	var units: Array = _ready(sim, "test_exact_unit", 9)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.DECISION_TICKS, 0)
	var exact = _world()
	_ready(exact, "test_exact_unit", 8)
	var exact_rec: Dictionary = _log()
	_play(exact, exact_rec, Skirmish.DECISION_TICKS, 0)
	Registry.clear_test_kinds()
	runner.check(rec.launches.size() == 1 and rec.launches[0].ids == units.slice(0, 8), "BR3 the wave stops at the unit that first reaches the 4248 target, the ninth stays, got %s" % [rec.launches])
	runner.check(exact_rec.launches.size() == 1, "BR3 ready units worth exactly the target leave at once")
	return true

func test_wave_capped_by_cost_rest_guards_home(runner) -> bool:
	var sim = _world()
	var tanks: Array = _ready(sim, "usa_tank", 10)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 1 and rec.launches[0].ids == tanks.slice(0, 5), "BR3 five tanks (4500) first reach 4248, got %s" % [rec.launches])
	runner.check(_attacking(sim, tanks.slice(5)).is_empty(), "BR3 the other five tanks guard home")
	_ready(sim, "usa_tank", 3)
	var due: int = _memory(sim).get("due", Skirmish.FIRST_WAVE_TICK)
	_play(sim, rec, due + Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 2 and rec.launches[1].tick == due and tanks.slice(5).all(func(id: int) -> bool: return rec.launches[1].ids.has(id)), "BR3 the five home tanks leave with wave 1 (6372), got %s" % [rec.launches])
	return true

func test_wave_zero_takes_at_most_16(runner) -> bool:
	var sim = _world()
	var rifles: Array = _ready(sim, "usa_rifle_infantry", 30)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 1 and rec.launches[0].ids == rifles.slice(0, 16), "BR3 wave 0 takes 16 riflemen although 19 would reach the target, got %d" % [rec.launches[0].ids.size() if not rec.launches.is_empty() else -1])
	_ready(sim, "usa_rifle_infantry", 30)
	_play(sim, rec, rec.launches[0].tick + 2700 + Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 2 and rec.launches[1].ids.size() == 29, "BR3 wave 1 has no unit cap: 29 riflemen reach 6372, got %s" % [rec.launches.map(func(row: Dictionary) -> int: return row.ids.size())])
	return true

func test_wave_leaves_at_wait_cap(runner) -> bool:
	var sim = _world()
	var rifles: Array = _ready(sim, "usa_rifle_infantry", 7)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.WAVE_WAIT, 0)
	runner.check(rec.launches.is_empty(), "BR3 seven riflemen (1575) wait while the target is unmet")
	_play(sim, rec, Skirmish.WAVE_WAIT + Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 1 and rec.launches[0].tick == _first_decision_from(Skirmish.WAVE_WAIT) and rec.launches[0].ids == rifles, "BR3 at 1800 ticks after due the wave leaves with what is ready, got %s" % [rec.launches])
	return true

func test_nothing_ready_at_wait_cap_leaves_with_first_ready(runner) -> bool:
	var sim = _world()
	var rec: Dictionary = _log()
	_play(sim, rec, 2500, 0)
	var rifle: Array = _ready(sim, "usa_rifle_infantry", 1)
	_play(sim, rec, 2600, 0)
	runner.check(rec.launches.size() == 1 and rec.launches[0].tick == _first_decision_from(2500) and rec.launches[0].ids == rifle, "BR2 with nothing ready at the cap the first ready unit leaves at the next decision, got %s" % [rec.launches])
	return true

func test_late_arrival_waits_for_next_wave(runner) -> bool:
	var sim = _world()
	_ready(sim, "usa_tank", 5)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.DECISION_TICKS, 0)
	var late: Array = _ready(sim, "usa_tank", 1)
	var due: int = _memory(sim).get("due", Skirmish.FIRST_WAVE_TICK)
	_play(sim, rec, due - Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 1 and _attacking(sim, late).is_empty(), "BR2 a unit that arrives after wave 0 left waits for the next wave")
	_ready(sim, "usa_tank", 7)
	_play(sim, rec, due + Skirmish.DECISION_TICKS, 0)
	runner.check(rec.launches.size() == 2 and rec.launches[1].tick == due and rec.launches[1].ids.has(late[0]), "BR2 the late unit leaves with wave 1 at its due tick, got %s" % [rec.launches])
	return true

func test_wave_targets_grow_then_hold_at_32(runner) -> bool:
	var sim = _world()
	var rec: Dictionary = _log()
	var sizes: Array = []
	for wave in range(8):
		var target: int = Skirmish.WAVE_SIZES[mini(wave, Skirmish.WAVE_SIZES.size() - 1)] * 531
		var below: int = ceili(target / 900.0) - 1
		_ready(sim, "usa_tank", below)
		var due: int = _memory(sim).get("due", Skirmish.FIRST_WAVE_TICK)
		_play(sim, rec, due + 60)
		runner.check(rec.launches.size() == wave, "BR3 wave %d does not leave with %d tanks (%d), target %d" % [wave, below, below * 900, target])
		_ready(sim, "usa_tank", 1)
		_play(sim, rec, due + 2 * Skirmish.DECISION_TICKS + 60)
		sizes.append(rec.launches[-1].ids.size() if rec.launches.size() > wave else -1)
	runner.check(sizes == [5, 8, 10, 12, 15, 17, 19, 19], "BR3 wave sizes grow 8, 12, 16, 20, 24, 28, 32 then hold at 32 (tanks), got %s" % [sizes])
	return true

func test_attack_tick_gates_gather(runner) -> bool:
	var sim = _world()
	var stray: int = sim.spawn(SEAT, Vector2(30.5, 10.5), "usa_tank")
	_ready(sim, "usa_tank", 5)
	var rec: Dictionary = _log()
	var moved_early: bool = false
	while sim.tick() < 3000:
		Skirmish.issue_opponent(sim, SEAT, 3000)
		moved_early = moved_early or (Skirmish.decides(sim.tick(), SEAT) and _moving(sim))
		sim.step()
	runner.check(not moved_early and rec.launches.is_empty(), "BR2 a caller's attack tick of 3000 holds back rally moves and waves until then")
	_play(sim, rec, 3100, 3000)
	runner.check(rec.launches.size() == 1 and rec.launches[0].tick == _first_decision_from(3000) and not rec.launches[0].ids.has(stray), "BR2 the first wave leaves at the first decision from the caller's tick with the units already at the rally, got %s" % [rec.launches])
	return true

func test_released_by_timer_size_wait_cap(runner) -> bool:
	var timer = _world()
	_ready(timer, "usa_tank", 5)
	_play(timer, _log(), 100, 0)
	runner.check(_memory(timer).get("released_by", "") == "timer", "BR4 target met at the first decision from due is released by timer, got %s" % [_memory(timer).get("released_by", "")])
	var size = _world()
	_ready(size, "usa_tank", 3)
	var size_log: Dictionary = _log()
	_play(size, size_log, 300, 0)
	_ready(size, "usa_tank", 2)
	_play(size, size_log, 400, 0)
	runner.check(_memory(size).get("released_by", "") == "size", "BR4 target met later, before the wait cap, is released by size, got %s" % [_memory(size).get("released_by", "")])
	var capped = _world()
	_ready(capped, "usa_tank", 2)
	_play(capped, _log(), Skirmish.WAVE_WAIT + 100, 0)
	runner.check(_memory(capped).get("released_by", "") == "wait_cap", "BR4 a wave left short at the wait cap is released by wait_cap, got %s" % [_memory(capped).get("released_by", "")])
	return true

func test_bot_without_building_launches_no_wave(runner) -> bool:
	var sim = _world()
	_ready(sim, "usa_tank", 5)
	for building in sim.snapshot().buildings:
		if building.owner == SEAT: sim.remove_object(building.id)
	var rec: Dictionary = _log()
	_play(sim, rec, Skirmish.WAVE_WAIT + 100, 0)
	runner.check(rec.launches.is_empty(), "BR4 a seat with no victory building is not a live bot and launches no wave")
	return true
