@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const FACTIONS := {1: "usa", 2: "china"}
const MATCH_TICKS: int = 900
const DIGEST_EVERY: int = 30

func cases() -> Array[Callable]:
	return [test_sb3_pump_digests_equal_direct, test_sb3_two_notes_one_drain, test_sb3_slot_invariant, test_sb3_sequence_stamp, test_sb3_refusal_one_tick_later, test_sb3_preview_answer, test_sb3_query_leaves_slots, test_sb3_job0_starts, test_sb3_freeze_rejects_late_insert, test_sb3_freeze_covers_match, test_sb3_ring_off_same_digest]

func _sim():
	return Skirmish.create(true, "ai", FACTIONS, Skirmish.MAP_PATH, [] as Array[int])

func _pump():
	var pump = SimPump.new(_sim())
	pump.start()
	return pump

func _job(commands: Array = [], bots: Array = []):
	var job = SimPump.Job.new()
	job.commands.assign(commands)
	job.bots.assign(bots)
	return job

func _own_unit(sim, kind: String = "") -> int:
	for entity in sim.snapshot().entities:
		if entity.owner == 1 and (kind.is_empty() or entity.kind == kind): return entity.id
	return -1

func _move(id: int) -> Dictionary:
	return {"type": "move", "player": 1, "entity_ids": [id], "target": [10.5, 10.5]}

func test_sb3_pump_digests_equal_direct(runner) -> bool:
	var direct = _sim()
	var recorder = CommandRecorder.new(direct)
	var pump = _pump()
	var equal: int = 0
	var bot_commands: int = 0
	for i in MATCH_TICKS:
		Skirmish.issue_opponent(recorder)
		direct.step()
		var job = _job([], [2])
		job.want_digest = (i + 1) % DIGEST_EVERY == 0
		pump.post(job)
		var note = pump.drain()[0]
		bot_commands += note.bot_commands.size()
		if job.want_digest and note.digest == StateHash.digest(direct.snapshot()): equal += 1
	runner.check(equal * DIGEST_EVERY == MATCH_TICKS, "SB3 pump digests equal a direct run every 30 ticks (%d)" % equal)
	runner.check(StateHash.digest(pump.live().snapshot()) == StateHash.digest(direct.snapshot()) and pump.live().tick() == MATCH_TICKS, "SB3 pump digest equal at 900")
	runner.check(bot_commands > 0, "SB3 bot commands reach the notes")
	return true

func _battle_pump():
	var sim = Fixture.make_world()
	sim.add_player(2, 0)
	var own: Array = []
	var enemy: Array = []
	for i in 8:
		own.append(sim.spawn(1, Vector2(10.5, 8.5 + i), "china_tank"))
		enemy.append(sim.spawn(2, Vector2(13.5, 8.5 + i), "china_tank"))
	var pump = SimPump.new(sim)
	pump.start()
	return {"pump": pump, "own": own, "enemy": enemy, "builder": _own_unit(sim, "usa_builder")}

func _attack(player: int, ids: Array, target: int) -> Dictionary:
	return {"type": "attack", "player": player, "entity_ids": ids, "target_id": target}

# A move has no command result; a stop has one.
func _halt(builder: int) -> Dictionary:
	return {"type": "stop", "player": 1, "entity_ids": [builder]}

func _ticks(rows: Array) -> Array:
	var ticks: Array = []
	for row in rows:
		if not ticks.has(row.tick): ticks.append(row.tick)
	return ticks

func test_sb3_two_notes_one_drain(runner) -> bool:
	var pump = _pump()
	runner.check(pump.current().tick == 0 and pump.previous() == null, "SB3 start fills CURRENT at tick 0")
	pump.post(_job())
	pump.post(_job())
	var notes: Array = pump.drain()
	runner.check(notes.size() == 2 and notes[0].tick == 1 and notes[1].tick == 2, "SB3 two notes in tick order")
	runner.check(pump.current().tick == 2 and pump.previous().tick == 0, "SB3 CURRENT is the last note, PREVIOUS the old CURRENT")
	runner.check(notes[0].done and notes[1].done, "SB3 inline notes are done")
	var battle: Dictionary = _battle_pump()
	pump = battle.pump
	pump.post(_job([_attack(1, battle.own, battle.enemy[0]), _attack(2, battle.enemy, battle.own[0])]))
	pump.drain()
	var pairs: int = 0
	for i in 60:
		pump.post(_job([_halt(battle.builder)]))
		pump.post(_job([_halt(battle.builder)]))
		notes = pump.drain()
		if notes[0].events.is_empty() or notes[1].events.is_empty(): continue
		var first: Array = _ticks(notes[0].events + notes[0].results)
		var second: Array = _ticks(notes[1].events + notes[1].results)
		if first.size() == 1 and second.size() == 1 and first[0] + 1 == second[0] and not notes[0].results.is_empty() and not notes[1].results.is_empty(): pairs += 1
		else: runner.check(false, "SB3 note %d keeps its own events and results: %s %s" % [notes[0].tick, first, second])
	runner.check(pairs > 0, "SB3 two notes with own events and results in one drain (%d pairs)" % pairs)
	var events: Array = []
	var results: Array = []
	for i in 60:
		var command: Dictionary = _halt(battle.builder).merged({"tick": pump.live().tick(), "sequence": pump.live().last_sequence(1) + 1})
		runner.check(pump.recorder().issue_command(command).ok, "SB3 external command accepted")
		pump.live().step()
		events = pump.live().combat_events().duplicate(true)
		results = pump.live().command_results().duplicate(true)
		if not events.is_empty(): break
	var publish = _job()
	publish.step = false
	pump.post(publish)
	var note = pump.drain()[0]
	runner.check(not events.is_empty() and not results.is_empty() and note.events == events and note.results == results, "SB3 publish job carries the externally stepped tick's events and results")
	runner.check(note.tick == pump.live().tick() and pump.current().tick == note.tick and pump.current().view.tick == note.tick, "SB3 publish job shows the externally stepped tick")
	return true

func test_sb3_slot_invariant(runner) -> bool:
	var pump = _pump()
	var seen: Array = [pump.current()]
	var held: int = 0
	var views: int = 0
	var kept: int = 0
	for i in 60:
		var shown = pump.current()
		var shown_tick: int = shown.view.tick
		pump.post(_job())
		if is_same(pump.current(), shown) and shown.tick == shown_tick and shown.view.tick == shown_tick and (pump.previous() == null or pump.previous().view.tick == shown_tick - 1): kept += 1
		var notes: Array = pump.drain()
		var current = pump.current()
		var previous = pump.previous()
		if current.tick == notes[-1].tick and not is_same(current, previous) and previous.tick == current.tick - 1: held += 1
		if current.view.tick == current.tick and previous.view.tick == previous.tick and not is_same(current.view, previous.view): views += 1
		for slot in [current, previous]:
			if not seen.any(func(other) -> bool: return is_same(other, slot)): seen.append(slot)
	runner.check(held == 60, "SB3 CURRENT equals the last note and differs from PREVIOUS (%d)" % held)
	runner.check(views == 60, "SB3 every slot holds a fresh view of its own tick (%d)" % views)
	runner.check(kept == 60, "SB3 a post leaves CURRENT and PREVIOUS untouched until the drain (%d)" % kept)
	runner.check(seen.size() <= 4, "SB3 at most four slots (%d)" % seen.size())
	return true

func test_sb3_sequence_stamp(runner) -> bool:
	var pump = _pump()
	var id: int = _own_unit(pump.live())
	pump.post(_job([_move(id), _move(999999), {"type": "stop", "player": 1, "entity_ids": [id]}]))
	var issued: Array = pump.drain()[0].issued
	runner.check(issued.map(func(row) -> int: return row.command.sequence) == [0, 1, 1], "SB3 sequences stamped from the simulation")
	runner.check(issued.map(func(row) -> bool: return row.ok) == [true, false, true], "SB3 refusal between two accepted commands")
	runner.check(not issued[1].error.is_empty() and issued[0].command.tick == 0, "SB3 refusal carries its error, tick stamped at issue")
	runner.check(pump.live().last_sequence(1) == 1 and pump.live().last_sequence(2) == -1, "SB3 last_sequence follows accepted commands")
	var explicit: Dictionary = _move(id)
	explicit.sequence = 5
	pump.post(_job([explicit]))
	var kept: Dictionary = pump.drain()[0].issued[0]
	runner.check(kept.ok and kept.command.sequence == 5 and pump.live().last_sequence(1) == 5 and not explicit.has("tick"), "SB3 explicit sequence kept, caller's command untouched")
	return true

func test_sb3_refusal_one_tick_later(runner) -> bool:
	var pump = _pump()
	pump.post(_job())
	pump.post(_job([_move(999999)]))
	var notes: Array = pump.drain()
	runner.check(notes[0].issued.is_empty(), "SB3 no answer before the issuing job")
	runner.check(notes[1].issued.size() == 1 and not notes[1].issued[0].ok, "SB3 refusal in the issuing job's note")
	runner.check(notes[1].issued[0].command.tick == notes[1].tick - 1, "SB3 refusal arrives with the next tick")
	return true

func _free_origin(sim, builder: int, kind: String) -> Vector2i:
	for y in range(2, 40):
		for x in range(2, 40):
			if sim.preview_build(1, builder, kind, Vector2i(x, y)).ok: return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_sb3_preview_answer(runner) -> bool:
	var pump = _pump()
	var builder: int = _own_unit(pump.live(), "usa_builder")
	var origin: Vector2i = _free_origin(pump.live(), builder, "usa_power_plant")
	var job = _job([{"type": "build", "player": 1, "builder_id": builder, "building_kind": "usa_power_plant", "origin": [origin.x, origin.y]}])
	job.preview = {"player": 1, "builder_id": builder, "kind": "usa_power_plant", "origin": origin}
	pump.post(job)
	var note = pump.drain()[0]
	var preview: Dictionary = note.preview
	var expected: Dictionary = pump.live().preview_build(1, builder, "usa_power_plant", origin)
	runner.check(origin.x >= 0 and note.issued[0].ok and not expected.ok, "SB3 the job's build takes the previewed footprint")
	runner.check(preview.keys() == ["kind", "origin", "ok", "error", "tick"], "SB3 preview answer shape")
	runner.check(preview.kind == "usa_power_plant" and preview.origin == origin and preview.ok == expected.ok and preview.error == expected.error and preview.tick == 1, "SB3 preview answered after the step")
	pump.post(_job())
	runner.check(pump.drain()[0].preview == {}, "SB3 no preview, no answer")
	return true

func test_sb3_query_leaves_slots(runner) -> bool:
	var pump = _pump()
	pump.post(_job())
	pump.drain()
	var current = pump.current()
	var previous = pump.previous()
	pump.post(_job())
	var job = _job()
	job.step = false
	job.want_digest = true
	var note = pump.query(job)
	runner.check(note.digest == StateHash.digest(pump.live().snapshot()) and note.tick == 2, "SB3 query digest equals the live digest")
	runner.check(is_same(pump.current(), current) and is_same(pump.previous(), previous) and current.tick == 1 and current.view.tick == 1, "SB3 query leaves the slots")
	var notes: Array = pump.drain()
	runner.check(notes.size() == 1 and notes[0].tick == 2 and not pump.busy(), "SB3 query leaves the queued note")
	runner.check(pump.current().tick == 2 and pump.current().view.tick == 2 and is_same(pump.previous(), current), "SB3 rotation after a query as without one")
	return true

func test_sb3_job0_starts(runner) -> bool:
	var pump = SimPump.new(_sim())
	var note = pump.start()
	var map: Dictionary = pump.live().map_data()
	runner.check(note.starts.size() == 2 and note.starts[1] == MapData.start_cell(map, 1) and note.starts[2] == MapData.start_cell(map, 2) and note.starts[1] != note.starts[2], "SB3 job 0 carries the start cells")
	runner.check(pump.current().tick == 0 and note.tick == 0 and pump.drain().is_empty(), "SB3 job 0 fills CURRENT, not the queue")
	runner.check(note.stats.size() == 2 and note.stats[0].player == 1, "SB3 notes carry match stats")
	var fixture = SimPump.new(Fixture.make_world())
	runner.check(fixture.start().starts == {} and fixture.current().tick == 0, "SB3 fixture world starts without start cells")
	fixture.stop()
	runner.check(not fixture.post(_job()), "SB3 post refused after stop")
	return true

func _frozen_count() -> int:
	return Registry.frozen_state().values().count(true)

func _rifle_row(weapon: String) -> Dictionary:
	var row: Dictionary = Registry.kind("usa_rifle_infantry").duplicate()
	row.weapon = weapon
	return row

func test_sb3_freeze_rejects_late_insert(runner) -> bool:
	_pump()
	runner.check(_frozen_count() == 5 and Registry.radius_cache.is_read_only(), "SB3 start freezes each of the five caches (%s)" % Registry.frozen_state())
	Registry.add_test_kind("sb3_probe", _rifle_row("rifle"))
	runner.check(_frozen_count() == 0 and Registry.cache_keys().values().all(func(keys: Array) -> bool: return keys.is_empty()), "SB3 add_test_kind leaves all five caches writable and empty (%s)" % Registry.cache_keys())
	runner.check(is_equal_approx(Combat.reach_of("sb3_probe"), 3.9), "SB3 test kind reach comes from its weapon")
	Registry.add_test_kind("sb3_probe", _rifle_row("rocket"))
	runner.check(is_equal_approx(Combat.reach_of("sb3_probe"), 6.9), "SB3 re-adding a test kind with another weapon drops the cached reach")
	Registry.clear_test_kinds()
	runner.check(_frozen_count() == 0 and Registry.cache_keys().values().all(func(keys: Array) -> bool: return keys.is_empty()), "SB3 clear_test_kinds leaves all five caches writable and empty (%s)" % Registry.cache_keys())
	_pump()
	runner.check(_frozen_count() == 5, "SB3 start freezes again after a reset")
	return true

func _fighters() -> Array:
	return Registry.units().filter(func(id: String) -> bool: return not CombatDefinitions.weapon(CombatDefinitions.profile(id).get("weapon", "")).is_empty())

func _battle_world() -> Dictionary:
	var sim = Fixture.make_world()
	sim.add_player(2, 0)
	var own: Array = []
	var enemy: Array = []
	for kind: String in _fighters():
		own.append(sim.spawn(1, Vector2(10.5, 3.5 + own.size()), kind))
		enemy.append(sim.spawn(2, Vector2(14.5, 3.5 + enemy.size()), kind))
	return {"sim": sim, "commands": [_attack(1, own, enemy[0]), _attack(2, enemy, own[0])]}

func _missing_warm() -> Array:
	var keys: Dictionary = Registry.cache_keys()
	var missing: Array = []
	for id: String in Registry.units() + Registry.buildings():
		var row: Dictionary = Registry.kind(id)
		var expected: Dictionary = {"radius": true, "unit": row.has("class"), "building": row.has("footprint"), "profile": row.has("max_hp"), "reach": row.has("weapon") and not CombatDefinitions.weapon(row.weapon).is_empty()}
		for name: String in expected:
			if expected[name] and not keys[name].has(id): missing.append("%s/%s" % [name, id])
	return missing

func _unwarmed(used: Dictionary, warm: Dictionary) -> Array:
	var unwarmed: Array = []
	for name: String in used:
		for key: String in used[name]:
			if not warm[name].has(key): unwarmed.append("%s/%s" % [name, key])
	return unwarmed

func test_sb3_freeze_covers_match(runner) -> bool:
	var pump = _pump()
	var warm: Dictionary = Registry.cache_keys()
	var missing: Array = _missing_warm()
	runner.check(missing.is_empty(), "SB3 warm-up fills every registered kind in each applicable cache (missing %s)" % [missing.slice(0, 5)])
	var warm_keys: Dictionary = Registry.cache_keys()
	var bots: Array = [2]
	for i in MATCH_TICKS:
		pump.post(_job([], bots))
		pump.drain()
	runner.check(Registry.cache_keys() == warm_keys, "SB3 no cache grows during a 900-tick bot match")
	var battle: Dictionary = _battle_world()
	var fight = SimPump.new(battle.sim)
	fight.start()
	fight.post(_job(battle.commands))
	for i in 150:
		fight.post(_job())
		fight.drain()
	runner.check(Registry.cache_keys() == warm_keys, "SB3 no cache grows during a 150-tick battle of every armed kind")
	var team = SimPump.new(TeamMatch.create())
	team.start()
	var seats: Array = []
	for entry in TeamMatch.SEATS: seats.append(entry.seat)
	for i in 300:
		team.post(_job([], seats))
		team.drain()
	runner.check(Registry.cache_keys() == warm_keys, "SB3 no cache grows during 300 team-match ticks")
	runner.check(Skirmish.map_frozen(), "SB3 skirmish map is read-only")
	Registry.clear_test_kinds()
	var direct = _sim()
	for i in MATCH_TICKS:
		Skirmish.issue_opponent(direct)
		direct.step()
	var control: Dictionary = _battle_world()
	var recorder = CommandRecorder.new(control.sim)
	for command: Dictionary in control.commands: recorder.issue_command(command)
	for i in 150: control.sim.step()
	var team_direct = TeamMatch.create()
	for i in 300: TeamMatch.step(team_direct)
	var unwarmed: Array = _unwarmed(Registry.cache_keys(), warm)
	runner.check(unwarmed.is_empty() and _frozen_count() == 0, "SB3 every key an unfrozen match inserts was warmed (unwarmed %s)" % [unwarmed.slice(0, 5)])
	return true

func test_sb3_ring_off_same_digest(runner) -> bool:
	var on = _sim()
	var off = _sim()
	off.set_hash_ring(false)
	var equal: int = 0
	for i in 300:
		Skirmish.issue_opponent(on)
		Skirmish.issue_opponent(off)
		on.step()
		off.step()
		if (i + 1) % DIGEST_EVERY == 0 and StateHash.digest(on.snapshot()) == StateHash.digest(off.snapshot()): equal += 1
	runner.check(equal == 10, "SB3 ring off keeps the digest every 30 ticks (%d)" % equal)
	runner.check(on.hash_ring().size() == 64 and off.hash_ring().is_empty(), "SB3 ring reads are empty when off")
	var late = _sim()
	late.set_hash_ring(false)
	for i in 10: late.step()
	late.set_hash_ring(true)
	late.step()
	var rows: PackedStringArray = late.hash_ring()
	var zero_rows: int = 0
	for row: String in rows:
		if row.ends_with("\t0000000000000000"): zero_rows += 1
	runner.check(rows.size() == 11 and zero_rows == 10 and not rows[10].ends_with("0000000000000000"), "SB3 ring off wrote nothing: ten zero rows, then one written (%d zero of %d)" % [zero_rows, rows.size()])
	return true
