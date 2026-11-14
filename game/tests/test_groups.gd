@warning_ignore_start("untyped_declaration")
extends RefCounted

const Simulation = preload("res://scripts/simulation/simulation.gd")
const Navigation = preload("res://scripts/simulation/grid_navigation.gd")
const Allocation = preload("res://scripts/simulation/destination_allocation.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")

func cases() -> Array[Callable]:
	return [test_allocation, test_partial_and_copy, test_thirty_arrivals, test_reservations, test_replacement_release, test_partition, test_path_budget, test_long_route_served_alone, test_failed_search_spends_the_tick, test_map_change_requeues_under_budget, test_group_order_across_ashfall, test_ashfall_burst_against_removal_and_map_change, test_queued_retarget, test_queue_replay, test_small_group_matches_brute_force]

func command(sim, ids: Array, target: Array, sequence: int = 0, player: int = 1, tick: int = -1) -> Dictionary:
	return {"tick": sim.snapshot().tick if tick < 0 else tick, "player": player, "sequence": sequence, "type": "move", "entity_ids": ids, "target": target}

func test_allocation(runner) -> bool:
	var nav = Navigation.new()
	var units: Array[Dictionary] = [
		{"id": 3, "position": [1.5, 3.5]}, {"id": 1, "position": [1.5, 1.5]}, {"id": 2, "position": [1.5, 2.5]},
	]
	var before: Array = units.duplicate(true)
	var expected := {1: Vector2(4.5, 4.5), 2: Vector2(4.5, 3.5), 3: Vector2(3.5, 4.5)}
	runner.check(Allocation.assign(nav, units, Vector2(4.5, 4.5), []) == expected, "G1 canonical slots")
	runner.check(units == before, "G1 input unchanged")
	units.reverse()
	runner.check(Allocation.assign(nav, units, Vector2(4.5, 4.5), []) == expected, "G1 input order independent")
	var single: Array[Dictionary] = [{"id": 1, "position": [1.5, 1.5]}]
	runner.check(Allocation.assign(nav, single, Vector2(4, 4.2), []) == {1: Vector2(4, 4.2)}, "G1 exact boundary target")
	return true

func test_partial_and_copy(runner) -> bool:
	var nav = Navigation.new([], Vector2i(2, 1))
	var units: Array[Dictionary] = [{"id": 2, "position": [0.5, 0.5]}, {"id": 1, "position": [0.5, 0.5]}]
	var goals: Dictionary = Allocation.assign(nav, units, Vector2(1.5, 0.5), [])
	runner.check(goals == {1: Vector2(1.5, 0.5), 2: null}, "G2 insufficient slots with transit overlap")
	var unavailable: Array[Vector2i] = [Vector2i(1, 0)]
	var before: Array[Vector2i] = unavailable.duplicate()
	runner.check(Allocation.assign(nav, units, Vector2(1.5, 0.5), unavailable) == {1: null, 2: null}, "G2 finite exhausted search")
	runner.check(unavailable == before, "G2 unavailable unchanged")
	nav = Navigation.new()
	units = [{"id": 1, "position": [1.5, 1.5]}, {"id": 2, "position": [4.5, 4.5]}]
	goals = Allocation.assign(nav, units, Vector2(4.5, 4.5), [])
	runner.check(goals.get(1) != Vector2(4.5, 4.5) and goals.get(2) == Vector2(4.5, 4.5), "G2 other unit cell excluded, own cell allowed")
	units = [{"id": 1, "position": [1.5, 1.5]}]
	var edge: Dictionary = Allocation.assign(nav, units, Vector2.ZERO, [])
	runner.check(edge == {1: Vector2.ZERO}, "G2 edge target")
	return true

func _thirty(blocked: Array[Vector2i]) -> Simulation:
	var sim = Simulation.new(blocked)
	for y in range(6):
		for x in range(5):
			sim.spawn(1, Vector2(x + 0.5, y + 0.5))
	return sim

func test_thirty_arrivals(runner) -> bool:
	for rectangle in [false, true]:
		var blocked: Array[Vector2i] = []
		if rectangle:
			for y in range(4, 10):
				for x in range(6, 9):
					blocked.append(Vector2i(x, y))
		var a = _thirty(blocked)
		var b = _thirty(blocked)
		var nav = Navigation.new(blocked)
		var ids: Array = range(1, 31)
		for sim in [a, b]:
			runner.check(sim.issue_command(command(sim, ids, [13.5, 12.5])).ok, "G3 group accepted")
		var all_arrived := false
		for tick in range(1800):
			var before: Dictionary = a.snapshot()
			a.step()
			b.step()
			var state: Dictionary = a.snapshot()
			runner.check(state == b.snapshot(), "G3 exact replay tick %d" % tick)
			all_arrived = true
			var slots: Dictionary = {}
			for i in range(30):
				var unit: Dictionary = state.entities[i]
				var old: Array = before.entities[i].position
				var start := Vector2(old[0], old[1])
				var finish := Vector2(unit.position[0], unit.position[1])
				for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
					runner.check(nav.is_walkable(start.lerp(finish, fraction)), "G3 no static-solid crossing")
				all_arrived = all_arrived and unit.get("status") == "arrived"
				if unit.get("destination") != null:
					var destination := Vector2(unit.destination[0], unit.destination[1])
					runner.check(not slots.has(Vector2i(destination.floor())), "G3 unique reserved cells")
					slots[Vector2i(destination.floor())] = true
			if all_arrived:
				runner.check(slots.size() == 30, "G3 thirty distinct arrivals")
				break
		runner.check(all_arrived, "G3 arrives within 1800 ticks")
	return true

func test_reservations(runner) -> bool:
	var sim = Simulation.new()
	for entry in [[1, Vector2(1.5, 1.5)], [1, Vector2(1.5, 2.5)], [2, Vector2(2.5, 1.5)], [2, Vector2(2.5, 2.5)]]:
		sim.spawn(entry[0], entry[1])
	runner.check(sim.issue_command(command(sim, [1, 2], [6.5, 6.5])).ok, "G4 first group")
	runner.check(sim.issue_command(command(sim, [3, 4], [6.5, 6.5], 0, 2)).ok, "G4 other owner group")
	sim.step()
	var state: Dictionary = sim.snapshot()
	var slots: Dictionary = {}
	for unit in state.entities:
		if unit.get("destination") != null:
			var cell := Vector2i(Vector2(unit.destination[0], unit.destination[1]).floor())
			runner.check(not slots.has(cell), "G4 cross-owner unique slots")
			slots[cell] = true
	runner.check(slots.size() == 4, "G4 all slots allocated")
	var before: Dictionary = sim.snapshot()
	runner.check(sim.spawn(1, Vector2(6.5, 6.5)) == -1 and sim.snapshot() == before, "G4 reserved spawn rejects without ID")
	var occupied: Array = state.entities[0].position
	runner.check(sim.spawn(1, Vector2(occupied[0], occupied[1])) == -1 and sim.snapshot() == before, "G4 occupied spawn rejects without ID")
	if state.entities[0].get("destination") != null:
		state.entities[0].destination[0] = 99
	runner.check(sim.snapshot() == before, "G4 destination snapshot isolated")
	return true

func test_replacement_release(runner) -> bool:
	var sim = Simulation.new()
	sim.spawn(1, Vector2(1.5, 1.5))
	sim.spawn(1, Vector2(1.5, 2.5))
	sim.issue_command(command(sim, [1, 2], [7.5, 7.5]))
	sim.issue_command(command(sim, [1], [12.5, 12.5], 1))
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.entities[0].get("destination") == [12.5, 12.5] and state.entities[1].get("destination") == [7.5, 7.5], "G5 superseded member consumes no old slot")
	sim.issue_command(command(sim, [1], [10.5, 10.5], 2, 1, 3))
	for i in range(2):
		sim.step()
	runner.check(sim.spawn(1, Vector2(12.5, 12.5)) == -1, "G5 future order retains reservation until due")
	sim.step()
	runner.check(sim.spawn(1, Vector2(12.5, 12.5)) == 3, "G5 applied replacement releases old reservation")
	return true

func test_partition(runner) -> bool:
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(3, y))
	var sim = Simulation.new(wall)
	sim.spawn(1, Vector2(1.5, 1.5))
	sim.spawn(1, Vector2(5.5, 1.5))
	runner.check(sim.issue_command(command(sim, [1, 2], [6.5, 5.5])).ok, "G6 partition command accepted")
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.entities[0].status == "blocked" and state.entities[0].order == null and state.entities[0].get("destination") == null and state.entities[0].route == [], "G6 unreachable member cleared")
	runner.check(state.entities[1].status == "moving" and state.entities[1].get("destination") == [6.5, 5.5], "G6 eligible member moves")
	return true

class CountingNavigation:
	extends "res://scripts/simulation/grid_navigation.gd"
	var calls: int = 0
	var sizes: Array[int] = []
	func route(from: Vector2, to: Vector2) -> Array[Vector2]:
		calls += 1
		var result: Array[Vector2] = super.route(from, to)
		sizes.append(result.size())
		return result

class FailingNavigation:
	extends CountingNavigation
	var fail_from: Dictionary = {}
	func route(from: Vector2, to: Vector2) -> Array[Vector2]:
		if not fail_from.has(Vector2i(from.floor())): return super.route(from, to)
		calls += 1
		sizes.append(0)
		return []

func _twenty(blocked: Array[Vector2i] = [], size := Vector2i(16, 16), target: Array = [13.5, 13.5]) -> Simulation:
	var sim = Simulation.new(blocked, size)
	for y in range(1, 5):
		for x in range(1, 6):
			sim._entities[sim.spawn(1, Vector2(x + 0.5, y + 0.5))].combat = null
	sim.issue_command(command(sim, range(1, 21), target))
	return sim

func _sum(values: Array[int]) -> int:
	var total: int = 0
	for value in values: total += value
	return total

func _budget_rule_holds(nav) -> bool:
	return nav.sizes.is_empty() or _sum(nav.sizes) - nav.sizes.back() < Simulation.PATH_CELLS_PER_TICK

func test_path_budget(runner) -> bool:
	var sim = _twenty([], Vector2i(64, 64), [60.5, 60.5])
	var nav := CountingNavigation.new([], Vector2i(64, 64))
	sim._navigation = nav
	var queue: Array = range(1, 21)
	var bound: bool = false
	var phase: int = 0
	while not queue.is_empty() and phase < 10:
		nav.sizes.clear()
		var before: Dictionary = sim.snapshot()
		sim.step()
		var state: Dictionary = sim.snapshot()
		var served: Array = queue.filter(func(id: int) -> bool: return state.entities[id - 1].status != "path_pending")
		runner.check(served == queue.slice(0, nav.sizes.size()) and _budget_rule_holds(nav) and (_sum(nav.sizes) >= Simulation.PATH_CELLS_PER_TICK or state.path_queue.is_empty()), "PB1 phase %d serves the queue front until the route cells reach the budget" % phase)
		bound = bound or not state.path_queue.is_empty()
		for i in range(20):
			var unit: Dictionary = state.entities[i]
			if unit.status == "path_pending":
				runner.check(unit.route == [] and unit.position == before.entities[i].position, "G7 waiting stays still")
			else:
				var old: Array = before.entities[i].position
				var distance: float = Vector2(unit.position[0], unit.position[1]).distance_to(Vector2(old[0], old[1]))
				runner.check(unit.status == "moving" and distance <= 0.1 + 1e-5, "G7 serviced/new movers stay within one budget")
		queue = state.path_queue
		phase += 1
	runner.check(bound, "PB1 the budget bound on at least one tick")
	runner.check(queue.is_empty(), "PB1 the twenty requests drain")
	var wall: Array[Vector2i] = []
	for y in range(16):
		wall.append(Vector2i(8, y))
	sim = _twenty(wall)
	nav = CountingNavigation.new(wall)
	sim._navigation = nav
	sim.step()
	var blocked: Array = sim.snapshot().entities
	for i in range(300):
		sim.step()
	runner.check(nav.calls == 0 and sim.snapshot().entities == blocked and sim.snapshot().get("path_queue") == [], "G7 unreachable allocations never search/retry")
	return true

func test_long_route_served_alone(runner) -> bool:
	var sim = Simulation.new([], Vector2i(256, 256))
	sim.spawn(1, Vector2(0.5, 0.5))
	sim.spawn(1, Vector2(250.5, 200.5))
	sim.issue_command(command(sim, [1, 2], [251.5, 201.5]))
	sim.step()
	var state: Dictionary = sim.snapshot()
	runner.check(state.entities[0].status == "moving" and state.entities[1].status == "path_pending", "PB2 a route longer than the budget is served alone")
	sim.step()
	runner.check(sim.snapshot().entities[1].status == "moving", "PB2 the next request waits one tick")
	return true

func test_failed_search_spends_the_tick(runner) -> bool:
	var sim = _twenty()
	var nav := FailingNavigation.new([], Vector2i(16, 16))
	nav.fail_from = {Vector2i(1, 1): true}
	sim._navigation = nav
	sim.step()
	var state: Dictionary = sim.snapshot()
	var waiting: bool = true
	for i in range(1, 20):
		waiting = waiting and state.entities[i].status == "path_pending"
	runner.check(nav.calls == 1 and state.entities[0].status == "blocked" and waiting, "PB3 a search that finds no route spends the whole tick's budget")
	sim.step()
	runner.check(nav.calls >= 3, "PB3 the next tick searches again")
	return true

func test_map_change_requeues_under_budget(runner) -> bool:
	var sim = _twenty([], Vector2i(64, 64), [60.5, 60.5])
	var nav := CountingNavigation.new([], Vector2i(64, 64))
	sim._navigation = nav
	sim.step()
	var corner: Array[Vector2i] = [Vector2i(63, 0)]
	runner.check(sim.replace_blocked_cells(corner).ok, "PB4 corner blocked")
	var expected: Array = []
	for unit: Dictionary in sim.snapshot().entities:
		if unit.status == "moving" or unit.status == "path_pending": expected.append(unit.id)
	expected.sort()
	runner.check(sim.snapshot().path_queue == expected, "PB4 a map change re-queues every moving unit once, in id order")
	var served := {}
	var twice: bool = false
	var rule: bool = true
	var ticks: int = 0
	while not sim.snapshot().path_queue.is_empty() and ticks < 10:
		var queue: Array = sim.snapshot().path_queue
		nav.sizes.clear()
		sim.step()
		rule = rule and _budget_rule_holds(nav)
		var state: Dictionary = sim.snapshot()
		for id: int in queue:
			if state.entities[id - 1].status != "path_pending" and not state.path_queue.has(id):
				twice = twice or served.has(id)
				served[id] = true
		ticks += 1
	runner.check(rule and sim.snapshot().path_queue.is_empty(), "PB4 the re-queued burst is served first in, first out under the budget")
	runner.check(not twice and served.size() == expected.size(), "PB4 no unit is served twice after a map change")
	return true

# (seat, seat whose start cell is the target): three groups ordered across Ashfall.
const X2_SEATS: Array[Vector2i] = [Vector2i(1, 4), Vector2i(4, 8), Vector2i(6, 2)]

# Seat 1's power plant stands so that destroying it later changes the map.
func _ashfall_groups() -> Dictionary:
	var map: Dictionary = MapData.load("res://data/maps/ashfall.json")
	var sim = MapData.create(map, [])
	var plant: int = sim._next_entity_id
	CombatWorkload._building(sim, "usa_power_plant", MapData.slot(map, 1, "usa_power_plant"))
	var nav := CountingNavigation.new(sim._union_cells(), Vector2i(int(map.size[0]), int(map.size[1])))
	var same: bool = nav.snapshot() == sim._navigation.snapshot()
	sim._navigation = nav
	var groups: Array = []
	var commands: Array = []
	for pair: Vector2i in X2_SEATS:
		var target := Vector2(MapData.start_cell(map, pair.y)) + Vector2(0.5, 0.5)
		var start: Vector2i = MapData.start_cell(map, pair.x)
		var ids: Array = []
		for y in range(start.y - 12, start.y + 13):
			for x in range(start.x - 12, start.x + 13):
				var point := Vector2(x + 0.5, y + 0.5)
				if ids.size() == 60 or nav.component_at(point) != nav.component_at(target): continue
				var id: int = sim.spawn(pair.x, point)
				if id > 0:
					sim._entities[id].combat = null
					ids.append(id)
		groups.append(ids)
		commands.append(command(sim, ids, [target.x, target.y], 0, pair.x))
	return {"sim": sim, "nav": nav, "plant": plant, "groups": groups, "commands": commands, "same_navigation": same}

func _drain_under_budget(sim, nav, limit: int = 300) -> Dictionary:
	var budget: int = Simulation.PATH_CELLS_PER_TICK
	var result := {"rule_ok": true, "full_ok": true, "cells": 0, "capped": 0, "max_queue": 0, "drain": 0}
	for tick in range(limit):
		nav.sizes.clear()
		sim.step()
		result.drain += 1
		var spent: int = _sum(nav.sizes)
		result.cells += spent
		result.rule_ok = result.rule_ok and (nav.sizes.is_empty() or spent - nav.sizes.back() < budget)
		result.max_queue = maxi(result.max_queue, sim._path_queue.size())
		if sim._path_queue.is_empty(): break
		result.capped += 1
		result.full_ok = result.full_ok and spent >= budget
	return result

func test_group_order_across_ashfall(runner) -> bool:
	var world: Dictionary = _ashfall_groups()
	var sim = world.sim
	var nav = world.nav
	var spawned := {}
	var all: Array = []
	for ids: Array in world.groups:
		for id: int in ids:
			spawned[id] = sim._entities[id].position.duplicate()
			all.append(id)
	runner.check(world.same_navigation and world.groups.map(func(ids: Array) -> int: return ids.size()) == [60, 60, 60], "X2 three seats of 60 units on Ashfall, counted on a navigation equal to the map's")
	var accepted: bool = true
	for order: Dictionary in world.commands:
		accepted = accepted and sim.issue_command(order).ok
	runner.check(accepted, "X2 the three group orders are accepted on one tick")
	var run: Dictionary = _drain_under_budget(sim, nav)
	runner.check(run.rule_ok, "X2 each tick starts no search after its route cells reach the budget")
	runner.check(run.full_ok, "X2 a tick leaves requests waiting only after charging the full budget")
	var bound: int = ceili(run.cells / float(Simulation.PATH_CELLS_PER_TICK))
	runner.check(sim._path_queue.is_empty() and run.drain <= bound, "X2 the burst drains within ceil(route cells / budget) ticks (%d ticks, %d cells)" % [run.drain, run.cells])
	runner.check(run.capped >= 1, "X2 the budget bound on at least one tick (%d ticks)" % run.capped)
	var routed: bool = nav.calls == 180
	for id: int in all:
		var unit: Dictionary = sim._entities[id]
		var last: Array = unit.route.back() if not unit.route.is_empty() else [-1.0, -1.0]
		routed = routed and unit.status == "moving" and Vector2i(int(floor(last[0])), int(floor(last[1]))) == Vector2i(int(floor(unit.destination[0])), int(floor(unit.destination[1])))
	runner.check(routed, "X2 every unit of the three orders is searched once and moving on a route to its destination (%d searches)" % nav.calls)
	for i in range(Simulation.START_DELAY_TICKS + 20):
		sim.step()
	var moved: bool = true
	for id: int in all:
		var unit: Dictionary = sim._entities[id]
		moved = moved and unit.status != "blocked" and unit.position != spawned[id]
	runner.check(moved, "X2 nothing is stuck: every unit has left its start point %d ticks after the drain" % (Simulation.START_DELAY_TICKS + 20))
	print("X2 ashfall drain_ticks=", run.drain, " route_cells=", run.cells, " max_queue=", run.max_queue, " capped_ticks=", run.capped, " searches=", nav.calls)
	return true

func test_ashfall_burst_against_removal_and_map_change(runner) -> bool:
	var world: Dictionary = _ashfall_groups()
	var sim = world.sim
	var nav = world.nav
	for order: Dictionary in world.commands:
		sim.issue_command(order)
	var gone: int = world.groups[0].back()
	sim.remove_object(gone)
	sim.step()
	runner.check(not sim._path_queue.has(gone) and not sim._entities.has(gone), "X2r a unit removed on its order's tick is never queued")
	@warning_ignore("integer_division")
	var waiting: int = sim._path_queue[sim._path_queue.size() / 2]
	var previous: Array = sim._path_queue.duplicate()
	sim.remove_object(waiting)
	previous.erase(waiting)
	runner.check(sim._path_queue == previous, "X2r removing a queued unit leaves the rest of the queue in order")
	sim.step()
	var mover: int = 0
	for id: int in world.groups[0]:
		if sim._entities.has(id) and sim._entities[id].status == "moving":
			mover = id
			break
	runner.check(mover > 0, "X2m a moving unit exists to remove")
	sim.remove_object(mover)
	runner.check(sim.remove_object(world.plant).ok, "X2m the power plant is destroyed")
	var expected: Array = []
	for id: int in sim._entities.keys():
		if sim._entities[id].has("status") and (sim._entities[id].status == "moving" or sim._entities[id].status == "path_pending"): expected.append(id)
	expected.sort()
	runner.check(mover > 0 and sim._path_queue == expected and not sim._path_queue.has(gone) and not sim._path_queue.has(waiting) and not sim._path_queue.has(mover), "X2m a map change re-queues every moving or waiting unit once, in id order, never a removed one")
	nav.calls = 0
	var run: Dictionary = _drain_under_budget(sim, nav)
	var bound: int = ceili(run.cells / float(Simulation.PATH_CELLS_PER_TICK))
	runner.check(run.rule_ok and run.full_ok and sim._path_queue.is_empty() and run.drain <= bound, "X2m the re-queued burst is served under the budget and drains within ceil(route cells / budget) ticks (%d ticks)" % run.drain)
	runner.check(nav.calls == expected.size(), "X2m every re-queued unit is searched exactly once after the map change (%d of %d)" % [nav.calls, expected.size()])
	return true

func test_queued_retarget(runner) -> bool:
	var sim = _twenty([], Vector2i(64, 64), [60.5, 60.5])
	sim.step()
	var first_queue: Array = sim.snapshot().path_queue
	runner.check(first_queue.size() >= 4, "G8 setup leaves requests waiting")
	var waiting: int = first_queue[0]
	runner.check(sim.issue_command(command(sim, [waiting], [2.1, 13.2], 1)).ok, "G8 queued replacement")
	runner.check(sim.issue_command(command(sim, [waiting], [4.3, 12.7], 2)).ok, "G8 final replacement")
	var before: Dictionary = sim.snapshot()
	runner.check(not sim.issue_command(command(sim, [waiting], [64, 0], 3)).ok and sim.snapshot() == before, "G8 invalid replacement preserves queue/sequence")
	sim.step()
	var state: Dictionary = sim.snapshot()
	var rest: Array = first_queue.filter(func(id: int) -> bool: return id != waiting)
	var now: Array = state.get("path_queue").filter(func(id: int) -> bool: return id != waiting)
	runner.check(state.get("path_queue").count(waiting) == 1 and state.get("path_queue").back() == waiting and rest.slice(rest.size() - now.size()) == now, "G8 stale queue entry removed, final appended once")
	runner.check(state.entities[waiting - 1].status == "path_pending" and state.entities[waiting - 1].route == [], "G8 replaced queued unit still waits")
	var queue_now: Array = sim.snapshot().get("path_queue")
	if not state.get("path_queue", []).is_empty():
		state.path_queue[0] = 999
		state.path_queue.clear()
	runner.check(sim.snapshot().get("path_queue") == queue_now, "G8 queue snapshot isolated")
	var last: int = queue_now.back() if queue_now.back() != waiting else queue_now[queue_now.size() - 2]
	var done_tick: int = -1
	for tick in range(40):
		sim.issue_command(command(sim, [1], [3.5, 13.5], 4 + tick))
		sim.step()
		state = sim.snapshot()
		if state.entities[waiting - 1].status == "moving" and state.entities[last - 1].status == "moving":
			done_tick = tick
			break
	runner.check(done_tick >= 0, "G8 low-ID repeated orders do not starve older requests (tick %d)" % done_tick)
	runner.check(state.entities[waiting - 1].order.target == [4.3, 12.7], "G8 current final order routed")
	return true

func _queue_replay(batch: int, reads: bool):
	var sim = _twenty()
	sim.issue_command(command(sim, [9], [4.3, 12.7], 1, 1, 1))
	for base in range(0, 300, batch):
		for tick in range(batch):
			if reads:
				var state: Dictionary = sim.snapshot()
				state.path_queue.clear()
			sim.step()
	return sim.snapshot()

func test_queue_replay(runner) -> bool:
	var expected: Dictionary = _queue_replay(1, false)
	for batch in [1, 3, 10]:
		runner.check(_queue_replay(batch, true) == expected, "G9 exact queue replay batch %d" % batch)
	return true

func test_small_group_matches_brute_force(runner) -> bool:
	var nav = Navigation.new([Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6)], Vector2i(12, 12))
	var target := Vector2(8.5, 8.5)
	var unavailable: Array[Vector2i] = [Vector2i(7, 7), Vector2i(9, 9), Vector2i(8, 7)]
	var ok: bool = true
	for size in [1, 2, 3, 5, 8]:
		var units: Array[Dictionary] = []
		for i in range(size):
			units.append({"id": 10 - i, "position": [8.5, 8.5] if i == 1 else [4.5 + (i % 3), 7.5 + (i % 2)]})
		var expected: Dictionary = {}
		var taken: Dictionary = {}
		var ordered: Array[Dictionary] = units.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		for unit in ordered:
			var best: Variant = null
			for cell in nav.cells_in_component(nav.component_at(target)):
				if taken.has(cell) or unavailable.has(cell): continue
				var own: bool = Vector2i(Vector2(unit.position[0], unit.position[1]).floor()) == cell
				var held: bool = false
				for other in units:
					if other.id != unit.id and Vector2i(Vector2(other.position[0], other.position[1]).floor()) == cell: held = true
				if held and not own: continue
				if best == null or _closer(cell, best, target): best = cell
			expected[unit.id] = Vector2(best) + Vector2(0.5, 0.5) if best != null else null
			if best != null: taken[best] = true
		ok = ok and Allocation.assign(nav, units, target, unavailable) == expected
	runner.check(ok, "G6 small groups equal the brute-force nearest-free-cell assignment")
	return true

func _closer(a: Vector2i, b: Vector2i, target: Vector2) -> bool:
	var da: float = (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(target)
	var db: float = (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(target)
	if da != db: return da < db
	return a.y < b.y or (a.y == b.y and a.x < b.x)
