@warning_ignore_start("untyped_declaration")
extends RefCounted

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Economy = preload("res://tests/economy_fixture.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")

const RALLY := Vector2(43.5, 14.5)
const SEAT: int = 2
const CROWN := "res://data/maps/broken_crown.json"
const ASHFALL := "res://data/maps/ashfall.json"
const A: int = 3
const B: int = 4
const DUE: int = 1000

func cases() -> Array[Callable]:
	return [test_bot_collector_quota_per_supply_centre, test_bot_seat_idle_unit_ignores_enemy_beyond_reach, test_no_enemy_building_attack_before_first_wave, test_wave_gaps_90_then_60, test_wave_leaves_when_ready_cost_reaches_target, test_wave_size_counts_unit_cost_not_count, test_unit_cost_is_build_list_mean, test_wave_takes_highest_cost_first, test_wave_stops_at_exact_target, test_wave_capped_by_cost_rest_guards_home, test_wave_zero_takes_at_most_16, test_wave_leaves_at_wait_cap, test_nothing_ready_at_wait_cap_leaves_with_first_ready, test_late_arrival_waits_for_next_wave, test_wave_targets_grow_then_hold_at_32, test_attack_tick_gates_gather, test_released_by_timer_size_wait_cap, test_bot_without_building_launches_no_wave, test_team_bots_leave_within_one_round, test_team_wave_takes_from_every_live_bot, test_team_target_sums_cost_of_live_bots, test_teammate_without_first_decision_not_counted, test_team_waves_share_objective, test_defeated_enemy_with_defence_is_no_victim, test_team_waves_alternate_human_target, test_three_enemies_least_recent_first, test_objective_repicked_once_for_team, test_engaged_wave_returns_to_team_objective, test_lone_bot_is_team_of_one, test_dead_teammate_does_not_hold_clock, test_last_live_joiner_takes_up_to_left, test_rally_units_sent_to_defend_skip_the_join, test_team_forms_on_either_side_of_due, test_released_by_is_first_team_decision]

func _world() -> RefCounted:
	var sim = Simulation.new([], Vector2i(48, 32))
	sim.add_player(1, 10000)
	sim.add_player(SEAT, 0)
	sim.spawn(SEAT, Vector2(46.5, 28.5), "usa_builder")
	Economy.add_completed(sim, SEAT, "usa_command_center", Vector2i(40, 26))
	Economy.add_completed(sim, 1, "usa_command_center", Vector2i(4, 4))
	return sim

func _ready(sim: RefCounted, kind: String, count: int) -> Array:
	return _around(sim, SEAT, RALLY, kind, count)

static func _around(sim: RefCounted, seat: int, centre: Vector2, kind: String, count: int) -> Array:
	var ids: Array = []
	for i in range(63):
		if ids.size() == count: break
		var id: int = sim.spawn(seat, centre + Vector2(i % 9 - 4, floori(i / 9.0) - 4), kind)
		if id >= 0: ids.append(id)
	return ids

static func stock(sim: RefCounted, seat: int, kind: String, count: int) -> Array:
	return _around(sim, seat, Vector2(MapData.start_cell(sim.map_data(), seat)) + Vector2(0.5, 0.5), kind, count)

# Seats are [seat, team] or [seat, team, faction]; every seat starts with its headquarters and no credits.
static func arena(map_path: String, seats: Array) -> RefCounted:
	var rows: Array[Dictionary] = []
	var ids: Array[int] = []
	for entry: Array in seats:
		rows.append({"seat": entry[0], "team": entry[1], "controller": "human", "faction": entry[2] if entry.size() > 2 else "usa", "credits": 0})
		ids.append(entry[0])
	var sim: RefCounted = MapData.create(MapData.load(map_path), rows)
	sim.start_match(ids)
	return sim

func _crown() -> RefCounted:
	var sim: RefCounted = arena(CROWN, [[1, 1], [2, 1], [A, 2], [B, 2]])
	Economy.add_completed(sim, 1, "usa_barracks", Vector2i(20, 18))
	Economy.add_completed(sim, 2, "usa_barracks", Vector2i(94, 18))
	return sim

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

func _first_decision_from(tick: int, seat: int = SEAT) -> int:
	return Skirmish.next_decision(tick - 1, seat)

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
	runner.check(rec.launches.size() == 1 and rec.launches[0].tick == _first_decision_from(Skirmish.FIRST_WAVE_TICK), "BR2 wave 0 leaves at the first decision from FIRST_WAVE_TICK once the ready cost reaches the target, got %s" % [rec.launches.map(func(row: Dictionary) -> int: return row.tick)])
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
	runner.check(ticks.size() == 5 and ticks[0] == _first_decision_from(Skirmish.FIRST_WAVE_TICK), "BR2 five waves left, the first at the first decision from FIRST_WAVE_TICK, got %s" % [ticks])
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

# Every attack order a bot sends on its decision tick; a launch is one that names a unit no earlier order named.
func _team_play(sim: RefCounted, rec: Dictionary, until: int, seats: Array[int], attack_tick: int = DUE, remove: bool = true) -> void:
	if not rec.has("orders"): rec.orders = []
	while sim.tick() < until:
		Skirmish.issue_opponents(sim, seats, attack_tick)
		var gone: Array = []
		for command in sim.snapshot().pending_commands:
			if command.type != "attack" or not seats.has(command.player) or not Skirmish.decides(sim.tick(), command.player): continue
			var ids: Array = command.entity_ids.duplicate()
			ids.sort()
			var order := {"tick": sim.tick(), "player": command.player, "target": command.target_id, "ids": ids}
			rec.orders.append(order)
			if ids.all(func(id: int) -> bool: return rec.seen.has(id)): continue
			for id in ids: rec.seen[id] = true
			rec.launches.append(order)
			gone.append_array(ids)
		sim.step()
		if remove:
			for id in gone: sim.remove_object(id)

func _both(sim: RefCounted, rec: Dictionary, until: int, remove: bool = true) -> void:
	_team_play(sim, rec, until, [A, B], DUE, remove)

func _owner_of(sim: RefCounted, building: Variant) -> int:
	for entry in sim.snapshot().buildings:
		if entry.id == building: return entry.owner
	return -1

func _of(rec: Dictionary, player: int) -> Array:
	return rec.launches.filter(func(row: Dictionary) -> bool: return row.player == player)

func test_team_bots_leave_within_one_round(runner) -> bool:
	var sim = _crown()
	var four: Array = stock(sim, A, "usa_tank", 4)
	var six: Array = stock(sim, B, "usa_tank", 6)
	var rec: Dictionary = _log()
	_both(sim, rec, DUE + 2 * Skirmish.DECISION_TICKS)
	var first: int = _first_decision_from(DUE, A)
	var ticks: Array = rec.launches.map(func(row: Dictionary) -> int: return row.tick)
	runner.check(rec.launches.size() == 2 and ticks.all(func(tick: int) -> bool: return tick >= first and tick < first + Skirmish.DECISION_TICKS), "BR4 both bots leave inside one round from the first decision after due although seat 3 alone is below the share, got %s" % [rec.launches.map(func(row: Dictionary) -> String: return "%d:%d" % [row.player, row.tick])])
	runner.check(four.size() == 4 and six.size() == 6 and _of(rec, A).size() == 1 and _of(rec, B).size() == 1, "BR4 each bot sends one order, got %d and %d" % [_of(rec, A).size(), _of(rec, B).size()])
	return true

func test_team_wave_takes_from_every_live_bot(runner) -> bool:
	var sim = _crown()
	var few: Array = stock(sim, A, "usa_tank", 3)
	var many: Array = stock(sim, B, "usa_tank", 8)
	var rec: Dictionary = _log()
	_both(sim, rec, DUE + 2 * Skirmish.DECISION_TICKS)
	runner.check(_of(rec, A).size() == 1 and _of(rec, A)[0].ids == few, "BR4 the launching bot sends all three of its tanks, got %s" % [_of(rec, A)])
	runner.check(_of(rec, B).size() == 1 and _of(rec, B)[0].ids == many.slice(0, 7), "BR4 the joiner takes up to what is left of the target (8496 less 2700): seven tanks, not its half share of five, got %s" % [_of(rec, B)])
	var rich = _crown()
	var a_tanks: Array = stock(rich, A, "usa_tank", 12)
	var b_tanks: Array = stock(rich, B, "usa_tank", 12)
	var rich_rec: Dictionary = _log()
	_both(rich, rich_rec, DUE + 2 * Skirmish.DECISION_TICKS)
	runner.check(_of(rich_rec, A).size() == 1 and _of(rich_rec, A)[0].ids == a_tanks.slice(0, 5) and _of(rich_rec, B).size() == 1 and _of(rich_rec, B)[0].ids == b_tanks.slice(0, 5), "BR4 two bots that each hold more than half the target send five tanks each, got %s" % [rich_rec.launches])
	return true

func test_team_target_sums_cost_of_live_bots(runner) -> bool:
	var sim: RefCounted = arena(CROWN, [[1, 1], [2, 1], [A, 2, "usa"], [B, 2, "china"]])
	stock(sim, A, "usa_tank", 5)
	stock(sim, B, "usa_tank", 4)
	var rec: Dictionary = _log()
	_both(sim, rec, DUE + 100)
	runner.check(rec.launches.is_empty(), "BR3 nine tanks (8100) stay below the team target 8 x 2 x 521 = 8336, got %s" % [rec.launches])
	stock(sim, B, "usa_tank", 1)
	_both(sim, rec, DUE + 200)
	var total: int = 0
	for row in rec.launches: total += row.ids.size()
	runner.check(rec.launches.size() == 2 and total == 10 and rec.launches[0].tick >= DUE + 100, "BR3 the tenth tank (9000) releases the team wave, got %s" % [rec.launches])
	return true

func test_teammate_without_first_decision_not_counted(runner) -> bool:
	var sim = _crown()
	var lead: Array = stock(sim, A, "usa_tank", 5)
	stock(sim, B, "usa_tank", 12)
	var rec: Dictionary = _log()
	_team_play(sim, rec, DUE + 100, [A])
	runner.check(rec.launches.size() == 1 and rec.launches[0].ids == lead, "BR4 a seat that has not decided is not live: seat 3 alone meets a target of 4248, got %s" % [rec.launches])
	var objective: Variant = Skirmish.team_memory(sim, 2).objective
	runner.check(objective != null and objective == rec.launches[0].target, "BR5 the launch wrote the team objective %s" % [objective])
	_both(sim, rec, DUE + 200)
	runner.check(_of(rec, B).is_empty(), "BR4 the late seat is no joiner of a wave already formed, got %s" % [_of(rec, B)])
	return true

func test_team_waves_share_objective(runner) -> bool:
	var sim = _crown()
	stock(sim, A, "usa_tank", 5)
	stock(sim, B, "usa_tank", 5)
	var rec: Dictionary = _log()
	_both(sim, rec, DUE + 100)
	var objective: Variant = Skirmish.team_memory(sim, 2).objective
	runner.check(rec.launches.size() == 2 and rec.launches[0].target == rec.launches[1].target and rec.launches[0].target == objective, "BR5 both waves target the one team objective, got %s, objective %s" % [rec.launches.map(func(row: Dictionary) -> Variant: return row.target), objective])
	runner.check(_owner_of(sim, objective) == 1, "BR5 the objective is a building of the lowest-id enemy when none was attacked, got owner %d" % _owner_of(sim, objective))
	return true

func test_defeated_enemy_with_defence_is_no_victim(runner) -> bool:
	var sim = _crown()
	var origin := Vector2i(-1, -1)
	for entry in sim.snapshot().buildings:
		if entry.owner != 1: continue
		if entry.kind == "usa_command_center": origin = Vector2i(entry.origin[0], entry.origin[1])
		sim.remove_object(entry.id)
	var battery: int = Economy.add_completed(sim, 1, "usa_defence", origin)
	stock(sim, A, "usa_tank", 5)
	var rec: Dictionary = _log()
	_team_play(sim, rec, DUE + 100, [A])
	var objective: Variant = Skirmish.team_memory(sim, 2).objective
	runner.check(battery >= 0 and rec.launches.size() == 1 and _owner_of(sim, objective) == 2, "BR5 a player left with only a defence is not live; the wave goes to live player 2, got objective %s owner %d" % [objective, _owner_of(sim, objective)])
	return true

func test_team_waves_alternate_human_target(runner) -> bool:
	var sim = _crown()
	var rec: Dictionary = _log()
	var owners: Array = []
	for wave in range(3):
		stock(sim, A, "usa_tank", 10)
		stock(sim, B, "usa_tank", 10)
		_both(sim, rec, Skirmish.team_memory(sim, 2).get("due", DUE) + 2 * Skirmish.DECISION_TICKS)
		owners.append(_owner_of(sim, Skirmish.team_memory(sim, 2).objective))
	runner.check(owners == [1, 2, 1], "BR5 waves go to the enemy attacked least recently: 1, 2, 1, got %s" % [owners])
	return true

func test_three_enemies_least_recent_first(runner) -> bool:
	var sim: RefCounted = arena(ASHFALL, [[1, 1], [2, 1], [8, 1], [4, 2], [5, 3], [6, 4]])
	var rec: Dictionary = _log()
	var owners: Array = []
	for wave in range(4):
		for seat in [1, 2, 8]: stock(sim, seat, "usa_tank", 10)
		var due: int = Skirmish.team_memory(sim, 1).get("due", DUE)
		_team_play(sim, rec, due + 3 * Skirmish.DECISION_TICKS + 10, [1, 2, 8])
		owners.append(_owner_of(sim, Skirmish.team_memory(sim, 1).objective))
	runner.check(owners == [4, 5, 6, 4], "BR5 three enemy players are attacked least recent first, ties lowest id: 4, 5, 6, 4, got %s" % [owners])
	return true

func test_objective_repicked_once_for_team(runner) -> bool:
	var sim = _crown()
	stock(sim, A, "usa_tank", 5)
	stock(sim, B, "usa_tank", 5)
	var rec: Dictionary = _log()
	_both(sim, rec, _first_decision_from(DUE, A) + 1, false)
	var old: Variant = Skirmish.team_memory(sim, 2).objective
	runner.check(old != null and rec.launches.size() == 1, "BR5 seat 3 formed the wave and wrote the objective, got %s, %s" % [old, rec.launches])
	if old != null: sim.remove_object(old)
	_both(sim, rec, DUE + 100, false)
	var fresh: Variant = Skirmish.team_memory(sim, 2).objective
	var later: Array = rec.orders.filter(func(row: Dictionary) -> bool: return row.tick > _first_decision_from(DUE, A))
	runner.check(fresh != null and fresh != old and later.size() >= 2 and later.all(func(row: Dictionary) -> bool: return row.target == fresh), "BR5 the first bot to notice stores one new objective and every wave follows it, got %s, objective %s" % [later.map(func(row: Dictionary) -> Variant: return row.target), fresh])
	return true

func test_engaged_wave_returns_to_team_objective(runner) -> bool:
	var sim = _crown()
	stock(sim, A, "usa_tank", 5)
	stock(sim, B, "usa_tank", 5)
	var rec: Dictionary = _log()
	_both(sim, rec, DUE + 100, false)
	var objective: Variant = Skirmish.team_memory(sim, 2).objective
	var at: int = Skirmish.next_decision(sim.tick(), A)
	_both(sim, rec, at, false)
	var lead: Dictionary = sim.snapshot().entities.filter(func(unit: Dictionary) -> bool: return unit.owner == A and unit.kind == "usa_tank")[0]
	var intruder: int = -1
	for step in [Vector2(0, -3), Vector2(0, 3), Vector2(-3, 0), Vector2(3, 0)]:
		if intruder < 0: intruder = sim.spawn(1, Vector2(lead.position[0], lead.position[1]) + step, "usa_rifle_infantry")
	_both(sim, rec, at + 1, false)
	var engaged: Array = rec.orders.filter(func(row: Dictionary) -> bool: return row.tick == at and row.player == A)
	runner.check(intruder >= 0 and engaged.size() == 1 and engaged[0].target == intruder, "BR5 a wave with an enemy unit in reach turns on it, got %s" % [engaged])
	runner.check(Skirmish.team_memory(sim, 2).objective == objective, "BR5 the engaged re-pick never writes the team objective")
	sim.remove_object(intruder)
	_both(sim, rec, at + Skirmish.DECISION_TICKS + 1, false)
	var back: Array = rec.orders.filter(func(row: Dictionary) -> bool: return row.tick == at + Skirmish.DECISION_TICKS and row.player == A)
	runner.check(back.size() == 1 and back[0].target == objective, "BR5 when the unit is gone the wave returns to the team objective, got %s, objective %s" % [back, objective])
	return true

func test_lone_bot_is_team_of_one(runner) -> bool:
	var sim = _world()
	_ready(sim, "usa_tank", 5)
	var rec: Dictionary = _log()
	_play(sim, rec, 100, 0)
	var memory: Dictionary = _memory(sim)
	runner.check(rec.launches.size() == 1 and memory.joiners == [] and memory.left_cost == 0, "BR4 a lone bot launches by itself and leaves no joiner, got %s" % [memory])
	runner.check(memory.objective != null and _owner_of(sim, memory.objective) == 1 and memory.attacked_at.get(1, -1) == rec.launches[0].tick, "BR5 a lone bot writes its objective and the attacked tick of that enemy, got %s" % [memory])
	return true

func test_dead_teammate_does_not_hold_clock(runner) -> bool:
	var sim = _crown()
	for entry in sim.snapshot().buildings:
		if entry.owner == B and entry.kind == "usa_command_center": sim.remove_object(entry.id)
	var lone: Array = stock(sim, A, "usa_tank", 5)
	stock(sim, B, "usa_tank", 12)
	var rec: Dictionary = _log()
	_both(sim, rec, DUE + 100)
	runner.check(rec.launches.size() == 1 and rec.launches[0].player == A and rec.launches[0].ids == lone and rec.launches[0].tick == _first_decision_from(DUE, A), "BR4 a defeated teammate neither holds the clock nor raises the target: seat 3 leaves at the first decision with five tanks, got %s" % [rec.launches])
	runner.check(Skirmish.team_memory(sim, 2).joiners == [] and Skirmish.team_memory(sim, 2).objective != null, "BR4 no joiner is waited for, got %s" % [Skirmish.team_memory(sim, 2)])
	return true

func test_last_live_joiner_takes_up_to_left(runner) -> bool:
	var sim: RefCounted = arena(ASHFALL, [[1, 1], [2, 1], [8, 1], [4, 2]])
	stock(sim, 1, "usa_tank", 5)
	stock(sim, 2, "usa_tank", 5)
	var last: Array = stock(sim, 8, "usa_tank", 12)
	var rec: Dictionary = _log()
	var first: int = _first_decision_from(DUE, 1)
	_team_play(sim, rec, first + 1, [1, 2, 8])
	for entry in sim.snapshot().buildings:
		if entry.owner == 2 and entry.kind == "usa_command_center": sim.remove_object(entry.id)
	_team_play(sim, rec, DUE + 100, [1, 2, 8])
	var rows: Array = rec.launches.filter(func(row: Dictionary) -> bool: return row.player == 8)
	runner.check(rec.launches[0].player == 1 and rec.launches[0].tick == first and rows.size() == 1 and rows[0].ids == last.slice(0, 10), "BR4 seat 2 is defeated before it joins, so seat 8 is the last live joiner and takes up to the 8244 left: ten tanks, got %s" % [rec.launches.map(func(row: Dictionary) -> String: return "%d:%d:%d" % [row.player, row.tick, row.ids.size()])])
	return true

func test_rally_units_sent_to_defend_skip_the_join(runner) -> bool:
	var sim = _crown()
	stock(sim, A, "usa_tank", 4)
	var home: Array = stock(sim, B, "usa_tank", 6)
	var rec: Dictionary = _log()
	_both(sim, rec, _first_decision_from(DUE, A) + 1, false)
	var intruder: int = sim.spawn(1, Vector2(18.5, 79.5), "usa_rifle_infantry")
	_both(sim, rec, DUE + 100, false)
	var from_b: Array = rec.orders.filter(func(row: Dictionary) -> bool: return row.player == B)
	runner.check(intruder >= 0 and not from_b.is_empty() and from_b.all(func(row: Dictionary) -> bool: return row.target == intruder) and Skirmish.team_memory(sim, 2).joiners == [], "BR4 units that go to _defend at the join are skipped, the wave leaves short, got %s" % [from_b])
	runner.check(home.size() == 6 and Skirmish.team_memory(sim, 2).objective != null, "BR5 seat 3's launch still wrote the objective")
	return true

func test_team_forms_on_either_side_of_due(runner) -> bool:
	for due in [_first_decision_from(DUE, A), _first_decision_from(DUE, A) + 1]:
		var sim = _crown()
		stock(sim, A, "usa_tank", 5)
		stock(sim, B, "usa_tank", 5)
		var rec: Dictionary = _log()
		_team_play(sim, rec, due + 2 * Skirmish.DECISION_TICKS, [A, B], due)
		var ticks: Array = rec.launches.map(func(row: Dictionary) -> int: return row.tick)
		var forming: int = A if due == _first_decision_from(DUE, A) else B
		runner.check(rec.launches.size() == 2 and rec.launches[0].player == forming and ticks[1] - ticks[0] <= Skirmish.DECISION_TICKS - 1 and rec.launches[0].target == rec.launches[1].target, "BR4 due %d: seat %d forms, the other joins at its next decision with the same objective, got %s" % [due, forming, rec.launches])
	return true

func test_released_by_is_first_team_decision(runner) -> bool:
	var sim = _crown()
	stock(sim, A, "usa_tank", 5)
	var rec: Dictionary = _log()
	var due: int = _first_decision_from(DUE, A) - 3
	_team_play(sim, rec, _first_decision_from(DUE, A) + 1, [A, B], due)
	stock(sim, B, "usa_tank", 5)
	_team_play(sim, rec, due + 100, [A, B], due)
	runner.check(rec.launches.size() == 2 and Skirmish.team_memory(sim, 2).released_by == "size", "BR4 target met by seat 4 after seat 3 already decided past due is released by size, got %s" % [Skirmish.team_memory(sim, 2).released_by])
	var timer = _crown()
	stock(timer, A, "usa_tank", 5)
	stock(timer, B, "usa_tank", 5)
	_team_play(timer, _log(), DUE + 100, [A, B])
	runner.check(Skirmish.team_memory(timer, 2).released_by == "timer", "BR4 target met at the first team decision from due is released by timer, got %s" % [Skirmish.team_memory(timer, 2).released_by])
	return true
