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
const BenchLoads = preload("res://scripts/debug/bench_loads.gd")
const MatchBenchScreen = preload("res://scripts/debug/match_bench_screen.gd")
const OnlineDriver = preload("res://scripts/match/online_driver.gd")
const OfflineDriver = preload("res://scripts/match/offline_driver.gd")
const Lockstep = preload("res://scripts/net/lockstep.gd")
const Wire = preload("res://scripts/net/wire.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const FACTIONS := {1: "usa", 2: "china"}
const MATCH_TICKS: int = 900
const RelayFrameOrder = preload("res://tests/relay_frame_order.gd")
const SeatFixture = preload("res://tests/seat_fixture.gd")
const HeadlessClient = preload("res://scripts/net/headless_client.gd")
const SimSettings = preload("res://scripts/presentation/sim_settings.gd")
const DIGEST_EVERY: int = 30
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const VIEW_COLUMNS: Array[String] = ["id", "owner", "kind", "hp", "max_hp", "target", "queue", "container", "x", "y", "heading_x", "heading_y", "order_x", "order_y", "status", "tier", "mode", "phase", "flags", "kinds", "modes", "phases"]

# Names the mode on every check of a looped case, so a red line says which pump failed.
class Tagged extends RefCounted:
	var runner
	var mode: String
	func _init(target, tag: String) -> void:
		runner = target
		mode = tag
	func check(condition: bool, message: String) -> void: runner.check(condition, "%s [%s]" % [message, mode])

# Stands in for a pump in SimPump._threads: an abandoned one leaves at the reap once gone, a running one at stop().
class HeldWorker extends RefCounted:
	var _abandoned: bool = true
	var gone: bool = false
	var stops: int = 0
	func _reap() -> void: if gone: SimPump._threads.erase(self)
	func stop() -> void:
		stops += 1
		if not _abandoned: SimPump._threads.erase(self)

# Posts a semaphore once a job has run, so a case waits for the worker's progress instead of reading live().
class RanPump extends "res://tests/failing_pump.gd":
	var ran := Semaphore.new()
	# Gate points to pause at, in order; the worker re-points the gate itself, so main never writes it while the worker runs. Unarmed: the plain gate.
	var points: Array[String] = []
	var armed: bool = false
	var arrived := Semaphore.new()
	func _note_for(job: Job, slot: Slot) -> Note:
		var note: Note = super(job, slot)
		ran.post()
		return note
	func _wait_gate(where: String) -> void:
		if not armed:
			super(where)
			return
		if _gate == null or points.is_empty() or points[0] != where: return
		points.pop_front()
		_gate_where = where
		arrived.post()
		super(where)

# Counts queries and names the thread of every job; the Web start must query nothing before the worker is ready.
class StartSpy extends "res://scripts/match/sim_pump.gd":
	var queries: int = 0
	var ids: Array[int] = []
	func query(job: Job) -> Note:
		queries += 1
		return super(job)
	func _note_for(job: Job, slot: Slot) -> Note:
		ids.append(OS.get_thread_caller_id())
		return super(job, slot)

# A worker that never reports in, so the polled start has to time out.
class NeverStartsPump extends "res://scripts/match/sim_pump.gd":
	func _run_worker() -> void: pass

# The frame and the millisecond a pump polls its start by.
class StartClock extends RefCounted:
	var frame: int = 0
	var msec: int = 0
	func frame_now() -> int: return frame
	func msec_now() -> int: return msec
	func advance(step_msec: int = 33) -> void:
		frame += 1
		msec += step_msec

# The thread that ran each job, read after the pump is idle.
class IdPump extends "res://scripts/match/sim_pump.gd":
	var ids: Array[int] = []
	func _note_for(job: Job, slot: Slot) -> Note:
		ids.append(OS.get_thread_caller_id())
		return super(job, slot)

# Says whether the caches were still empty when stop() was called, which is before the next simulation is built.
class StopSpy extends "res://scripts/match/sim_pump.gd":
	var caches_empty_at_stop: bool = false
	var _seen: bool = false
	func stop() -> void:
		if not _seen: caches_empty_at_stop = Registry.cache_keys().values().all(func(keys: Array) -> bool: return keys.is_empty())
		_seen = true
		super()

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

# A close counts, and with tell_peer it reaches the peer as the relay's left frame after this seat's last tick.
class RelayEnd extends PairTransport:
	var seat: int = 0
	var closes: int = 0
	var tell_peer: bool = false
	var gone: bool = false
	func closed() -> bool: return gone
	func close() -> void:
		closes += 1
		if tell_peer and closes == 1: peer.inbox.append(Wire.encode({"type": "left", "seat": seat, "after_tick": order._last}))

# Records the preview request of every post, accepted or not.
class PostSpy extends "res://scripts/match/sim_pump.gd":
	var previews: Array[Dictionary] = []
	func post(job: Job) -> bool:
		previews.append(job.preview)
		return super(job)

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

func test_sb5a_team_bench_requires_combat(runner) -> bool:
	var screen = MatchBenchScreen.new()
	screen.load_name = "team"
	screen._scripted = 1
	screen._views_shown = 1
	screen._last_view_tick = 100
	screen._bot_commands = 5
	runner.check(screen._check_run(100) == "mechanics missing: shots and deaths", "SB5A the team bench fails without shots and deaths, got '%s'" % screen._check_run(100))
	screen._shots = 3
	runner.check(screen._check_run(100) == "mechanics missing: shots and deaths", "SB5A the team bench fails with shots but no deaths")
	screen._deaths = 1
	runner.check(screen._check_run(100).is_empty(), "SB5A the team bench passes with shots, deaths and bot commands, got '%s'" % screen._check_run(100))
	screen._bot_commands = 0
	runner.check(screen._check_run(100) == "mechanics missing: bot commands", "SB5A the team bench still requires bot commands")
	screen.free()
	runner.check(BenchLoads.start_tick("team") == 10200, "SB5A the team window opens at tick 10200, where the first shot falls near 10365")
	return true

func cases() -> Array[Callable]:
	return [test_sb3_pump_digests_equal_direct, test_sb3_two_notes_one_drain, test_sb3_slot_invariant, test_sb3_sequence_stamp, test_sb3_refusal_one_tick_later, test_sb3_preview_answer, test_sb3_query_leaves_slots, test_sb3_job0_starts, test_sb3_freeze_rejects_late_insert, test_sb3_freeze_covers_match, test_sb3_ring_off_same_digest, test_sb4_two_drivers_loopback, test_sb4_two_drivers_match_end, test_sb4_take_record_equals_advance, test_sb4_quiet_take_keeps_status, test_sb4_finish_tick_uses_given_digest, test_sb4_ring_query, test_th_pump_tick_hash_on_request, test_ph_fresh_slot_per_job, test_ph_null_job_fails_pump, test_ph_sequence_stamp_only_on_request, test_ph_record_returns_command_log, test_ph_pair_drivers_send_legal_frames, test_ph_finish_tick_refuses_after_end, test_ph_start_after_end_sends_nothing, test_ph_finish_tick_refuses_out_of_order, test_ph_take_checks_next_tick, test_ph_driver_matches_advance_peer, test_ph_nested_cache_freeze, test_pal_survivors_query, test_pal_note_carries_survivors, test_pal_three_drivers_play_on, test_pal_driver_quiet_defers_verdict, test_pal_played_on_catches_up, test_pal_driver_play_on_then_end_closes_room, test_trio_leave_has_no_match_ended_heading, test_pump_bot_first_wave_at_5400, test_pump_bot_lines_on_request, test_shot_carries_its_building_target, test_plan_bots_leaves_sim_untouched, test_planned_bot_commands_not_in_pump_record, test_planner_drops_invalid_bot_order, test_setup_plans_no_bot_orders, test_host_submits_bot_commands_after_human, test_bot_refusal_not_in_driver_answers, test_guest_runs_no_bot, test_bot_refused_submit_recovers_next_decision, test_sb5a_mode_from_switch, test_sb5b_headless_pump_refuses_the_switch, test_sb5a_null_job_marker_fails_pump, test_sb5a_idle_is_no_stall, test_sb5a_abandoned_worker_takes_no_more_jobs, test_sb5a_post_refused_when_full, test_sb5a_empty_drain_keeps_slots, test_sb5a_drain_at_publish_boundary, test_sb5a_held_view_never_changes, test_sb5a_queue_stats_counts, test_sb5a_undrained_notes_bounded, test_sb5a_worker_runs_off_main, test_sb5a_payload_is_values, test_sb5a_query_never_touches_slots, test_sb5a_query_waits_behind_jobs, test_sb5a_record_waits_for_queue, test_sb5a_query_after_stop_runs_inline, test_sb5a_query_null_on_failed_pump, test_sb5a_record_keeps_commands, test_sb5a_record_on_stalled_worker_is_empty, test_sb5a_query_null_job_fails_worker_pump, test_sb5a_query_behind_a_failing_job_answers_null, test_sb5a_stop_idle_worker, test_sb5a_stop_with_job_in_flight, test_sb5a_stop_is_idempotent, test_sb5a_stop_reads_failure_marker, test_sb5a_thread_start_failure_fails_pump, test_sb5a_stopped_pump_keeps_timing_rows, test_sb5a_owner_marker_stops_the_worker, test_sb5a_window_end_follows_the_first_tick, test_sb5a_job_zero_null_fails_pump, test_sb5a_create_stops_old_pump_first, test_sb5a_restart_drops_old_notes, test_sb5a_leave_record_replays, test_sb5a_end_record_replays, test_sb5a_full_pump_leaves_next_tick_in_lockstep, test_sb5a_preview_waits_for_room, test_sb5a_two_notes_one_frame_pair_in_order, test_sb5a_hash_tick_note_carries_digest, test_sb5a_failure_between_room_and_post, test_sb5a_online_failure_ends_and_closes, test_sb5a_relay_loss_and_pump_failure_same_frame, test_sb5a_job_zero_null_ends_online_match, test_sb5a_pairing_rejects_foreign_note, test_sb5a_notice_waiting_empty, test_sb5a_play_on_leave_with_jobs_in_flight, test_sb5a_worker_host_bot_frames, test_sb5a_human_order_in_held_window_leads_the_bots, test_sb5a_ring_may_trail_desync_tick, test_sb5a_report_survives_failed_query, test_sb5a_suspend_is_no_stall, test_sb5a_lock_guards_publish, test_sb5a_publish_orders, test_sb5a_stop_and_post_same_frame, test_sb5a_free_running_equals_inline, test_sb5a_queue_stats_job_timings, test_sb5a_offline_digest_every_and_bots, test_sb5a_job_timing_rows_edges, test_sb5a_team_bench_requires_combat, test_sb5b_request_reaches_the_next_pump_only, test_sb5b_restart_after_failure_falls_back, test_sb5b_start_polls_readiness_across_frames, test_sb5b_start_driver_waits_for_ready, test_sb5b_start_cancelled_before_ready, test_sb5b_start_late_poll_is_no_stall, test_sb5b_start_times_out, test_sb5b_start_online_reads_job_zero, test_sb5b_log_online_commands_kept_once, test_sb5b_log_offline_record_replays, test_t0b_quit_helper_kills_only_a_live_worker_off_the_web]

func _sim():
	return Skirmish.create(true, "ai", FACTIONS, Skirmish.MAP_PATH, [] as Array[int])

var _built: Array = []

func _modes() -> Array[String]:
	return ["inline", "worker"] if OS.has_feature("threads") else ["inline"]

# A forced mode applies to this pump only, and the case's end stops it (_stop_built).
func _make(sim, mode: String = "", kind = SimPump):
	var saved: String = SimPump._forced
	if not mode.is_empty(): SimPump.force_mode_for_test(mode)
	var pump = kind.new(sim)
	SimPump.force_mode_for_test(saved)
	if not mode.is_empty(): _built.append(pump)
	return pump

func _pump(mode: String = ""):
	var pump = _make(_sim(), mode)
	pump.start()
	return pump

func _stop_built() -> void:
	for pump in _built: pump.stop()
	_built.clear()

func _each_mode(runner, body: Callable) -> bool:
	for mode in _modes():
		body.call(Tagged.new(runner, mode), mode)
		_stop_built()
	return true

func _idle(pump, limit_ms: int = 5000) -> bool:
	var end: int = Time.get_ticks_msec() + limit_ms
	while pump.busy() and Time.get_ticks_msec() < end: OS.delay_usec(200)
	return not pump.busy()

func _drain(pump) -> Array:
	_idle(pump)
	return pump.drain()

func _post_when_room(pump, job) -> bool:
	var end: int = Time.get_ticks_msec() + 5000
	while not pump.has_room() and Time.get_ticks_msec() < end: OS.delay_usec(200)
	return pump.post(job)

func _collect(pump, count: int, limit_ms: int = 1500) -> Array:
	var notes: Array = []
	var end: int = Time.get_ticks_msec() + limit_ms
	while notes.size() < count and Time.get_ticks_msec() < end:
		notes.append_array(pump.drain())
		OS.delay_usec(200)
	return notes

func _ran_pump():
	var pump = _make(_sim(), "worker", RanPump)
	pump.start()
	while pump.ran.try_wait(): pass
	return pump

func _await_ran(pump, limit_ms: int = 1500) -> bool:
	var end: int = Time.get_ticks_msec() + limit_ms
	var ran: bool = pump.ran.try_wait()
	while not ran and Time.get_ticks_msec() < end:
		OS.delay_usec(200)
		ran = pump.ran.try_wait()
	return ran

func _gated() -> Dictionary:
	var pump = _pump("worker")
	var gate := Semaphore.new()
	pump.gate_publish_for_test(gate, "before_publish")
	return {"pump": pump, "gate": gate}

func _release(gate: Semaphore, count: int) -> void:
	for i in count: gate.post()

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
	return _each_mode(runner, _sb3_pump_digests_equal_direct)

func _sb3_pump_digests_equal_direct(runner, mode: String) -> void:
	var direct = _sim()
	var recorder = CommandRecorder.new(direct)
	var pump = _pump(mode)
	var equal: int = 0
	var bot_commands: int = 0
	for i in MATCH_TICKS:
		Skirmish.issue_opponent(recorder)
		direct.step()
		var job = _job([], [2])
		job.want_digest = (i + 1) % DIGEST_EVERY == 0
		pump.post(job)
		var note = _drain(pump)[0]
		bot_commands += note.bot_commands.size()
		if job.want_digest and note.digest == StateHash.digest(direct.snapshot()): equal += 1
	runner.check(equal * DIGEST_EVERY == MATCH_TICKS, "SB3 pump digests equal a direct run every 30 ticks (%d)" % equal)
	runner.check(StateHash.digest(pump.live().snapshot()) == StateHash.digest(direct.snapshot()) and pump.live().tick() == MATCH_TICKS, "SB3 pump digest equal at 900")
	runner.check(bot_commands > 0, "SB3 bot commands reach the notes")

func _battle_pump(mode: String = ""):
	var sim = Fixture.make_world()
	sim.add_player(2, 0)
	var own: Array = []
	var enemy: Array = []
	for i in 8:
		own.append(sim.spawn(1, Vector2(10.5, 8.5 + i), "china_tank"))
		enemy.append(sim.spawn(2, Vector2(13.5, 8.5 + i), "china_tank"))
	var pump = _make(sim, mode)
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
	return _each_mode(runner, _sb3_two_notes_one_drain)

func _sb3_two_notes_one_drain(runner, mode: String) -> void:
	var pump = _pump(mode)
	runner.check(pump.current().tick == 0 and pump.previous() == null, "SB3 start fills CURRENT at tick 0")
	pump.post(_job())
	pump.post(_job())
	var notes: Array = _drain(pump)
	runner.check(notes.size() == 2 and notes[0].tick == 1 and notes[1].tick == 2, "SB3 two notes in tick order")
	runner.check(pump.current().tick == 2 and pump.previous().tick == 0, "SB3 CURRENT is the last note, PREVIOUS the old CURRENT")
	runner.check(notes[0].done and notes[1].done, "SB3 inline notes are done")
	var battle: Dictionary = _battle_pump(mode)
	pump = battle.pump
	pump.post(_job([_attack(1, battle.own, battle.enemy[0]), _attack(2, battle.enemy, battle.own[0])]))
	_drain(pump)
	var pairs: int = 0
	for i in 60:
		pump.post(_job([_halt(battle.builder)]))
		pump.post(_job([_halt(battle.builder)]))
		notes = _drain(pump)
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
	var note = _drain(pump)[0]
	runner.check(not events.is_empty() and not results.is_empty() and note.events == events and note.results == results, "SB3 publish job carries the externally stepped tick's events and results")
	runner.check(note.tick == pump.live().tick() and pump.current().tick == note.tick and pump.current().view.tick == note.tick, "SB3 publish job shows the externally stepped tick")

func test_sb3_slot_invariant(runner) -> bool:
	return _each_mode(runner, _sb3_slot_invariant)

func _sb3_slot_invariant(runner, mode: String) -> void:
	var pump = _pump(mode)
	var seen: Array = [pump.current()]
	var held: int = 0
	var views: int = 0
	var kept: int = 0
	for i in 60:
		var shown = pump.current()
		var shown_tick: int = shown.view.tick
		pump.post(_job())
		if is_same(pump.current(), shown) and shown.tick == shown_tick and shown.view.tick == shown_tick and (pump.previous() == null or pump.previous().view.tick == shown_tick - 1): kept += 1
		var notes: Array = _drain(pump)
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

func test_ph_fresh_slot_per_job(runner) -> bool:
	return _each_mode(runner, _ph_fresh_slot_per_job)

func _ph_fresh_slot_per_job(runner, mode: String) -> void:
	var pump = _pump(mode)
	var held = pump.current()
	var kept_tick: int = held.tick
	var kept_view: Dictionary = held.view
	for i in 6:
		pump.post(_job())
		_drain(pump)
	runner.check(held.tick == kept_tick and is_same(held.view, kept_view) and held.view.tick == held.tick, "PH a held slot never changes after publishing")
	var old = pump.current()
	pump.post(_job())
	pump.post(_job())
	_drain(pump)
	runner.check(pump.current().tick == old.tick + 2 and is_same(pump.previous(), old), "PH two posts, one drain: current is the second job, previous the old current")

func test_ph_null_job_fails_pump(runner) -> bool:
	SimPump.force_mode_for_test("inline")
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
	return _each_mode(runner, _sb3_sequence_stamp)

func _sb3_sequence_stamp(runner, mode: String) -> void:
	var pump = _pump(mode)
	var id: int = _own_unit(pump.live())
	pump.post(_job([_move(id), _move(999999), {"type": "stop", "player": 1, "entity_ids": [id]}]))
	var issued: Array = _drain(pump)[0].issued
	runner.check(issued.map(func(row) -> int: return row.command.sequence) == [0, 1, 1], "SB3 sequences stamped from the simulation")
	runner.check(issued.map(func(row) -> bool: return row.ok) == [true, false, true], "SB3 refusal between two accepted commands")
	runner.check(not issued[1].error.is_empty() and issued[0].command.tick == 0, "SB3 refusal carries its error, tick stamped at issue")
	runner.check(pump.live().last_sequence(1) == 1 and pump.live().last_sequence(2) == -1, "SB3 last_sequence follows accepted commands")
	var explicit: Dictionary = _move(id)
	explicit.sequence = 5
	pump.post(_job([explicit]))
	var kept: Dictionary = _drain(pump)[0].issued[0]
	runner.check(kept.ok and kept.command.sequence == 5 and pump.live().last_sequence(1) == 5 and not explicit.has("tick"), "SB3 explicit sequence kept, caller's command untouched")

func test_sb3_refusal_one_tick_later(runner) -> bool:
	return _each_mode(runner, _sb3_refusal_one_tick_later)

func _sb3_refusal_one_tick_later(runner, mode: String) -> void:
	var pump = _pump(mode)
	pump.post(_job())
	pump.post(_job([_move(999999)]))
	var notes: Array = _drain(pump)
	runner.check(notes[0].issued.is_empty(), "SB3 no answer before the issuing job")
	runner.check(notes[1].issued.size() == 1 and not notes[1].issued[0].ok, "SB3 refusal in the issuing job's note")
	runner.check(notes[1].issued[0].command.tick == notes[1].tick - 1, "SB3 refusal arrives with the next tick")

func _free_origin(sim, builder: int, kind: String) -> Vector2i:
	for y in range(2, 40):
		for x in range(2, 40):
			if sim.preview_build(1, builder, kind, Vector2i(x, y)).ok: return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_sb3_preview_answer(runner) -> bool:
	return _each_mode(runner, _sb3_preview_answer)

func _sb3_preview_answer(runner, mode: String) -> void:
	var pump = _pump(mode)
	var builder: int = _own_unit(pump.live(), "usa_builder")
	var origin: Vector2i = _free_origin(pump.live(), builder, "usa_power_plant")
	var job = _job([{"type": "build", "player": 1, "builder_id": builder, "building_kind": "usa_power_plant", "origin": [origin.x, origin.y]}])
	job.preview = {"player": 1, "builder_id": builder, "kind": "usa_power_plant", "origin": origin}
	pump.post(job)
	var note = _drain(pump)[0]
	var preview: Dictionary = note.preview
	var expected: Dictionary = pump.live().preview_build(1, builder, "usa_power_plant", origin)
	runner.check(origin.x >= 0 and note.issued[0].ok and not expected.ok, "SB3 the job's build takes the previewed footprint")
	runner.check(preview.keys() == ["kind", "origin", "ok", "error", "tick"], "SB3 preview answer shape")
	runner.check(preview.kind == "usa_power_plant" and preview.origin == origin and preview.ok == expected.ok and preview.error == expected.error and preview.tick == 1, "SB3 preview answered after the step")
	pump.post(_job())
	runner.check(_drain(pump)[0].preview == {}, "SB3 no preview, no answer")

func test_sb3_query_leaves_slots(runner) -> bool:
	return _each_mode(runner, _sb3_query_leaves_slots)

func _sb3_query_leaves_slots(runner, mode: String) -> void:
	var pump = _pump(mode)
	pump.post(_job())
	_drain(pump)
	var current = pump.current()
	var previous = pump.previous()
	pump.post(_job())
	var job = _job()
	job.step = false
	job.want_digest = true
	var note = pump.query(job)
	runner.check(note.digest == StateHash.digest(pump.live().snapshot()) and note.tick == 2, "SB3 query digest equals the live digest")
	runner.check(is_same(pump.current(), current) and is_same(pump.previous(), previous) and current.tick == 1 and current.view.tick == 1, "SB3 query leaves the slots")
	var notes: Array = _drain(pump)
	runner.check(notes.size() == 1 and notes[0].tick == 2 and not pump.busy(), "SB3 query leaves the queued note")
	runner.check(pump.current().tick == 2 and pump.current().view.tick == 2 and is_same(pump.previous(), current), "SB3 rotation after a query as without one")

func test_sb3_job0_starts(runner) -> bool:
	return _each_mode(runner, _sb3_job0_starts)

func _sb3_job0_starts(runner, mode: String) -> void:
	var pump = _make(_sim(), mode)
	var note = pump.start()
	var map: Dictionary = pump.live().map_data()
	runner.check(note.starts.size() == 2 and note.starts[1] == MapData.start_cell(map, 1) and note.starts[2] == MapData.start_cell(map, 2) and note.starts[1] != note.starts[2], "SB3 job 0 carries the start cells")
	runner.check(pump.current().tick == 0 and note.tick == 0 and _drain(pump).is_empty(), "SB3 job 0 fills CURRENT, not the queue")
	runner.check(note.stats.size() == 2 and note.stats[0].player == 1, "SB3 notes carry match stats")
	var fixture = _make(Fixture.make_world(), mode)
	runner.check(fixture.start().starts == {} and fixture.current().tick == 0, "SB3 fixture world starts without start cells")
	fixture.stop()
	runner.check(not fixture.post(_job()), "SB3 post refused after stop")
	runner.check(fixture.live().tick() == 0, "PH a post refused after stop steps nothing, got tick %d" % fixture.live().tick())

func _frozen_count() -> int:
	return Registry.frozen_state().values().count(true)

func _rifle_row(weapon: String) -> Dictionary:
	var row: Dictionary = Registry.kind("usa_rifle_infantry").duplicate()
	row.weapon = weapon
	return row

func test_sb3_freeze_rejects_late_insert(runner) -> bool:
	return _each_mode(runner, _sb3_freeze_rejects_late_insert)

func _sb3_freeze_rejects_late_insert(runner, mode: String) -> void:
	_pump(mode)
	runner.check(_frozen_count() == 5 and Registry.radius_cache.is_read_only(), "SB3 start freezes each of the five caches (%s)" % Registry.frozen_state())
	Registry.add_test_kind("sb3_probe", _rifle_row("rifle"))
	runner.check(_frozen_count() == 0 and Registry.cache_keys().values().all(func(keys: Array) -> bool: return keys.is_empty()), "SB3 add_test_kind leaves all five caches writable and empty (%s)" % Registry.cache_keys())
	runner.check(is_equal_approx(Combat.reach_of("sb3_probe"), 3.9), "SB3 test kind reach comes from its weapon")
	Registry.add_test_kind("sb3_probe", _rifle_row("rocket"))
	runner.check(is_equal_approx(Combat.reach_of("sb3_probe"), 6.9), "SB3 re-adding a test kind with another weapon drops the cached reach")
	Registry.clear_test_kinds()
	runner.check(_frozen_count() == 0 and Registry.cache_keys().values().all(func(keys: Array) -> bool: return keys.is_empty()), "SB3 clear_test_kinds leaves all five caches writable and empty (%s)" % Registry.cache_keys())
	_pump(mode)
	runner.check(_frozen_count() == 5, "SB3 start freezes again after a reset")

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
	return _each_mode(runner, _sb3_freeze_covers_match)

func _sb3_freeze_covers_match(runner, mode: String) -> void:
	var pump = _pump(mode)
	var warm: Dictionary = Registry.cache_keys()
	var missing: Array = _missing_warm()
	runner.check(missing.is_empty(), "SB3 warm-up fills every registered kind in each applicable cache (missing %s)" % [missing.slice(0, 5)])
	var warm_keys: Dictionary = Registry.cache_keys()
	var bots: Array = [2]
	for i in MATCH_TICKS:
		pump.post(_job([], bots))
		_drain(pump)
	runner.check(Registry.cache_keys() == warm_keys, "SB3 no cache grows during a 900-tick bot match")
	var battle: Dictionary = _battle_world()
	var fight = _make(battle.sim, mode)
	fight.start()
	fight.post(_job(battle.commands))
	for i in 150:
		fight.post(_job())
		_drain(fight)
	runner.check(Registry.cache_keys() == warm_keys, "SB3 no cache grows during a 150-tick battle of every armed kind")
	var team = _make(TeamMatch.create(), mode)
	team.start()
	var seats: Array = []
	for entry in TeamMatch.SEATS: seats.append(entry.seat)
	for i in 300:
		team.post(_job([], seats))
		_drain(team)
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

func _pair_drivers(mode: String = "") -> Dictionary:
	var a := RelayEnd.new()
	var b := RelayEnd.new()
	a.peer = b
	b.peer = a
	a.seat = 1
	b.seat = 2
	var one = OnlineDriver.new(a, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)
	var two = OnlineDriver.new(b, Lockstep.new(2, [1, 2] as Array[int]), "china", 2)
	SimPump.force_mode_for_test(mode)
	for driver in [one, two]:
		driver.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
		driver.start()
	SimPump.force_mode_for_test("")
	return {"drivers": [one, two], "transports": [a, b]}

# Breaks the transports' reference cycle and stops both pumps.
func _unpair(pair: Dictionary) -> void:
	pair.transports[0].peer = null
	for driver in pair.drivers: driver.stop()

# One frame of a driver: step, wait for its worker, drain.
func _cycle(driver) -> void:
	driver.step()
	_idle(driver.pump)
	driver.drain()

# Seat 2 lags so seat 1 sometimes takes two ticks in one callback.
func _frames(drivers: Array, frames: int, lag: int) -> int:
	var double_takes: int = 0
	for frame in frames:
		var before: int = drivers[0].current().tick
		_cycle(drivers[0])
		if drivers[0].current().tick == before + 2: double_takes += 1
		if lag > 0 and frame % lag != lag - 1: continue
		for i in lag - 1 if lag > 0 else 1: _cycle(drivers[1])
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
	return _each_mode(runner, _sb4_two_drivers_loopback)

func _sb4_two_drivers_loopback(runner, mode: String) -> void:
	var pair: Dictionary = _pair_drivers(mode)
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

func test_sb4_two_drivers_match_end(runner) -> bool:
	return _each_mode(runner, _sb4_two_drivers_match_end)

func _sb4_two_drivers_match_end(runner, mode: String) -> void:
	var pair: Dictionary = _pair_drivers(mode)
	var drivers: Array = pair.drivers
	var seen: Array[bool] = [false, false]
	var frames: int = 0
	while not (drivers[0].over() and drivers[1].over()) and frames < 400:
		frames += 1
		for i in 2:
			_cycle(drivers[i])
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
	return _each_mode(runner, _sb4_ring_query)

func _sb4_ring_query(runner, mode: String) -> void:
	var pump = _make(Skirmish.create(true, "human"), mode)
	pump.start()
	for i in 40: _post_when_room(pump, _job())
	var current = pump.current()
	var job = SimPump.Job.new()
	job.step = false
	job.want_ring = true
	var ring: PackedStringArray = pump.query(job).ring
	runner.check(ring == pump.live().hash_ring() and ring.size() == 40, "SB4 the ring query returns the live ring, got %d rows" % ring.size())
	job.want_ring = false
	runner.check(pump.query(job).ring.is_empty(), "SB4 a query without want_ring has no ring")
	runner.check(is_same(pump.current(), current) and pump.live().tick() == 40 and _drain(pump).size() == 40, "SB4 the ring query leaves the slots and the note queue alone")

func test_th_pump_tick_hash_on_request(runner) -> bool:
	return _each_mode(runner, _th_pump_tick_hash_on_request)

func _th_pump_tick_hash_on_request(runner, mode: String) -> void:
	var pump = _make(Skirmish.create(true, "human"), mode)
	pump.start()
	var plain = pump.query(_job())
	runner.check(plain.get("tick_hash") == "", "TH pump: a job without want_tick_hash has an empty tick_hash")
	var job = _job()
	job.want_tick_hash = true
	var asked = pump.query(job)
	runner.check(asked.get("tick_hash") == pump.live().tick_hash() and not asked.tick_hash.is_empty(), "TH pump: want_tick_hash fills the live tick hash after the step")

func test_ph_sequence_stamp_only_on_request(runner) -> bool:
	return _each_mode(runner, _ph_sequence_stamp_only_on_request)

func _ph_sequence_stamp_only_on_request(runner, mode: String) -> void:
	var pump = _pump(mode)
	var id: int = _own_unit(pump.live())
	var bare = SimPump.Job.new()
	bare.commands.assign([_move(id)])
	pump.post(bare)
	var issued: Array = _drain(pump)[0].issued
	runner.check(not issued[0].ok and issued[0].error == "Missing field: sequence" and pump.live().last_sequence(1) == -1, "PH without the flag a missing sequence is refused, got %s" % [issued[0]])
	pump.post(_job([_move(id)]))
	issued = _drain(pump)[0].issued
	runner.check(issued[0].ok and issued[0].command.sequence == 0, "PH with the flag it is stamped, got %s" % [issued[0]])

func test_ph_record_returns_command_log(runner) -> bool:
	return _each_mode(runner, _ph_record_returns_command_log)

func _ph_record_returns_command_log(runner, mode: String) -> void:
	var pump = _pump(mode)
	var id: int = _own_unit(pump.live())
	pump.post(_job([_move(id), _move(999999)]))
	_drain(pump)
	var r: Dictionary = pump.record()
	runner.check(r.keys() == ["tick", "digest", "match", "commands"], "PH record has tick, digest, match and commands, got %s" % [r.keys()])
	runner.check(r.get("commands", []).size() == 1 and r.commands[0].entity_ids == [id], "PH the log holds the accepted command only")
	if r.has("commands") and not r.commands.is_empty(): r.commands[0].type = "x"
	runner.check(pump.record().get("commands", [{}])[0].get("type", "") == "move", "PH record hands a copy")
	runner.check(not pump.has_method("recorder"), "PH recorder() is gone")

func test_ph_pair_drivers_send_legal_frames(runner) -> bool:
	return _each_mode(runner, _ph_pair_drivers_send_legal_frames)

func _ph_pair_drivers_send_legal_frames(runner, mode: String) -> void:
	var pair: Dictionary = _pair_drivers(mode)
	var double_takes: int = _frames(pair.drivers, 120, 3)
	runner.check(double_takes > 0, "PH fixture: seat 1 takes two ticks in one callback, got %d" % double_takes)
	runner.check(pair.transports[0].order.refusals.is_empty() and pair.transports[1].order.refusals.is_empty(), "PH both seats send only frames the relay accepts, got %s and %s" % [pair.transports[0].order.refusals, pair.transports[1].order.refusals])
	_unpair(pair)

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
	return _each_mode(runner, _ph_driver_matches_advance_peer)

func _ph_driver_matches_advance_peer(runner, mode: String) -> void:
	var a := PairTransport.new()
	var b := PairTransport.new()
	a.peer = b
	var driver = OnlineDriver.new(a, Lockstep.new(1, [1, 2] as Array[int]), "usa", 1)
	SimPump.force_mode_for_test(mode)
	driver.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
	SimPump.force_mode_for_test("")
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
		_cycle(driver)
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
	driver.stop()

func test_ph_nested_cache_freeze(runner) -> bool:
	return _each_mode(runner, _ph_nested_cache_freeze)

func _ph_nested_cache_freeze(runner, mode: String) -> void:
	_pump(mode)
	var views: Array = []
	for id: String in Registry.units() + Registry.buildings():
		for view: Dictionary in [Registry.unit_view(id), Registry.building_view(id), Registry.profile_view(id)]:
			if not view.is_empty(): views.append(view)
	runner.check(not views.is_empty() and views.all(func(view: Dictionary) -> bool: return view.is_read_only()), "PH start freezes every cached view (%d views)" % views.size())
	Registry.add_test_kind("ph_probe", _rifle_row("rifle"))
	runner.check(not Registry.unit_view("ph_probe").is_read_only(), "PH a test kind resets to writable caches")
	Registry.clear_test_kinds()

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
	return _each_mode(runner, _pal_note_carries_survivors)

func _pal_note_carries_survivors(runner, mode: String) -> void:
	var seats: Array[Dictionary] = []
	for seat in [1, 2, 3]:
		seats.append({"seat": seat, "team": seat, "controller": "human", "credits": Skirmish.START_CREDITS, "defer": true})
	var sim: RefCounted = MapData.create(MapData.load("res://data/maps/broken_crown.json"), seats)
	sim.begin_setup([1, 2, 3] as Array[int])
	var pump = _make(sim, mode)
	var first = pump.start()
	runner.check(first.survivors == [1, 2, 3], "PAL a setup sim counts every seat as a survivor, got %s" % [first.survivors])
	var job = SimPump.Job.new()
	for seat in [1, 2, 3]: job.commands.append({"type": "choose_faction", "faction": "usa", "player": seat, "tick": 0, "sequence": 0})
	pump.post(job)
	var note = _drain(pump)[0]
	runner.check(note.survivors == [1, 2, 3], "PAL the job's note carries the survivors after its step, got %s" % [note.survivors])
	runner.check(_make(SeatFixture.sim(), mode).start().survivors == [1, 2, 3], "PAL a note from a job without a step carries survivors")

func _trio_drivers(mode: String = "") -> Dictionary:
	var relay := TrioRelay.new()
	var starts: Array[int] = MatchSettings.starts("broken_crown", 7, [1, 2, 3] as Array[int])
	var drivers: Array = []
	SimPump.force_mode_for_test(mode)
	for seat in [1, 2, 3]:
		var driver = OnlineDriver.new(relay.ends[seat - 1], Lockstep.new(seat, [1, 2, 3] as Array[int]), "usa", seat)
		var sim: RefCounted = Skirmish.create(true, "human", {1: "usa", 2: "usa", 3: "usa"}, MatchSettings.map_path("broken_crown"), starts, 3)
		SeatFixture.defeat(sim, 2)
		driver.adopt(sim)
		drivers.append(driver)
	SimPump.force_mode_for_test("")
	for driver in drivers: driver.start()
	return {"drivers": drivers, "relay": relay}

# Stops every pump and breaks the relay's reference cycle.
func _trio_done(trio: Dictionary) -> void:
	for driver in trio.drivers: driver.stop()
	trio.relay.ends.clear()

func _trio_frames(drivers: Array, frames: int) -> void:
	for frame in frames:
		for driver in drivers: _cycle(driver)

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
	_cycle(driver)

func _last_sent(trio: Dictionary, seat: int) -> int:
	return trio.relay.ends[seat - 1].order._last

func test_pal_three_drivers_play_on(runner) -> bool:
	return _each_mode(runner, _pal_three_drivers_play_on)

func _pal_three_drivers_play_on(runner, mode: String) -> void:
	var trio: Dictionary = _trio_drivers(mode)
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
	_trio_done(trio)

func test_pal_driver_quiet_defers_verdict(runner) -> bool:
	return _each_mode(runner, _pal_driver_quiet_defers_verdict)

func _pal_driver_quiet_defers_verdict(runner, mode: String) -> void:
	var trio: Dictionary = _trio_drivers(mode)
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
	_cycle(one)
	runner.check(one.current().tick == a + 1, "PAL the call took A and only A, now at %d" % one.current().tick)
	runner.check(one._lockstep.can_step(a + 1) and one._credit >= 1, "PAL the A + 1 packets were in hand with credit left (%d)" % one._credit)
	runner.check(one._lockstep.status() == "running", "PAL a quiet take keeps the status, got %s" % one._lockstep.status())
	_single(one)
	runner.check(one._lockstep.status() == "running" and one.current().tick == a + 2, "PAL the next loud take plays on at A + 1, got %s at %d" % [one._lockstep.status(), one.current().tick])
	_trio_done(trio)

func test_pal_played_on_catches_up(runner) -> bool:
	return _each_mode(runner, _pal_played_on_catches_up)

func _pal_played_on_catches_up(runner, mode: String) -> void:
	var trio: Dictionary = _trio_drivers(mode)
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
	_cycle(one)
	runner.check(one.current().tick == t + 2, "PAL a played-on match still catches up two ticks in one call, from %d to %d" % [t, one.current().tick])
	_trio_done(trio)

func test_trio_leave_has_no_match_ended_heading(runner) -> bool:
	return _each_mode(runner, _trio_leave_has_no_match_ended_heading)

func _trio_leave_has_no_match_ended_heading(runner, mode: String) -> void:
	var trio: Dictionary = _trio_drivers(mode)
	var one = trio.drivers[0]
	runner.check(_trio_until(trio.drivers, 40), "T26 fixture: three drivers reach tick 40")
	trio.relay.leave(3, _last_sent(trio, 3))
	_trio_frames([one, trio.drivers[1]], 60)
	runner.check(one._lockstep.status() == "ended_left" and one.leave_heading() == "", "T26 Match ended is the 2v2 heading only, got %s '%s'" % [one._lockstep.status(), one.leave_heading()])
	_trio_done(trio)

func test_pal_driver_play_on_then_end_closes_room(runner) -> bool:
	return _each_mode(runner, _pal_driver_play_on_then_end_closes_room)

func _pal_driver_play_on_then_end_closes_room(runner, mode: String) -> void:
	var trio: Dictionary = _trio_drivers(mode)
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
	_trio_done(trio)

func test_pump_bot_first_wave_at_5400(runner) -> bool:
	return _each_mode(runner, _pump_bot_first_wave_at_5400)

func _pump_bot_first_wave_at_5400(runner, mode: String) -> void:
	var sim = _sim()
	var pump = _make(sim, mode)
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
		for command: Dictionary in _drain(pump)[0].bot_commands:
			if command.type == "attack": attacks.append(command.tick)
	runner.check(not attacks.is_empty() and attacks[0] == Skirmish.next_decision(Skirmish.FIRST_WAVE_TICK - 1, 2), "7-14 the offline bot's first wave leaves at the first decision from tick 5400, got %s" % [attacks.slice(0, 3)])

func test_pump_bot_lines_on_request(runner) -> bool:
	return _each_mode(runner, _pump_bot_lines_on_request)

func _pump_bot_lines_on_request(runner, mode: String) -> void:
	var plain = _pump(mode)
	var asked = _pump(mode)
	var lines: Array[PackedStringArray] = []
	for i in 80:
		plain.post(_job([], [1, 2]))
		var job = _job([], [1, 2])
		job.want_bot_lines = i >= 40
		asked.post(job)
		lines.append(_drain(asked)[0].bot_lines)
		_drain(plain)
	runner.check(lines.slice(0, 40).all(func(rows: PackedStringArray) -> bool: return rows.is_empty()), "BL4 no line without the flag")
	runner.check(lines[79].size() == 2 and lines[79][0].begins_with("Bot 1 usa | W0 in ") and lines[79][1].begins_with("Bot 2 china | W0 in "), "BL4 one line per bot seat, in seat order, got %s" % [lines[79]])
	runner.check(StateHash.digest(asked.live().snapshot()) == StateHash.digest(plain.live().snapshot()), "BL4 asking for the lines leaves the digest alone")
	for key: StringName in [Skirmish.BOT_META, Skirmish.BOT_TEAM_META]:
		runner.check(var_to_str(asked.live().get_meta(key)) == var_to_str(plain.live().get_meta(key)), "BL4 asking for the lines leaves the %s memory alone after the second decisions" % key)
	var none = _job([], [])
	none.want_bot_lines = true
	none.step = false
	runner.check(asked.query(none).bot_lines.is_empty(), "BL4 a job with no bot seats has no lines")

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
	return _each_mode(runner, _plan_bots_leaves_sim_untouched)

func _plan_bots_leaves_sim_untouched(runner, mode: String) -> void:
	var planned = _pump(mode)
	var quiet = _pump(mode)
	var commands: int = 0
	for i in 100:
		planned.post(_planning())
		quiet.post(_job())
		commands += _drain(planned)[0].bot_commands.size()
		_drain(quiet)
	runner.check(commands > 0, "PB1 the bot planned orders (%d)" % commands)
	runner.check(planned.live().last_sequence(2) == -1 and planned.live().snapshot().pending_commands.is_empty(), "PB1 none reached the sim, last sequence %d" % planned.live().last_sequence(2))
	runner.check(planned.live().tick_hash() == quiet.live().tick_hash() and StateHash.digest(planned.live().snapshot()) == StateHash.digest(quiet.live().snapshot()), "PB1 planning leaves the hash and the digest of a sim without the bot")

func test_planned_bot_commands_not_in_pump_record(runner) -> bool:
	return _each_mode(runner, _planned_bot_commands_not_in_pump_record)

func _planned_bot_commands_not_in_pump_record(runner, mode: String) -> void:
	var pump = _pump(mode)
	var own: int = _own_unit(pump.live())
	var job = _planning()
	job.commands.assign([_move(own)])
	pump.post(job)
	var planned: int = _drain(pump)[0].bot_commands.size()
	for i in 99:
		pump.post(_planning())
		planned += _drain(pump)[0].bot_commands.size()
	var recorded: Array = pump.record().commands
	runner.check(planned > 0 and recorded.size() == 1 and recorded[0].player == 1, "PB1 the record holds the human order only, planned %d recorded %s" % [planned, recorded])

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
	return _each_mode(runner, _setup_plans_no_bot_orders)

func _setup_plans_no_bot_orders(runner, mode: String) -> void:
	var pump = _make(_quad_sim(), mode)
	pump.start()
	var planned: int = 0
	for i in 70:
		pump.post(_planning([3, 4]))
		planned += _drain(pump)[0].bot_commands.size()
	runner.check(pump.live().snapshot().match.status == "setup" and pump.live().tick() == 70, "PB2 fixture: the humans have not chosen, status %s" % pump.live().snapshot().match.status)
	runner.check(planned == 0 and pump.live().last_sequence(3) == -1 and pump.live().last_sequence(4) == -1, "PB2 setup plans no order for players 3 and 4, planned %d" % planned)
	var pair: Dictionary = _quad_drivers(4, mode)
	_trio_until(pair.drivers, 20, true)
	var early: Array = pair.drivers[0]._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.player > 2)
	runner.check(early.is_empty() and pair.drivers[0].current().view.match.status == "ongoing", "PB2 no frame holds a bot order while the match is in setup, got %s" % [early])
	_unpair(pair)

func _quad_drivers(delay: int = 4, mode: String = "") -> Dictionary:
	var a := PairTransport.new()
	var b := PairTransport.new()
	a.peer = b
	b.peer = a
	var allowed := {1: [1, 3, 4]}
	var seats: Array[int] = [1, 2]
	var one = OnlineDriver.new(a, Lockstep.new(1, seats, delay, 30, Time.get_ticks_usec, allowed), "usa", 1)
	var two = OnlineDriver.new(b, Lockstep.new(2, seats, delay, 30, Time.get_ticks_usec, allowed), "china", 2)
	var starts: Array[int] = MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2))
	SimPump.force_mode_for_test(mode)
	for driver in [one, two]:
		driver.create(MatchSettings.map_path("broken_crown"), starts, {3: "china", 4: "frc"}, 7)
		driver.start()
	SimPump.force_mode_for_test("")
	return {"drivers": [one, two], "transports": [a, b]}

func _player_ticks(driver, player: int) -> Array:
	return driver._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.player == player).map(func(m: Dictionary) -> int: return m.tick)

func test_host_submits_bot_commands_after_human(runner) -> bool:
	return _each_mode(runner, _host_submits_bot_commands_after_human)

func _host_submits_bot_commands_after_human(runner, mode: String) -> void:
	var pair: Dictionary = _quad_drivers(4, mode)
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

func test_bot_refusal_not_in_driver_answers(runner) -> bool:
	return _each_mode(runner, _bot_refusal_not_in_driver_answers)

func _bot_refusal_not_in_driver_answers(runner, mode: String) -> void:
	var pair: Dictionary = _quad_drivers(4, mode)
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

func test_guest_runs_no_bot(runner) -> bool:
	return _each_mode(runner, _guest_runs_no_bot)

func _guest_runs_no_bot(runner, mode: String) -> void:
	var pair: Dictionary = _quad_drivers(4, mode)
	var one = pair.drivers[0]
	var two = pair.drivers[1]
	var host_job = one._tick_job([] as Array[Dictionary])
	var guest_job = two._tick_job([] as Array[Dictionary])
	runner.check(host_job.plan_bots and host_job.bots == [3, 4], "PB5 the host plans its two bots, got %s" % [host_job.bots])
	runner.check(guest_job.bots.is_empty(), "PB5 the guest runs no bot, got %s" % [guest_job.bots])
	var plain = _pair_drivers(mode)
	runner.check(plain.drivers[0]._tick_job([] as Array[Dictionary]).bots.is_empty(), "PB5 a 1v1 host runs no bot")
	_unpair(plain)
	_unpair(pair)

func _bot_orders(driver, player: int) -> Array:
	return driver._lockstep.command_log().filter(func(m: Dictionary) -> bool: return m.player == player)

# The same seed and orders without the full frame: its first bot orders are the ones the full frame dropped.
func test_bot_refused_submit_recovers_next_decision(runner) -> bool:
	return _each_mode(runner, _bot_refused_submit_recovers_next_decision)

func _bot_refused_submit_recovers_next_decision(runner, mode: String) -> void:
	var twin: Dictionary = _quad_drivers(4, mode)
	_trio_until(twin.drivers, 33, true)
	_trio_frames(twin.drivers, 90)
	var first: Array = _bot_orders(twin.drivers[0], 3)
	first = first.filter(func(m: Dictionary) -> bool: return m.tick == first[0].tick) if not first.is_empty() else []
	_unpair(twin)
	var pair: Dictionary = _quad_drivers(4, mode)
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
	var counted: Dictionary = SimPump.pump_counts()
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
	SimPump._counts = counted # the probes name the mode, they are not the suite's pumps
	if saved.is_empty(): OS.unset_environment("WARGRID_SIM_THREAD")
	else: OS.set_environment("WARGRID_SIM_THREAD", saved)
	return true

func test_sb5b_headless_pump_refuses_the_switch(runner) -> bool:
	var saved: String = OS.get_environment("WARGRID_SIM_THREAD")
	var client = HeadlessClient.new()
	OS.set_environment("WARGRID_SIM_THREAD", "1")
	client._args = {"pump": ""}
	runner.check(client._pump_error().contains("WARGRID_SIM_THREAD"), "SB5B --pump with the worker switch set is refused and names the switch, got '%s'" % client._pump_error())
	client._args = {}
	runner.check(client._pump_error() == "", "SB5B the switch alone is no error for the advance client")
	OS.unset_environment("WARGRID_SIM_THREAD")
	client._args = {"pump": ""}
	runner.check(client._pump_error() == "", "SB5B --pump without the switch runs")
	client.free()
	if saved.is_empty(): OS.unset_environment("WARGRID_SIM_THREAD")
	else: OS.set_environment("WARGRID_SIM_THREAD", saved)
	return true

func test_sb5a_null_job_marker_fails_pump(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var pump = _make(_sim(), "worker", NullJobPump)
	pump.start()
	runner.check(pump.mode() == "worker" and SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	runner.check(pump.failure() == "" and pump.post(_job([_move(_own_unit(pump.live()))])), "SB5A a good job before the null job is accepted")
	_idle(pump)
	pump.fail_next = true
	runner.check(pump.post(_job()), "SB5A the null job's post is accepted, its failure comes back as a marker")
	_idle(pump)
	pump.fail_next = false
	var notes: Array = pump.drain()
	var reason: String = pump.failure()
	runner.check(reason.begins_with("post job returned no note after tick"), "SB5A the marker names the failure at the next drain, got '%s'" % reason)
	runner.check(notes.size() == 1 and notes[0].tick == 1 and pump.current().tick == 1, "SB5A notes filed before the marker drain, the null job publishes nothing")
	runner.check(not pump.busy() and pump.has_room(), "SB5A a failed pump is not busy and reports room")
	runner.check(not pump.post(_job()) and pump.drain().is_empty() and pump.failure() == reason, "SB5A later posts are refused and the first reason stays")
	pump.stop()
	runner.check(SimPump.live_workers() == threads, "SB5A stop joins the worker of a failed pump")
	var held = _ran_pump()
	var gate := Semaphore.new()
	held.gate_publish_for_test(gate, "before_publish")
	held.post(_job())
	_await_ran(held)
	held.fail_next = true
	held.post(_job())
	held.post(_job())
	gate.post()
	runner.check(_idle(held) and held.failure() == "", "SB5A a marker with a job waiting drops it and leaves the count at 0")
	runner.check(held.drain().size() == 1 and held.failure().begins_with("post job returned no note after tick 1"), "SB5A the marker with a waiting job fails the pump at the next drain, got '%s'" % held.failure())
	held.stop()
	runner.check(held.live().tick() == 1 and SimPump.live_workers() == threads, "SB5A the waiting job never ran and stop joins")
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_idle_is_no_stall(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var frames: Array[int] = [1000]
	var now: Array[int] = [50000]
	var pump = _make(_sim(), "worker")
	pump.frame_source = func() -> int: return frames[0]
	pump.clock = func() -> int: return now[0]
	pump.start()
	runner.check(SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	frames[0] += 200
	now[0] += 10000
	runner.check(pump.drain().is_empty() and pump.failure() == "", "SB5A an idle pump never stalls, got '%s'" % pump.failure())
	pump.post(_job())
	var notes: Array = _drain(pump)
	runner.check(notes.size() == 1 and notes[0].tick == 1 and pump.failure() == "", "SB5A a post after the idle time runs, got '%s'" % pump.failure())
	frames[0] += 200
	now[0] += 10000
	runner.check(pump.drain().is_empty() and pump.failure() == "", "SB5A an idle pump after a drain never stalls, got '%s'" % pump.failure())
	pump.stop()
	return true

func test_sb5a_abandoned_worker_takes_no_more_jobs(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var frames: Array[int] = [1000]
	var now: Array[int] = [50000]
	var gate := Semaphore.new()
	var pump = _make(_sim(), "worker", IdPump)
	pump.frame_source = func() -> int: return frames[0]
	pump.clock = func() -> int: return now[0]
	pump.start()
	pump.gate_publish_for_test(gate, "before_publish")
	for i in 3: pump.post(_job())
	var began: int = Time.get_ticks_msec() + 1500
	while pump.ids.size() < 2 and Time.get_ticks_msec() < began: OS.delay_usec(200)
	frames[0] += SimPump.STALL_FRAMES
	now[0] += SimPump.STALL_MSEC
	pump.drain()
	runner.check(pump.failure().begins_with("stall: job at tick 1"), "SB5A a job over the stall limit fails the pump, got '%s'" % pump.failure())
	_release(gate, 3)
	var end: int = Time.get_ticks_msec() + 1500
	while not pump._exited and Time.get_ticks_msec() < end: OS.delay_usec(200)
	runner.check(pump._exited and pump.ids.size() == 2, "SB5A the abandoned worker ends its running job and takes no other (%s)" % [pump.ids])
	runner.check(SimPump.live_workers() == threads + 1, "SB5A an abandoned pump stays counted until it is reaped")
	_make(_sim(), "inline").start()
	runner.check(SimPump.live_workers() == threads, "SB5A the next pump's start joins the abandoned worker that exited")
	pump.stop()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_post_refused_when_full(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var gated: Dictionary = _gated()
	var pump = gated.pump
	runner.check(SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	var accepted: int = 0
	for i in 3:
		if pump.post(_job()): accepted += 1
	runner.check(accepted == 3 and pump.busy() and not pump.has_room(), "SB5A three posts fill the queue while the first job waits at the gate (%d)" % accepted)
	runner.check(not pump.post(_job()) and pump.failure() == "", "SB5A the fourth post is refused without a failure")
	_release(gated.gate, 3)
	var notes: Array = _collect(pump, 3)
	runner.check(notes.size() == 3 and notes.map(func(note) -> int: return note.tick) == [1, 2, 3], "SB5A the three accepted jobs drain in order, got %s" % [notes.map(func(note) -> int: return note.tick)])
	runner.check(_idle(pump) and pump.has_room() and pump.failure() == "", "SB5A room returns once the jobs are published")
	_release(gated.gate, 1)
	runner.check(pump.post(_job()) and _drain(pump).size() == 1, "SB5A a post after the queue emptied is accepted")
	_release(gated.gate, 3)
	pump.stop()
	return true

func test_sb5a_empty_drain_keeps_slots(runner) -> bool:
	return _each_mode(runner, _sb5a_empty_drain_keeps_slots)

func _sb5a_empty_drain_keeps_slots(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var pump = _pump(mode)
	runner.check((mode != "worker") or SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	var current = pump.current()
	runner.check(pump.drain().is_empty() and is_same(pump.current(), current) and pump.previous() == null, "SB5A an empty drain at the start keeps the slots")
	pump.post(_job())
	var notes: Array = _drain(pump)
	var shown = pump.current()
	var kept = pump.previous()
	runner.check(notes.size() == 1 and shown.tick == 1 and is_same(kept, current), "SB5A one post rotates the slots once")
	for i in 3:
		runner.check(pump.drain().is_empty() and is_same(pump.current(), shown) and is_same(pump.previous(), kept), "SB5A empty drain %d keeps both slots" % i)

func test_sb5a_drain_at_publish_boundary(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var gated: Dictionary = _gated()
	var pump = gated.pump
	runner.check(SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	pump.post(_job())
	pump.post(_job())
	var start = pump.current()
	var early: Array = pump.drain()
	runner.check(early.is_empty() and pump.busy() and is_same(pump.current(), start) and pump.previous() == null, "SB5A a drain before any publish takes nothing, and the gated job still counts as unpublished")
	_release(gated.gate, 1)
	var first: Array = _collect(pump, 1)
	var one = pump.current()
	runner.check(first.size() == 1 and first[0].tick == 1 and one.tick == 1 and is_same(pump.previous(), start) and pump.busy(), "SB5A a drain after one publish takes that note, the second job is still unpublished")
	_release(gated.gate, 1)
	var second: Array = _collect(pump, 1)
	runner.check(second.size() == 1 and second[0].tick == 2 and pump.current().tick == 2 and is_same(pump.previous(), one), "SB5A a drain after the second publish takes that note once")
	runner.check(_idle(pump) and pump.drain().is_empty(), "SB5A nothing is left after both notes drained")
	_release(gated.gate, 2)
	pump.stop()
	return true

func _siege_pump(mode: String) -> Dictionary:
	var sim = Fixture.make_world()
	sim.add_player(2, 0)
	var barracks: int = Fixture.add_completed(sim, 1, "usa_barracks", Vector2i(10, 10))
	sim.spawn(2, Vector2(8.5, 11.5), "usa_tank")
	var pump = _make(sim, mode)
	pump.start()
	return {"pump": pump, "barracks": barracks}

# The first note whose shot carries a building row, or null.
func _shot_note(pump) -> Variant:
	for i in 120:
		pump.post(_job())
		for note in _drain(pump):
			for event: Dictionary in note.events:
				if event.type == "shot" and event.get("target_building", {}).has("id"): return note
	return null

func _held_projection(note, slot) -> Dictionary:
	var projection: Dictionary = {}
	for key: String in slot.view:
		if key == "units": continue
		projection["view." + key] = slot.view[key].duplicate(true) if slot.view[key] is Array or slot.view[key] is Dictionary else slot.view[key]
	for column in VIEW_COLUMNS: projection["units." + column] = slot.view.units.get(column).duplicate()
	for field in ["events", "results", "issued", "bot_commands", "stats", "survivors", "starts", "preview"]: projection["note." + field] = note.get(field).duplicate(true)
	projection["note.tick"] = note.tick
	projection["slot.tick"] = slot.tick
	return projection

func test_sb5a_held_view_never_changes(runner) -> bool:
	return _each_mode(runner, _sb5a_held_view_never_changes)

func _sb5a_held_view_never_changes(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var siege: Dictionary = _siege_pump(mode)
	var pump = siege.pump
	runner.check((mode != "worker") or SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	var note = _shot_note(pump)
	runner.check(note != null, "SB5A fixture: a shot at a building reaches a note")
	if note == null: return
	var slot = pump.current()
	var before: Dictionary = _held_projection(note, slot)
	var moved: int = 0
	for i in 60:
		if pump.has_room() and pump.post(_job()): moved += 1
		if _held_projection(note, slot) != before: runner.check(false, "SB5A the held note and view changed while job %d ran" % i)
		pump.drain()
	_drain(pump)
	runner.check(moved > 0 and _held_projection(note, slot) == before and slot.view.tick == slot.tick, "SB5A the held note and view are unchanged after %d later jobs" % moved)
	runner.check(not before["note.events"].is_empty() and before["units.container"].size() == slot.view.units.size(), "SB5A the projection covered the shot row and the container column")

func test_sb5a_queue_stats_counts(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var frames: Array[int] = [10]
	var gated: Dictionary = _gated()
	var pump = gated.pump
	pump.frame_source = func() -> int: return frames[0]
	runner.check(SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	var fresh: Dictionary = pump.queue_stats()
	runner.check(fresh.get("queue_cap", -1) == SimPump.MAX_QUEUED and fresh.get("posts_attempted", -1) == 0 and fresh.get("room_refusals", -1) == 0 and fresh.get("depth_max", -1) == 0, "SB5A a fresh pump counts nothing and names its cap, got %s" % [fresh])
	for i in 3: pump.post(_job())
	runner.check(not pump.has_room() and not pump.has_room(), "SB5A two refusals in frame 10")
	frames[0] += 1
	runner.check(not pump.has_room(), "SB5A a refusal in frame 11")
	frames[0] += 1
	runner.check(not pump.has_room(), "SB5A a refusal in frame 12")
	frames[0] += 1
	_release(gated.gate, 3)
	_collect(pump, 3)
	runner.check(_idle(pump) and pump.has_room(), "SB5A room in frame 13 is no refusal")
	var stats: Dictionary = pump.queue_stats()
	runner.check(stats.get("room_refusals", -1) == 4 and stats.get("posts_attempted", -1) == 7, "SB5A three accepted posts and four refusals, got %s" % [stats])
	runner.check(stats.get("refusal_streak_max", -1) == 3, "SB5A the refusals ran over three frames in a row, got %s" % [stats.get("refusal_streak_max")])
	runner.check(stats.get("depth_max", -1) == 3 and is_equal_approx(stats.get("depth_at_cap_share", -1.0), 1.0 / 3.0) and stats.get("queue_cap", -1) == SimPump.MAX_QUEUED, "SB5A depth 3 reached once in three accepted posts, got %s" % [stats])
	var stopped = _pump("worker")
	stopped.stop()
	runner.check(stopped.has_room() and not stopped.post(_job()) and stopped.queue_stats().get("room_refusals", -1) == 0, "SB5A a stopped pump's refusal is no room refusal")
	var failing = _make(_sim(), "worker", NullJobPump)
	failing.start()
	failing.fail_next = true
	failing.post(_job())
	_idle(failing)
	failing.drain()
	runner.check(not failing.failure().is_empty() and not failing.post(_job()) and failing.queue_stats().get("room_refusals", -1) == 0, "SB5A a failed pump's refusal is no room refusal")
	pump.reset_queue_stats()
	var zero: Dictionary = pump.queue_stats()
	runner.check(zero.get("posts_attempted", -1) == 0 and zero.get("room_refusals", -1) == 0 and zero.get("refusal_streak_max", -1) == 0 and zero.get("depth_max", -1) == 0 and zero.get("depth_at_cap_share", -1.0) == 0.0 and zero.get("queue_cap", -1) == SimPump.MAX_QUEUED, "SB5A reset_queue_stats zeroes the counts and keeps the cap, got %s" % [zero])
	_release(gated.gate, 3)
	_stop_built()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_queue_stats_job_timings(runner) -> bool:
	var pump = _pump("worker")
	for tick in 4:
		var job = _job()
		job.want_digest = tick == 1
		_post_when_room(pump, job)
	_idle(pump)
	OS.delay_msec(20)
	_collect(pump, 4)
	var jobs: Array = pump.queue_stats().get("jobs", [])
	runner.check(jobs.size() == 4, "SB5A every drained job leaves one timing row, got %d" % jobs.size())
	var tags: Array = jobs.map(func(row: Dictionary) -> String: return row.get("tag", ""))
	runner.check(tags == ["plain", "snapshot+digest", "plain", "plain"], "SB5A the row names its job's digest ask, got %s" % [tags])
	var sane: bool = not jobs.is_empty()
	for row: Dictionary in jobs: sane = sane and row.get("job_usec", -1) > 0 and row.get("handoff_usec", -1) >= 0 and row.get("handoff_usec", -1) < row.get("job_usec", -1) and row.get("age_usec", -1) >= 15000
	runner.check(sane, "SB5A a row times the job, its hand-over inside it, and its 20 ms wait for the drain, got %s" % [jobs])
	pump.reset_queue_stats()
	runner.check(pump.queue_stats().get("jobs", [1]).is_empty(), "SB5A a reset forgets the rows")
	_post_when_room(pump, _job())
	_idle(pump)
	pump.reset_queue_stats()
	_collect(pump, 1)
	runner.check(pump.queue_stats().get("jobs", [1]).is_empty(), "SB5A a reset also forgets a job published before it and drained after")
	var inline = _pump("inline")
	inline.post(_job())
	inline.drain()
	runner.check(inline.queue_stats().get("jobs", [1]).is_empty(), "SB5A an inline pump has no worker rows")
	pump.stop()
	return true

func test_sb5a_undrained_notes_bounded(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var pump = _pump("worker")
	runner.check(SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	var accepted: int = 0
	var biggest: int = 0
	var ticks: Array = []
	for frame in 40:
		for step in 8:
			for take in 2:
				if pump.has_room() and pump.post(_job()): accepted += 1
		var notes: Array = pump.drain()
		biggest = maxi(biggest, notes.size())
		ticks.append_array(notes.map(func(note) -> int: return note.tick))
	ticks.append_array(_drain(pump).map(func(note) -> int: return note.tick))
	var sequence: Array = range(1, accepted + 1)
	runner.check(accepted > 0 and ticks == sequence, "SB5A every accepted job drains once, in order (%d accepted, %d drained)" % [accepted, ticks.size()])
	var stats: Dictionary = pump.queue_stats()
	runner.check(stats.get("depth_max", 0) >= 1 and stats.get("depth_max", 0) <= SimPump.MAX_QUEUED, "SB5A the unpublished count never passed the cap, got %s" % [stats.get("depth_max")])
	pump.stop()
	return true

func test_sb5a_worker_runs_off_main(runner) -> bool:
	return _each_mode(runner, _sb5a_worker_runs_off_main)

func _sb5a_worker_runs_off_main(runner, mode: String) -> void:
	var main_id: int = OS.get_thread_caller_id()
	var pump = _make(_sim(), mode, IdPump)
	pump.start()
	for i in 5:
		pump.post(_job())
		_drain(pump)
	var ids: Array[int] = pump.ids
	runner.check(ids.size() == 6 and ids[0] == main_id, "SB5A job zero runs on the caller (%s)" % [ids])
	var later: Array = ids.slice(1)
	if mode == "worker": runner.check(later.all(func(id: int) -> bool: return id != main_id) and later.all(func(id: int) -> bool: return id == later[0]), "SB5A later jobs run on one other thread (%s)" % [ids])
	else: runner.check(later.all(func(id: int) -> bool: return id == main_id), "SB5A inline jobs run on the caller (%s)" % [ids])

func _packed(type: int) -> bool:
	return type >= TYPE_PACKED_BYTE_ARRAY and type < TYPE_MAX

func _foreign(value, path: String, found: Array, seen: Dictionary) -> void:
	match typeof(value):
		TYPE_CALLABLE, TYPE_SIGNAL: found.append(path)
		TYPE_DICTIONARY:
			for key in value:
				_foreign(key, path + ".<key>", found, seen)
				_foreign(value[key], "%s.%s" % [path, key], found, seen)
		TYPE_ARRAY:
			for i in value.size(): _foreign(value[i], "%s[%d]" % [path, i], found, seen)
		TYPE_OBJECT: _foreign_object(value, path, found, seen)

func _foreign_object(value: Object, path: String, found: Array, seen: Dictionary) -> void:
	var rows: bool = value.get_script() == ViewRows
	if not rows and not (value is SimPump.Note or value is SimPump.Slot):
		found.append(path)
		return
	seen["rows" if rows else "owner"] = seen.get("rows" if rows else "owner", 0) + 1
	for property: Dictionary in value.get_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
		if rows and not _packed(property.type): found.append("%s.%s" % [path, property.name])
		else: _foreign(value.get(property.name), "%s.%s" % [path, property.name], found, seen)

func test_sb5a_payload_is_values(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var siege: Dictionary = _siege_pump("worker")
	var pump = siege.pump
	runner.check(SimPump.live_workers() == threads + 1, "SB5A a worker pump keeps its own thread")
	var shot = _shot_note(pump)
	runner.check(shot != null, "SB5A fixture: a shot at a building reaches a note")
	var job = _job([{"type": "stop", "player": 1, "entity_ids": [siege.barracks]}])
	job.want_digest = true
	job.want_ring = true
	job.want_tick_hash = true
	job.want_log = true
	job.want_bot_lines = true
	job.bots.assign([1])
	job.preview = {"player": 1, "builder_id": siege.barracks, "kind": "usa_power_plant", "origin": Vector2i(30, 30)}
	pump.post(job)
	var note = _drain(pump)[0]
	var found: Array = []
	var seen: Dictionary = {}
	_foreign(note, "note", found, seen)
	_foreign(pump.current(), "slot", found, seen)
	runner.check(found.is_empty(), "SB5A a published note and slot hold values only, found %s" % [found.slice(0, 5)])
	runner.check(seen.get("rows", 0) == 1 and seen.get("owner", 0) == 2 and not note.preview.is_empty() and not note.snapshot.is_empty(), "SB5A the walk reached the note, the slot, the per-job rows and the preview and snapshot payloads (%s)" % [seen])
	pump.stop()
	return true

func _release_later(gate: Semaphore, count: int, delay_ms: int) -> void:
	OS.delay_msec(delay_ms)
	_release(gate, count)

func _digest_job():
	var job = _job()
	job.step = false
	job.want_digest = true
	return job

func test_sb5a_query_never_touches_slots(runner) -> bool:
	return _each_mode(runner, _sb5a_query_never_touches_slots)

func _sb5a_query_never_touches_slots(runner, mode: String) -> void:
	var pump = _pump(mode)
	for i in 2: pump.post(_job())
	_drain(pump)
	var current = pump.current()
	var previous = pump.previous()
	pump.post(_job())
	_idle(pump)
	var record: Dictionary = pump.record()
	runner.check(record.tick == 3 and record.digest != "", "SB5A record() answers at the latest tick, got %d" % record.tick)
	runner.check(is_same(pump.current(), current) and is_same(pump.previous(), previous) and current.tick == 2, "SB5A record() leaves CURRENT and PREVIOUS where they were")
	var notes: Array = pump.drain()
	runner.check(notes.size() == 1 and notes[0].tick == 3 and pump.current().tick == 3 and is_same(pump.previous(), current), "SB5A the drain after record() holds the tick job's note only and rotates as without a query")

func test_sb5a_query_waits_behind_jobs(runner) -> bool:
	var gated: Dictionary = _gated()
	var pump = gated.pump
	var shown = pump.current()
	for i in 2: pump.post(_job())
	var releaser := Thread.new()
	releaser.start(_release_later.bind(gated.gate, 2, 150))
	var began: int = Time.get_ticks_msec()
	var note = pump.query(_digest_job())
	var waited: int = Time.get_ticks_msec() - began
	releaser.wait_to_finish()
	runner.check(note != null and note.tick == 2 and waited >= 100, "SB5A a query waits for the two jobs held ahead of it and runs after them (tick %s after %d ms)" % [note.tick if note != null else -1, waited])
	runner.check(note != null and note.digest == StateHash.digest(pump.live().snapshot()), "SB5A the query's digest is the digest after both jobs")
	runner.check(is_same(pump.current(), shown) and shown.tick == 0, "SB5A the query leaves the shown slot")
	var ticks: Array = pump.drain().map(func(row) -> int: return row.tick)
	runner.check(ticks == [1, 2], "SB5A the query's note is not in the drain queue, got %s" % [ticks])
	pump.stop()
	return true

func test_sb5a_record_waits_for_queue(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var gated: Dictionary = _gated()
	var worker = gated.pump
	var inline = _pump("inline")
	var id: int = _own_unit(worker.live())
	_release(gated.gate, 37)
	for i in 40:
		var commands: Array = [_move(id)] if i == 4 or i == 36 else []
		_post_when_room(worker, _job(commands))
		inline.post(_job(commands))
		_drain(inline)
	runner.check(worker.busy(), "SB5A fixture: the last three jobs are held at the gate")
	var releaser := Thread.new()
	releaser.start(_release_later.bind(gated.gate, 3, 150))
	var began: int = Time.get_ticks_msec()
	var waited_for: Dictionary = worker.record()
	var waited: int = Time.get_ticks_msec() - began
	releaser.wait_to_finish()
	var direct: Dictionary = inline.record()
	runner.check(waited >= 100 and not worker.busy(), "SB5A record() waits behind the unpublished jobs (%d ms)" % waited)
	runner.check(waited_for.tick == 40 and waited_for.digest == direct.digest and waited_for.digest != "", "SB5A the record is at tick 40 with the inline digest, got tick %d" % waited_for.tick)
	runner.check(var_to_str(waited_for.commands) == var_to_str(direct.commands) and waited_for.commands.size() == 2 and waited_for.match == direct.match, "SB5A the record's log and match equal the inline record's")
	worker.drain()
	worker.stop()
	runner.check(SimPump.live_workers() == threads, "SB5A stop joins the worker")
	return true

func test_sb5a_query_after_stop_runs_inline(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var pump = _make(_sim(), "worker", IdPump)
	pump.start()
	for i in 2: pump.post(_job())
	_drain(pump)
	pump.stop()
	runner.check(SimPump.live_workers() == threads and pump.failure() == "", "SB5A stop joins the worker and sets no failure")
	var before: int = pump.ids.size()
	var note = pump.query(_digest_job())
	runner.check(note != null and note.tick == 2 and note.digest == StateHash.digest(pump.live().snapshot()), "SB5A a query after stop() answers from the joined simulation")
	runner.check(pump.ids.size() == before + 1 and pump.ids[-1] == OS.get_thread_caller_id(), "SB5A it runs on the caller")
	var record: Dictionary = pump.record()
	runner.check(record.tick == 2 and record.digest == note.digest, "SB5A record() after stop() answers inline too")
	return true

func test_sb5a_query_null_on_failed_pump(runner) -> bool:
	var done: bool = _each_mode(runner, _sb5a_query_null_on_failed_pump)
	_sb5a_query_null_on_stalled_worker(runner)
	SimPump.reset_process_latch_for_test()
	return done

# A stall sets no marker, so only the early return keeps the query from waiting out its deadline.
func _sb5a_query_null_on_stalled_worker(runner) -> void:
	var frames: Array[int] = [1000]
	var now: Array[int] = [50000]
	var gate := Semaphore.new()
	var pump = _make(_sim(), "worker")
	pump.frame_source = func() -> int: return frames[0]
	pump.clock = func() -> int: return now[0]
	pump.start()
	pump.gate_publish_for_test(gate, "before_publish")
	pump.post(_job())
	frames[0] += SimPump.STALL_FRAMES
	now[0] += SimPump.STALL_MSEC
	pump.drain()
	var reason: String = pump.failure()
	runner.check(reason.begins_with("stall"), "SB5A fixture: the held job stalled the pump, got '%s'" % reason)
	var began: int = Time.get_ticks_msec()
	var note = pump.query(_job())
	var took: int = Time.get_ticks_msec() - began
	runner.check(note == null and took < 50 and pump.failure() == reason, "SB5A a query on a stalled pump returns null at once and keeps the reason (%d ms)" % took)
	_release(gate, 1)
	var end: int = Time.get_ticks_msec() + 1500
	while not pump._exited and Time.get_ticks_msec() < end: OS.delay_usec(200)
	_make(_sim(), "inline").start()

func _sb5a_query_null_on_failed_pump(runner, mode: String) -> void:
	var pump = _make(_sim(), mode, NullJobPump)
	pump.start()
	pump.fail_next = true
	pump.post(_job())
	_idle(pump)
	pump.fail_next = false
	pump.drain()
	var reason: String = pump.failure()
	runner.check(reason.begins_with("post job returned no note after tick"), "SB5A fixture: the pump failed, got '%s'" % reason)
	var began: int = Time.get_ticks_msec()
	var note = pump.query(_job())
	var took: int = Time.get_ticks_msec() - began
	runner.check(note == null and took < 50, "SB5A a query on a failed pump returns null at once (%d ms)" % took)
	runner.check(pump.failure() == reason, "SB5A and keeps the first reason, got '%s'" % pump.failure())

func test_sb5a_record_keeps_commands(runner) -> bool:
	return _each_mode(runner, _sb5a_record_keeps_commands)

func _sb5a_record_keeps_commands(runner, mode: String) -> void:
	var pump = _pump(mode)
	var id: int = _own_unit(pump.live())
	var posted: Array = []
	for i in 6:
		pump.post(_job([_move(id)] if i % 2 == 0 else []))
		for note in _drain(pump):
			for row in note.issued:
				if row.ok: posted.append(row.command)
	var record: Dictionary = pump.record()
	runner.check(posted.size() == 3 and record.commands.map(var_to_str) == posted.map(var_to_str), "SB5A the record's log is the posted commands, got %d of %d" % [record.commands.size(), posted.size()])

func test_sb5a_record_on_stalled_worker_is_empty(runner) -> bool:
	var frames: Array[int] = [1000]
	var now: Array[int] = [50000]
	var gate := Semaphore.new()
	var pump = _ran_pump()
	pump.frame_source = func() -> int: return frames[0]
	pump.clock = func() -> int: return now[0]
	var id: int = _own_unit(pump.live())
	pump.gate_publish_for_test(gate, "before_publish")
	pump.post(_job([_move(id)]))
	pump.post(_job())
	_await_ran(pump)
	frames[0] += SimPump.STALL_FRAMES
	now[0] += SimPump.STALL_MSEC
	pump.drain()
	runner.check(pump.failure().begins_with("stall"), "SB5A fixture: the held job stalled the pump, got '%s'" % pump.failure())
	var shown: Dictionary = pump.record()
	runner.check(shown.digest == "" and shown.tick == pump.current().tick and shown.commands.is_empty(), "SB5A record() on a stalled, living worker has no digest and an empty log, got %s" % [shown])
	_release(gate, 2)
	var end: int = Time.get_ticks_msec() + 1500
	while not pump._exited and Time.get_ticks_msec() < end: OS.delay_usec(200)
	var exited: Dictionary = pump.record()
	runner.check(pump._exited and exited.digest == "" and exited.commands.size() == 1, "SB5A once the worker has exited the fallback keeps the log, got %s" % [exited.commands])
	_make(_sim(), "inline").start()
	pump.stop()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_query_null_job_fails_worker_pump(runner) -> bool:
	var pump = _make(_sim(), "worker", NullJobPump)
	pump.start()
	var id: int = _own_unit(pump.live())
	pump.post(_job([_move(id)]))
	_drain(pump)
	pump.fail_next = true
	var began: int = Time.get_ticks_msec()
	var note = pump.query(_job())
	var took: int = Time.get_ticks_msec() - began
	pump.fail_next = false
	runner.check(note == null and took < 50, "SB5A a worker query whose job returns no note answers null at once (%d ms)" % took)
	runner.check(pump.failure().begins_with("query job returned no note after tick") and not pump.post(_job()), "SB5A it fails the pump and later posts are refused, got '%s'" % pump.failure())
	var end: int = Time.get_ticks_msec() + 1500
	while not pump._exited and Time.get_ticks_msec() < end: OS.delay_usec(200)
	var record: Dictionary = pump.record()
	runner.check(pump._exited and record.digest == "" and record.commands.size() == 1, "SB5A the exited worker's log is kept by the fallback, got %s" % [record.commands])
	pump.stop()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_query_behind_a_failing_job_answers_null(runner) -> bool:
	var pump = _ran_pump()
	var gate := Semaphore.new()
	pump.gate_publish_for_test(gate, "before_publish")
	pump.post(_job())
	_await_ran(pump)
	pump.fail_next = true
	pump.post(_job())
	var releaser := Thread.new()
	releaser.start(_release_later.bind(gate, 1, 150))
	var began: int = Time.get_ticks_msec()
	var note = pump.query(_job())
	var took: int = Time.get_ticks_msec() - began
	releaser.wait_to_finish()
	pump.fail_next = false
	runner.check(note == null and took < 2500, "SB5A a query queued behind a job that returns no note answers null without waiting out its deadline (%d ms)" % took)
	runner.check(pump.failure().begins_with("post job returned no note after tick"), "SB5A the failed job's reason stands, got '%s'" % pump.failure())
	pump.stop()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_stop_idle_worker(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var fresh = _pump("worker")
	var used = _pump("worker")
	used.post(_job())
	_drain(used)
	runner.check(SimPump.live_workers() == threads + 2, "SB5A fixture: two worker pumps, one of them has run a job")
	for pump in [fresh, used]:
		var began: int = Time.get_ticks_msec()
		pump.stop()
		var waited: int = Time.get_ticks_msec() - began
		runner.check(pump.failure() == "" and waited < 1000, "SB5A stop wakes an idle worker and joins it at once, no stall (%d ms)" % waited)
	runner.check(SimPump.live_workers() == threads, "SB5A both idle workers are joined")
	return true

func test_sb5a_stop_with_job_in_flight(runner) -> bool:
	for waiting in [0, 2]: _stop_in_flight(runner, waiting)
	return true

func _stop_in_flight(runner, waiting: int) -> void:
	var threads: int = SimPump.live_workers()
	var pump = _ran_pump()
	var gate := Semaphore.new()
	pump.gate_publish_for_test(gate, "before_publish")
	pump.post(_job([_move(_first_mobile(pump.live(), 1))]))
	runner.check(_await_ran(pump), "SB5A fixture: the running job has run and waits at the gate (%d waiting)" % waiting)
	for i in waiting: pump.post(_job())
	var releaser := Thread.new()
	releaser.start(_release_later.bind(gate, 1, 150))
	var began: int = Time.get_ticks_msec()
	pump.stop()
	var waited: int = Time.get_ticks_msec() - began
	releaser.wait_to_finish()
	runner.check(waited >= 100 and waited < SimPump.WAIT_MSEC and pump.failure() == "" and SimPump.live_workers() == threads, "SB5A stop waits for the running job and joins (%d ms, %d waiting)" % [waited, waiting])
	runner.check(not pump.busy() and pump.has_room(), "SB5A a stopped pump owes no jobs, so its count is back at 0 (%d waiting)" % waiting)
	runner.check(pump.live().tick() == 1 and pump.drain().size() == 1, "SB5A the running job finished and published, the %d waiting ones never ran, got tick %d" % [waiting, pump.live().tick()])
	var later = pump.query(_digest_job())
	runner.check(later != null and later.tick == 1 and pump.failure() == "", "SB5A a query after stop runs inline on the joined simulation")
	var record: Dictionary = pump.record()
	runner.check(record.tick == 1 and record.commands.size() == 1 and _replayed_digest(record.commands, record.tick, _sim()) == record.digest, "SB5A the record's log replays to its digest at tick %d" % record.tick)

func _replayed_digest(commands: Array, end_tick: int, sim = null) -> String:
	if sim == null: sim = Skirmish.create(true, "human", {}, Skirmish.MAP_PATH, [] as Array[int])
	for tick in end_tick:
		for command in commands:
			if command.tick == tick: sim.issue_command(command)
		sim.step()
	return StateHash.digest(sim.snapshot())

func test_sb5a_stop_is_idempotent(runner) -> bool:
	var threads: int = SimPump.live_workers()
	for mode in _modes():
		var pump = _pump(mode)
		pump.post(_job())
		_drain(pump)
		pump.stop()
		pump.stop()
		runner.check(SimPump.live_workers() == threads and pump.failure() == "" and not pump.post(_job()), "SB5A stopping twice joins once and leaves no failure [%s]" % mode)
		_built.clear()
	var failing = _make(_sim(), "worker", NullJobPump)
	failing.start()
	failing.fail_next = true
	failing.post(_job())
	_idle(failing)
	failing.drain()
	var reason: String = failing.failure()
	failing.stop()
	failing.stop()
	runner.check(not reason.is_empty() and failing.failure() == reason and SimPump.live_workers() == threads, "SB5A stopping a failed pump twice joins its exited worker and keeps the reason, got '%s'" % failing.failure())
	_built.clear()
	SimPump.new(_sim()).stop()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_stop_reads_failure_marker(runner) -> bool:
	var failing = _make(_sim(), "worker", NullJobPump)
	failing.start()
	failing.fail_next = true
	failing.post(_job())
	_idle(failing)
	failing.stop()
	failing.fail_next = false
	runner.check(not failing.failure().is_empty() and SimPump._latched, "SB5A stop joins a worker that failed and latches the failure, got '%s'" % failing.failure())
	var record: Dictionary = failing.record()
	runner.check(record.digest == "" and record.tick == 0, "SB5A the record of a failed, stopped pump keeps what was last shown and has no digest")
	_built.clear()
	SimPump.reset_process_latch_for_test()
	return true

class NoThreadPump extends "res://tests/failing_pump.gd":
	func _start_thread() -> Error: return ERR_CANT_CREATE

func test_sb5a_thread_start_failure_fails_pump(runner) -> bool:
	var threads: int = SimPump.live_workers()
	var pump = _make(_sim(), "worker", NoThreadPump)
	var began: int = Time.get_ticks_msec()
	pump.start()
	var waited: int = Time.get_ticks_msec() - began
	runner.check(not pump.failure().is_empty() and waited < 1000 and SimPump.live_workers() == threads, "SB5A a thread that cannot start fails the pump at once, no stall (%d ms, '%s')" % [waited, pump.failure()])
	runner.check(not pump.post(_job()) and pump.query(_job()) == null, "SB5A a pump without its thread takes no jobs")
	pump.stop()
	_built.clear()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_stopped_pump_keeps_timing_rows(runner) -> bool:
	var pump = _pump("worker")
	pump.post(_job())
	_idle(pump)
	pump.stop()
	pump.record()
	pump.drain()
	var jobs: Array = pump.queue_stats().get("jobs", [])
	runner.check(jobs.size() == 1 and jobs[0].handoff_usec >= 0, "SB5A an inline record after stop leaves the undrained timing row alone, got %s" % [jobs])
	_built.clear()
	return true

func test_sb5a_owner_marker_stops_the_worker(runner) -> bool:
	var pump = _make(_sim(), "worker", RanPump)
	pump.start()
	while pump.ran.try_wait(): pass
	var gate := Semaphore.new()
	pump.gate_publish_for_test(gate, "before_publish")
	pump.post(_job())
	runner.check(_await_ran(pump), "SB5A fixture: the first job waits at the gate")
	pump.post(_job())
	Engine.print_error_messages = false
	var off_thread = pump._run_owned(_job(), null)
	Engine.print_error_messages = true
	runner.check(off_thread == null, "SB5A fixture: a job run off the owner thread fails")
	_release(gate, 2)
	_idle(pump)
	var first: Array = pump.drain()
	runner.check(pump.failure().begins_with("owner thread") and pump.live().tick() == 1, "SB5A the worker stops at the marker, the queued job never runs (tick %d, '%s')" % [pump.live().tick(), pump.failure()])
	runner.check(pump.drain().is_empty() and first.size() <= 1, "SB5A a failed pump drains nothing more")
	pump.stop()
	_built.clear()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5a_window_end_follows_the_first_tick(runner) -> bool:
	var screen = MatchBenchScreen.new()
	screen.start_tick = BenchLoads.start_tick("team")
	screen._t_first = screen.start_tick + BenchLoads.WARMUP + 1
	runner.check(screen._window_end() - screen._t_first == BenchLoads.WINDOW, "SB5A the window lasts its full length from the first tick a late drain opened it, got %d" % (screen._window_end() - screen._t_first))
	screen.free()
	return true

func test_sb5a_job_zero_null_fails_pump(runner) -> bool:
	var done: bool = _each_mode(runner, _sb5a_job_zero_null_fails_pump)
	SimPump.reset_process_latch_for_test()
	return done

func _sb5a_job_zero_null_fails_pump(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var sim = _sim()
	var pump = _make(sim, mode, NullJobPump)
	pump.fail_next = true
	var note = pump.start()
	runner.check(pump.failure() == "start job returned no note after tick 0", "SB5A a null job zero fails the pump with the null-result cause, got '%s'" % pump.failure())
	runner.check(note != null and note.tick == sim.tick() and note.starts.is_empty(), "SB5A start still returns a readable note at the simulation's tick")
	runner.check(pump.current().tick == sim.tick() and pump.current().view.players.size() == 2 and pump.current().view.has("map"), "SB5A current() is readable at once")
	runner.check(SimPump.live_workers() == threads and not pump.busy() and pump.has_room() and not pump.post(_job()), "SB5A no worker was spawned and later posts are refused")

func _offline_driver() -> RefCounted:
	return OfflineDriver.new(1)

func _online_driver() -> RefCounted:
	var transport := PairTransport.new()
	transport.peer = PairTransport.new()
	var seats: Array[int] = [1, 2]
	return OnlineDriver.new(transport, Lockstep.new(2, seats, 4, 30, Time.get_ticks_usec, {1: [1, 3, 4]}), "china", 2)

# Bot seats give the online world factions, so building it fills the caches; the arguments are read before the caches are cleared.
func _world_args(kind: String) -> Array:
	if kind == "offline": return [Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 7]
	return [MatchSettings.map_path("broken_crown"), MatchSettings.starts("broken_crown", 7, MatchSettings.teams(2, 2)), {3: "china", 4: "frc"}, 7]

func test_sb5a_create_stops_old_pump_first(runner) -> bool:
	runner.check(_caches_fill_on_create(), "SB5A fixture: building a world after clear_test_kinds fills the caches")
	for kind in ["offline", "online"]:
		for mode in _modes():
			var driver = _offline_driver() if kind == "offline" else _online_driver()
			var args: Array = _world_args(kind)
			var spy = _make(_sim(), "inline", StopSpy)
			spy.start()
			driver.pump = spy
			Registry.clear_test_kinds()
			SimPump.force_mode_for_test(mode)
			driver.callv("create", args)
			SimPump.force_mode_for_test("")
			runner.check(spy.caches_empty_at_stop and not is_same(driver.pump, spy), "SB5A the %s create stops the old pump before the new simulation is built [%s]" % [kind, mode])
			driver.stop()
			_stop_built()
	return true

func _caches_fill_on_create() -> bool:
	Registry.clear_test_kinds()
	_sim()
	var filled: bool = not Registry.cache_keys().values().all(func(keys: Array) -> bool: return keys.is_empty())
	Registry.clear_test_kinds()
	return filled

func test_sb5a_restart_drops_old_notes(runner) -> bool:
	for mode in _modes():
		_restart_offline(runner, mode)
		_restart_online(runner, mode)
	return true

func _restart_offline(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var driver = _offline_driver()
	SimPump.force_mode_for_test(mode)
	driver.create(Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 0)
	var old = driver.pump
	for i in 3:
		driver.step()
		_idle(old)
	runner.check(old.live().tick() == 3, "SB5A fixture: three offline notes wait undrained [%s]" % mode)
	driver.create(Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 0)
	SimPump.force_mode_for_test("")
	runner.check(not is_same(driver.pump, old) and driver.drain().is_empty() and driver.current().tick == 0, "SB5A an offline restart reaches none of the old notes [%s]" % mode)
	runner.check(SimPump.live_workers() == threads + (1 if mode == "worker" else 0), "SB5A the old offline worker was joined at the restart [%s]" % mode)
	driver.stop()

func test_sb5a_job_timing_rows_edges(runner) -> bool:
	var pump = _pump("worker")
	for tick in 3: _post_when_room(pump, _job())
	_idle(pump)
	var query = _job()
	query.step = false
	runner.check(pump.query(query) != null, "SB5A fixture: a query between published jobs and their drain is answered")
	_collect(pump, 3)
	var jobs: Array = pump.queue_stats().get("jobs", [])
	var intact: bool = jobs.size() == 3
	for row: Dictionary in jobs: intact = intact and row.get("handoff_usec", -1) >= 0
	runner.check(intact, "SB5A a query leaves the published rows alone, got %s" % [jobs])
	pump.reset_queue_stats()
	var posted: int = 0
	var end: int = Time.get_ticks_msec() + 60000
	while posted < SimPump.TIMING_CAP + 20 and Time.get_ticks_msec() < end:
		if pump.has_room() and pump.post(_job()): posted += 1
		pump.drain()
	_drain(pump)
	var rows: int = pump.queue_stats().get("jobs", []).size()
	runner.check(posted == SimPump.TIMING_CAP + 20 and rows == SimPump.TIMING_CAP, "SB5A the rows stop at the cap (%d posted, %d rows)" % [posted, rows])
	pump.stop()
	return true

func test_sb5a_offline_digest_every_and_bots(runner) -> bool:
	return _each_mode(runner, _sb5a_offline_digest_every_and_bots)

func _sb5a_offline_digest_every_and_bots(runner, mode: String) -> void:
	var asked: Array[int] = []
	var bot_orders: Array[int] = []
	for bots: Array[int] in [[2] as Array[int], [] as Array[int]]:
		var driver = _offline_driver()
		SimPump.force_mode_for_test(mode)
		driver.create(Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 0)
		SimPump.force_mode_for_test("")
		driver.bots = bots
		driver.digest_every = 5 if bots.size() == 1 else 0
		var orders: int = 0
		for tick in 12:
			driver.step()
			_idle(driver.pump)
			for note in driver.drain():
				orders += note.bot_commands.size()
				if not note.digest.is_empty(): asked.append(note.tick)
		bot_orders.append(orders)
		runner.check(driver.bot_players() == bots, "SB5A bot_players names the seats the job plans, got %s for %s" % [driver.bot_players(), bots])
		driver.stop()
	runner.check(asked == [5, 10], "SB5A digest_every asks a snapshot and digest on its multiples only, and 0 asks none, got %s [%s]" % [asked, mode])
	runner.check(bot_orders[0] > 0 and bot_orders[1] == 0, "SB5A the driver's bots decide the seats the job names, got %s [%s]" % [bot_orders, mode])

func _restart_online(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 12)
	for i in 3:
		_take_one(driver)
		_idle(driver.pump)
	var logged: int = driver._lockstep.command_log().size()
	SimPump.force_mode_for_test(mode)
	driver.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
	SimPump.force_mode_for_test("")
	runner.check(driver.drain().is_empty() and driver.current().tick == 0 and driver._lockstep.command_log().size() == logged, "SB5A an online rematch reaches none of the old notes and logs none of their commands [%s]" % mode)
	runner.check(SimPump.live_workers() == threads + (1 if mode == "worker" else 0), "SB5A the old online worker was joined at the rematch [%s]" % mode)
	driver.stop()

# Seat 2's driver, fed by a scripted seat 1 that moves one of its units at move_tick; its faction exists from tick 5, so the move is written once the unit does.
func _lone_online(mode: String, move_tick: int, kind = SimPump, bad_hash_tick: int = -1) -> Dictionary:
	var seat: Dictionary = _seat_two(mode, kind)
	var driver = seat.driver
	driver.start()
	_seat_one_packets(seat.transport, 4, move_tick - 1, -1, -1)
	_frames_to(driver, 8)
	_seat_one_packets(seat.transport, move_tick, 60, move_tick, _first_mobile(driver.pump.live(), 1), bad_hash_tick)
	return seat

# Seat 2's driver before start(); a pump kind other than SimPump replaces the one create() made, zero_fails makes its job zero return null.
func _seat_two(mode: String, kind = SimPump, zero_fails: bool = false) -> Dictionary:
	var transport := RelayEnd.new()
	transport.seat = 2
	transport.peer = RelayEnd.new()
	SimPump.force_mode_for_test(mode)
	var driver = OnlineDriver.new(transport, Lockstep.new(2, [1, 2] as Array[int]), "china", 2)
	driver.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
	SimPump.force_mode_for_test("")
	if kind != SimPump: _swap_pump(driver, mode, kind, zero_fails)
	return {"driver": driver, "transport": transport}

func _swap_pump(driver, mode: String, kind, zero_fails: bool = false) -> void:
	driver.pump.stop()
	var pump = _make(driver.pump.live(), mode, kind)
	if zero_fails: pump.fail_next = true
	driver._last = pump.start()
	driver.pump = pump

# The pump holds every job unpublished (worker) or counts every undrained note (inline) until three are in.
func _hold_pump(driver, mode: String) -> Semaphore:
	driver.pump.cap_for_test(SimPump.MAX_QUEUED)
	return _gate_worker(driver, mode)

func _seat_one_packets(transport, from_tick: int, to_tick: int, move_tick: int, unit: int, bad_hash_tick: int = -1) -> void:
	for tick in range(from_tick, to_tick + 1):
		var commands: Array = []
		if tick == 4: commands.append({"type": "choose_faction", "faction": "usa", "tick": 4, "player": 1, "sequence": 0})
		if tick == move_tick: commands.append(_move(unit).merged({"tick": tick, "sequence": 1}))
		var hash_entry: Variant = {"tick": tick - 4, "value": "0000000000000000"} if tick == bad_hash_tick else null
		transport.inbox.append(Wire.encode(Wire.tick_message(1, tick, commands, hash_entry)))

func _first_mobile(sim, owner: int) -> int:
	for entity in sim.snapshot().entities:
		if entity.owner == owner and Registry.units().has(entity.kind): return entity.id
	return -1

# One tick per call, so a case knows how many jobs it has posted.
func _take_one(driver) -> void:
	driver._credit = 0
	driver.step()

func _frames_to(driver, tick: int) -> void:
	var frames: int = 0
	while driver.get("_next_tick") < tick and frames < 200:
		frames += 1
		_take_one(driver)
		_idle(driver.pump)
		driver.drain()

func _logged_commands(driver) -> Array:
	var commands: Array = []
	for line in driver.match_log().commands: commands.append_array(Wire.decode(line).message.commands)
	return commands

# The worker has popped the gated job (it runs it to the gate), so a stop cannot drop it as a waiting one.
func _await_popped(driver, mode: String) -> bool:
	if mode != "worker": return true
	var pump = driver.pump
	var end: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < end:
		pump._mutex.lock()
		var popped: bool = pump._queue.is_empty()
		pump._mutex.unlock()
		if popped: return true
		OS.delay_usec(200)
	return false

func _gate_worker(driver, mode: String) -> Semaphore:
	if mode != "worker": return null
	var gate := Semaphore.new()
	driver.pump.gate_publish_for_test(gate, "before_publish")
	return gate

func _release_in_background(gate: Semaphore) -> Thread:
	if gate == null: return null
	var releaser := Thread.new()
	releaser.start(_release_later.bind(gate, 3, 150))
	return releaser

func _join_releaser(releaser: Thread) -> void:
	if releaser != null: releaser.wait_to_finish()

func test_sb5a_leave_record_replays(runner) -> bool:
	for mode in _modes(): _leave_record(runner, mode)
	return true

func _leave_record(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 12)
	_take_one(driver)
	_idle(driver.pump)
	var gate: Semaphore = _gate_worker(driver, mode)
	_take_one(driver)
	runner.check(_await_popped(driver, mode), "SB5A fixture: the worker holds the gated job [%s]" % mode)
	_take_one(driver)
	var peer: int = online.transport.peer.inbox.size()
	var others: int = online.transport.others.size()
	driver.leave()
	var releaser: Thread = _release_in_background(gate)
	driver.stop()
	_join_releaser(releaser)
	var record: Dictionary = driver.record()
	var commands: Array = _logged_commands(driver)
	runner.check(commands.any(func(command: Dictionary) -> bool: return command.type == "move" and command.tick == 12), "SB5A the leave's saved log holds the move of the completed, undrained job [%s]" % mode)
	runner.check(record.tick == (14 if mode == "worker" else 15), "SB5A the record ends at the last completed job, the waiting one never ran, got tick %d [%s]" % [record.tick, mode])
	runner.check(_replayed_digest(commands, record.tick) == record.digest, "SB5A the saved log replays to the record's end digest [%s]" % mode)
	runner.check(online.transport.peer.inbox.size() == peer and online.transport.others.size() == others, "SB5A no frame is sent after the leave [%s]" % mode)
	runner.check(SimPump.live_workers() == threads, "SB5A the leave joined the worker [%s]" % mode)

func test_sb5a_end_record_replays(runner) -> bool:
	for mode in _modes():
		for how in ["relay", "protocol"]: _end_record(runner, mode, how)
	return true

func _end_record(runner, mode: String, how: String) -> void:
	var threads: int = SimPump.live_workers()
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 12)
	var gate: Semaphore = _gate_worker(driver, mode)
	_take_one(driver)
	runner.check(_await_popped(driver, mode), "SB5A fixture: the worker holds the job at the end (%s end, %s)" % [how, mode])
	if how == "relay": driver._lockstep.set_relay_lost()
	else: driver._lockstep.set_protocol_error("probe")
	var releaser: Thread = _release_in_background(gate)
	driver.drain()
	_join_releaser(releaser)
	var label: String = "%s end, %s" % [how, mode]
	var record: Dictionary = driver.record()
	var commands: Array = _logged_commands(driver)
	runner.check(driver.over() and driver._lockstep.status().begins_with("ended"), "SB5A fixture: the %s ended the lockstep and the driver" % label)
	runner.check(commands.any(func(command: Dictionary) -> bool: return command.type == "move" and command.tick == 12) and record.tick == 13, "SB5A the log holds the move of the job that was still running at the end, record tick %d (%s)" % [record.tick, label])
	runner.check(_replayed_digest(commands, record.tick) == record.digest, "SB5A the saved log replays to the record's end digest (%s)" % label)
	driver.stop()
	runner.check(SimPump.live_workers() == threads, "SB5A the end joined the worker (%s)" % label)

func test_sb5a_full_pump_leaves_next_tick_in_lockstep(runner) -> bool:
	return _each_mode(runner, _sb5a_full_pump_leaves_next_tick)

func _sb5a_full_pump_leaves_next_tick(runner, mode: String) -> void:
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 12)
	var gate: Semaphore = _hold_pump(driver, mode)
	driver._credit = 4
	driver.step()
	driver._credit = 3
	driver.step()
	runner.check(not driver.pump.has_room(), "SB5A fixture: three jobs fill the pump")
	runner.check(driver.get("_next_tick") == 15 and driver.get("_taken") == [12, 13, 14], "SB5A a full pump leaves tick 15 in the lockstep, taken %s next %d" % [driver.get("_taken"), driver.get("_next_tick")])
	runner.check(driver.failure().is_empty() and driver._lockstep.status() == "running" and not driver.over(), "SB5A a full pump is no failure and ends nothing, got '%s' status %s" % [driver.failure(), driver._lockstep.status()])
	runner.check(driver._credit == 3 and driver._lockstep.can_step(15), "SB5A the credit is earned and not spent, and the lockstep still holds tick 15, credit %d" % driver._credit)
	if gate != null: _release(gate, 4)
	_idle(driver.pump)
	driver.drain()
	_take_one(driver)
	_idle(driver.pump)
	driver.drain()
	runner.check(driver.get("_next_tick") == 16 and driver.current().tick == 16 and online.transport.order._last == 20, "SB5A the next frame takes tick 15 and pairs it as the note of tick 16, next %d shown %d sent %d" % [driver.get("_next_tick"), driver.current().tick, online.transport.order._last])
	driver.stop()

func test_sb5a_preview_waits_for_room(runner) -> bool:
	return _each_mode(runner, _sb5a_preview_waits_for_room)

func _sb5a_preview_waits_for_room(runner, mode: String) -> void:
	var online: Dictionary = _lone_online(mode, 12, PostSpy)
	var driver = online.driver
	var spy = driver.pump
	_frames_to(driver, 12)
	var request := {"player": 2, "builder_id": _first_mobile(spy.live(), 2), "kind": "usa_power_plant", "origin": Vector2i(14, 14)}
	driver.request_preview(request)
	var gate: Semaphore = _hold_pump(driver, mode)
	spy.previews.clear()
	driver._credit = 4
	driver.step()
	driver._credit = 3
	driver.step()
	runner.check(spy.previews.size() == 3 and spy.previews.all(func(preview: Dictionary) -> bool: return preview == request), "SB5A every accepted job of the catch-up carries the request, and the frame that ran out of room builds none, got %d jobs" % spy.previews.size())
	if gate != null: _release(gate, 4)
	_idle(driver.pump)
	driver.drain()
	_take_one(driver)
	runner.check(spy.previews.size() == 4 and spy.previews[3] == request and driver.get("_preview_request") == request, "SB5A the next frame's first job carries the kept request, got %d jobs" % spy.previews.size())
	driver.stop()

func test_sb5a_two_notes_one_frame_pair_in_order(runner) -> bool:
	return _each_mode(runner, _sb5a_two_notes_one_frame)

func _sb5a_two_notes_one_frame(runner, mode: String) -> void:
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 12)
	driver._credit = 4
	driver.step()
	_idle(driver.pump)
	var notes: Array = driver.drain()
	var inbox: PackedStringArray = online.transport.peer.inbox
	var sent: Array = Array(inbox.slice(inbox.size() - 2)).map(func(text: String) -> int: return Wire.decode(text).message.tick)
	runner.check(notes.map(func(note) -> int: return note.tick) == [13, 14], "SB5A two jobs of one frame come back in post order, got %s" % [notes.map(func(note) -> int: return note.tick)])
	runner.check(notes.size() == 2 and notes[0].issued.any(func(entry: Dictionary) -> bool: return entry.command.type == "move") and notes[1].issued.is_empty(), "SB5A each note carries its own issued commands")
	runner.check(sent == [17, 18] and driver.get("_taken").is_empty(), "SB5A the two frames go out as ticks 17 and 18, got %s" % [sent])
	driver.stop()

func test_sb5a_hash_tick_note_carries_digest(runner) -> bool:
	return _each_mode(runner, _sb5a_hash_tick_note)

func _sb5a_hash_tick_note(runner, mode: String) -> void:
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 29)
	driver._credit = 4
	driver.step()
	_idle(driver.pump)
	var notes: Array = driver.drain()
	var inbox: PackedStringArray = online.transport.peer.inbox
	var frame: Dictionary = Wire.decode(inbox[inbox.size() - 2]).message
	runner.check(notes.size() == 2 and notes[0].tick == 30 and not notes[0].digest.is_empty() and notes[1].digest.is_empty(), "SB5A fixture: ticks 30 and 31 in one drain, only tick 30 asked for a digest")
	runner.check(frame.tick == 34 and frame.get("hash", {}).get("tick", -1) == 30 and frame.hash.value == notes[0].digest, "SB5A the frame names tick 30's own digest, got %s" % [frame.get("hash")])
	runner.check(frame.get("hash", {}).get("value", "") != StateHash.digest(driver.pump.live().snapshot()) and driver._lockstep.hash_rows()[-1] == "30\t" + notes[0].digest, "SB5A the digest is not the shown tick's")
	driver.stop()

func test_sb5a_failure_between_room_and_post(runner) -> bool:
	if not OS.has_feature("threads"): return true
	var online: Dictionary = _lone_online("worker", 12, NullJobPump)
	var driver = online.driver
	_frames_to(driver, 12)
	driver.pump.fail_next = true
	_take_one(driver)
	_idle(driver.pump)
	runner.check(driver.pump.has_room() and driver.pump.failure().is_empty() and not driver.pump.busy(), "SB5A fixture: the marker is queued and main has not read it")
	_take_one(driver)
	var reason: String = driver._lockstep.end_reason()
	runner.check(driver._lockstep.status() == "ended_protocol" and reason.begins_with("sim pump failed: post job returned no note"), "SB5A a marker met inside post ends the lockstep with the pump's reason, got %s '%s'" % [driver._lockstep.status(), reason])
	runner.check(online.transport.closes == 1, "SB5A the transport closes in the frame of the failure, got %d closes" % online.transport.closes)
	runner.check(not driver.failure().is_empty() and driver.failure() == driver.pump.failure(), "SB5A the driver reports the pump's failure, got '%s'" % driver.failure())
	driver.stop()
	return true

func test_sb5a_online_failure_ends_and_closes(runner) -> bool:
	return _each_mode(runner, _sb5a_online_failure_ends_and_closes)

func _sb5a_online_failure_ends_and_closes(runner, mode: String) -> void:
	var pair: Dictionary = _pair_drivers(mode)
	var one = pair.drivers[0]
	var two = pair.drivers[1]
	for transport in pair.transports: transport.tell_peer = true
	_frames(pair.drivers, 40, 0)
	_swap_pump(one, mode, NullJobPump)
	one.pump.fail_next = true
	var frames: int = 0
	while frames < 60 and not two._lockstep.status().begins_with("ended"):
		frames += 1
		_cycle(one)
		_cycle(two)
	var reason: String = one._lockstep.end_reason()
	runner.check(one._lockstep.status() == "ended_protocol" and reason.begins_with("sim pump failed: "), "SB5A the failing seat ends with the pump's reason, got %s '%s'" % [one._lockstep.status(), reason])
	runner.check(not one.failure().is_empty() and one.failure() == one.pump.failure() and one.over(), "SB5A the driver reports the failure and is over, got '%s'" % one.failure())
	runner.check(pair.transports[0].closes >= 1, "SB5A the failing seat closes its transport")
	runner.check(two._lockstep.status() == "ended_left" and two._lockstep.opponent_left() and two.rematch_line() == "P1 USA left the match", "SB5A the peer reads the relay's left frame, got %s '%s'" % [two._lockstep.status(), two.rematch_line()])
	var overs: Array = []
	for transport in pair.transports: overs.append_array(transport.others.filter(func(text: String) -> bool: return Wire.decode(text).message.type == "over"))
	runner.check(overs.is_empty(), "SB5A no seat reports a result")
	_unpair(pair)

func test_sb5a_relay_loss_and_pump_failure_same_frame(runner) -> bool:
	return _each_mode(runner, _sb5a_relay_loss_and_pump_failure)

func _sb5a_relay_loss_and_pump_failure(runner, mode: String) -> void:
	for first in ["relay", "failure"]:
		var label: String = "%s seen first [%s]" % [first, mode]
		var online: Dictionary = _lone_online(mode, 12, NullJobPump)
		var driver = online.driver
		_frames_to(driver, 12)
		driver.pump.fail_next = true
		driver.pump.post(SimPump.Job.new())
		_idle(driver.pump)
		if first == "relay":
			online.transport.gone = true
			driver.step()
			driver.drain()
		else:
			driver.drain()
			runner.check(driver._lockstep.end_reason().begins_with("sim pump failed: ") and online.transport.closes >= 1, "SB5A the failure read ends the match and closes in its own frame (%s)" % label)
			online.transport.gone = true
			driver.step()
			driver.drain()
		var expected: String = "connection to relay lost" if first == "relay" else "sim pump failed: "
		runner.check(driver._lockstep.end_reason().begins_with(expected), "SB5A the first end stands, got '%s' (%s)" % [driver._lockstep.end_reason(), label])
		runner.check(online.transport.closes >= 1 and not driver.failure().is_empty() and driver.failure() == driver.pump.failure(), "SB5A the transport is closed and the failure is known (%s)" % label)
		driver.stop()

func test_sb5a_job_zero_null_ends_online_match(runner) -> bool:
	return _each_mode(runner, _sb5a_job_zero_null_ends_online_match)

func _sb5a_job_zero_null_ends_online_match(runner, mode: String) -> void:
	var seat: Dictionary = _seat_two(mode, NullJobPump, true)
	var driver = seat.driver
	runner.check(driver.pump.failure().begins_with("start job returned no note") and driver.current().tick == 0, "SB5A fixture: job zero returned null and the pump is readable")
	driver.start()
	runner.check(driver._lockstep.status() == "ended_protocol" and driver._lockstep.end_reason().begins_with("sim pump failed: start job returned no note"), "SB5A a null job zero ends the online match before any packet, got %s '%s'" % [driver._lockstep.status(), driver._lockstep.end_reason()])
	runner.check(seat.transport.order._last == 0 and seat.transport.peer.inbox.is_empty() and seat.transport.others.is_empty(), "SB5A no packet is sent")
	driver.stop()

func test_sb5a_pairing_rejects_foreign_note(runner) -> bool:
	return _each_mode(runner, _sb5a_pairing_rejects_foreign_note)

func _sb5a_pairing_rejects_foreign_note(runner, mode: String) -> void:
	var online: Dictionary = _lone_online(mode, 12)
	var driver = online.driver
	_frames_to(driver, 12)
	var logged: int = driver._lockstep.command_log().size()
	var sent: int = online.transport.order._last
	runner.check(driver.get("_taken").is_empty(), "SB5A fixture: nothing is taken")
	driver.pump.post(SimPump.Job.new())
	_idle(driver.pump)
	driver.drain()
	runner.check(driver._lockstep.status() == "ended_protocol", "SB5A a note that advanced with nothing taken ends the match, got %s" % driver._lockstep.status())
	runner.check(driver._lockstep.command_log().size() == logged and online.transport.order._last == sent, "SB5A nothing is recorded or sent for it")
	driver.stop()

func test_sb5a_notice_waiting_empty(runner) -> bool:
	var seat: Dictionary = _seat_two("inline")
	var driver = seat.driver
	driver.start()
	_seat_one_packets(seat.transport, 4, 20, -1, -1)
	_frames_to(driver, 40)
	runner.check(driver._lockstep.status() == "waiting" and driver._lockstep.waiting_for() == [1], "SB5A fixture: the lockstep waits for seat 1")
	driver._lockstep.receive(Wire.encode({"type": "left", "seat": 1, "after_tick": 20}))
	runner.check(driver._lockstep.status() == "waiting" and driver._lockstep.waiting_for().is_empty(), "SB5A fixture: the leave leaves the status waiting and nobody to wait for")
	runner.check(driver.notice() == "", "SB5A the notice names nobody and raises no error, got '%s'" % driver.notice())
	driver.stop()
	return true

func test_sb5a_play_on_leave_with_jobs_in_flight(runner) -> bool:
	for leaver in [2, 3]:
		var results: Dictionary = {}
		for mode in _modes(): results[mode] = _leave_in_flight(mode, leaver)
		var inline: Dictionary = results.inline
		runner.check(inline.status == ("running" if leaver == 2 else "ended_left") and inline.left == leaver, "SB5A the inline reference: seat %d leaving gives %s" % [leaver, inline])
		for mode in results: runner.check(results[mode] == inline, "SB5A seat %d leaving with jobs in flight gives the inline result [%s], got %s against %s" % [leaver, mode, results[mode], inline])
	for defeated in [false, true]:
		var results: Dictionary = {}
		for mode in _modes(): results[mode] = _host_leave_in_flight(mode, defeated)
		var inline: Dictionary = results.inline
		runner.check(inline.pending == "running" and inline.status == "ended_left" and inline.left == 1, "SB5A the inline reference: the verdict waits for the notes in flight, then a host with bots alive leaving ends the match (defeated %s), got %s" % [defeated, inline])
		for mode in results: runner.check(results[mode] == inline, "SB5A the host leaving with bots alive and jobs in flight gives the inline result [%s] (defeated %s), got %s against %s" % [mode, defeated, results[mode], inline])
	return true

# The guest has jobs taken and undrained when the host's leave arrives; the host's bots 3 and 4 are alive.
func _host_leave_in_flight(mode: String, host_defeated: bool) -> Dictionary:
	var pair: Dictionary = _quad_drivers(4, mode)
	var host = pair.drivers[0]
	var guest = pair.drivers[1]
	_trio_until(pair.drivers, 40, true)
	if host_defeated:
		for driver in pair.drivers: SeatFixture.defeat(driver.pump.live(), 1)
	var a: int = host._transport.order._last
	pair.transports[1].inbox.append(Wire.encode({"type": "left", "seat": 1, "after_tick": a}))
	for guard in 30:
		if guest.current().tick >= a - 1: break
		_single(guest)
	var gate: Semaphore = _gate_worker(guest, mode)
	for i in 2:
		guest._credit = 4
		guest.step()
	var pending: String = guest._lockstep.status()
	if gate != null: _release(gate, 4)
	_idle(guest.pump)
	guest.drain()
	for guard in 30:
		if guest.over() or guest._lockstep.status().begins_with("ended"): break
		_single(guest)
	var result := {"pending": pending, "status": guest._lockstep.status(), "tick": guest.current().tick, "left": guest._lockstep.left_seat()}
	_unpair(pair)
	return result

func test_sb5a_worker_host_bot_frames(runner) -> bool:
	var runs: Dictionary = {}
	for mode in _modes():
		runs[mode] = _host_bot_run(mode, false)
		_stop_built()
	var inline: Dictionary = runs.inline
	var bot_ticks: Array = inline.host.filter(func(m: Dictionary) -> bool: return m.player > 2).map(func(m: Dictionary) -> int: return m.tick)
	runner.check(not bot_ticks.is_empty() and bot_ticks.min() > 33 and not inline.ended, "SB5A fixture: the host's bots order after empty decisions, first at %s, ended %s" % [bot_ticks.min() if not bot_ticks.is_empty() else -1, inline.ended])
	for mode in runs:
		var run: Dictionary = runs[mode]
		runner.check(run.sent == inline.sent, "SB5A the host's packet ticks equal inline [%s], got %s against %s" % [mode, run.sent, inline.sent])
		runner.check(run.host == inline.host and run.guest == inline.guest, "SB5A packet ticks, players, sequences and command logs equal inline on both seats [%s]" % mode)
		runner.check(run.rows == inline.rows and run.peers_equal and not run.ended, "SB5A the peer hashes equal inline and each other [%s], ended %s" % [mode, run.ended])
	return true

func test_sb5a_human_order_in_held_window_leads_the_bots(runner) -> bool:
	for mode in _modes():
		var run: Dictionary = _host_bot_run(mode, true)
		_stop_built()
		var by_tick: Dictionary = {}
		for command: Dictionary in run.host: by_tick.get_or_add(command.tick, []).append(command.player)
		var shared: Array = by_tick.values().filter(func(players: Array) -> bool: return players.has(1) and players.any(func(player: int) -> bool: return player > 2))
		runner.check(not shared.is_empty(), "SB5A fixture: a frame holds a human order and bot orders [%s]" % mode)
		runner.check(shared.all(func(players: Array) -> bool: return players.slice(0, players.find(1)).all(func(player: int) -> bool: return player <= 2)), "SB5A the human order leads the bot orders in its open frame [%s], got %s" % [mode, shared])
		runner.check(run.peers_equal and not run.ended, "SB5A the peer hashes stay equal [%s], ended %s" % [mode, run.ended])
	return true

# Seat one takes two ticks per round and drains both at once; a human order goes in at a drain boundary, or inside the held window.
func _host_bot_run(mode: String, in_window: bool) -> Dictionary:
	var pair: Dictionary = _quad_drivers(4, mode)
	var host = pair.drivers[0]
	var guest = pair.drivers[1]
	_trio_until(pair.drivers, 33, true)
	var unit: int = _own_unit(host.pump.live())
	var gate: Semaphore = _gate_worker(host, mode)
	var sent: Array = []
	for frame in 80:
		host._credit = 1
		host.step()
		if in_window: host.submit(_move(unit))
		if gate != null: _release(gate, host._taken.size())
		_idle(host.pump)
		host.drain()
		if not in_window and frame % 4 == 0: host.submit(_move(unit))
		_cycle(guest)
		sent.append(host._transport.order._last)
	var rows: PackedStringArray = host._lockstep.hash_rows()
	var other: PackedStringArray = guest._lockstep.hash_rows()
	var common: int = mini(rows.size(), other.size())
	var result := {"host": host._lockstep.command_log(), "guest": guest._lockstep.command_log(), "sent": sent, "rows": rows.slice(0, common), "peers_equal": common >= 4 and rows.slice(0, common) == other.slice(0, common), "ended": _ended_any(pair.drivers)}
	_unpair(pair)
	return result

# Seat one has three jobs taken and undrained when the leave's turn comes, so its verdict waits for the drain.
func _leave_in_flight(mode: String, leaver: int) -> Dictionary:
	var trio: Dictionary = _trio_drivers(mode)
	var one = trio.drivers[0]
	var other = trio.drivers[2] if leaver == 2 else trio.drivers[1]
	var other_seat: int = 3 if leaver == 2 else 2
	_trio_until(trio.drivers, 40)
	var a: int = _last_sent(trio, leaver)
	trio.relay.leave(leaver, a)
	for guard in 30:
		if one.current().tick >= a - 2: break
		_single(one)
	for guard in 30:
		if _last_sent(trio, other_seat) > a + 1: break
		_single(other)
	var gate: Semaphore = _gate_worker(one, mode)
	for i in 2:
		one._credit = 4
		one.step()
	if gate != null: _release(gate, 4)
	_idle(one.pump)
	one.drain()
	_single(one)
	var result := {"status": one._lockstep.status(), "tick": one.current().tick, "left": one._lockstep.left_seat()}
	_trio_done(trio)
	return result

func test_sb5a_ring_may_trail_desync_tick(runner) -> bool:
	return _each_mode(runner, _sb5a_ring_may_trail_desync_tick)

func _sb5a_ring_may_trail_desync_tick(runner, mode: String) -> void:
	var online: Dictionary = _lone_online(mode, 12, SimPump, 34)
	var driver = online.driver
	var downloads: Array = []
	driver.web = true
	driver.download = func(buffer: PackedByteArray, _file_name: String, _mime: String) -> void: downloads.append(buffer)
	for i in 60:
		_take_one(driver)
		_idle(driver.pump)
		driver.drain()
		if driver.over(): break
	var report = JSON.parse_string(downloads[0].get_string_from_utf8()) if downloads.size() == 1 else null
	runner.check(driver._lockstep.status() == "ended_desync" and report is Dictionary, "SB5A fixture: a wrong hash at tick 30 ends the match with one report")
	if not report is Dictionary:
		driver.stop()
		return
	var rows: Array = report.get("hash_ring", [])
	runner.check(int(report.tick) == 30 and rows.any(func(row: String) -> bool: return row.begins_with("30\t")), "SB5A the report names tick 30 and its ring has that row, got tick %s" % report.tick)
	runner.check(not rows.is_empty() and int(rows[-1].split("\t")[0]) > 30, "SB5A the ring may run past the desync tick, the rows are labelled")
	var record: Dictionary = driver.record()
	runner.check(_replayed_digest(_logged_commands(driver), record.tick) == record.digest, "SB5A the saved record's log replays to its end digest")
	driver.stop()

func test_sb5a_report_survives_failed_query(runner) -> bool:
	if not OS.has_feature("threads"): return true
	var online: Dictionary = _lone_online("worker", 12, NullJobPump, 34)
	var driver = online.driver
	var downloads: Array = []
	driver.web = true
	driver.download = func(buffer: PackedByteArray, _file_name: String, _mime: String) -> void: downloads.append(buffer)
	_frames_to(driver, 34)
	driver.pump.fail_next = true
	driver.pump.post(SimPump.Job.new())
	_idle(driver.pump)
	_take_one(driver)
	driver.drain()
	var report = JSON.parse_string(downloads[0].get_string_from_utf8()) if downloads.size() == 1 else null
	runner.check(driver._lockstep.status() == "ended_desync" and driver.pump.failure() != "" and report is Dictionary, "SB5A fixture: a pump marker and a desync meet in one drain, got %s '%s'" % [driver._lockstep.status(), driver.pump.failure()])
	runner.check(report is Dictionary and report.has("hash_ring") and report.hash_ring.is_empty(), "SB5A the report of a failed query writes an empty ring")
	driver.stop()
	return true

func test_sb5a_suspend_is_no_stall(runner) -> bool:
	if not OS.has_feature("threads"): return true
	var frames: Array[int] = [1000]
	var now: Array[int] = [50000]
	var gate := Semaphore.new()
	var pump = _make(_sim(), "worker")
	pump.frame_source = func() -> int: return frames[0]
	pump.clock = func() -> int: return now[0]
	pump.start()
	pump.gate_publish_for_test(gate, "before_publish")
	pump.post(_job())
	frames[0] += 2 * SimPump.STALL_FRAMES
	now[0] += 2 * SimPump.STALL_MSEC
	gate.post()
	var notes: Array = _drain(pump)
	runner.check(notes.size() == 1 and pump.failure().is_empty(), "SB5A a note finished while the app was suspended is drained, no stall, got %d notes '%s'" % [notes.size(), pump.failure()])
	pump.stop()
	return true

const LOCK_HOLD_MS: int = 150

# Runs on a helper thread and touches only the gate: after main's signal it holds the gate for LOCK_HOLD_MS, then posts it and returns the usec stamp taken just before the post.
func _release_after(gate: Semaphore, called: Semaphore) -> int:
	var end: int = Time.get_ticks_msec() + 10000
	while not called.try_wait() and Time.get_ticks_msec() < end: OS.delay_usec(500)
	OS.delay_msec(LOCK_HOLD_MS)
	var stamp: int = Time.get_ticks_usec()
	gate.post()
	return stamp

func _await_arrival(pump, limit_ms: int = 1500) -> bool:
	var end: int = Time.get_ticks_msec() + limit_ms
	var arrived: bool = pump.arrived.try_wait()
	while not arrived and Time.get_ticks_msec() < end:
		OS.delay_usec(200)
		arrived = pump.arrived.try_wait()
	return arrived

# A worker pump whose first job has run and is paused at the first gate point, which it has told us (inside_publish: holding the lock).
func _paused_pump(gate: Semaphore, points: Array[String]):
	var pump = _ran_pump()
	pump.points.assign(points)
	pump.armed = true
	pump.gate_publish_for_test(gate, points[0])
	pump.post(_job())
	_await_arrival(pump)
	return pump

func test_sb5a_lock_guards_publish(runner) -> bool:
	if not OS.has_feature("threads"): return true
	var gate := Semaphore.new()
	var pump = _paused_pump(gate, ["inside_publish"])
	var called := Semaphore.new()
	var releaser := Thread.new()
	releaser.start(_release_after.bind(gate, called))
	called.post()
	var began: int = Time.get_ticks_usec()
	var notes: Array = pump.drain()
	var returned: int = Time.get_ticks_usec()
	var stamp: int = releaser.wait_to_finish()
	runner.check(began < stamp and returned >= stamp, "SB5A drain waited for the publish lock until the gate was released (returned %d us before the release)" % (stamp - returned))
	runner.check(notes.size() == 1 and notes[0].tick == 1 and pump.current().tick == notes[0].tick, "SB5A drain saw the note and its slot together, got %d notes, slot tick %d" % [notes.size(), pump.current().tick])
	_stop_built()
	return true

func _call_on(pump, action: String) -> Variant:
	match action:
		"post": return pump.post(_job())
		"drain": return pump.drain()
		"has_room": return pump.has_room()
		"busy": return pump.busy()
		"query": return pump.query(_digest_job())
		"stop":
			pump.stop()
			return true
	return null

# One main-side call against a paused worker. Steps that wait run beside a helper that releases the gate LOCK_HOLD_MS after the signal; the others check the job is still unpublished and release the gate themselves.
func _order_step(runner, pump, gate: Semaphore, action: String, where: String, label: String, ticks: Array) -> void:
	var waits: bool = where == "inside_publish" or action in ["query", "stop"]
	var tag: String = "SB5A %s: %s@%s" % [label, action, where]
	var called := Semaphore.new()
	var releaser := Thread.new()
	if waits: releaser.start(_release_after.bind(gate, called))
	called.post()
	var began: int = Time.get_ticks_usec()
	var value = _call_on(pump, action)
	var returned: int = Time.get_ticks_usec()
	if waits:
		var stamp: int = releaser.wait_to_finish()
		runner.check(began < stamp and returned >= stamp, "%s waits for the release" % tag)
	else:
		pump._mutex.lock()
		var pending: int = pump._unpublished
		var queued: int = pump._notes.size()
		pump._mutex.unlock()
		runner.check(pending >= 1 and queued == 0, "%s returns with the job still unpublished (pending %d, notes %d)" % [tag, pending, queued])
		gate.post()
	if action == "post": runner.check(value == true, "%s: the post is accepted" % tag)
	if action == "query": runner.check(value != null, "%s: the query is answered" % tag)
	if action == "has_room": runner.check(value == true, "%s: there is room" % tag)
	if action == "busy": runner.check(value != waits, "%s: busy says %s, got %s" % [tag, not waits, value])
	if action == "drain":
		runner.check(value.size() == (1 if waits else 0), "%s: a drain takes the note only after the publish (%d)" % [tag, value.size()])
		ticks.append_array(value.map(func(note) -> int: return note.tick))

# steps: [call, gate point] per pause; a second step runs while the same job is paused again, inside the lock.
func _sb5a_publish_order(runner, steps: Array) -> void:
	var gate := Semaphore.new()
	var points: Array[String] = []
	for step: Array in steps: points.append(step[1])
	var pump = _paused_pump(gate, points)
	var label: String = " -> ".join(steps.map(func(step: Array) -> String: return "%s@%s" % step))
	var ticks: Array = []
	for i in steps.size():
		if i > 0: runner.check(_await_arrival(pump), "SB5A %s: the worker reached its second pause" % label)
		_order_step(runner, pump, gate, steps[i][0], steps[i][1], label, ticks)
	runner.check(_idle(pump), "SB5A %s: the pump goes idle" % label)
	ticks.append_array(pump.drain().map(func(note) -> int: return note.tick))
	pump._mutex.lock()
	var pending: int = pump._unpublished
	pump._mutex.unlock()
	var contiguous: bool = not ticks.is_empty() and ticks == range(1, ticks.size() + 1)
	runner.check(contiguous and pump.current().tick == ticks.back() and pending == 0 and pump.failure().is_empty(), "SB5A %s: notes in tick order, READY equals the last note, nothing unpublished (ticks %s, slot %d, pending %d, '%s')" % [label, ticks, pump.current().tick, pending, pump.failure()])
	_stop_built()

func test_sb5a_publish_orders(runner) -> bool:
	if not OS.has_feature("threads"): return true
	for action: String in ["post", "drain", "has_room", "busy", "query", "stop"]:
		for where: String in ["before_publish", "inside_publish"]: _sb5a_publish_order(runner, [[action, where]])
	for pair: Array in [["drain", "drain"], ["has_room", "post"], ["busy", "query"], ["post", "stop"], ["drain", "has_room"], ["has_room", "busy"]]:
		_sb5a_publish_order(runner, [[pair[0], "before_publish"], [pair[1], "inside_publish"]])
	return true

func test_sb5a_stop_and_post_same_frame(runner) -> bool:
	if not OS.has_feature("threads"): return true
	var threads: int = SimPump.live_workers()
	var gate := Semaphore.new()
	var pump = _ran_pump()
	pump.gate_publish_for_test(gate, "before_publish")
	runner.check(pump.post(_job()), "SB5A the running job is accepted")
	runner.check(_await_ran(pump), "SB5A the running job ran")
	runner.check(pump.post(_job()), "SB5A the waiting job is accepted")
	var called := Semaphore.new()
	var releaser := Thread.new()
	releaser.start(_release_after.bind(gate, called))
	called.post()
	pump.stop()
	var late: bool = pump.post(_job())
	releaser.wait_to_finish()
	runner.check(not late, "SB5A a post after stop is refused")
	runner.check(not pump.ran.try_wait() and SimPump.live_workers() == threads, "SB5A the waiting job never ran and the worker exited, live %d" % [SimPump.live_workers() - threads])
	var notes: Array = pump.drain()
	runner.check(notes.size() == 1 and notes[0].tick == 1 and pump.drain().is_empty(), "SB5A the finished job is drained once, got %d" % notes.size())
	_stop_built()
	return true

# Moves at two ticks, so the notes carry issued results.
func _free_job(index: int, unit: int):
	var job = _job([_move(unit)] if index == 5 or index == 400 else [], [2])
	job.want_digest = (index + 1) % DIGEST_EVERY == 0
	return job

func _slot_projection(slot) -> Dictionary:
	var projection: Dictionary = {"tick": slot.tick}
	for key: String in slot.view:
		if key != "units": projection[key] = slot.view[key]
	for column in VIEW_COLUMNS: projection["units." + column] = slot.view.units.get(column)
	return projection

func _note_projection(note) -> Dictionary:
	var projection: Dictionary = {"tick": note.tick, "over": note.over, "digest": note.digest}
	for field in ["events", "results", "issued", "bot_commands", "stats", "survivors", "starts", "preview"]: projection[field] = note.get(field)
	return projection

# Per tick: the hash of the note and of the slot an inline pump publishes.
func _inline_reference(unit: int) -> Dictionary:
	var pump = _pump("inline")
	var baseline: Dictionary = {"notes": {}, "views": {0: hash(_slot_projection(pump.current()))}, "digest": ""}
	for i in MATCH_TICKS:
		pump.post(_free_job(i, unit))
		var note = pump.drain()[0]
		baseline.notes[note.tick] = hash(_note_projection(note))
		baseline.views[note.tick] = hash(_slot_projection(pump.current()))
	baseline.digest = StateHash.digest(pump.live().snapshot())
	return baseline

func _view_mismatch(slot, baseline: Dictionary) -> String:
	if slot == null: return ""
	var held: int = hash(_slot_projection(slot))
	if held == baseline.views.get(slot.tick, 0): return ""
	return "view at tick %d: worker %d, inline %d" % [slot.tick, held, baseline.views.get(slot.tick, 0)]

func test_sb5a_free_running_equals_inline(runner) -> bool:
	if not OS.has_feature("threads"): return true
	var unit: int = _own_unit(_sim())
	var baseline: Dictionary = _inline_reference(unit)
	var pump = _pump("worker")
	var posted: int = 0
	var seen: int = 0
	var drains: int = 0
	var widest: int = 0
	var mismatch: String = ""
	var end: int = Time.get_ticks_msec() + 60000
	while seen < MATCH_TICKS and mismatch.is_empty() and Time.get_ticks_msec() < end:
		if posted < MATCH_TICKS and pump.has_room() and pump.post(_free_job(posted, unit)): posted += 1
		var began: int = Time.get_ticks_usec()
		var notes: Array = pump.drain()
		widest = maxi(widest, Time.get_ticks_usec() - began)
		drains += 1
		for note in notes:
			seen += 1
			var held: int = hash(_note_projection(note))
			if note.tick != seen or held != baseline.notes.get(note.tick, 0):
				mismatch = "note at tick %d (expected %d): issued %s, bot commands %s, worker %d, inline %d" % [note.tick, seen, note.issued, note.bot_commands, held, baseline.notes.get(note.tick, 0)]
				break
		if mismatch.is_empty() and not notes.is_empty():
			if pump.current().tick != notes.back().tick: mismatch = "READY at tick %d after a drain whose last note is tick %d" % [pump.current().tick, notes.back().tick]
			else: mismatch = _view_mismatch(pump.current(), baseline) + _view_mismatch(pump.previous(), baseline)
	runner.check(mismatch.is_empty() and seen == MATCH_TICKS, "SB5A a free-running worker equals the inline run at every tick, first mismatch: %s (%d of %d notes)" % [mismatch, seen, MATCH_TICKS])
	var stats: Dictionary = pump.queue_stats()
	runner.check(pump.mode() == "worker" and stats.get("depth_max", 0) >= 2 and drains > seen, "SB5A the run was a free-running worker: mode %s, queue depth %s, %d drains for %d notes" % [pump.mode(), stats.get("depth_max"), drains, seen])
	var idle: bool = _idle(pump)
	runner.check(idle, "SB5A the worker goes idle after the last note")
	if idle: runner.check(StateHash.digest(pump.live().snapshot()) == baseline.digest and pump.failure().is_empty(), "SB5A the free-running worker ends on the inline digest, '%s'" % pump.failure())
	print("SB5A free run: %d notes in %d drains, drain longest call %d us (lock wait included)" % [seen, drains, widest])
	_stop_built()
	return true

func _drained_ticks(driver) -> Array:
	_idle(driver.pump)
	return driver.drain().map(func(note) -> int: return note.tick)

func _in_order(ticks: Array) -> bool:
	return ticks.size() == 3 and ticks == range(ticks[0], ticks[0] + 3)

# A click with a note pending keeps the running pump and its mode, the notes drain in order, and only the next create (Restart, rematch) follows the click.
func test_sb5b_request_reaches_the_next_pump_only(runner) -> bool:
	SimSettings.available_in_tests = true
	var offline = _offline_driver()
	offline.create(Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 0)
	for want in ["worker", "inline"]:
		var pump = offline.pump
		var before: String = offline.sim_mode()
		offline.step()
		SimSettings.save_worker(want == "worker")
		for i in 2: offline.step()
		var ticks: Array = _drained_ticks(offline)
		runner.check(is_same(offline.pump, pump) and offline.sim_mode() == before and ticks == [1, 2, 3], "SB5B offline: a click with a note pending keeps the %s pump and drains in order, got %s %s" % [before, offline.sim_mode(), ticks])
		offline.create(Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 0)
		runner.check(offline.sim_mode() == want, "SB5B offline: the restart's pump runs %s, got %s" % [want, offline.sim_mode()])
	offline.stop()
	SimSettings.save_worker(false)
	var seat: Dictionary = _seat_two("")
	var online = seat.driver
	online.start()
	_seat_one_packets(seat.transport, 4, 30, -1, -1)
	_frames_to(online, 8)
	var first = online.pump
	_take_one(online)
	SimSettings.save_worker(true)
	for i in 2: _take_one(online)
	var played: Array = _drained_ticks(online)
	runner.check(is_same(online.pump, first) and online.sim_mode() == "inline" and _in_order(played), "SB5B online: a click while ticks step keeps the inline pump and drains in order, got %s %s" % [online.sim_mode(), played])
	online.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
	runner.check(online.sim_mode() == "worker", "SB5B online: the rematch's pump runs worker, got %s" % online.sim_mode())
	SimSettings.save_worker(false)
	runner.check(online.sim_mode() == "worker", "SB5B online: switching off keeps the running worker")
	online.create(Skirmish.MAP_PATH, [] as Array[int], {}, 7)
	runner.check(online.sim_mode() == "inline", "SB5B online: the next rematch runs inline, got %s" % online.sim_mode())
	online.stop()
	SimSettings.available_in_tests = false
	return true

# Restart and rematch stop the old pump before the next one is built, so a failure that stop finds still turns the stored on into inline-fallback.
func test_sb5b_restart_after_failure_falls_back(runner) -> bool:
	SimSettings.available_in_tests = true
	SimSettings.save_worker(true)
	for kind in ["offline", "online"]:
		var driver = _offline_driver() if kind == "offline" else _seat_two("").driver
		var args: Array = [Skirmish.MAP_PATH, [] as Array[int], FACTIONS if kind == "offline" else {}, 7]
		if kind == "offline": driver.callv("create", args)
		runner.check(driver.sim_mode() == "worker", "SB5B fixture: the stored on gives the %s match a worker, got %s" % [kind, driver.sim_mode()])
		_swap_pump(driver, "worker", NullJobPump)
		driver.pump.fail_next = true
		driver.pump.post(_job())
		_idle(driver.pump)
		runner.check(not SimPump._latched, "SB5B fixture: the %s failure waits in the pump until its stop" % kind)
		driver.callv("create", args)
		runner.check(SimPump._latched and driver.sim_mode() == "inline-fallback" and SimSettings.load_worker(), "SB5B the %s match after a failed one runs inline-fallback and keeps the stored on, got %s" % [kind, driver.sim_mode()])
		driver.stop()
		_built.clear()
		SimPump.reset_process_latch_for_test()
	SimSettings.available_in_tests = false
	return true

# A Web pump: the pthread starts once the page returns to the event loop, so the handshake is polled across frame callbacks.
func _web_pump(kind, clock: StartClock, hold_frames: int):
	var pump = _make(_sim(), "worker", kind)
	pump.web = true
	pump.frame_source = clock.frame_now
	pump.clock = clock.msec_now
	pump.hold_start_for_test(hold_frames)
	return pump

func test_sb5b_start_polls_readiness_across_frames(runner) -> bool:
	if not _modes().has("worker"): return true
	var clock := StartClock.new()
	var pump = _web_pump(StartSpy, clock, 2)
	var note = pump.start()
	var main_id: int = OS.get_thread_caller_id()
	runner.check(note != null and note.tick == 0 and pump.mode() == "worker" and pump.failure().is_empty() and pump.ids == [main_id], "SB5B job zero runs on main and the Web pump starts unready, got %s" % [pump.failure()])
	var inline = pump.query(_job())
	runner.check(inline != null and inline.tick == 1 and pump.ids == [main_id, main_id], "SB5B a query before the worker is ready runs inline on main")
	runner.check(not pump.post(_job()) and pump.queue_stats().posts_attempted == 0, "SB5B a post before the worker is ready is refused and queues nothing")
	var posted: Array[int] = []
	var asked: Array[bool] = []
	for frame in 5:
		clock.advance()
		pump.drain()
		var room: bool = pump.has_room()
		asked.append(room)
		if room and pump.post(_job()): posted.append(clock.frame)
		if frame == 1: runner.check(posted.is_empty() and pump.queue_stats().room_refusals == 0 and pump.queries == 1, "SB5B two frames held: nothing posted, no refusal counted, no query beyond the inline one")
	runner.check(asked == [false, false, true, true, true] and posted.size() == 3 and posted[0] == 3, "SB5B the third frame callback finds the worker ready and posts, room answers %s posted at %s" % [asked, posted])
	var stats: Dictionary = pump.queue_stats()
	runner.check(stats.start_frames == 3 and stats.start_ms == 99, "SB5B the handshake took 3 frames and 99 ms, got %s frames %s ms" % [stats.start_frames, stats.start_ms])
	_idle(pump)
	pump.drain()
	runner.check(pump.ids.slice(2).all(func(id: int) -> bool: return id != main_id) and pump.failure().is_empty(), "SB5B the posted jobs ran on the worker thread, got %s" % [pump.failure()])
	var native = _web_pump(StartSpy, clock, 0)
	native.web = false
	native.start()
	runner.check(native.has_room() and native.queue_stats().start_frames == 0, "SB5B native keeps the synchronous handshake: room at once")
	_stop_built()
	return true

# Both drivers keep stepping their frames while the Web worker starts, and post their first tick only once it is ready.
func test_sb5b_start_driver_waits_for_ready(runner) -> bool:
	if not _modes().has("worker"): return true
	var clock := StartClock.new()
	var offline = _offline_driver()
	offline.create(Skirmish.MAP_PATH, [] as Array[int], FACTIONS, 0)
	var seat: Dictionary = _seat_two("")
	var online = seat.driver
	online.start()
	_seat_one_packets(seat.transport, 4, 30, -1, -1)
	for driver in [offline, online]:
		driver.pump.stop()
		var pump = _make(driver.pump.live(), "worker", StartSpy)
		pump.web = true
		pump.frame_source = clock.frame_now
		pump.clock = clock.msec_now
		pump.hold_start_for_test(2)
		driver._last = pump.start()
		driver.pump = pump
	var before: Array[int] = []
	var after: Array[int] = []
	for frame in 4:
		clock.advance()
		for driver in [offline, online]:
			if driver == online: driver._credit = 0
			driver.step()
			driver.drain()
		(before if frame < 2 else after).append(offline.get("_next_tick") + online.get("_next_tick"))
	runner.check(before == [0, 0] and after[0] >= 1 and offline.pump.queue_stats().room_refusals == 0 and online.pump.queue_stats().room_refusals == 0, "SB5B both drivers post nothing during the two held frames and count no refusal, got %s then %s" % [before, after])
	runner.check(offline.failure().is_empty() and online.failure().is_empty() and offline.sim_mode() == "worker", "SB5B the slow start is no failure")
	offline.stop()
	online.stop()
	_stop_built()
	return true

# The stopped start leaves no failure and no latch: the next pump is a worker again, and the record the stopped pump gives replays.
func test_sb5b_start_cancelled_before_ready(runner) -> bool:
	if not _modes().has("worker"): return true
	var threads: int = SimPump.live_workers()
	var clock := StartClock.new()
	var pump = _web_pump(StartSpy, clock, 1000)
	pump.start()
	pump.query(_job([_move(_own_unit(pump.live()))]))
	pump.stop()
	runner.check(pump.failure().is_empty() and not SimPump._latched and pump.has_room(), "SB5B a stop before ready sets no failure and no latch, got '%s'" % pump.failure())
	var record: Dictionary = pump.record()
	runner.check(record.tick == 1 and record.commands.size() == 1 and _replayed_digest(record.commands, record.tick, _sim()) == record.digest and pump.failure().is_empty(), "SB5B the stopped pump's record is read inline and replays to its digest at tick %d" % record.tick)
	runner.check(SimPump.live_workers() == threads + 1, "SB5B the unstarted thread waits on the reap list")
	var end: int = Time.get_ticks_msec() + 3000
	while pump._thread.is_alive() and Time.get_ticks_msec() < end: OS.delay_usec(500)
	var next = SimPump.new(_sim(), true)
	_built.append(next)
	next.start()
	runner.check(next.mode() == "worker" and SimPump.live_workers() == threads + 1 and pump._thread == null, "SB5B the next pump is a worker and its start joined the old thread, got %s with %d live" % [next.mode(), SimPump.live_workers() - threads])
	var started = _web_pump(StartSpy, clock, 0)
	started.start()
	_await_worker_id(started)
	started.stop()
	clock.advance()
	started.drain()
	var inline = started.record()
	runner.check(started.failure().is_empty() and inline.tick == 0 and started._owner_id != started._worker_id, "SB5B a stopped start whose worker did report in stays inline: a drain hands over nothing, got '%s'" % started.failure())
	while started._thread.is_alive() and Time.get_ticks_msec() < end + 3000: OS.delay_usec(500)
	SimPump._reap_abandoned()
	runner.check(SimPump.live_workers() == threads + 1, "SB5B the stopped worker that reported in was reaped")
	_stop_built()
	SimPump.reset_process_latch_for_test()
	return true

# A worker that reported in is not a stall just because the page was slow to poll.
func test_sb5b_start_late_poll_is_no_stall(runner) -> bool:
	if not _modes().has("worker"): return true
	var clock := StartClock.new()
	var pump = _web_pump(StartSpy, clock, 0)
	pump.start()
	_await_worker_id(pump)
	clock.advance(SimPump.WAIT_MSEC + 1)
	pump.drain()
	runner.check(pump.failure().is_empty() and not SimPump._latched and pump._owner_id == pump._worker_id and pump.has_room(), "SB5B a started worker first polled after WAIT_MSEC gets the simulation, got '%s'" % pump.failure())
	_stop_built()
	return true

func _await_worker_id(pump) -> void:
	var end: int = Time.get_ticks_msec() + 3000
	while pump._worker_id == 0 and Time.get_ticks_msec() < end: OS.delay_usec(500)

func test_sb5b_start_times_out(runner) -> bool:
	if not _modes().has("worker"): return true
	var threads: int = SimPump.live_workers()
	var clock := StartClock.new()
	var pump = _web_pump(NeverStartsPump, clock, 0)
	pump.start()
	clock.advance(SimPump.WAIT_MSEC - 1)
	pump.drain()
	runner.check(pump.failure().is_empty() and not pump.has_room(), "SB5B just under WAIT_MSEC the start is still waiting, got '%s'" % pump.failure())
	clock.advance(1)
	pump.drain()
	runner.check(pump.failure() == "stall: worker did not start" and SimPump._latched, "SB5B at WAIT_MSEC the pump fails with the stall cause and latches, got '%s'" % pump.failure())
	runner.check(pump.has_room() and not pump.post(_job()) and pump.queue_stats().start_frames == 2 and pump.queue_stats().start_ms == SimPump.WAIT_MSEC, "SB5B the failed start takes no jobs and records its wait")
	var end: int = Time.get_ticks_msec() + 3000
	while pump._thread.is_alive() and Time.get_ticks_msec() < end: OS.delay_usec(500)
	SimPump._reap_abandoned()
	runner.check(SimPump.live_workers() == threads, "SB5B the dead thread was reaped")
	_built.clear()
	SimPump.reset_process_latch_for_test()
	return true

func test_sb5b_start_online_reads_job_zero(runner) -> bool:
	return _each_mode(runner, _sb5b_start_online_reads_job_zero)

func _sb5b_start_online_reads_job_zero(runner, mode: String) -> void:
	var seat: Dictionary = _seat_two(mode)
	var driver = seat.driver
	var expected: String = StateHash.digest(driver.pump.live().snapshot())
	var note = driver.first_note
	runner.check(note.digest == expected and note.snapshot.has("entities"), "SB5B job zero of an online pump carries the tick-0 snapshot and digest")
	_swap_pump(driver, mode, StartSpy)
	driver.start()
	var hashed: Array = Array(seat.transport.peer.inbox).filter(func(text: String) -> bool: return Wire.decode(text).message.has("hash"))
	var sent: String = Wire.decode(hashed[0]).message.hash.value if not hashed.is_empty() else ""
	runner.check(driver.pump.queries == 0 and sent == expected, "SB5B the start sends job zero's digest and asks the pump nothing, queries %d, sent '%s'" % [driver.pump.queries, sent])
	runner.check(driver.first_note.snapshot.is_empty() and driver.first_note.digest == expected, "SB5B the driver lets go of the tick-0 snapshot once it is sent")
	driver.stop()

func test_sb5b_log_online_commands_kept_once(runner) -> bool:
	return _each_mode(runner, _sb5b_log_online_commands_kept_once)

func _sb5b_log_online_commands_kept_once(runner, mode: String) -> void:
	var threads: int = SimPump.live_workers()
	var pair: Dictionary = _quad_drivers(4, mode)
	var drivers: Array = pair.drivers
	var one = drivers[0]
	var two = drivers[1]
	_trio_until(drivers, 33, true)
	one.submit(_move(_own_unit(one.pump.live())))
	two.submit(_move(_own_unit(two.pump.live(), "", 2)))
	var double_takes: int = _frames(drivers, 150, 3)
	runner.check(double_takes > 0, "SB5B fixture: the host drained two notes in one frame on some frames, got %d" % double_takes)
	for i in 3: _cycle(two)
	_take_one(one)
	_idle(one.pump)
	runner.check(not one.get("_taken").is_empty(), "SB5B fixture: a completed note waits undrained at the leave")
	one.leave()
	one.stop()
	var record: Dictionary = one.record()
	var logged: Array = one._lockstep.command_log()
	var seen: Dictionary = {}
	var players: Dictionary = {}
	var repeats: int = 0
	for command: Dictionary in logged:
		var key: String = "%d/%d/%d" % [command.tick, command.player, command.sequence]
		if seen.has(key): repeats += 1
		seen[key] = true
		players[command.player] = true
	runner.check(repeats == 0 and players.has(1) and players.has(2) and players.has(3) and players.has(4), "SB5B the lockstep log holds every order once, host bots included, %d repeats, players %s" % [repeats, players.keys()])
	runner.check(record.commands.is_empty() and one.pump._recorder.commands().is_empty(), "SB5B an online pump keeps no log of its own: record() has %d commands, the recorder %d" % [record.commands.size(), one.pump._recorder.commands().size()])
	var teams: Array[int] = MatchSettings.teams(2, 2)
	var starts: Array[int] = MatchSettings.starts("broken_crown", 7, teams)
	var replay = Skirmish.create(true, "human", {3: "china", 4: "frc"}, MatchSettings.map_path("broken_crown"), starts, 4, teams)
	runner.check(record.tick > 40 and _replayed_digest(_logged_commands(one), record.tick, replay) == record.digest, "SB5B the saved online log replays to the end tick %d and digest" % record.tick)
	two.stop()
	pair.transports[0].peer = null
	runner.check(SimPump.live_workers() == threads, "SB5B both pumps were joined")

func test_sb5b_log_offline_record_replays(runner) -> bool:
	return _each_mode(runner, _sb5b_log_offline_record_replays)

func _sb5b_log_offline_record_replays(runner, mode: String) -> void:
	var pump = _pump(mode)
	pump.post(_job([_move(_own_unit(pump.live()))]))
	_idle(pump)
	pump.post(_job())
	_idle(pump)
	pump.drain()
	var record: Dictionary = pump.record()
	runner.check(record.commands.size() == 1 and _replayed_digest(record.commands, record.tick, _sim()) == record.digest, "SB5B an offline pump keeps its log and the record replays to tick %d" % record.tick)

func test_t0b_quit_helper_kills_only_a_live_worker_off_the_web(runner) -> bool:
	runner.check(SimPump.live_workers() == 0, "T0B fixture: no live worker before the case")
	var ends: Array = []
	SimPump.end_for_test = func(code: int, kill: bool) -> void: ends.append([code, kill])
	SimPump.finish_quit(null, 3, false)
	SimPump.finish_quit(null, 0, true)
	runner.check(ends == [[3, false], [0, false]], "T0B with no live worker the helper quits with its code, desktop and Web, got %s" % [ends])
	var held := HeldWorker.new()
	SimPump._threads.append(held)
	ends.clear()
	SimPump.finish_quit(null, 1, false)
	SimPump.finish_quit(null, 1, true)
	runner.check(ends == [[1, true], [1, false]], "T0B a live abandoned worker is killed on desktop and never on Web, got %s" % [ends])
	held.gone = true
	ends.clear()
	SimPump.finish_quit(null, 0, false)
	runner.check(ends == [[0, false]] and SimPump.live_workers() == 0, "T0B a worker that has exited is reaped at quit and the quit is normal, got %s, %d live" % [ends, SimPump.live_workers()])
	SimPump._threads.erase(held)
	runner.check(held.stops == 0, "T0B an abandoned worker is not stopped again at quit, %d stops" % held.stops)
	var running := HeldWorker.new()
	running._abandoned = false
	SimPump._threads.append(running)
	ends.clear()
	SimPump.finish_quit(null, 0, false)
	SimPump._threads.erase(running)
	runner.check(ends == [[0, false]] and running.stops == 1, "T0B a running worker is stopped and joined at quit, not killed, got %s, %d stops" % [ends, running.stops])
	return true
