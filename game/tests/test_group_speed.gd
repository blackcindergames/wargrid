@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/combat_fixture.gd")
const EconomyFixture = preload("res://tests/economy_fixture.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

const GOAL := [26.5, 11.5]
# Positions read back as Vector2 (32-bit floats).
const SLACK: float = 1e-3

func cases() -> Array[Callable]:
	return [test_gs1_group_marches_at_its_slowest_speed, test_gs2_move_attack_and_attack_move_take_the_flag, test_gs3_order_without_the_flag_lifts_the_cap, test_gs4_flag_rejections, test_gs5_same_tick_cases, test_gs6_removal, test_gs7_cap_holds_only_while_the_order_does]

func _world() -> Dictionary:
	var sim = Fixture.world()
	sim.add_player(1, 10000)
	sim.add_player(2, 0)
	EconomyFixture.add_completed(sim, 1, "usa_power_plant", Vector2i(1, 1))
	var ids := {"sim": sim}
	ids.scout = sim.spawn(1, Vector2(4.5, 10.5), "usa_light_vehicle")
	ids.tank = sim.spawn(1, Vector2(4.5, 12.5), "usa_tank")
	return ids

func _speed(kind: String) -> float:
	return Registry.kind(kind).speed

func _cap(sim, id: int) -> Variant:
	return Fixture.object(sim, id).get("group_speed")

func _at(sim, id: int) -> Vector2:
	var position: Array = Fixture.object(sim, id).position
	return Vector2(position[0], position[1])

# Fastest pace per unit over the ticks, in cells per second.
func _pace(sim, ids: Array, ticks: int) -> Dictionary:
	var fastest := {}
	for id: int in ids: fastest[id] = 0.0
	for _tick in range(ticks):
		var before := {}
		for id: int in ids: before[id] = _at(sim, id)
		sim.step()
		for id: int in ids: fastest[id] = maxf(fastest[id], before[id].distance_to(_at(sim, id)) * 30.0)
	return fastest

func test_gs1_group_marches_at_its_slowest_speed(runner) -> bool:
	var plain: Dictionary = _world()
	Fixture.send(plain.sim, {"type": "move", "entity_ids": [plain.scout, plain.tank], "target": GOAL})
	_pace(plain.sim, [plain.scout, plain.tank], 300)
	runner.check(_at(plain.sim, plain.scout).x - _at(plain.sim, plain.tank).x > 4.0, "GS1 premise: without the flag the scout runs ahead of the tank, got %s and %s" % [_at(plain.sim, plain.scout), _at(plain.sim, plain.tank)])
	var ids: Dictionary = _world()
	var sent: Dictionary = Fixture.send(ids.sim, {"type": "move", "entity_ids": [ids.scout, ids.tank], "target": GOAL, "group_speed": true})
	_pace(ids.sim, [ids.scout], 100)
	var gap: float = _at(ids.sim, ids.scout).x - _at(ids.sim, ids.tank).x
	var pace: Dictionary = _pace(ids.sim, [ids.scout, ids.tank], 200)
	var tank: float = _speed("usa_tank")
	runner.check(sent.ok and pace[ids.scout] <= tank + SLACK and pace[ids.scout] > tank - SLACK, "GS1 with group_speed the scout moves at most at the tank's speed %s, got %s" % [tank, pace[ids.scout]])
	var later: float = _at(ids.sim, ids.scout).x - _at(ids.sim, ids.tank).x
	runner.check(absf(later - gap) < 0.1, "GS1 once both march, the gap between the scout and the tank stays the same, got %s then %s" % [gap, later])
	return true

func test_gs2_move_attack_and_attack_move_take_the_flag(runner) -> bool:
	for type: String in ["move", "attack", "attack_move"]:
		var ids: Dictionary = _world()
		var payload := {"type": type, "entity_ids": [ids.scout, ids.tank], "group_speed": true}
		if type == "attack": payload.target_id = EconomyFixture.add_completed(ids.sim, 2, "usa_power_plant", Vector2i(26, 10))
		else: payload.target = GOAL
		var sent: Dictionary = Fixture.send(ids.sim, payload)
		var pace: Dictionary = _pace(ids.sim, [ids.scout], 120)
		var tank: float = _speed("usa_tank")
		runner.check(sent.ok and _cap(ids.sim, ids.scout) == tank and _cap(ids.sim, ids.tank) == tank, "GS2 %s with group_speed gives every ordered unit the lowest speed %s, got %s and %s" % [type, tank, _cap(ids.sim, ids.scout), _cap(ids.sim, ids.tank)])
		runner.check(pace[ids.scout] <= tank + SLACK and pace[ids.scout] > 0.0, "GS2 %s with group_speed holds the scout to %s, got %s" % [type, tank, pace[ids.scout]])
	return true

func test_gs3_order_without_the_flag_lifts_the_cap(runner) -> bool:
	var ids: Dictionary = _world()
	Fixture.send(ids.sim, {"type": "move", "entity_ids": [ids.scout, ids.tank], "target": GOAL, "group_speed": true})
	_pace(ids.sim, [ids.scout], 30)
	Fixture.send(ids.sim, {"type": "move", "entity_ids": [ids.scout], "target": GOAL})
	var pace: Dictionary = _pace(ids.sim, [ids.scout], 60)
	runner.check(_cap(ids.sim, ids.scout) == null and _cap(ids.sim, ids.tank) == _speed("usa_tank"), "GS3 a later order without the flag removes only its own units' cap, got %s and %s" % [_cap(ids.sim, ids.scout), _cap(ids.sim, ids.tank)])
	runner.check(pace[ids.scout] > _speed("usa_tank") + 0.5, "GS3 the scout runs at its own speed again, got %s" % pace[ids.scout])
	var flag_off: Dictionary = _world()
	Fixture.send(flag_off.sim, {"type": "move", "entity_ids": [flag_off.scout, flag_off.tank], "target": GOAL, "group_speed": false})
	flag_off.sim.step()
	runner.check(_cap(flag_off.sim, flag_off.scout) == null, "GS3 group_speed false sets no cap")
	return true

func test_gs4_flag_rejections(runner) -> bool:
	var ids: Dictionary = _world()
	var source: int = ids.sim.add_supply_source(Vector2i(2, 24), 8)
	var payloads := [
		{"type": "move", "entity_ids": [ids.scout], "target": GOAL, "group_speed": 1},
		{"type": "attack_move", "entity_ids": [ids.scout], "target": GOAL, "group_speed": "yes"},
		{"type": "stop", "entity_ids": [ids.scout], "group_speed": true},
		{"type": "gather", "entity_ids": [ids.scout], "source_id": source, "group_speed": true},
		{"type": "enter", "entity_ids": [ids.scout], "target_id": ids.tank, "group_speed": true}]
	for payload: Dictionary in payloads:
		var sent: Dictionary = Fixture.send(ids.sim, payload)
		runner.check(not sent.ok and sent.error == "Invalid group_speed", "GS4 %s with group_speed %s is refused, got %s" % [payload.type, payload.group_speed, sent])
	return true

func _same_tick_world() -> Dictionary:
	var ids: Dictionary = _world()
	var sim = ids.sim
	ids.near = sim.spawn(2, Vector2(14.5, 20.5), "usa_tank")
	ids.defence = EconomyFixture.add_completed(sim, 1, "usa_defence", Vector2i(10, 22))
	ids.builder = sim.spawn(1, Vector2(4.5, 4.5), "usa_builder")
	ids.barracks = EconomyFixture.add_completed(sim, 1, "usa_barracks", Vector2i(20, 4))
	ids.car = sim.spawn(1, Vector2(8.5, 18.5), "usa_light_vehicle")
	ids.rifle = sim.spawn(1, Vector2(9.5, 18.5), "usa_rifle_infantry")
	ids.collector = sim.spawn(1, Vector2(6.5, 18.5), "usa_collector")
	ids.source = sim.add_supply_source(Vector2i(2, 24), 8)
	Fixture.send(sim, {"type": "produce", "building_id": ids.barracks, "unit_kind": "usa_rifle_infantry"})
	Fixture.send(sim, {"type": "build", "builder_id": ids.builder, "building_kind": "usa_power_plant", "origin": [25, 4]})
	sim.step()
	ids.production = Fixture.object(sim, ids.barracks).queue[0].id
	ids.foundation = sim.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.origin == [25, 4])[0].id
	return ids

# Each other command with the unit it names that joins the flagged group (the tank when it names none).
func _other_commands(ids: Dictionary) -> Array:
	return [
		[{"type": "move", "entity_ids": [ids.tank], "target": [8.5, 14.5]}, ids.tank],
		[{"type": "move", "entity_ids": [ids.tank], "target": [8.5, 14.5], "group_speed": true}, ids.tank],
		[{"type": "stop", "entity_ids": [ids.tank]}, ids.tank],
		[{"type": "build", "builder_id": ids.builder, "building_kind": "usa_power_plant", "origin": [6, 6]}, ids.builder],
		[{"type": "resume_build", "builder_id": ids.builder, "building_id": ids.foundation}, ids.builder],
		[{"type": "cancel_build", "building_id": ids.foundation}, ids.tank],
		[{"type": "produce", "building_id": ids.barracks, "unit_kind": "usa_rifle_infantry"}, ids.tank],
		[{"type": "cancel_production", "building_id": ids.barracks, "production_id": ids.production}, ids.tank],
		[{"type": "set_rally", "building_id": ids.barracks, "target": [22.5, 8.5]}, ids.tank],
		[{"type": "gather", "entity_ids": [ids.collector], "source_id": ids.source}, ids.collector],
		[{"type": "attack", "entity_ids": [ids.tank], "target_id": ids.near}, ids.tank],
		[{"type": "attack_move", "entity_ids": [ids.tank], "target": [8.5, 14.5]}, ids.tank],
		[{"type": "enter", "entity_ids": [ids.rifle], "target_id": ids.car}, ids.rifle],
		[{"type": "unload", "target_id": ids.car}, ids.tank],
		[{"type": "defence_attack", "building_id": ids.defence, "target_id": ids.near}, ids.tank]]

func test_gs5_same_tick_cases(runner) -> bool:
	var count: int = _other_commands(_same_tick_world()).size()
	for index in range(count):
		for flagged_first in [true, false]:
			var ids: Dictionary = _same_tick_world()
			var sim = ids.sim
			var row: Array = _other_commands(ids)[index]
			var other: Dictionary = row[0]
			var member: int = row[1]
			var label: String = "%s%s %s" % [other.type, " flagged" if other.has("group_speed") else "", "after" if flagged_first else "before"]
			var companion: Dictionary = {}
			if not flagged_first: companion = Fixture.send(sim, other)
			var order: Dictionary = Fixture.send(sim, {"type": "move", "entity_ids": [ids.scout, member], "target": GOAL, "group_speed": true})
			if flagged_first: companion = Fixture.send(sim, other)
			sim.step()
			var named: Array = other.get("entity_ids", [other.get("builder_id", -1)])
			var keeps: bool = not (flagged_first and named.has(member))
			var lowest: float = minf(_speed("usa_light_vehicle"), _speed(Fixture.object(sim, member).kind)) if keeps else _speed("usa_light_vehicle")
			var member_cap: Variant = lowest if keeps else (_speed("usa_tank") if other.has("group_speed") else null)
			runner.check(order.ok and companion.ok, "GS5 order and companion accepted with %s: %s" % [label, companion])
			runner.check(_cap(sim, ids.scout) == lowest and _cap(sim, member) == member_cap, "GS5 %s: the cap is the lowest speed among the units the flagged order commands at its tick; scout %s expected %s, member %s expected %s" % [label, _cap(sim, ids.scout), lowest, _cap(sim, member), member_cap])
	return true

func test_gs6_removal(runner) -> bool:
	var before: Dictionary = _world()
	Fixture.send(before.sim, {"type": "move", "entity_ids": [before.scout, before.tank], "target": GOAL, "group_speed": true})
	before.sim.remove_object(before.tank)
	before.sim.step()
	runner.check(_cap(before.sim, before.scout) == _speed("usa_light_vehicle"), "GS6 a member removed before the order applies does not count, got %s" % _cap(before.sim, before.scout))
	var after: Dictionary = _world()
	Fixture.send(after.sim, {"type": "move", "entity_ids": [after.scout, after.tank], "target": GOAL, "group_speed": true})
	after.sim.step()
	after.sim.remove_object(after.tank)
	var pace: Dictionary = _pace(after.sim, [after.scout], 60)
	runner.check(_cap(after.sim, after.scout) == _speed("usa_tank") and pace[after.scout] <= _speed("usa_tank") + SLACK, "GS6 the cap is taken once: the slowest member's death leaves it, got %s, pace %s" % [_cap(after.sim, after.scout), pace[after.scout]])
	return true

# A human unit hit from beyond its reach retaliates (an automatic chase, not an order): the cap does not hold it.
func test_gs7_cap_holds_only_while_the_order_does(runner) -> bool:
	var ids: Dictionary = _world()
	var sim = ids.sim
	Fixture.send(sim, {"type": "move", "entity_ids": [ids.scout, ids.tank], "target": [6.5, 10.5], "group_speed": true})
	_pace(sim, [ids.scout], 150)
	var scout: Dictionary = Fixture.object(sim, ids.scout)
	runner.check(scout.status == "arrived" and scout.combat.mode == "guard" and _cap(sim, ids.scout) == _speed("usa_tank"), "GS7 premise: the scout arrived and guards, cap kept, got %s %s %s" % [scout.status, scout.combat.mode, _cap(sim, ids.scout)])
	var rocket: int = sim.spawn(2, _at(sim, ids.scout) + Vector2(7.5, 0.0), "usa_rocket_infantry")
	Fixture.send(sim, {"type": "attack", "entity_ids": [rocket], "target_id": ids.scout, "player": 2})
	var pace: Dictionary = _pace(sim, [ids.scout], 90)
	runner.check(pace[ids.scout] > _speed("usa_tank") + 0.5, "GS7 the cap holds only while the unit's intent is the ordered move, attack or attack-move: the retaliating scout runs at its own speed, got %s" % pace[ids.scout])
	return true
