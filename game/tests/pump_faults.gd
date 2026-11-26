@warning_ignore_start("untyped_declaration")
extends SceneTree

# One fault case per process (--case=<name>), real 30 Hz physics frames; the shell script judges the marker and the exit status.

const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")
const FACTIONS := {1: "usa", 2: "china"}
const HOLD_MSEC: int = 12000 # a held job is finite, so an abandoned worker ends before the process does
const FRAME_LIMIT: int = 400

# Inside the worker's job window, before the simulation steps: pushes an error (only in a query, if asked) and holds the job.
class HookPump extends "res://scripts/match/sim_pump.gd":
	var error_text: String = ""
	var error_in_query_only: bool = false
	var hold: Semaphore
	var entered := Semaphore.new()
	func _note_for(job: Job, slot: Slot) -> Note:
		if not error_text.is_empty() and (job.want_tick_hash or not error_in_query_only): push_error(error_text)
		if hold != null:
			entered.post()
			var end: int = Time.get_ticks_msec() + HOLD_MSEC
			while not hold.try_wait() and Time.get_ticks_msec() < end: OS.delay_usec(1000)
		return super(job, slot)

# A worker thread that returns at once, with a job still unpublished.
class DeadPump extends "res://scripts/match/sim_pump.gd":
	func _run_worker() -> void:
		_owner_id = OS.get_thread_caller_id()
		_started.post()

var _case: String = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): _case = arg.trim_prefix("--case=")
	_run.call_deferred()

func _run() -> void:
	var method := "_case_" + _case
	if not has_method(method):
		print("FAULT CASE ", _case, " FAILED unknown case")
		quit(2)
		return
	var began: int = Time.get_ticks_msec()
	var why: String = await call(method)
	if why.is_empty():
		print("FAULT CASE ", _case, " PASSED ", Time.get_ticks_msec() - began)
		quit(0)
	else:
		print("FAULT CASE ", _case, " FAILED ", why)
		quit(1)

static func _wait_for(gate: Semaphore, limit_ms: int = 3000) -> bool:
	var end: int = Time.get_ticks_msec() + limit_ms
	var got: bool = gate.try_wait()
	while not got and Time.get_ticks_msec() < end:
		OS.delay_usec(1000)
		got = gate.try_wait()
	return got

func _pump(kind = SimPump):
	var pump = kind.new(Skirmish.create(true, "ai", FACTIONS, Skirmish.MAP_PATH, [] as Array[int]))
	pump.start()
	return pump

func _job(commands: Array = []):
	var job = SimPump.Job.new()
	job.commands.assign(commands)
	job.stamp_sequence = true
	return job

# Drains once per physics frame until the pump has a failure; returns the notes it took and the frames it needed.
func _until_failed(pump, notes: Array) -> int:
	var first: int = Engine.get_physics_frames()
	while pump.failure().is_empty() and Engine.get_physics_frames() - first < FRAME_LIMIT:
		await physics_frame
		notes.append_array(pump.drain())
	return Engine.get_physics_frames() - first

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _worker_pump(kind = SimPump) -> Array:
	var pump = _pump(kind)
	if pump.mode() != "worker": return [null, "the pump is %s, not worker: run with WARGRID_SIM_THREAD=1" % pump.mode()]
	return [pump, ""]

func _refused_after(pump) -> bool:
	return not pump.post(_job()) and not pump.busy() and pump.has_room()

func _case_logged_error() -> String:
	if not Engine.print_error_messages: return "print_error_messages is off, the logger would hear nothing"
	var made := _worker_pump(HookPump)
	var pump = made[0]
	if pump == null: return made[1]
	pump.error_text = "fault probe: logged_error"
	pump.post(_job())
	var notes: Array = []
	await _until_failed(pump, notes)
	var why := ""
	if not pump.failure().begins_with("fault"): why = "failure is '%s', not a fault" % pump.failure()
	elif not notes.is_empty(): why = "the faulted note reached drain (%d notes)" % notes.size()
	elif not _refused_after(pump): why = "a failed pump still takes jobs or reports busy"
	pump.stop()
	if why.is_empty() and SimPump.live_workers() != 0: why = "the failed worker was not joined"
	return why

func _case_main_error_control() -> String:
	if not Engine.print_error_messages: return "print_error_messages is off, the control proves nothing"
	var made := _worker_pump(HookPump)
	var pump = made[0]
	if pump == null: return made[1]
	pump.hold = Semaphore.new()
	pump.post(_job())
	if not _wait_for(pump.entered): return "the worker never entered the job"
	push_error("fault control: an error on the main thread during a worker job")
	pump.hold.post()
	var notes: Array = []
	for i in 30:
		await physics_frame
		notes.append_array(pump.drain())
		if not notes.is_empty(): break
	var why := ""
	if not pump.failure().is_empty(): why = "a main-thread error faulted the worker job: '%s'" % pump.failure()
	elif notes.size() != 1: why = "expected the job's note, drained %d" % notes.size()
	pump.stop()
	return why

func _case_wrong_thread() -> String:
	var made := _worker_pump()
	var pump = made[0]
	if pump == null: return made[1]
	var note = pump._run_owned(_job(), null)
	pump.drain()
	var why := ""
	if note != null: why = "a job ran on a thread that is not the owner"
	elif not pump.failure().begins_with("owner thread"): why = "failure is '%s', not owner thread" % pump.failure()
	elif not _refused_after(pump): why = "a failed pump still takes jobs or reports busy"
	pump.stop()
	return why

func _case_fault_in_query() -> String:
	var made := _worker_pump(HookPump)
	var pump = made[0]
	if pump == null: return made[1]
	pump.error_text = "fault probe: fault_in_query"
	pump.error_in_query_only = true
	var asked = _job()
	asked.step = false
	asked.want_tick_hash = true
	var began: int = Time.get_ticks_msec()
	var note = pump.query(asked)
	var took: int = Time.get_ticks_msec() - began
	var why := ""
	if note != null: why = "a faulted query returned a note"
	elif took > 1500: why = "the faulted query waited %d ms, the answer was not null at once" % took
	elif not pump.failure().begins_with("fault"): why = "failure is '%s', not a fault" % pump.failure()
	elif not _refused_after(pump): why = "a failed pump still takes jobs or reports busy"
	pump.stop()
	return why

# Releases the held job and waits for the abandoned worker to exit and be joined, so no thread is inside a job at process exit.
func _finish_stalled(pump) -> String:
	pump.hold.post()
	var end: int = Time.get_ticks_msec() + HOLD_MSEC + SimPump.WAIT_MSEC
	while not pump._worker_gone() and Time.get_ticks_msec() < end: await physics_frame
	SimPump._reap_abandoned()
	if SimPump.live_workers() != 0: return "the abandoned worker did not exit after its job ended (%d live)" % SimPump.live_workers()
	return ""

func _live_asserts(pump) -> bool:
	var me: int = OS.get_thread_caller_id()
	var before: int = SimPump._logger.count_for(me)
	pump.live()
	return SimPump._logger.count_for(me) > before

# A job held past the stall limit (and released by _finish_stalled).
func _stalled(with_log: bool = false) -> Array:
	var made := _worker_pump(HookPump)
	var pump = made[0]
	if pump == null: return [null, made[1]]
	if with_log:
		var own: int = -1
		for entity in pump.live().snapshot().entities:
			if entity.owner == 1:
				own = entity.id
				break
		pump.post(_job([{"type": "move", "player": 1, "entity_ids": [own], "target": [10.5, 10.5]}]))
		var end: int = Time.get_ticks_msec() + SimPump.WAIT_MSEC
		while pump.busy() and Time.get_ticks_msec() < end: await physics_frame
		if pump.busy(): return [null, "the first job never finished"]
		pump.drain()
	pump.hold = Semaphore.new()
	pump.post(_job())
	if not _wait_for(pump.entered): return [null, "the worker never entered the held job"]
	return [pump, ""]

func _case_stall_restart() -> String:
	var held: Array = await _stalled()
	var pump = held[0]
	if pump == null: return held[1]
	var began: int = Time.get_ticks_msec()
	var frames: int = await _until_failed(pump, [])
	var found: int = Time.get_ticks_msec() - began
	if not pump.failure().begins_with("stall: job at tick"): return "failure is '%s' after %d frames" % [pump.failure(), frames]
	if found < SimPump.STALL_MSEC - 200 or found > 3 * SimPump.STALL_MSEC: return "the stall was found after %d ms" % found
	var stopped: int = Time.get_ticks_msec()
	pump.stop()
	if Time.get_ticks_msec() - stopped > 200: return "stop() on an abandoned pump waited"
	var next = _pump()
	if next.mode() != "inline-fallback": return "the next pump is %s, not inline-fallback" % next.mode()
	var drained: int = 0
	for i in 30:
		if not next.post(_job()): return "the inline pump refused job %d" % i
		drained += next.drain().size()
	if drained != 30 or SimPump.live_workers() != 1: return "the restart drained %d of 30 notes, %d workers live" % [drained, SimPump.live_workers()]
	return await _finish_stalled(pump)

func _case_stall_leave() -> String:
	var held: Array = await _stalled(true)
	var pump = held[0]
	if pump == null: return held[1]
	await _until_failed(pump, [])
	if not pump.failure().begins_with("stall"): return "failure is '%s', not a stall" % pump.failure()
	var stopped: int = Time.get_ticks_msec()
	pump.stop()
	pump.stop()
	if Time.get_ticks_msec() - stopped > 200: return "a leave on an abandoned pump waited"
	var record: Dictionary = pump.record()
	if record.digest != "" or not record.commands.is_empty(): return "record() read a living worker's log or digest: %s" % [record]
	if record.tick != pump.current().tick: return "record() tick %d is not the last shown %d" % [record.tick, pump.current().tick]
	if pump.post(_job()) or SimPump.live_workers() != 1: return "a stopped abandoned pump takes jobs or was joined"
	return await _finish_stalled(pump)

func _case_stall_stop() -> String:
	var held: Array = await _stalled()
	var pump = held[0]
	if pump == null: return held[1]
	await _frames(3)
	var began: int = Time.get_ticks_msec()
	pump.stop()
	var took: int = Time.get_ticks_msec() - began
	if took < SimPump.WAIT_MSEC - 200 or took > 2 * SimPump.WAIT_MSEC: return "stop() took %d ms, the deadline is %d" % [took, SimPump.WAIT_MSEC]
	if pump.failure() != "stall: stop waited %d ms" % SimPump.WAIT_MSEC: return "failure is '%s'" % pump.failure()
	if not _live_asserts(pump): return "live() on an abandoned pump did not assert"
	began = Time.get_ticks_msec()
	pump.stop()
	if Time.get_ticks_msec() - began > 200 or SimPump.live_workers() != 1: return "the second stop() waited or the thread was joined"
	return await _finish_stalled(pump)

func _case_stall_query() -> String:
	var held: Array = await _stalled()
	var pump = held[0]
	if pump == null: return held[1]
	await _frames(3)
	var asked = _job()
	asked.step = false
	asked.want_digest = true
	var began: int = Time.get_ticks_msec()
	var note = pump.query(asked)
	var took: int = Time.get_ticks_msec() - began
	if note != null or took < SimPump.WAIT_MSEC - 200 or took > 2 * SimPump.WAIT_MSEC: return "query returned %s after %d ms, the deadline is %d" % [note, took, SimPump.WAIT_MSEC]
	if pump.failure() != "stall: query waited %d ms" % SimPump.WAIT_MSEC: return "failure is '%s'" % pump.failure()
	began = Time.get_ticks_msec()
	var again = pump.query(asked)
	pump.stop()
	if again != null or Time.get_ticks_msec() - began > 200: return "a query or stop on the abandoned pump waited"
	return await _finish_stalled(pump)

func _case_dead_thread() -> String:
	var made := _worker_pump(DeadPump)
	var pump = made[0]
	if pump == null: return made[1]
	if not pump.post(_job()): return "the job was refused"
	await _until_failed(pump, [])
	var why := ""
	if pump.failure() != "dead thread": why = "failure is '%s', not dead thread" % pump.failure()
	pump.stop()
	if why.is_empty() and SimPump.live_workers() != 0: why = "the dead thread was not joined"
	return why

func _case_next_match_inline() -> String:
	var made := _worker_pump(HookPump)
	var pump = made[0]
	if pump == null: return made[1]
	pump.error_text = "fault probe: next_match_inline"
	pump.post(_job())
	await _until_failed(pump, [])
	pump.stop()
	if pump.failure().is_empty(): return "the fixture did not fail the pump"
	var next = _pump()
	var why := ""
	if next.mode() != "inline-fallback" or SimPump.worker_wanted(): why = "the next pump is %s after a failure" % next.mode()
	elif not next.post(_job()) or next.drain().size() != 1 or SimPump.live_workers() != 0: why = "the next pump does not run inline"
	elif _live_asserts(next): why = "live() asserted on a healthy inline pump"
	return why
