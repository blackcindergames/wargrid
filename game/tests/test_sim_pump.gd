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
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const FACTIONS := {1: "usa", 2: "china"}
const MATCH_TICKS: int = 900
const DIGEST_EVERY: int = 30

# The relay forwards ticks; over and again end at the relay.
class PairTransport extends RefCounted:
	var patient: bool = false
	var peer
	var inbox := PackedStringArray()
	var others: Array[String] = []
	func poll() -> PackedStringArray:
		var out := inbox
		inbox = PackedStringArray()
		return out
	func send_text(text: String) -> void:
		if Wire.decode(text).message.get("type") == "tick": peer.inbox.append(text)
		else: others.append(text)
	func closed() -> bool: return false
	func silent(_now: int) -> bool: return false
	func close() -> void: pass
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

class NullJobPump extends SimPump:
	var fail_next: bool = false
	func _note_for(job: SimPump.Job, slot: SimPump.Slot) -> SimPump.Note:
		if fail_next: return null
		return super(job, slot)

func cases() -> Array[Callable]:
	return [test_sb3_pump_digests_equal_direct, test_sb3_two_notes_one_drain, test_sb3_slot_invariant, test_sb3_sequence_stamp, test_sb3_refusal_one_tick_later, test_sb3_preview_answer, test_sb3_query_leaves_slots, test_sb3_job0_starts, test_sb3_freeze_rejects_late_insert, test_sb3_freeze_covers_match, test_sb3_ring_off_same_digest, test_sb4_two_drivers_loopback, test_sb4_two_drivers_match_end, test_sb4_take_record_equals_advance, test_sb4_quiet_take_keeps_status, test_sb4_finish_tick_uses_given_digest, test_sb4_ring_query, test_ph_fresh_slot_per_job, test_ph_null_job_fails_pump, test_ph_sequence_stamp_only_on_request]

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
	job.stamp_sequence = true
	return job

func _own_unit(sim, kind: String = "", owner: int = 1) -> int:
	for entity in sim.snapshot().entities:
		if entity.owner == owner and (kind.is_empty() or entity.kind == kind): return entity.id
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
	runner.check(seen.size() == 61, "PH every job publishes a new slot, answer 11 (%d)" % seen.size())
	return true

func test_ph_fresh_slot_per_job(runner) -> bool:
	var pump = _pump()
	var held = pump.current()
	var kept_tick: int = held.tick
	var kept_view: Dictionary = held.view
	var seen: Array = [held]
	for i in 6:
		pump.post(_job())
		pump.drain()
		if not seen.any(func(other) -> bool: return is_same(other, pump.current())): seen.append(pump.current())
	runner.check(held.tick == kept_tick and is_same(held.view, kept_view) and held.view.tick == held.tick, "PH a held slot never changes after publishing")
	runner.check(seen.size() == 7, "PH every drain shows a new slot (%d)" % seen.size())
	var old = pump.current()
	pump.post(_job())
	pump.post(_job())
	pump.drain()
	runner.check(pump.current().tick == old.tick + 2 and is_same(pump.previous(), old), "PH two posts, one drain: current is the second job, previous the old current")
	return true

func test_ph_null_job_fails_pump(runner) -> bool:
	var pump = NullJobPump.new(_sim())
	pump.start()
	pump.post(_job())
	pump.drain()
	var shown = pump.current()
	runner.check(pump.post(_job()), "PH a good job before the failure is accepted")
	pump.fail_next = true
	runner.check(not pump.post(_job()), "PH a null job is refused")
	runner.check(pump.drain().size() == 1, "PH notes filed before the failure still drain")
	runner.check(pump.current().tick == shown.tick + 1, "PH a null job publishes nothing")
	pump.fail_next = false
	runner.check(not pump.post(_job()) and pump.drain().is_empty(), "PH a failed pump refuses every later post")
	var queried = NullJobPump.new(_sim())
	queried.start()
	queried.fail_next = true
	var answer = queried.query(_job())
	queried.fail_next = false
	runner.check(answer == null and not queried.post(_job()), "PH a null query fails the pump")
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

func _pair_drivers() -> Dictionary:
	var a := PairTransport.new()
	var b := PairTransport.new()
	a.peer = b
	b.peer = a
	var one = OnlineDriver.new(a, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)
	var two = OnlineDriver.new(b, Lockstep.new(2, [1, 2] as Array[int]), "china", 2)
	for driver in [one, two]:
		driver.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
		driver.start()
	return {"drivers": [one, two], "transports": [a, b]}

# Breaks the transports' reference cycle.
func _unpair(pair: Dictionary) -> void:
	pair.transports[0].peer = null

# Seat 2 lags so seat 1 sometimes takes two ticks in one callback.
func _frames(drivers: Array, frames: int, lag: int) -> int:
	var double_takes: int = 0
	for frame in frames:
		var before: int = drivers[0].current().tick
		drivers[0].step()
		drivers[0].drain()
		if drivers[0].current().tick == before + 2: double_takes += 1
		if lag > 0 and frame % lag != lag - 1: continue
		for i in lag - 1 if lag > 0 else 1:
			drivers[1].step()
			drivers[1].drain()
	return double_takes

func _lines_to(lines: PackedStringArray, last_tick: int) -> Array:
	return Array(lines).filter(func(line: String) -> bool: return Wire.decode(line).message.tick <= last_tick)

func _replay_rows(lines: PackedStringArray, last_tick: int) -> PackedStringArray:
	var sim = Skirmish.create(true, "human", {}, Skirmish.MAP_PATH, [] as Array[int])
	var by_tick: Dictionary = {}
	for line in lines:
		var message: Dictionary = Wire.decode(line).message
		by_tick[message.tick] = message.commands
	var rows := PackedStringArray()
	for tick in last_tick + 1:
		if tick % DIGEST_EVERY == 0: rows.append("%d\t%s" % [tick, StateHash.digest(sim.snapshot())])
		for command in by_tick.get(tick, []): sim.issue_command(command)
		sim.step()
	return rows

func _ended_any(drivers: Array) -> bool:
	return drivers.any(func(driver) -> bool: return driver._lockstep.status().begins_with("ended"))

func test_sb4_two_drivers_loopback(runner) -> bool:
	var pair: Dictionary = _pair_drivers()
	var one = pair.drivers[0]
	var two = pair.drivers[1]
	_frames(pair.drivers, 20, 0)
	one.submit(_move(_own_unit(one.pump.live())))
	one.submit(_move(999))
	two.submit(_move(_own_unit(two.pump.live(), "", 2)))
	var double_takes: int = _frames(pair.drivers, 360, 3)
	runner.check(double_takes > 0, "SB4 loopback: seat 1 takes two ticks in one callback on some frames, got %d" % double_takes)
	var rows: PackedStringArray = one._lockstep.hash_rows()
	var other: PackedStringArray = two._lockstep.hash_rows()
	var common: int = mini(rows.size(), other.size())
	runner.check(common >= 8 and rows.slice(0, common) == other.slice(0, common), "SB4 loopback hash rows agree on %d common rows" % common)
	var last: int = mini(one.current().tick, two.current().tick) - 1
	var lines: Array = _lines_to(one.match_log().commands, last)
	runner.check(lines.size() >= 2 and lines == _lines_to(two.match_log().commands, last), "SB4 loopback command logs agree up to tick %d (%d lines)" % [last, lines.size()])
	runner.check(_replay_rows(one.match_log().commands, 210) == rows.slice(0, 8) and _replay_rows(PackedStringArray(), 210) != rows.slice(0, 8), "SB4 a replay of the command log gives the first 8 hash rows, and the orders change them")
	var answers: Array[Dictionary] = one.take_answers()
	var theirs: Array[Dictionary] = two.take_answers()
	runner.check(answers.size() == 2 and answers.filter(func(answer: Dictionary) -> bool: return not answer.ok).size() == 1 and answers.any(func(answer: Dictionary) -> bool: return not answer.ok and int(answer.command.entity_ids[0]) == 999),"SB4 seat 1 gets one refusal, the missing entity, got %s" % [answers])
	runner.check(theirs.size() == 1 and theirs[0].ok, "SB4 seat 2 gets no refusal, got %s" % [theirs])
	runner.check(not _ended_any(pair.drivers), "SB4 loopback never ends a lockstep")
	_unpair(pair)
	return true

func test_sb4_two_drivers_match_end(runner) -> bool:
	var pair: Dictionary = _pair_drivers()
	var drivers: Array = pair.drivers
	var seen: Array[bool] = [false, false]
	var frames: int = 0
	while not (drivers[0].over() and drivers[1].over()) and frames < 400:
		frames += 1
		for i in 2:
			drivers[i].step()
			drivers[i].drain()
			if drivers[i].current().tick != 100 or seen[i]: continue
			seen[i] = true
			drivers[i].pump.live().remove_object(4)
			drivers[i].pump.live().remove_object(6)
	runner.check(seen[0] and seen[1], "SB4 fixture: both seats were seen at tick 100")
	runner.check(drivers[0].over() and drivers[1].over(), "SB4 both seats end the match (%d frames)" % frames)
	var records: Array = [drivers[0].record(), drivers[1].record()]
	runner.check(records[0].tick == records[1].tick and records[0].digest == records[1].digest, "SB4 both seats end on the same tick and digest, got %s" % [records])
	for transport in pair.transports:
		var overs: int = transport.others.filter(func(text: String) -> bool: return Wire.decode(text).message.type == "over").size()
		runner.check(overs == 1, "SB4 each seat sends exactly one over, got %d" % overs)
	runner.check(not _ended_any(drivers), "SB4 a normal end leaves no ended status")
	_unpair(pair)
	return true

func _twin() -> Dictionary:
	var now: Array[int] = [0]
	var clock := func() -> int:
		now[0] += 1000
		return now[0]
	var ls = Lockstep.new(1, [1, 2] as Array[int], 4, 30, clock)
	var frames: Array[String] = []
	ls.send = func(text: String) -> void: frames.append(text)
	var sim = Skirmish.create(true, "human")
	ls.start(sim.snapshot())
	return {"ls": ls, "sim": sim, "frames": frames}

func _advance_whole(twin: Dictionary) -> bool:
	if not twin.ls.advance(twin.sim): return false
	var tick: int = twin.sim.tick()
	twin.ls.finish_tick(tick, twin.sim.snapshot() if twin.ls.wants_snapshot(tick) else null)
	return true

func _advance_split(twin: Dictionary) -> bool:
	var tick: int = twin.sim.tick()
	var commands = twin.ls.take(tick)
	if commands == null: return false
	var issued: Array[Dictionary] = []
	for command: Dictionary in commands:
		var result: Dictionary = twin.sim.issue_command(command)
		issued.append({"command": command, "ok": result.ok, "error": result.error})
	twin.ls.record(tick, issued)
	twin.sim.step()
	var after: int = twin.sim.tick()
	if not twin.ls.wants_snapshot(after):
		twin.ls.finish_tick(after, null)
		return true
	var snapshot: Dictionary = twin.sim.snapshot()
	twin.ls.finish_tick(after, snapshot, StateHash.digest(snapshot))
	return true

func _peer(tick: int, commands: Array = [], hash_entry = null) -> String:
	return Wire.encode(Wire.tick_message(2, tick, commands, hash_entry))

func _peer_move(sim, tick: int) -> Array:
	return [_move(_own_unit(sim, "", 2)).merged({"player": 2, "tick": tick, "sequence": 0}, true)]

func _twin_at_four() -> Dictionary:
	var twin: Dictionary = _twin()
	for tick in 4: _advance_whole(twin)
	return twin

func test_sb4_take_record_equals_advance(runner) -> bool:
	var twins: Array = [_twin(), _twin()]
	var steps: Array[Callable] = [_advance_whole, _advance_split]
	var stepped: int = 0
	for tick in 70:
		for i in 2:
			var twin: Dictionary = twins[i]
			if tick == 10:
				twin.ls.submit(_move(999))
				twin.ls.submit(_move(_own_unit(twin.sim)))
			if tick >= 4: twin.ls.receive(_peer(tick, _peer_move(twin.sim, tick) if tick == 20 else []))
			if steps[i].call(twin): stepped += 1
	var a = twins[0].ls
	var b = twins[1].ls
	runner.check(stepped == 140 and twins[0].sim.tick() == 70 and twins[1].sim.tick() == 70, "SB4 both twins step 70 ticks (%d steps)" % stepped)
	runner.check(a.command_log() == b.command_log() and a.command_log().size() == 3 and a.command_log().filter(func(command: Dictionary) -> bool: return command.player == 2).size() == 1, "SB4 take and record log every seat's command as advance does, got %s" % [b.command_log()])
	runner.check(a.latency_samples() == b.latency_samples() and b.latency_samples().size() == 2 and b.latency_samples()[0] - b.latency_samples()[1] == 1000, "SB4 take and record keep the latency samples, got %s %s" % [a.latency_samples(), b.latency_samples()])
	runner.check(a.rejections() == b.rejections() and b.rejections().size() == 1 and b.rejections()[0].tick == 15, "SB4 take and record keep the rejection, got %s" % [b.rejections()])
	runner.check(a.hash_rows() == b.hash_rows() and b.hash_rows().size() == 3, "SB4 take and record keep the hash rows, got %s" % [b.hash_rows()])
	runner.check(a.status() == b.status() and b.status() == "running", "SB4 take and record keep the status")
	runner.check(twins[0].frames == twins[1].frames and twins[1].frames.size() == 71, "SB4 take and record send the same frames (%d)" % twins[1].frames.size())
	runner.check(StateHash.digest(twins[0].sim.snapshot()) == StateHash.digest(twins[1].sim.snapshot()), "SB4 take and record end on the same digest")
	return true

func test_sb4_quiet_take_keeps_status(runner) -> bool:
	var twin: Dictionary = _twin_at_four()
	runner.check(twin.ls.take(4, true) == null and twin.ls.status() == "running", "SB4 quiet take without the peer packet keeps the status")
	runner.check(twin.ls.take(4) == null and twin.ls.status() == "waiting", "SB4 loud take without the peer packet waits")
	twin = _twin_at_four()
	twin.ls.receive(Wire.encode({"type": "left", "seat": 2, "after_tick": 3}))
	runner.check(twin.ls.take(4, true) == null and twin.ls.status() == "running", "SB4 quiet take after a leave keeps the status, got %s" % twin.ls.status())
	runner.check(twin.ls.take(4) == null and twin.ls.status() == "ended_left", "SB4 loud take after a leave ends ended_left")
	twin = _twin_at_four()
	twin.ls.receive(_peer(4, [], {"tick": 0, "value": "ffffffffffffffff"}))
	runner.check(twin.ls.take(4, true) == null and twin.ls.desync_report().tick == -1 and twin.ls.status() == "running", "SB4 quiet take on a hash mismatch keeps the status and desync tick, got %s" % twin.ls.status())
	runner.check(twin.ls.take(4) == null and twin.ls.status() == "ended_desync" and twin.ls.desync_report().tick == 0, "SB4 loud take on a hash mismatch ends ended_desync at tick 0")
	var twins: Array = [_twin_at_four(), _twin_at_four()]
	for each: Dictionary in twins: each.ls.receive(_peer(4, _peer_move(each.sim, 4)))
	var quiet = twins[0].ls.take(4, true)
	var loud = twins[1].ls.take(4)
	runner.check(quiet != null and quiet.size() == 1 and quiet == loud, "SB4 a successful quiet take returns the loud take's commands, got %s %s" % [quiet, loud])
	var missing: Array[int] = twins[0].ls.waiting_for()
	runner.check(missing.size() == 1 and missing[0] == 2 and twins[0].ls.status() == "running", "SB4 after a quiet take waiting_for names the next tick's missing seat, got %s" % [missing])
	return true

func test_sb4_finish_tick_uses_given_digest(runner) -> bool:
	var twin: Dictionary = _twin()
	var snap: Dictionary = twin.sim.snapshot()
	var real: String = StateHash.digest(snap)
	twin.ls.finish_tick(30, snap, "feedfacecafebeef")
	var sent: Dictionary = Wire.decode(twin.frames[-1]).message
	runner.check(sent.hash.value == "feedfacecafebeef" and int(sent.hash.tick) == 30 and twin.ls.hash_rows()[-1] == "30\tfeedfacecafebeef", "SB4 finish_tick sends and logs the given digest, got %s" % [sent.get("hash")])
	twin.ls.finish_tick(60, snap)
	sent = Wire.decode(twin.frames[-1]).message
	runner.check(sent.hash.value == real and twin.ls.hash_rows()[-1] == "60\t" + real, "SB4 finish_tick without a digest computes it, got %s" % [sent.get("hash")])
	var fresh = Lockstep.new(1, [1, 2] as Array[int])
	fresh.start(snap, "abcdefabcdefabcd")
	runner.check(real != "abcdefabcdefabcd" and fresh.hash_rows() == PackedStringArray(["0\tabcdefabcdefabcd"]), "SB4 start logs the given digest as row 0, got %s" % [fresh.hash_rows()])
	return true

func test_sb4_ring_query(runner) -> bool:
	var pump = SimPump.new(Skirmish.create(true, "human"))
	pump.start()
	for i in 40: pump.post(_job())
	var current = pump.current()
	var job = SimPump.Job.new()
	job.step = false
	job.want_ring = true
	var ring: PackedStringArray = pump.query(job).ring
	runner.check(ring == pump.live().hash_ring() and ring.size() == 40, "SB4 the ring query returns the live ring, got %d rows" % ring.size())
	job.want_ring = false
	runner.check(pump.query(job).ring.is_empty(), "SB4 a query without want_ring has no ring")
	runner.check(is_same(pump.current(), current) and pump.live().tick() == 40 and pump.drain().size() == 40, "SB4 the ring query leaves the slots and the note queue alone")
	return true

func test_ph_sequence_stamp_only_on_request(runner) -> bool:
	var pump = _pump()
	var id: int = _own_unit(pump.live())
	var bare = SimPump.Job.new()
	bare.commands.assign([_move(id)])
	pump.post(bare)
	var issued: Array = pump.drain()[0].issued
	runner.check(not issued[0].ok and issued[0].error == "Missing field: sequence" and pump.live().last_sequence(1) == -1, "PH without the flag a missing sequence is refused, got %s" % [issued[0]])
	pump.post(_job([_move(id)]))
	issued = pump.drain()[0].issued
	runner.check(issued[0].ok and issued[0].command.sequence == 0, "PH with the flag it is stamped, got %s" % [issued[0]])
	return true
