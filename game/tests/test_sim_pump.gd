@warning_ignore_start("untyped_declaration")
extends RefCounted

const Fixture = preload("res://tests/economy_fixture.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const MapData = preload("res://scripts/simulation/map_data.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const CommandRecorder = preload("res://scripts/playtest/command_recorder.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const NullJobPump = preload("res://tests/failing_pump.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")
const CombatDefinitions = preload("res://scripts/simulation/combat_definitions.gd")
const Combat = preload("res://scripts/simulation/combat.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const FACTIONS := {1: "usa", 2: "china"}
const MATCH_TICKS: int = 900
const RelayFrameOrder = preload("res://tests/relay_frame_order.gd")
const SeatFixture = preload("res://tests/seat_fixture.gd")
const DIGEST_EVERY: int = 30

# The relay forwards ticks; over and again end at the relay.
class PairTransport extends RefCounted:
	var patient: bool = false
	var peer
	var inbox := PackedStringArray()
	var others: Array[String] = []
	var order := RelayFrameOrder.new()
	func poll() -> PackedStringArray:
		var out := inbox
		inbox = PackedStringArray()
		return out
	func send_text(text: String) -> void:
		if not order.accepts(text): push_error("relay refused: %s" % text)
		if Wire.decode(text).message.get("type") == "tick": peer.inbox.append(text)
		else: others.append(text)
	func closed() -> bool: return false
	func refused() -> bool: return false
	func silent(_now: int) -> bool: return false
	func close() -> void: pass
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

# Forwards a seat's ticks to the other two seats, as the relay does.
class TrioEnd extends RefCounted:
	var patient: bool = false
	var relay
	var seat: int = 0
	var inbox := PackedStringArray()
	var order := RelayFrameOrder.new()
	func poll() -> PackedStringArray:
		var out := inbox
		inbox = PackedStringArray()
		return out
	func send_text(text: String) -> void:
		if not order.accepts(text): push_error("relay refused: %s" % text)
		if Wire.decode(text).message.get("type") == "tick": relay.forward(seat, text)
	func closed() -> bool: return false
	func refused() -> bool: return false
	func silent(_now: int) -> bool: return false
	func close() -> void: pass
	func rtt_samples() -> PackedInt64Array: return PackedInt64Array()

class TrioRelay extends RefCounted:
	var ends: Array = []
	func _init() -> void:
		for seat in [1, 2, 3]:
			var end := TrioEnd.new()
			end.relay = self
			end.seat = seat
			ends.append(end)
	func forward(from: int, text: String) -> void:
		for end in ends:
			if end.seat != from: end.inbox.append(text)
	func leave(seat: int, after_tick: int) -> void:
		var text: String = Wire.encode({"type": "left", "seat": seat, "after_tick": after_tick})
		for end in ends:
			if end.seat != seat: end.inbox.append(text)

func cases() -> Array[Callable]:
	return [test_sb3_pump_digests_equal_direct, test_sb3_two_notes_one_drain, test_sb3_slot_invariant, test_sb3_sequence_stamp, test_sb3_refusal_one_tick_later, test_sb3_preview_answer, test_sb3_query_leaves_slots, test_sb3_job0_starts, test_sb3_freeze_rejects_late_insert, test_sb3_freeze_covers_match, test_sb3_ring_off_same_digest, test_sb4_two_drivers_loopback, test_sb4_two_drivers_match_end, test_sb4_take_record_equals_advance, test_sb4_quiet_take_keeps_status, test_sb4_finish_tick_uses_given_digest, test_sb4_ring_query, test_th_pump_tick_hash_on_request, test_ph_fresh_slot_per_job, test_ph_null_job_fails_pump, test_ph_sequence_stamp_only_on_request, test_ph_record_returns_command_log, test_ph_pair_drivers_send_legal_frames, test_ph_finish_tick_refuses_after_end, test_ph_start_after_end_sends_nothing, test_ph_finish_tick_refuses_out_of_order, test_ph_take_checks_next_tick, test_ph_driver_matches_advance_peer, test_ph_nested_cache_freeze, test_pal_survivors_query, test_pal_note_carries_survivors, test_pal_three_drivers_play_on, test_pal_driver_quiet_defers_verdict, test_pal_played_on_catches_up, test_pal_driver_play_on_then_end_closes_room, test_trio_leave_has_no_match_ended_heading, test_pump_bot_first_wave_at_5400, test_pump_bot_lines_on_request, test_shot_carries_its_building_target, test_plan_bots_leaves_sim_untouched, test_planned_bot_commands_not_in_pump_record, test_planner_drops_invalid_bot_order, test_setup_plans_no_bot_orders, test_host_submits_bot_commands_after_human, test_bot_refusal_not_in_driver_answers, test_guest_runs_no_bot, test_bot_refused_submit_recovers_next_decision, test_sb5a_mode_from_switch]

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
		runner.check(pump.live().issue_command(command).ok, "SB3 external command accepted")
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
	for i in 6:
		pump.post(_job())
		pump.drain()
	runner.check(held.tick == kept_tick and is_same(held.view, kept_view) and held.view.tick == held.tick, "PH a held slot never changes after publishing")
	var old = pump.current()
	pump.post(_job())
	pump.post(_job())
	pump.drain()
	runner.check(pump.current().tick == old.tick + 2 and is_same(pump.previous(), old), "PH two posts, one drain: current is the second job, previous the old current")
	return true

func test_ph_null_job_fails_pump(runner) -> bool:
	var pump = NullJobPump.new(_sim())
	pump.start()
	runner.check(pump.failure() == "", "PH a healthy pump reports no failure")
	pump.post(_job([_move(_own_unit(pump.live()))]))
	pump.drain()
	var shown = pump.current()
	runner.check(pump.post(_job()), "PH a good job before the failure is accepted")
	pump.fail_next = true
	runner.check(not pump.post(_job()), "PH a null job is refused")
	var reason: String = pump.failure()
	runner.check(reason.begins_with("post job returned no note after tick"), "PH the refused post names its failure, got '%s'" % reason)
	runner.check(pump.drain().size() == 1, "PH notes filed before the failure still drain")
	runner.check(pump.current().tick == shown.tick + 1, "PH a null job publishes nothing")
	pump.fail_next = false
	var shown_after = pump.current()
	var kept_tick: int = pump.live().tick()
	runner.check(not pump.post(_job()) and pump.drain().is_empty(), "PH a failed pump refuses every later post")
	runner.check(pump.live().tick() == kept_tick and is_same(pump.current(), shown_after), "PH a refused post on a failed pump steps nothing, got tick %d" % pump.live().tick())
	pump.fail_next = true
	pump.query(_job())
	pump.fail_next = false
	runner.check(pump.failure() == reason, "PH a later failure keeps the first reason, got '%s'" % pump.failure())
	var record: Dictionary = pump.record()
	runner.check(record.digest == "" and record.tick == pump.current().tick and record.commands.size() == 1 and record.commands[0].type == "move", "PH record() on a failed pump falls back to the shown tick and the kept commands, got %s" % [record])
	runner.check(record.match == pump.current().view.match, "PH the fallback record carries the shown match")
	var queried = NullJobPump.new(_sim())
	queried.start()
	queried.fail_next = true
	var answer = queried.query(_job())
	queried.fail_next = false
	runner.check(answer == null and not queried.post(_job()), "PH a null query fails the pump")
	runner.check(queried.failure().begins_with("query job returned no note after tick"), "PH the failed query names its failure, got '%s'" % queried.failure())
	var stopped = NullJobPump.new(_sim())
	stopped.start()
	stopped.stop()
	runner.check(stopped.failure() == "" and not stopped.post(_job()) and stopped.failure() == "", "PH stop() alone sets no failure")
	stopped.fail_next = true
	var filed: Dictionary = stopped.record()
	runner.check(stopped.failure().begins_with("query job returned no note after tick") and filed.digest == "" and filed.tick == stopped.current().tick, "PH a failure first met by record() after stop() is kept and falls back, got '%s' %s" % [stopped.failure(), filed])
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
	runner.check(fixture.live().tick() == 0, "PH a post refused after stop steps nothing, got tick %d" % fixture.live().tick())
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
	for tick in range(1, 30): twin.ls.finish_tick(tick, null)
	twin.ls.finish_tick(30, snap, "feedfacecafebeef")
	var sent: Dictionary = Wire.decode(twin.frames[-1]).message
	runner.check(sent.hash.value == "feedfacecafebeef" and int(sent.hash.tick) == 30 and twin.ls.hash_rows()[-1] == "30\tfeedfacecafebeef", "SB4 finish_tick sends and logs the given digest, got %s" % [sent.get("hash")])
	for tick in range(31, 60): twin.ls.finish_tick(tick, null)
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

func test_th_pump_tick_hash_on_request(runner) -> bool:
	var pump = SimPump.new(Skirmish.create(true, "human"))
	pump.start()
	var plain = pump.query(_job())
	runner.check(plain.get("tick_hash") == "", "TH pump: a job without want_tick_hash has an empty tick_hash")
	var job = _job()
	job.want_tick_hash = true
	var asked = pump.query(job)
	runner.check(asked.get("tick_hash") == pump.live().tick_hash() and not asked.tick_hash.is_empty(), "TH pump: want_tick_hash fills the live tick hash after the step")
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

func test_ph_record_returns_command_log(runner) -> bool:
	var pump = _pump()
	var id: int = _own_unit(pump.live())
	pump.post(_job([_move(id), _move(999999)]))
	pump.drain()
	var r: Dictionary = pump.record()
	runner.check(r.keys() == ["tick", "digest", "match", "commands"], "PH record has tick, digest, match and commands, got %s" % [r.keys()])
	runner.check(r.get("commands", []).size() == 1 and r.commands[0].entity_ids == [id], "PH the log holds the accepted command only")
	if r.has("commands") and not r.commands.is_empty(): r.commands[0].type = "x"
	runner.check(pump.record().get("commands", [{}])[0].get("type", "") == "move", "PH record hands a copy")
	runner.check(not pump.has_method("recorder"), "PH recorder() is gone")
	return true

func test_ph_pair_drivers_send_legal_frames(runner) -> bool:
	var pair: Dictionary = _pair_drivers()
	var double_takes: int = _frames(pair.drivers, 120, 3)
	runner.check(double_takes > 0, "PH fixture: seat 1 takes two ticks in one callback, got %d" % double_takes)
	runner.check(pair.transports[0].order.refusals.is_empty() and pair.transports[1].order.refusals.is_empty(), "PH both seats send only frames the relay accepts, got %s and %s" % [pair.transports[0].order.refusals, pair.transports[1].order.refusals])
	_unpair(pair)
	return true

func test_ph_finish_tick_refuses_after_end(runner) -> bool:
	var twin: Dictionary = _twin()
	var before: int = twin.frames.size()
	twin.ls.set_protocol_error("probe")
	twin.ls.finish_tick(1, null)
	twin.ls.finish_tick(2, null)
	runner.check(twin.frames.size() == before and twin.ls.status() == "ended_protocol" and twin.ls.end_reason() == "probe", "PH finish_tick, in order or gapped, sends nothing after the end and keeps its reason, got %d frames, %s" % [twin.frames.size() - before, twin.ls.end_reason()])
	return true

func test_ph_start_after_end_sends_nothing(runner) -> bool:
	var ls = Lockstep.new(1, [1, 2] as Array[int], 4, 30, func() -> int: return 0)
	var frames: Array[String] = []
	ls.send = func(text: String) -> void: frames.append(text)
	ls.set_protocol_error("probe")
	ls.start(Skirmish.create(true, "human").snapshot())
	runner.check(frames.is_empty() and ls.hash_rows().is_empty() and ls.end_reason() == "probe", "PH start after the end sends nothing and logs no hash row, got %d frames" % frames.size())
	return true

func test_ph_finish_tick_refuses_out_of_order(runner) -> bool:
	var gap: Dictionary = _twin()
	gap.ls.finish_tick(2, null)
	runner.check(gap.frames.size() == 1 and gap.ls.end_reason() == "own tick 6 after 4", "PH a gap is refused, got %d frames, %s" % [gap.frames.size(), gap.ls.end_reason()])
	var repeat: Dictionary = _twin()
	repeat.ls.finish_tick(1, null)
	repeat.ls.finish_tick(1, null)
	runner.check(repeat.frames.size() == 2 and repeat.ls.end_reason() == "own tick 5 after 5", "PH a repeat is refused, got %d frames, %s" % [repeat.frames.size(), repeat.ls.end_reason()])
	var ordered: Dictionary = _twin()
	for tick in range(1, 4): ordered.ls.finish_tick(tick, null)
	var ticks: Array = ordered.frames.slice(1).map(func(text: String) -> int: return Wire.decode(text).message.tick)
	runner.check(ticks == [5, 6, 7] and ordered.ls.status() == "running", "PH in order sends each, got %s %s" % [ticks, ordered.ls.status()])
	return true

func test_ph_take_checks_next_tick(runner) -> bool:
	var ahead: Dictionary = _twin_at_four()
	runner.check(ahead.ls.take(5) == null and ahead.ls.status() == "ended_protocol" and ahead.ls.end_reason() == "take tick 5, expected 4", "PH take ahead ends the lockstep, got %s" % [ahead.ls.end_reason()])
	runner.check(ahead.ls.take(9) == null and ahead.ls.end_reason() == "take tick 5, expected 4", "PH take after the end keeps the first reason")
	var quiet: Dictionary = _twin_at_four()
	runner.check(quiet.ls.take(3, true) == null and quiet.ls.status() == "ended_protocol", "PH a quiet take does not hide a wrong tick, got %s" % [quiet.ls.status()])
	var legal: Dictionary = _twin_at_four()
	legal.ls.receive(_peer(4))
	runner.check(legal.ls.take(4) != null and legal.ls.status() == "running", "PH the expected tick is taken")
	return true

func _remove_both(sim) -> void:
	sim.remove_object(4)
	sim.remove_object(6)

# Seat 2 is a plain Lockstep and Simulation pair, the way the headless client plays it.
func _advance_peer_frame(peer: Dictionary, frame: int) -> void:
	for text in peer.inbox.poll(): peer.ls.receive(text)
	if frame == 40: peer.ls.submit(_move(_own_unit(peer.sim, "", 2)))
	if peer.sim.tick() == 100 and not peer.removed:
		peer.removed = true
		_remove_both(peer.sim)
	if peer.ls.advance(peer.sim):
		var tick: int = peer.sim.tick()
		peer.ls.finish_tick(tick, peer.sim.snapshot() if peer.ls.wants_snapshot(tick) else null)
	if peer.sim.match_over() and not peer.over_sent:
		peer.over_sent = true
		peer.order.accepts(Wire.encode({"type": "over"}))

func test_ph_driver_matches_advance_peer(runner) -> bool:
	var a := PairTransport.new()
	var b := PairTransport.new()
	a.peer = b
	var driver = OnlineDriver.new(a, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)
	driver.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
	driver.start()
	var ls = Lockstep.new(2, [1, 2] as Array[int])
	var peer := {"ls": ls, "inbox": b, "order": RelayFrameOrder.new(), "removed": false, "over_sent": false,
		"sim": Skirmish.create(true, "human", {}, Skirmish.MAP_PATH, [] as Array[int])}
	ls.send = func(text: String) -> void:
		if peer.order.accepts(text) and Wire.decode(text).message.type == "tick": a.inbox.append(text)
	ls.submit({"type": "choose_faction", "faction": "china"})
	ls.start(peer.sim.snapshot())
	var removed: bool = false
	var frames: int = 0
	while not (driver.over() and peer.sim.match_over()) and frames < 400:
		frames += 1
		_advance_peer_frame(peer, frames)
		driver.step()
		driver.drain()
		if frames == 20:
			driver.submit(_move(_own_unit(driver.pump.live())))
			driver.submit(_move(999))
		if driver.current().tick == 100 and not removed:
			removed = true
			_remove_both(driver.pump.live())
	runner.check(removed and peer.removed, "PH fixture: both sides removed at tick 100")
	runner.check(driver.over() and peer.sim.match_over(), "PH both end the match (%d frames)" % frames)
	var rows: PackedStringArray = driver._lockstep.hash_rows()
	runner.check(rows.size() >= 4 and rows == ls.hash_rows(), "PH hash rows equal through the end, got %d and %d" % [rows.size(), ls.hash_rows().size()])
	var lines: PackedStringArray = Lockstep.log_lines(driver._lockstep.command_log())
	runner.check(lines.size() >= 3 and lines == Lockstep.log_lines(ls.command_log()), "PH command logs equal, got %d lines" % lines.size())
	var record: Dictionary = driver.record()
	runner.check(record.tick == peer.sim.tick() and record.digest == StateHash.digest(peer.sim.snapshot()), "PH same end tick and digest, got %d and %d" % [record.tick, peer.sim.tick()])
	var overs: int = a.others.filter(func(text: String) -> bool: return Wire.decode(text).message.type == "over").size()
	runner.check(a.order.refusals.is_empty() and peer.order.refusals.is_empty() and overs == 1 and peer.over_sent, "PH every frame of both sides is legal at the relay, got %s and %s" % [a.order.refusals, peer.order.refusals])
	a.peer = null
	ls.send = Callable()
	return true

func test_ph_nested_cache_freeze(runner) -> bool:
	_pump()
	var views: Array = []
	for id: String in Registry.units() + Registry.buildings():
		for view: Dictionary in [Registry.unit_view(id), Registry.building_view(id), Registry.profile_view(id)]:
			if not view.is_empty(): views.append(view)
	runner.check(not views.is_empty() and views.all(func(view: Dictionary) -> bool: return view.is_read_only()), "PH start freezes every cached view (%d views)" % views.size())
	Registry.add_test_kind("ph_probe", _rifle_row("rifle"))
	runner.check(not Registry.unit_view("ph_probe").is_read_only(), "PH a test kind resets to writable caches")
	Registry.clear_test_kinds()
	return true

func test_pal_survivors_query(runner) -> bool:
	var sim := SeatFixture.sim()
	var digest: String = StateHash.digest(sim.snapshot())
	runner.check(sim.survivors() == [1, 2, 3], "PAL every seat with a victory building survives, got %s" % [sim.survivors()])
	runner.check(StateHash.digest(sim.snapshot()) == digest, "PAL the query leaves the digest unchanged")
	SeatFixture.defeat(sim, 2)
	runner.check(sim.survivors() == [1, 3], "PAL a seat without a victory building drops out, got %s" % [sim.survivors()])
	var seats: Array[Dictionary] = []
	for seat in [1, 2]:
		seats.append({"seat": seat, "team": seat, "controller": "human", "credits": Skirmish.START_CREDITS, "faction": "usa"})
	runner.check(MapData.create(MapData.load("res://data/maps/broken_crown.json"), seats).survivors().is_empty(), "PAL no match has no survivors")
	return true

func test_pal_note_carries_survivors(runner) -> bool:
	var seats: Array[Dictionary] = []
	for seat in [1, 2, 3]:
		seats.append({"seat": seat, "team": seat, "controller": "human", "credits": Skirmish.START_CREDITS, "defer": true})
	var sim: RefCounted = MapData.create(MapData.load("res://data/maps/broken_crown.json"), seats)
	sim.begin_setup([1, 2, 3] as Array[int])
	var pump = SimPump.new(sim)
	var first = pump.start()
	runner.check(first.survivors == [1, 2, 3], "PAL a setup sim counts every seat as a survivor, got %s" % [first.survivors])
	var job = SimPump.Job.new()
	for seat in [1, 2, 3]: job.commands.append({"type": "choose_faction", "faction": "usa", "player": seat, "tick": 0, "sequence": 0})
	pump.post(job)
	var note = pump.drain()[0]
	runner.check(note.survivors == [1, 2, 3], "PAL the job's note carries the survivors after its step, got %s" % [note.survivors])
	runner.check(SimPump.new(SeatFixture.sim()).start().survivors == [1, 2, 3], "PAL a note from a job without a step carries survivors")
	return true

func _trio_drivers() -> Dictionary:
	var relay := TrioRelay.new()
	var starts: Array[int] = MatchSettings.starts("broken_crown", 7, [1, 2, 3] as Array[int])
	var drivers: Array = []
	for seat in [1, 2, 3]:
		var driver = OnlineDriver.new(relay.ends[seat - 1], Lockstep.new(seat, [1, 2, 3] as Array[int]), "usa", seat)
		var sim: RefCounted = Skirmish.create(true, "human", {1: "usa", 2: "usa", 3: "usa"}, MatchSettings.map_path("broken_crown"), starts, 3)
		SeatFixture.defeat(sim, 2)
		driver.adopt(sim)
		drivers.append(driver)
	for driver in drivers: driver.start()
	return {"drivers": drivers, "relay": relay}

func _trio_frames(drivers: Array, frames: int) -> void:
	for frame in frames:
		for driver in drivers:
			driver.step()
			driver.drain()

func _trio_until(drivers: Array, tick: int, single: bool = false) -> bool:
	for frame in 400:
		if drivers.all(func(driver) -> bool: return driver.current().tick >= tick): return not single or drivers.all(func(driver) -> bool: return driver.current().tick == tick)
		if not single: _trio_frames(drivers, 1)
		for driver in drivers:
			if single and driver.current().tick < tick: _single(driver)
	return false

func _single(driver) -> void:
	# The driver has no public cap; one tick per call lets a test stop exactly on a tick.
	driver._credit = 0
	driver.step()
	driver.drain()

func _last_sent(trio: Dictionary, seat: int) -> int:
	return trio.relay.ends[seat - 1].order._last

func test_pal_three_drivers_play_on(runner) -> bool:
	var trio: Dictionary = _trio_drivers()
	var drivers: Array = trio.drivers
	runner.check(_trio_until(drivers, 40), "PAL fixture: three drivers reach tick 40")
	trio.relay.leave(2, _last_sent(trio, 2))
	var rest: Array = [drivers[0], drivers[2]]
	_trio_frames(rest, 150)
	var one = drivers[0]
	var three = drivers[2]
	runner.check(one._lockstep.status() == "running" and three._lockstep.status() == "running" and one.current().tick > 45 and three.current().tick > 45, "PAL a defeated seat's leave lets the others play on, got %s %s at %d %d" % [one._lockstep.status(), three._lockstep.status(), one.current().tick, three.current().tick])
	var rows: PackedStringArray = one._lockstep.hash_rows()
	var other: PackedStringArray = three._lockstep.hash_rows()
	var common: int = mini(rows.size(), other.size())
	runner.check(common >= 4 and rows.slice(0, common) == other.slice(0, common), "PAL digests stay equal on %d common rows" % common)
	trio.relay.leave(3, _last_sent(trio, 3))
	_trio_frames([one], 60)
	runner.check(one._lockstep.status() == "ended_left" and one._lockstep.left_seat() == 3 and one._lockstep.end_reason() == "player 3 disconnected", "PAL seat 3 leaving later ends the match, got %s seat %d" % [one._lockstep.status(), one._lockstep.left_seat()])
	runner.check(trio.relay.ends.all(func(end) -> bool: return end.order.refusals.is_empty()), "PAL every frame is legal at the relay")
	trio.relay.ends.clear()
	return true

func test_pal_driver_quiet_defers_verdict(runner) -> bool:
	var trio: Dictionary = _trio_drivers()
	var one = trio.drivers[0]
	var three = trio.drivers[2]
	runner.check(_trio_until(trio.drivers, 40), "PAL fixture: three drivers reach tick 40")
	var a: int = _last_sent(trio, 2)
	trio.relay.leave(2, a)
	for guard in 30:
		if one.current().tick >= a: break
		_single(one)
	for guard in 30:
		if _last_sent(trio, 3) > a: break
		_single(three)
	runner.check(one.current().tick == a and _last_sent(trio, 3) > a, "PAL fixture: seat 1 waits at A %d (at %d), seat 3 sent past it" % [a, one.current().tick])
	one._credit = 3
	one.step()
	one.drain()
	runner.check(one.current().tick == a + 1, "PAL the call took A and only A, now at %d" % one.current().tick)
	runner.check(one._lockstep.can_step(a + 1) and one._credit >= 1, "PAL the A + 1 packets were in hand with credit left (%d)" % one._credit)
	runner.check(one._lockstep.status() == "running", "PAL a quiet take keeps the status, got %s" % one._lockstep.status())
	_single(one)
	runner.check(one._lockstep.status() == "running" and one.current().tick == a + 2, "PAL the next loud take plays on at A + 1, got %s at %d" % [one._lockstep.status(), one.current().tick])
	trio.relay.ends.clear()
	return true

func test_pal_played_on_catches_up(runner) -> bool:
	var trio: Dictionary = _trio_drivers()
	var one = trio.drivers[0]
	var three = trio.drivers[2]
	runner.check(_trio_until(trio.drivers, 40), "PAL fixture: three drivers reach tick 40")
	var a: int = _last_sent(trio, 2)
	trio.relay.leave(2, a)
	runner.check(_trio_until([one, three], a + 4, true), "PAL fixture: both drivers stand on A + 4")
	for guard in 2: _single(three)
	var t: int = one.current().tick
	runner.check(one._lockstep.status() == "running" and one._lockstep.can_step(t) and one._lockstep.can_step(t + 1), "PAL fixture: seat 1 played on and holds packets %d and %d" % [t, t + 1])
	one._credit = 3
	one.step()
	one.drain()
	runner.check(one.current().tick == t + 2, "PAL a played-on match still catches up two ticks in one call, from %d to %d" % [t, one.current().tick])
	trio.relay.ends.clear()
	return true

func test_trio_leave_has_no_match_ended_heading(runner) -> bool:
	var trio: Dictionary = _trio_drivers()
	var one = trio.drivers[0]
	runner.check(_trio_until(trio.drivers, 40), "T26 fixture: three drivers reach tick 40")
	trio.relay.leave(3, _last_sent(trio, 3))
	_trio_frames([one, trio.drivers[1]], 60)
	runner.check(one._lockstep.status() == "ended_left" and one.leave_heading() == "", "T26 Match ended is the 2v2 heading only, got %s '%s'" % [one._lockstep.status(), one.leave_heading()])
	trio.relay.ends.clear()
	return true

func test_pal_driver_play_on_then_end_closes_room(runner) -> bool:
	var trio: Dictionary = _trio_drivers()
	var one = trio.drivers[0]
	var rest: Array = [one, trio.drivers[2]]
	runner.check(_trio_until(trio.drivers, 40), "PAL fixture: three drivers reach tick 40")
	trio.relay.leave(2, _last_sent(trio, 2))
	var end_tick: int = 80
	runner.check(_trio_until(rest, end_tick, true),"PAL fixture: both drivers stand on tick %d, got %d %d" % [end_tick, one.current().tick, rest[1].current().tick])
	for driver in rest: SeatFixture.defeat(driver.pump.live(), 3)
	for frame in 60:
		if one.over(): break
		for driver in rest: _single(driver)
	runner.check(one.over() and one._phase == "done" and not one.can_play_again(), "PAL a played-on match that ends closes the room, phase %s" % one._phase)
	runner.check(one.rematch_line() == "P2 USA left the match" and not one._lockstep.opponent_left() and one.notice() == "", "PAL the line says the friend left, not a relay loss, got '%s' notice '%s'" % [one.rematch_line(), one.notice()])
	trio.relay.ends.clear()
	return true

func test_pump_bot_first_wave_at_5400(runner) -> bool:
	var sim = _sim()
	var pump = SimPump.new(sim)
	var rally: Vector2 = Vector2(pump.start().starts[2]) + Vector2(0.5, 0.5)
	var tanks: Array = []
	for i in 40:
		if tanks.size() == 6: break
		var id: int = sim.spawn(2, rally + Vector2(i % 8 - 4, floori(i / 8.0) - 2), "china_tank")
		if id >= 0: tanks.append(id)
	runner.check(tanks.size() == 6, "7-14 setup: six tanks stand at the rally of the bot seat, got %d at %s" % [tanks.size(), rally])
	var attacks: Array = []
	for i in Skirmish.FIRST_WAVE_TICK + Skirmish.DECISION_TICKS + 70:
		pump.post(_job([], [2]))
		for command: Dictionary in pump.drain()[0].bot_commands:
			if command.type == "attack": attacks.append(command.tick)
	runner.check(not attacks.is_empty() and attacks[0] == Skirmish.next_decision(Skirmish.FIRST_WAVE_TICK - 1, 2), "7-14 the offline bot's first wave leaves at the first decision from tick 5400, got %s" % [attacks.slice(0, 3)])
	return true

func test_pump_bot_lines_on_request(runner) -> bool:
	var plain = _pump()
	var asked = _pump()
	var lines: Array[PackedStringArray] = []
	for i in 80:
		plain.post(_job([], [1, 2]))
		var job = _job([], [1, 2])
		job.want_bot_lines = i >= 40
		asked.post(job)
		lines.append(asked.drain()[0].bot_lines)
		plain.drain()
	runner.check(lines.slice(0, 40).all(func(rows: PackedStringArray) -> bool: return rows.is_empty()), "BL4 no line without the flag")
	runner.check(lines[79].size() == 2 and lines[79][0].begins_with("Bot 1 usa | W0 in ") and lines[79][1].begins_with("Bot 2 china | W0 in "), "BL4 one line per bot seat, in seat order, got %s" % [lines[79]])
	runner.check(StateHash.digest(asked.live().snapshot()) == StateHash.digest(plain.live().snapshot()), "BL4 asking for the lines leaves the digest alone")
	for key: StringName in [Skirmish.BOT_META, Skirmish.BOT_TEAM_META]:
		runner.check(var_to_str(asked.live().get_meta(key)) == var_to_str(plain.live().get_meta(key)), "BL4 asking for the lines leaves the %s memory alone after the second decisions" % key)
	var none = _job([], [])
	none.want_bot_lines = true
	none.step = false
	runner.check(asked.query(none).bot_lines.is_empty(), "BL4 a job with no bot seats has no lines")
	return true

func test_shot_carries_its_building_target(runner) -> bool:
	var sim = Fixture.make_world()
	sim.add_player(2, 0)
	var barracks: int = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(10, 10))
	sim.spawn(2, Vector2(8.5, 11.5), "usa_tank")
	var recorder = CommandRecorder.new(sim)
	var target: Dictionary = {}
	for i in 90:
		var note = SimPump.run_job(sim, recorder, SimPump.Job.new(), SimPump.Slot.new())
		for event: Dictionary in note.events:
			if event.type == "shot" and event.target_id == barracks: target = event.get("target_building", {})
		if not target.is_empty(): break
	runner.check(not target.is_empty() and target.id == barracks and target.owner == 1 and target.kind == "usa_barracks" and target.origin.size() == 2, "PH shot at a building carries its row, got %s" % [target])
	return true

func _planning(bots: Array = [2]):
	var job = _job([], bots)
	job.plan_bots = true
	return job

func test_plan_bots_leaves_sim_untouched(runner) -> bool:
	var planned = _pump()
	var quiet = _pump()
	var commands: int = 0
	for i in 100:
		planned.post(_planning())
		quiet.post(_job())
		commands += planned.drain()[0].bot_commands.size()
		quiet.drain()
	runner.check(commands > 0, "PB1 the bot planned orders (%d)" % commands)
	runner.check(planned.live().last_sequence(2) == -1 and planned.live().snapshot().pending_commands.is_empty(), "PB1 none reached the sim, last sequence %d" % planned.live().last_sequence(2))
	runner.check(planned.live().tick_hash() == quiet.live().tick_hash() and StateHash.digest(planned.live().snapshot()) == StateHash.digest(quiet.live().snapshot()), "PB1 planning leaves the hash and the digest of a sim without the bot")
	return true

func test_planned_bot_commands_not_in_pump_record(runner) -> bool:
	var pump = _pump()
	var own: int = _own_unit(pump.live())
	var job = _planning()
	job.commands.assign([_move(own)])
	pump.post(job)
	var planned: int = pump.drain()[0].bot_commands.size()
	for i in 99:
		pump.post(_planning())
		planned += pump.drain()[0].bot_commands.size()
	var recorded: Array = pump.record().commands
	runner.check(planned > 0 and recorded.size() == 1 and recorded[0].player == 1, "PB1 the record holds the human order only, planned %d recorded %s" % [planned, recorded])
	return true

func test_planner_drops_invalid_bot_order(runner) -> bool:
	var sim = _sim()
	var recorder = SimPump.PlanRecorder.new(sim)
	var mine: int = _own_unit(sim, "", 2)
	var good: Dictionary = recorder.issue_command({"type": "move", "player": 2, "tick": 0, "sequence": 0, "entity_ids": [mine], "target": [10.5, 10.5]})
	var dead: Dictionary = recorder.issue_command({"type": "move", "player": 2, "tick": 0, "sequence": 1, "entity_ids": [99999], "target": [10.5, 10.5]})
	runner.check(good.ok and not dead.ok and dead.error == "Missing entity or wrong owner", "PB1 the planner answers as the sim would, got %s %s" % [good, dead])
	runner.check(recorder.commands().size() == 1 and sim.last_sequence(2) == -1 and sim.snapshot().pending_commands.is_empty(), "PB1 only the valid order is kept and the sim is untouched")
	return true

func _quad_sim():
	var starts: Array[int] = MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2))
	return Skirmish.create(true, "human", {3: "china", 4: "frc"}, MatchSettings.map_path("broken_crown"), starts, 4, MatchSettings.teams(2, 2))

# Guard: setup already refuses every non-faction order; this pins that no bot order is planned or sent then.
func test_setup_plans_no_bot_orders(runner) -> bool:
	var pump = SimPump.new(_quad_sim())
	pump.start()
	var planned: int = 0
	for i in 70:
		pump.post(_planning([3, 4]))
		planned += pump.drain()[0].bot_commands.size()
	runner.check(pump.live().snapshot().match.status == "setup" and pump.live().tick() == 70, "PB2 fixture: the humans have not chosen, status %s" % pump.live().snapshot().match.status)
	runner.check(planned == 0 and pump.live().last_sequence(3) == -1 and pump.live().last_sequence(4) == -1, "PB2 setup plans no order for players 3 and 4, planned %d" % planned)
	var pair: Dictionary = _quad_drivers()
	_trio_until(pair.drivers, 20, true)
	var early: Array = pair.drivers[0]._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.player > 2)
	runner.check(early.is_empty() and pair.drivers[0].current().view.match.status == "ongoing", "PB2 no frame holds a bot order while the match is in setup, got %s" % [early])
	_unpair(pair)
	return true

func _quad_drivers(delay: int = 4) -> Dictionary:
	var a := PairTransport.new()
	var b := PairTransport.new()
	a.peer = b
	b.peer = a
	var allowed := {1: [1, 3, 4]}
	var seats: Array[int] = [1, 2]
	var one = OnlineDriver.new(a, Lockstep.new(1, seats, delay, 30, Time.get_ticks_usec, allowed), "usa", 1)
	var two = OnlineDriver.new(b, Lockstep.new(2, seats, delay, 30, Time.get_ticks_usec, allowed), "china", 2)
	var starts: Array[int] = MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2))
	for driver in [one, two]:
		driver.create(MatchSettings.map_path("broken_crown"), starts, {3: "china", 4: "frc"}, 7)
		driver.start()
	return {"drivers": [one, two], "transports": [a, b]}

func _player_ticks(driver, player: int) -> Array:
	return driver._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.player == player).map(func(m: Dictionary) -> int: return m.tick)

func test_host_submits_bot_commands_after_human(runner) -> bool:
	var pair: Dictionary = _quad_drivers()
	var drivers: Array = pair.drivers
	runner.check(_trio_until(drivers, 33, true), "PB3 fixture: both seats stand at tick 33")
	var one = drivers[0]
	one.submit(_move(_own_unit(one.pump.live())))
	_single(one)
	_trio_frames(drivers, 150)
	var played: Array = one._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.type != "choose_faction")
	var players: Array = played.filter(func(m: Dictionary) -> bool: return m.tick == played[0].tick).map(func(m: Dictionary) -> int: return m.player)
	runner.check(players.size() >= 2 and players[0] == 1 and players.slice(1).all(func(player: int) -> bool: return player == 3), "PB3 the frame holds the human order first, then the bot's, got %s" % [players])
	runner.check(not _player_ticks(one, 4).is_empty() and not _player_ticks(drivers[1], 4).is_empty(), "PB3 both bots order and both seats applied them")
	var rows: PackedStringArray = one._lockstep.hash_rows()
	var other: PackedStringArray = drivers[1]._lockstep.hash_rows()
	var common: int = mini(rows.size(), other.size())
	runner.check(common >= 4 and rows.slice(0, common) == other.slice(0, common) and not _ended_any(drivers), "PB3 equal digests on %d rows, ended %s" % [common, one._lockstep.status()])
	_unpair(pair)
	return true

func test_bot_refusal_not_in_driver_answers(runner) -> bool:
	var pair: Dictionary = _quad_drivers()
	var drivers: Array = pair.drivers
	_trio_until(drivers, 33, true)
	_single(drivers[0])
	_single(drivers[1])
	for driver in drivers: SeatFixture.defeat(driver.pump.live(), 3)
	_trio_frames(drivers, 30)
	var one = drivers[0]
	runner.check(not _player_ticks(one, 3).is_empty() and one._lockstep.bot_rejections().size() > 0, "PB4 fixture: the bot's order was applied and refused, rejections %d" % one._lockstep.bot_rejections().size())
	runner.check(one.take_answers().is_empty() and one._lockstep.rejections().is_empty(), "PB4 the host's answers hold nothing of it")
	runner.check(not _ended_any(drivers) and one._lockstep.hash_rows().slice(0, 2) == drivers[1]._lockstep.hash_rows().slice(0, 2), "PB4 neither seat ended, status %s" % one._lockstep.status())
	_unpair(pair)
	return true

func test_guest_runs_no_bot(runner) -> bool:
	var pair: Dictionary = _quad_drivers()
	var one = pair.drivers[0]
	var two = pair.drivers[1]
	var host_job = one._tick_job([] as Array[Dictionary])
	var guest_job = two._tick_job([] as Array[Dictionary])
	runner.check(host_job.plan_bots and host_job.bots == [3, 4], "PB5 the host plans its two bots, got %s" % [host_job.bots])
	runner.check(guest_job.bots.is_empty(), "PB5 the guest runs no bot, got %s" % [guest_job.bots])
	var plain = _pair_drivers()
	runner.check(plain.drivers[0]._tick_job([] as Array[Dictionary]).bots.is_empty(), "PB5 a 1v1 host runs no bot")
	_unpair(plain)
	_unpair(pair)
	return true

func _bot_orders(driver, player: int) -> Array:
	return driver._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.player == player)

# The same seed and orders without the full frame: its first bot orders are the ones the full frame dropped.
func test_bot_refused_submit_recovers_next_decision(runner) -> bool:
	var twin: Dictionary = _quad_drivers()
	_trio_until(twin.drivers, 33, true)
	_trio_frames(twin.drivers, 90)
	var first: Array = _bot_orders(twin.drivers[0], 3)
	first = first.filter(func(m: Dictionary) -> bool: return m.tick == first[0].tick) if not first.is_empty() else []
	_unpair(twin)
	var pair: Dictionary = _quad_drivers()
	var drivers: Array = pair.drivers
	_trio_until(drivers, 33, true)
	var one = drivers[0]
	one._lockstep._queue_bytes = Wire.MAX_FRAME_BYTES
	_single(one)
	_trio_frames(drivers, 90)
	var later: Array = _bot_orders(one, 3)
	var ticks: Array = later.map(func(m: Dictionary) -> int: return m.tick)
	runner.check(not first.is_empty() and not ticks.is_empty() and ticks.min() > first[0].tick and not _ended_any(drivers), "PB6 fixture: the full frame dropped the tick-33 orders %s, later ticks %s" % [first.map(func(m: Dictionary) -> String: return m.type), ticks])
	for order: Dictionary in first:
		runner.check(later.any(func(m: Dictionary) -> bool: return m.type == order.type and m.get("entity_ids", []) == order.get("entity_ids", [])), "PB6 the dropped %s for %s is sent at the bot's next decision" % [order.type, order.get("entity_ids", [])])
	_unpair(pair)
	return true

static func latch_for_test() -> void:
	var forced: String = SimPump._forced
	SimPump.force_mode_for_test("inline")
	var failing = NullJobPump.new(Skirmish.create(true, "ai", FACTIONS, Skirmish.MAP_PATH, [] as Array[int]))
	SimPump.force_mode_for_test(forced)
	failing.start()
	failing.fail_next = true
	failing.query(SimPump.Job.new())
	failing.stop()

static func mode_after_latch() -> String:
	return "inline-fallback" if OS.get_environment("WARGRID_SIM_THREAD") == "1" and OS.has_feature("threads") else "inline"

func _mode() -> String:
	return SimPump.new(_sim()).mode()

func test_sb5a_mode_from_switch(runner) -> bool:
	var saved: String = OS.get_environment("WARGRID_SIM_THREAD")
	var threads: bool = OS.has_feature("threads")
	SimPump.reset_process_latch_for_test()
	SimPump.force_mode_for_test("worker")
	runner.check(_mode() == "worker", "SB5A forced worker names worker")
	SimPump.force_mode_for_test("inline")
	runner.check(_mode() == "inline", "SB5A forced inline names inline")
	SimPump.force_mode_for_test("")
	OS.unset_environment("WARGRID_SIM_THREAD")
	runner.check(not SimPump.worker_wanted() and _mode() == "inline", "SB5A switch off is inline")
	OS.set_environment("WARGRID_SIM_THREAD", "1")
	runner.check(SimPump.worker_wanted() == threads and _mode() == ("worker" if threads else "inline"), "SB5A switch on is worker where threads exist")
	latch_for_test()
	runner.check(not SimPump.worker_wanted() and _mode() == mode_after_latch(), "SB5A after a failure the next pump is inline (fallback), got %s" % _mode())
	SimPump.force_mode_for_test("worker")
	runner.check(_mode() == "worker", "SB5A a forced worker overrides the latch")
	SimPump.force_mode_for_test("")
	SimPump.reset_process_latch_for_test()
	runner.check(SimPump.worker_wanted() == threads and _mode() == ("worker" if threads else "inline"), "SB5A a reset latch gives the worker back")
	if saved.is_empty(): OS.unset_environment("WARGRID_SIM_THREAD")
	else: OS.set_environment("WARGRID_SIM_THREAD", saved)
	return true
