@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Fixture = preload("res://tests/economy_fixture.gd")
const SeatFixture = preload("res://tests/seat_fixture.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")

func cases() -> Array[Callable]:
	return [test_spawn, test_tick_zero, test_future_tick, test_same_tick_replacement, test_atomic_rejection, test_sequences, test_malformed_commands, test_command_copy, test_snapshot_copy, test_canonical_pending_order, test_repeatability, test_group_move, test_check_command_matches_issue_command]

func equal(runner, actual: Variant, expected: Variant, label: String) -> void:
	runner.check(actual == expected, "%s expected %s, actual %s" % [label, expected, actual])

func test_spawn(runner) -> bool:
	var sim = Simulation.new()
	equal(runner, sim.snapshot(), {"tick": 0, "next_entity_id": 1, "entities": [], "pending_commands": [], "last_sequences": [], "map": {"size": [16, 16], "blocked_cells": []}, "path_queue": [], "players":[],"buildings":[],"sources":[],"terrain_cells":[],"next_production_id":1,"command_results":[],"combat_events":[],"match":null,"rng":625341585}, "C1 fresh")
	equal(runner, sim.spawn(1, Vector2(1, 2)), 1, "C1 first ID")
	equal(runner, sim.spawn(2, Vector2.ZERO), 2, "C1 second ID")
	var before: Dictionary = sim.snapshot()
	for invalid in [[0, Vector2.ZERO], [1, Vector2(INF, 0)], [1, Vector2(0, NAN)]]:
		equal(runner, sim.spawn(invalid[0], invalid[1]), -1, "C1 invalid spawn")
		equal(runner, sim.snapshot(), before, "C1 rejection unchanged")
	equal(runner, sim.spawn(1, Vector2(0.5, 2.5)), 3, "C1 next ID")
	equal(runner, sim.snapshot().entities, [
		{"id": 1, "owner": 1, "position": [1.0, 2.0], "order": null, "status": "idle", "route": [], "destination": null,"kind":"usa_light_vehicle","hp":240000,"max_hp":240000,"combat":{"mode":"guard","target_id":null,"goal":null,"next_fire_tick":0,"shots_left":0,"repath_tick":0,"retarget":false,"until":0},"speed":0.0,"move_after":0,"heading":[1.0,0.0],"construction_id":null,"collection":null},
		{"id": 2, "owner": 2, "position": [0.0, 0.0], "order": null, "status": "idle", "route": [], "destination": null,"kind":"usa_light_vehicle","hp":240000,"max_hp":240000,"combat":{"mode":"guard","target_id":null,"goal":null,"next_fire_tick":0,"shots_left":0,"repath_tick":0,"retarget":false,"until":0},"speed":0.0,"move_after":0,"heading":[1.0,0.0],"construction_id":null,"collection":null},
		{"id": 3, "owner": 1, "position": [0.5, 2.5], "order": null, "status": "idle", "route": [], "destination": null,"kind":"usa_light_vehicle","hp":240000,"max_hp":240000,"combat":{"mode":"guard","target_id":null,"goal":null,"next_fire_tick":0,"shots_left":0,"repath_tick":0,"retarget":false,"until":0},"speed":0.0,"move_after":0,"heading":[1.0,0.0],"construction_id":null,"collection":null},
	], "C1 entities in ID order")
	return true

func world():
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1, 2))
	return sim

func command(tick: int = 0, sequence: int = 0, player: int = 1, ids: Array = [1], target: Array = [3.5, 4.0]) -> Dictionary:
	return {"tick": tick, "player": player, "sequence": sequence, "type": "move", "entity_ids": ids, "target": target}

func accepted(runner, sim, cmd: Dictionary, label: String) -> void:
	var result: Dictionary = sim.issue_command(cmd)
	equal(runner, result, {"ok": true, "error": ""}, label)

func rejected(runner, sim, cmd: Dictionary, label: String) -> void:
	var before: Dictionary = sim.snapshot()
	var result: Dictionary = sim.issue_command(cmd)
	equal(runner, result.ok, false, label + " rejected")
	runner.check(result.error is String and not result.error.is_empty(), label + " expected nonempty explanation, actual " + str(result))
	equal(runner, sim.snapshot(), before, label + " unchanged")

func test_tick_zero(runner) -> bool:
	var sim = world()
	accepted(runner, sim, command(), "C2 accepted")
	var before: Dictionary = sim.snapshot()
	equal(runner, before.tick, 0, "C2 before tick")
	equal(runner, before.pending_commands.size(), 1, "C2 queued")
	if before.entities.is_empty():
		return false
	equal(runner, before.entities[0].order, null, "C2 not applied")
	sim.step()
	var state: Dictionary = sim.snapshot()
	equal(runner, state.tick, 1, "C2 tick")
	equal(runner, state.pending_commands, [], "C2 consumed")
	equal(runner, state.entities[0].order, {"type": "move", "target": [3.5, 4.0]}, "C2 applied")
	check_first_motion(runner, state.entities[0], "C2")
	return true

func test_future_tick(runner) -> bool:
	var sim = world()
	accepted(runner, sim, command(2), "C3 accepted")
	sim.step()
	sim.step()
	var state: Dictionary = sim.snapshot()
	equal(runner, state.tick, 2, "C3 tick")
	equal(runner, state.pending_commands.size(), 1, "C3 waiting")
	if state.entities.is_empty():
		return false
	equal(runner, state.entities[0].order, null, "C3 no early application")
	equal(runner, state.entities[0].position, [1.0, 2.0], "C3 no early motion")
	sim.step()
	equal(runner, sim.snapshot().tick, 3, "C3 third tick")
	equal(runner, sim.snapshot().pending_commands, [], "C3 consumed")
	equal(runner, sim.snapshot().entities[0].order, {"type": "move", "target": [3.5, 4.0]}, "C3 applied")
	check_first_motion(runner, sim.snapshot().entities[0], "C3 due movement")
	return true

func test_same_tick_replacement(runner) -> bool:
	var sim = world()
	accepted(runner, sim, command(0, 0, 1, [1], [3, 4]), "C4 first")
	accepted(runner, sim, command(0, 1, 1, [1], [8, 9]), "C4 second")
	var queued_target: Array = sim.snapshot().pending_commands[1].target
	for axis in range(2):
		equal(runner, typeof(queued_target[axis]), TYPE_FLOAT, "C4 queued target axis %d type" % axis)
	sim.step()
	var state: Dictionary = sim.snapshot()
	equal(runner, state.last_sequences, [{"player": 1, "sequence": 1}], "C4 sequence")
	if state.entities.is_empty():
		return false
	equal(runner, state.entities[0].order, {"type": "move", "target": [8.0, 9.0]}, "C4 replaced")
	for axis in range(2):
		equal(runner, typeof(state.entities[0].order.target[axis]), TYPE_FLOAT, "C4 applied target axis %d type" % axis)
	check_first_motion(runner, state.entities[0], "C4")
	return true

func test_atomic_rejection(runner) -> bool:
	var sim = world()
	sim.spawn(2, Vector2.ZERO)
	for ids in [[2], [999], [1, 2]]:
		rejected(runner, sim, command(0, 0, 1, ids), "C5 " + str(ids))
	accepted(runner, sim, command(), "C5 corrected sequence")
	return true

func test_sequences(runner) -> bool:
	var sim = world()
	sim.spawn(2, Vector2.ZERO)
	accepted(runner, sim, command(0, 4), "C6 sequence 4")
	for sequence in [4, 3]:
		rejected(runner, sim, command(0, sequence), "C6 duplicate/old")
	accepted(runner, sim, command(0, 5), "C6 sequence 5")
	accepted(runner, sim, command(0, 0, 2, [2]), "C6 player 2")
	sim.step()
	rejected(runner, sim, command(0, 6), "C6 past tick")
	equal(runner, sim.snapshot().last_sequences, [{"player": 1, "sequence": 5}, {"player": 2, "sequence": 0}], "C6 independent")
	return true

func test_malformed_commands(runner) -> bool:
	var sim = world()
	for key in command():
		var missing: Dictionary = command()
		missing.erase(key)
		rejected(runner, sim, missing, "C7 missing " + key)
	var variants: Dictionary = {
		"tick": [0.0, "0", false, -1],
		"player": [1.0, "1", true, 0, -1],
		"sequence": [0.0, "0", false, -1],
		"type": ["attack", 1, null],
		"entity_ids": [[], [1, 1], "1", [true], [1.0], [0], [-1], null],
		"target": [[], [1], [1, 2, 3], "1,2", ["1", 2], [true, 2], [1, false], [INF, 0], [0, -INF], [NAN, 0], null],
	}
	for key in variants:
		for value in variants[key]:
			var malformed: Dictionary = command()
			malformed[key] = value
			rejected(runner, sim, malformed, "C7 " + key + "=" + str(value))
	var valid: Dictionary = command()
	valid["ignored"] = {"extra": true}
	accepted(runner, sim, valid, "C7 finite fractional target")
	equal(runner, sim.snapshot().pending_commands, [command()], "C7 only defined fields")
	return true

func test_command_copy(runner) -> bool:
	var sim = world()
	var cmd: Dictionary = command()
	accepted(runner, sim, cmd, "C8 accepted")
	cmd.target[0] = 99
	cmd.entity_ids[0] = 999
	equal(runner, sim.snapshot().pending_commands, [command()], "C8 independent queued data")
	sim.step()
	if sim.snapshot().entities.is_empty():
		return false
	equal(runner, sim.snapshot().entities[0].order, {"type": "move", "target": [3.5, 4.0]}, "C8 original target")
	return true

func test_snapshot_copy(runner) -> bool:
	var sim = world()
	accepted(runner, sim, command(), "C9 accepted")
	var before: Dictionary = sim.snapshot()
	var changed: Dictionary = sim.snapshot().duplicate(true)
	if changed.entities.is_empty() or changed.pending_commands.is_empty() or changed.last_sequences.is_empty():
		return false
	changed.entities[0].position[0] = 99
	changed.pending_commands[0].target[0] = 99
	changed.pending_commands[0].entity_ids[0] = 99
	changed.last_sequences[0].sequence = 99
	equal(runner, sim.snapshot(), before, "C9 queued snapshot isolation")
	sim.step()
	before = sim.snapshot()
	changed = sim.snapshot().duplicate(true)
	changed.entities[0].order.target[0] = 99
	if not changed.entities[0].route.is_empty():
		changed.entities[0].route[0][0] = 99
	changed.map.size[0] = 99
	changed.map.blocked_cells.append([1, 1])
	equal(runner, sim.snapshot(), before, "C9 applied order isolation")
	return true

func test_canonical_pending_order(runner) -> bool:
	var a = world()
	var b = world()
	for sim in [a, b]:
		sim.spawn(2, Vector2.ZERO)
	accepted(runner, a, command(0, 0, 2, [2]), "C10 a player2")
	for cmd in [command(), command(3, 1), command(1, 2), command(1, 3)]:
		accepted(runner, a, cmd, "C10 a player1 " + str(cmd.sequence))
		accepted(runner, b, cmd, "C10 b player1 " + str(cmd.sequence))
	accepted(runner, b, command(0, 0, 2, [2]), "C10 b player2")
	equal(runner, a.snapshot(), b.snapshot(), "C10 canonical before")
	equal(runner, a.snapshot().last_sequences, [{"player": 1, "sequence": 3}, {"player": 2, "sequence": 0}], "C10 sorted sequences")
	equal(runner, a.snapshot().pending_commands, [command(), command(0, 0, 2, [2]), command(1, 2), command(1, 3), command(3, 1)], "C10 commands sorted by tick/player/sequence")
	a.step()
	b.step()
	equal(runner, a.snapshot(), b.snapshot(), "C10 canonical after")
	return true

func test_repeatability(runner) -> bool:
	var a = world()
	var b = world()
	for sim in [a, b]:
		accepted(runner, sim, command(), "C11 tick zero")
		accepted(runner, sim, command(3, 1, 1, [1], [8, 9]), "C11 future")
		for tick in range(1000):
			sim.step()
	equal(runner, a.snapshot(), b.snapshot(), "C11 equal worlds")
	equal(runner, a.snapshot(), {
		"tick": 1000, "next_entity_id": 2,
		"entities": [{"id": 1, "owner": 1, "position": [8.0, 9.0], "order": null, "status": "arrived", "route": [], "destination": [8.0, 9.0],"kind":"usa_light_vehicle","hp":240000,"max_hp":240000,"combat":{"mode":"guard","target_id":null,"goal":null,"next_fire_tick":0,"shots_left":0,"repath_tick":1007,"retarget":false,"until":0},"speed":0.0,"move_after":2,"heading":[-0.7071067690849304,-0.7071067690849304],"construction_id":null,"collection":null}],
		"map": {"size": [16, 16], "blocked_cells": []}, "path_queue": [],
		"pending_commands": [], "last_sequences": [{"player": 1, "sequence": 1}],
		"players":[],"buildings":[],"sources":[],"terrain_cells":[],"next_production_id":1,"command_results":[],"combat_events":[],"match":null,"rng":625341585,
	}, "C11 full final state")
	return true

func test_group_move(runner) -> bool:
	var sim = world()
	sim.spawn(1, Vector2(5, 6))
	accepted(runner, sim, command(0, 0, 1, [2, 1]), "C12 group accepted")
	equal(runner, sim.snapshot().pending_commands, [command(0, 0, 1, [2, 1])], "C12 whole group queued")
	sim.step()
	var state: Dictionary = sim.snapshot()
	equal(runner, state.tick, 1, "C12 tick")
	equal(runner, state.next_entity_id, 3, "C12 next ID")
	equal(runner, state.pending_commands, [], "C12 consumed")
	equal(runner, state.last_sequences, [{"player": 1, "sequence": 0}], "C12 sequence")
	equal(runner, state.map, {"size": [16, 16], "blocked_cells": []}, "C12 map")
	equal(runner, state.entities.size(), 2, "C12 entity count")
	for i in range(state.entities.size()):
		var unit: Dictionary = state.entities[i]
		equal(runner, unit.id, i + 1, "C12 ID order")
		equal(runner, unit.owner, 1, "C12 owner")
		equal(runner, unit.order, {"type": "move", "target": [3.5, 4.0]}, "C12 copied target")
		equal(runner, unit.status, "moving", "C12 status")
		equal(runner, unit.destination, [3.5, 4.0] if i == 0 else [3.5, 3.5], "C12 distinct destination")
		runner.check(not unit.route.is_empty(), "C12 remaining route")
	sim.step()
	sim.step()
	for i in range(2):
		var unit: Dictionary = sim.snapshot().entities[i]
		var start := Vector2(1, 2) if i == 0 else Vector2(5, 6)
		var distance: float = Vector2(unit.position[0], unit.position[1]).distance_to(start)
		runner.check(distance > 0 and distance <= 0.1 + 1e-5, "C12 each member moves within one budget after the start delay")
	state.entities[0].order.target[0] = 99
	equal(runner, sim.snapshot().entities[1].order.target, [3.5, 4.0], "C12 targets independent")
	return true

func check_first_motion(runner, unit: Dictionary, label: String) -> void:
	var point := Vector2(unit.position[0], unit.position[1])
	runner.check(point == Vector2(1, 2), label + " waits out the start delay")
	equal(runner, unit.get("status"), "moving", label + " status")

func _check_world(kind: String):
	var sim: RefCounted = Fixture.make_world(0 if kind == "poor" else 10000)
	match kind:
		"poor": Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(10, 10))
		"blocked": Fixture.add_completed(sim, 1, "usa_power_plant", Vector2i(10, 10))
		"setup":
			sim.add_player(2, 0)
			sim.begin_setup([1, 2] as Array[int])
		"ended":
			sim = SeatFixture.sim([1, 2] as Array[int])
			SeatFixture.defeat(sim, 2)
			sim.step()
	return sim

func test_check_command_matches_issue_command(runner) -> bool:
	var move := {"tick": 0, "player": 1, "sequence": 0, "type": "move", "entity_ids": [1], "target": [5.5, 5.5]}
	var produce := {"tick": 0, "player": 1, "sequence": 0, "type": "produce", "building_id": 2, "unit_kind": "usa_rifle_infantry"}
	var build := {"tick": 0, "player": 1, "sequence": 0, "type": "build", "builder_id": 1, "building_kind": "usa_power_plant", "origin": [10, 10]}
	var rows := [["valid move", "rich", move, false], ["unaffordable produce", "poor", produce, true], ["valid build", "rich", build, false], ["blocked build", "blocked", build, true], ["setup-time order", "setup", move, true]]
	for row: Array in rows:
		var checked: RefCounted = _check_world(row[1])
		var issued: RefCounted = _check_world(row[1])
		var before: String = checked.tick_hash()
		var digest: String = StateHash.digest(checked.snapshot())
		var error: String = checked.check_command(row[2])
		equal(runner, error, issued.issue_command(row[2]).error, "CC1 %s: the same answer" % row[0])
		runner.check(error.is_empty() != row[3], "CC1 %s: %s, got '%s'" % [row[0], "refused" if row[3] else "accepted", error])
		runner.check(checked.tick_hash() == before and StateHash.digest(checked.snapshot()) == digest, "CC1 %s: the check leaves the hash and the digest alone" % row[0])
	var over: RefCounted = _check_world("ended")
	equal(runner, over.check_command(move.merged({"player": 1, "tick": over.tick(), "entity_ids": [over.snapshot().entities[0].id]})), "Match ended", "CC1 after the end")
	equal(runner, _check_world("rich").check_command({"player": 1}), _check_world("rich").issue_command({"player": 1}).error, "CC1 a malformed order gets the same answer")
	return true
