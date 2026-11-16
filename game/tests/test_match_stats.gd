@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const Construction = preload("res://scripts/simulation/construction.gd")
const KILL_TICKS: int = 3000
const ALIGN_TRIES: int = 12

func cases() -> Array[Callable]:
	return [test_rows_in_player_order, test_produced_counts, test_blocked_and_cancelled_not_built, test_free_units_not_built, test_unit_death_counts_lost, test_building_lost_rules, test_passengers_counted_once, test_bury_counts_lost_once, test_site_completes_under_fire, test_counters_outside_snapshot]

func _row(sim, player: int) -> Dictionary:
	for row in sim.match_stats():
		if row.player == player: return row
	return {}

func _zero(player: int) -> Dictionary:
	return {"player": player, "units_built": 0, "units_lost": 0, "buildings_lost": 0}

func _frc_world() -> RefCounted:
	var sim = Simulation.new([], Vector2i(32, 32))
	sim.add_player(1, 50000)
	sim.spawn(1, Vector2(4.5, 4.5), "frc_builder")
	sim.add_player(2, 0)
	return sim

func _tanks(sim, count: int, x: float, y: float, owner: int = 2) -> Array:
	var ids: Array = []
	for i in count:
		var id: int = sim.spawn(owner, Vector2(x, y + i), "china_tank")
		if id != -1: ids.append(id)
	return ids

func _died(sim, id: int) -> bool:
	return sim.combat_events().any(func(e: Dictionary) -> bool: return e.type == "death" and e.object_id == id)

func _attack(sim, attackers: Array, target: int, player: int = 2) -> bool:
	return Fixture.send(sim, {"type": "attack", "player": player, "entity_ids": attackers, "target_id": target}).ok

func _kill(runner, sim, target: int, attackers: Array, label: String, player: int = 2) -> bool:
	runner.check(_attack(sim, attackers, target, player), label + " attack accepted")
	for i in KILL_TICKS:
		sim.step()
		if _died(sim, target): return true
	runner.check(false, label + " kill timed out")
	return false

func _remove_all(sim, ids: Array) -> void:
	for id in ids:
		if not Fixture.object(sim, id).is_empty(): sim.remove_object(id)

func _units_of(sim, kind: String) -> Array:
	return sim.snapshot().entities.filter(func(u: Dictionary) -> bool: return u.kind == kind)

func _contained(sim, ids: Array, host: int) -> bool:
	return ids.all(func(id: int) -> bool: return Fixture.object(sim, id).get("container_id", 0) == host)

func _board(sim, ids: Array, host: int) -> bool:
	if not Fixture.send(sim, {"type": "enter", "entity_ids": ids, "target_id": host}).ok: return false
	for i in 600:
		sim.step()
		if _contained(sim, ids, host): return true
	return false

func test_rows_in_player_order(runner) -> bool:
	var sim = Skirmish.create(true, "human")
	var expected: Array[Dictionary] = [_zero(1), _zero(2)]
	runner.check(sim.match_stats() == expected, "MS1 one zero row per player in id order, start units not built: " + str(sim.match_stats()))
	var rows: Array[Dictionary] = sim.match_stats()
	rows[0].units_built = 9
	runner.check(sim.match_stats()[0].units_built == 0, "MS1 a returned row is a copy")
	var reversed = Simulation.new([], Vector2i(16, 16))
	reversed.add_player(2, 0)
	reversed.add_player(1, 0)
	runner.check(reversed.match_stats() == expected, "MS1 rows sorted by player id, not insertion order")
	return true

func test_produced_counts(runner) -> bool:
	var sim = Fixture.make_world(50000)
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	runner.check(Fixture.send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "usa_rifle_infantry"}).ok, "MS2 rifleman order accepted")
	var appeared: bool = false
	for i in 400:
		var before: int = _row(sim, 1).units_built
		sim.step()
		if not _units_of(sim, "usa_rifle_infantry").is_empty():
			runner.check(before == 0 and _row(sim, 1).units_built == 1, "MS2 built 0 the tick before, 1 on the tick the rifleman appears")
			appeared = true
			break
	runner.check(appeared, "MS2 rifleman produced")
	var china = Simulation.new([], Vector2i(32, 32))
	china.add_player(1, 20000)
	china.spawn(1, Vector2(4.5, 4.5), "china_builder")
	var china_barracks: int = Fixture.build(runner, china, "china_barracks", Vector2i(12, 12))
	runner.check(Fixture.send(china, {"type": "produce", "building_id": china_barracks, "unit_kind": "china_rifle_infantry"}).ok, "MS2 militia order accepted")
	for i in 400:
		china.step()
		if not _units_of(china, "china_rifle_infantry").is_empty(): break
	runner.check(_units_of(china, "china_rifle_infantry").size() == 2 and _row(china, 1).units_built == 2, "MS2 a quantity-2 order counts 2")
	return true

func _rifle_world(runner) -> Array:
	var sim = Fixture.make_world(50000)
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	Fixture.send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "usa_rifle_infantry"})
	sim.step()
	return [sim, barracks]

func test_blocked_and_cancelled_not_built(runner) -> bool:
	var sim = Fixture.make_world(50000)
	var barracks: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	var first: int = -1
	for cell in Construction.perimeter("usa_barracks", Vector2i(12, 12)):
		var id: int = sim.spawn(1, Vector2(cell) + Vector2(.5, .5))
		if first == -1 and id != -1: first = id
	Fixture.send(sim, {"type": "produce", "building_id": barracks, "unit_kind": "usa_rifle_infantry"})
	Fixture.steps(sim, 300)
	var queue: Array = Fixture.object(sim, barracks).queue
	runner.check(queue.size() == 1 and queue[0].work == 150000, "MS3 work complete, exit blocked")
	var held: bool = true
	for i in 10:
		sim.step()
		held = held and _row(sim, 1).units_built == 0
	runner.check(held and _units_of(sim, "usa_rifle_infantry").is_empty(), "MS3 blocked exit builds nothing for 10 ticks")
	Fixture.send(sim, {"type": "move", "entity_ids": [first], "target": [24.5, 24.5]})
	for i in 30:
		sim.step()
		if not _units_of(sim, "usa_rifle_infantry").is_empty(): break
	runner.check(_row(sim, 1).units_built == 1, "MS3 a freed exit builds 1")
	var probe: Array = _rifle_world(runner)
	var done: int = -1
	for i in 400:
		var tick: int = probe[0].tick()
		probe[0].step()
		if not _units_of(probe[0], "usa_rifle_infantry").is_empty():
			done = tick
			break
	var world: Array = _rifle_world(runner)
	var entry: Array = Fixture.object(world[0], world[1]).queue
	runner.check(done != -1 and entry.size() == 1, "MS3 completion tick found")
	if entry.is_empty(): return true
	runner.check(Fixture.send(world[0], {"type": "cancel_production", "building_id": world[1], "production_id": entry[0].id, "tick": done}).ok, "MS3 cancel stamped for the completion tick accepted")
	while world[0].tick() <= done + 5: world[0].step()
	runner.check(_row(world[0], 1).units_built == 0 and _units_of(world[0], "usa_rifle_infantry").is_empty(), "MS3 cancel on the completion tick builds nothing")
	return true

func test_free_units_not_built(runner) -> bool:
	var sim = Fixture.make_world(50000)
	Fixture.build(runner, sim, "usa_power_plant", Vector2i(5, 5))
	Fixture.build(runner, sim, "usa_supply_center", Vector2i(10, 4))
	runner.check(_units_of(sim, "usa_collector").size() == 1 and _row(sim, 1).units_built == 0, "MS4 free collector not built")
	var frc = _frc_world()
	Fixture.build(runner, frc, "frc_supply_center", Vector2i(4, 14))
	var barracks: int = Fixture.build(runner, frc, "frc_barracks", Vector2i(12, 12))
	var tanks: Array = _tanks(frc, 6, 24.5, 10.5)
	_kill(runner, frc, barracks, tanks, "MS4 barracks")
	_remove_all(frc, tanks)
	var laborer: bool = false
	for i in 1500:
		frc.step()
		laborer = frc.bot_state().entities.any(func(u: Dictionary) -> bool: return u.has("hole_id"))
		if laborer: break
	runner.check(laborer and _row(frc, 1).units_built == 0, "MS4 cache laborer and rebuild laborer not built")
	return true

func test_unit_death_counts_lost(runner) -> bool:
	var sim = _two_player_kill(runner)
	runner.check(_row(sim, 1).units_lost == 0 and _row(sim, 2).units_lost == 1, "MS5 the victim's owner loses 1, the killer 0")
	var before: Array[Dictionary] = sim.match_stats()
	var other: int = _units_of(sim, "usa_rocket_infantry").filter(func(u: Dictionary) -> bool: return u.owner == 2)[0].id
	sim.remove_object(other)
	runner.check(sim.match_stats() == before, "MS5 remove_object of a unit is not a loss")
	var guarded = Fixture.make_world(50000)
	guarded.add_player(2, 0)
	Fixture.build(runner, guarded, "usa_power_plant", Vector2i(5, 5))
	var battery: int = Fixture.build(runner, guarded, "usa_defence", Vector2i(12, 12))
	var intruder: int = guarded.spawn(2, Vector2(18.5, 12.5), "usa_rifle_infantry")
	for i in KILL_TICKS:
		guarded.step()
		if _died(guarded, intruder): break
	runner.check(battery != -1 and _died(guarded, intruder) and _row(guarded, 2).units_lost == 1, "MS5 a unit killed by a defence counts 1")
	return true

func _two_player_kill(runner) -> RefCounted:
	var sim = Fixture.make_world(50000)
	sim.add_player(2, 0)
	var victim: int = sim.spawn(2, Vector2(24.5, 24.5), "usa_rifle_infantry")
	sim.spawn(2, Vector2(28.5, 4.5), "usa_rocket_infantry")
	_kill(runner, sim, victim, _tanks(sim, 2, 16.5, 20.5, 1), "MS5 unit", 1)
	return sim

func _site_of(sim, kind: String) -> int:
	for b in sim.snapshot().buildings:
		if b.kind == kind and not b.completed: return b.id
	return -1

func test_building_lost_rules(runner) -> bool:
	var sim = Fixture.make_world(50000)
	sim.add_player(2, 0)
	var first: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(12, 12))
	var kept: int = Fixture.build(runner, sim, "usa_barracks", Vector2i(4, 20))
	Fixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "usa_barracks", "origin": [20, 4]})
	sim.step()
	var cancelled: int = _site_of(sim, "usa_barracks")
	runner.check(cancelled != -1 and Fixture.send(sim, {"type": "cancel_build", "building_id": cancelled}).ok, "MS6 cancel_build accepted")
	Fixture.steps(sim, 2)
	runner.check(Fixture.object(sim, cancelled).is_empty() and _row(sim, 1).buildings_lost == 0, "MS6 a cancelled site is not lost")
	var second_builder: int = sim.spawn(1, Vector2(6.5, 10.5), "usa_builder")
	Fixture.send(sim, {"type": "build", "builder_id": second_builder, "building_kind": "usa_barracks", "origin": [20, 20]})
	sim.step()
	var site: int = _site_of(sim, "usa_barracks")
	sim.remove_object(second_builder)
	var tanks: Array = _tanks(sim, 6, 28.5, 10.5)
	_kill(runner, sim, first, tanks, "MS6 barracks")
	runner.check(_row(sim, 1).buildings_lost == 1, "MS6 a completed building killed counts 1")
	_kill(runner, sim, site, tanks, "MS6 site")
	runner.check(_row(sim, 1).buildings_lost == 1, "MS6 an unfinished site killed is not lost")
	sim.remove_object(kept)
	runner.check(_row(sim, 1).buildings_lost == 1, "MS6 remove_object of a completed building is not lost")
	var frc = _frc_world()
	Fixture.build(runner, frc, "frc_supply_center", Vector2i(4, 14))
	var barracks: int = Fixture.build(runner, frc, "frc_barracks", Vector2i(12, 12))
	var frc_tanks: Array = _tanks(frc, 6, 24.5, 10.5)
	_kill(runner, frc, barracks, frc_tanks, "MS6 FRC barracks")
	var holes: Array = frc.snapshot().buildings.filter(func(b: Dictionary) -> bool: return b.has("rebuild"))
	runner.check(holes.size() == 1 and _row(frc, 1).buildings_lost == 1, "MS6 FRC barracks counts 1 and leaves a hole")
	if holes.is_empty(): return true
	_kill(runner, frc, holes[0].id, frc_tanks, "MS6 hole")
	runner.check(_row(frc, 1).buildings_lost == 1, "MS6 a killed hole is not a second loss")
	return true

func test_passengers_counted_once(runner) -> bool:
	var sim = _frc_world()
	var weak: int = sim.spawn(1, Vector2(10.5, 10.5), "frc_rifle_infantry")
	var shooter: int = sim.spawn(2, Vector2(13.5, 10.5), "usa_rifle_infantry")
	runner.check(_attack(sim, [shooter], weak), "MS7 pre-damage attack accepted")
	for i in KILL_TICKS:
		sim.step()
		if Fixture.object(sim, weak).get("hp", 0) <= 12000: break
	runner.check(Fixture.object(sim, weak).get("hp", 0) > 0, "MS7 weak passenger alive at 10 percent or less")
	sim.remove_object(shooter)
	var strong: int = sim.spawn(1, Vector2(10.5, 12.5), "frc_rifle_infantry")
	var pickup: int = sim.spawn(1, Vector2(8.5, 16.5), "frc_light_vehicle")
	runner.check(_board(sim, [weak, strong], pickup), "MS7 both board the pickup")
	var before: int = _row(sim, 1).units_lost
	_kill(runner, sim, pickup, _tanks(sim, 3, 24.5, 20.5), "MS7 pickup")
	var deaths: Array = sim.combat_events().filter(func(e: Dictionary) -> bool: return e.type == "death").map(func(e: Dictionary) -> int: return e.object_id)
	runner.check(deaths.has(weak) and not deaths.has(strong), "MS7 release damage kills the weak passenger only: deaths %s weak %d strong %d pickup %d" % [str(deaths), weak, strong, pickup])
	runner.check(_row(sim, 1).units_lost - before == 2 and deaths.size() == 2, "MS7 transport and dead passenger count once each, survivor 0: " + str(_row(sim, 1)))
	return true

# Hub with a pickup (two riders) and a rifleman inside, plus an outside rifleman; attackers spawned far away.
func _tunnel_world(runner) -> Dictionary:
	var sim = _frc_world()
	Fixture.build(runner, sim, "frc_barracks", Vector2i(4, 8))
	var hub: int = Fixture.build(runner, sim, "frc_defence", Vector2i(10, 10))
	var riders: Array = _units_of(sim, "frc_rocket_infantry").map(func(u: Dictionary) -> int: return u.id)
	var pickup: int = sim.spawn(1, Vector2(14.5, 14.5), "frc_light_vehicle")
	var rifle: int = sim.spawn(1, Vector2(12.5, 4.5), "frc_rifle_infantry")
	var boarded: bool = riders.size() == 2 and _board(sim, riders, pickup) and _board(sim, [pickup, rifle], hub)
	var outside: int = sim.spawn(1, Vector2(20.5, 4.5), "frc_rifle_infantry")
	return {"sim": sim, "hub": hub, "outside": outside, "boarded": boarded, "hub_tanks": _tanks(sim, 6, 27.5, 20.5), "unit_tanks": _tanks(sim, 1, 28.5, 4.5)}

func _death_ticks(world: Dictionary, offset: int) -> Array:
	var sim = world.sim
	var start: int = sim.tick()
	var hub_tick: int = -1
	var outside_tick: int = -1
	for i in KILL_TICKS:
		var tick: int = sim.tick()
		if tick == start + maxi(0, -offset): _attack(sim, world.hub_tanks, world.hub)
		if tick == start + maxi(0, offset): _attack(sim, world.unit_tanks, world.outside)
		sim.step()
		if _died(sim, world.hub): hub_tick = tick
		if _died(sim, world.outside): outside_tick = tick
		if hub_tick != -1 and outside_tick != -1: break
	return [hub_tick, outside_tick]

func test_bury_counts_lost_once(runner) -> bool:
	var offset: int = 0
	for attempt in ALIGN_TRIES:
		var world: Dictionary = _tunnel_world(runner)
		runner.check(world.boarded, "MS8 riders in the pickup, pickup and rifleman in the hub")
		if not world.boarded: return true
		var ticks: Array = _death_ticks(world, offset)
		if ticks.has(-1):
			runner.check(false, "MS8 hub and outside unit killed: " + str(ticks))
			return true
		if ticks[0] == ticks[1]:
			runner.check(_row(world.sim, 1).units_lost == 5 and _row(world.sim, 1).buildings_lost == 1, "MS8 one volley: pickup, two riders, rifleman, outside unit and the hub each once: " + str(_row(world.sim, 1)))
			return true
		offset += ticks[0] - ticks[1]
	runner.check(false, "MS8 could not align the hub and outside deaths on one tick")
	return true

func _site_world(runner) -> Dictionary:
	var sim = _frc_world()
	Fixture.build(runner, sim, "frc_barracks", Vector2i(4, 8))
	Fixture.send(sim, {"type": "build", "builder_id": 1, "building_kind": "frc_defence", "origin": [16, 16]})
	sim.step()
	return {"sim": sim, "site": _site_of(sim, "frc_defence"), "tanks": _tanks(sim, 6, 24.5, 13.5)}

func test_site_completes_under_fire(runner) -> bool:
	var probe: Dictionary = _site_world(runner)
	var completes: int = -1
	for i in KILL_TICKS:
		var tick: int = probe.sim.tick()
		probe.sim.step()
		if Fixture.object(probe.sim, probe.site).get("completed", false):
			completes = tick
			break
	runner.check(completes != -1, "MS9 site completes without fire")
	var issue: int = probe.sim.tick() - 200
	for attempt in ALIGN_TRIES:
		var world: Dictionary = _site_world(runner)
		var sim = world.sim
		var died: int = -1
		issue = maxi(issue, sim.tick())
		for i in KILL_TICKS:
			var tick: int = sim.tick()
			if tick == issue: _attack(sim, world.tanks, world.site)
			sim.step()
			if _died(sim, world.site):
				died = tick
				break
		if died == completes:
			runner.check(_row(sim, 1).buildings_lost == 1 and _row(sim, 1).units_built == 0, "MS9 completed and killed on one tick: lost 1, free fighters not built: " + str(_row(sim, 1)))
			return true
		if died == -1: break
		issue += completes - died
	runner.check(false, "MS9 could not align the kill with the completion tick")
	return true

func test_counters_outside_snapshot(runner) -> bool:
	var sim = _two_player_kill(runner)
	var state: Dictionary = sim.snapshot()
	runner.check(not state.has("match_stats"), "MS10 no match_stats key in the snapshot")
	var leaked: bool = state.players.any(func(p: Dictionary) -> bool: return p.has("units_built") or p.has("units_lost") or p.has("buildings_lost"))
	runner.check(not leaked and _row(sim, 2).units_lost == 1, "MS10 no counter key in the snapshot's player rows")
	return true
