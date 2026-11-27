extends SceneTree

# One process per run (--layout=<name> --mode=<inline|worker>); tools/run_worker_digests.sh compares the DIGEST lines of two runs.
# --window=<from>,<to> reruns that window per tick in both modes and names the first difference. --inject-divergence changes one worker command.

const SimPump = preload("res://scripts/match/sim_pump.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")

const EVERY: int = 30
const END_TICKS: Dictionary = {"skirmish3v3": 3000, "hordes300": 3000, "late_game_3v3": 3000, "team": 12000}
const INPUT_TICKS: Array[int] = [100, 400]
const RUN_MSEC: int = 270000

class Run:
	var pump: SimPump
	var start: int = 0
	var total: int = 0
	var window := Vector2i.ZERO
	var inputs: Dictionary = {}
	var seats: Array[int] = []
	var posted: int = 0
	var seen: int = 0
	var holding: bool = false
	var entries: Array[Dictionary] = []
	var commands: String = ""
	var stats: Dictionary = {}
	var error: String = ""

var _layout: String = ""
var _mode: String = "inline"
var _inject: bool = false
var _window := Vector2i.ZERO

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="): _layout = arg.trim_prefix("--layout=")
		elif arg.begins_with("--mode="): _mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--window="): _window = Vector2i(int(arg.get_slice("=", 1).get_slice(",", 0)), int(arg.get_slice(",", 1)))
		elif arg == "--inject-divergence": _inject = true
	_run.call_deferred()

func _run() -> void:
	var ok: bool = _report_window() if _window.y > 0 else _report_run()
	SimPump.force_mode_for_test("")
	quit(0 if ok else 1)

func _create() -> Simulation:
	return TeamMatch.create() if _layout == "team" else CombatWorkload.create(_layout)

func _seats() -> Array[int]:
	var seats: Array[int] = []
	if _layout != "team": return seats
	for entry: Dictionary in TeamMatch.SEATS: seats.append(entry.seat)
	return seats

# Two human orders for the lowest unit, so every load has a command stream that a divergence can corrupt.
func _inputs(sim: Simulation, inject: bool) -> Dictionary:
	var unit: Dictionary = sim.snapshot().entities[0]
	var first: Array = [11.5 if inject else 10.5, 10.5]
	var second: Array = [20.5, 20.5]
	var inputs: Dictionary = {}
	for index: int in INPUT_TICKS.size():
		inputs[INPUT_TICKS[index]] = {"type": "move", "player": unit.owner, "entity_ids": [unit.id], "target": first if index == 0 else second}
	return inputs

func _drive(mode: String, inject: bool, window: Vector2i) -> Run:
	var run := Run.new()
	var sim: Simulation = _create()
	run.inputs = _inputs(sim, inject)
	run.seats = _seats()
	run.window = window
	SimPump.force_mode_for_test(mode)
	run.pump = SimPump.new(sim)
	run.start = run.pump.start().tick
	run.total = (window.y if window.y > 0 else END_TICKS[_layout]) - run.start
	if run.pump.mode() != mode: run.error = "the pump is %s, not %s" % [run.pump.mode(), mode]
	else: _loop(run)
	if run.error.is_empty() and window.y == 0: run.commands = _hash(run.pump.record().commands)
	run.stats = run.pump.queue_stats()
	run.pump.stop()
	return run

func _loop(run: Run) -> void:
	var end: int = Time.get_ticks_msec() + RUN_MSEC
	while run.seen < run.total and run.error.is_empty():
		if Time.get_ticks_msec() > end: run.error = "over %d ms at note %d of %d" % [RUN_MSEC, run.seen, run.total]
		elif not run.pump.failure().is_empty(): run.error = "the pump failed: " + run.pump.failure()
		else: _step(run)

func _step(run: Run) -> void:
	_post_next(run)
	var before: int = run.seen
	_collect(run, run.pump.drain())
	if run.seen == before: OS.delay_usec(200)

# Only when there is room; a digest job holds the next post until its note is drained, so its slot is the one shown.
func _post_next(run: Run) -> void:
	if run.posted >= run.total or run.holding or not run.pump.has_room(): return
	var tick: int = run.start + run.posted
	var job := SimPump.Job.new()
	job.bots.assign(run.seats)
	job.stamp_sequence = true
	if run.inputs.has(tick): job.commands.append(run.inputs[tick].duplicate(true))
	job.want_digest = _wants_digest(run, tick + 1)
	if run.pump.post(job):
		run.posted += 1
		run.holding = job.want_digest

func _wants_digest(run: Run, tick: int) -> bool:
	if run.window.y > 0: return tick > run.window.x and tick <= run.window.y
	return tick % EVERY == 0

func _collect(run: Run, notes: Array[SimPump.Note]) -> void:
	for note: SimPump.Note in notes:
		run.seen += 1
		if note.tick != run.start + run.seen: run.error = "note at tick %d, expected %d" % [note.tick, run.start + run.seen]
		elif not note.digest.is_empty(): run.entries.append(_entry(run, note))
	if run.seen == run.posted: run.holding = false

func _entry(run: Run, note: SimPump.Note) -> Dictionary:
	var slot: SimPump.Slot = run.pump.current()
	if slot.tick != note.tick: run.error = "the shown slot is tick %d at the digest of tick %d" % [slot.tick, note.tick]
	var entry: Dictionary = {"tick": note.tick, "digest": note.digest, "view": _hash(_projection(slot)), "commands": note.issued + note.bot_commands}
	if run.window.y > 0: entry.snapshot = note.snapshot
	return entry

# The value projection of a slot: every column of the units, and everything else as it is.
func _projection(slot: SimPump.Slot) -> Dictionary:
	var projection: Dictionary = {"tick": slot.tick}
	for key: String in slot.view:
		if key != "units": projection[key] = slot.view[key]
	for property: Dictionary in slot.view.units.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: projection["units." + property.name] = slot.view.units.get(property.name)
	return projection

static func _hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode().substr(0, 16)

func _report_run() -> bool:
	var run: Run = _drive(_mode, _inject and _mode == "worker", Vector2i.ZERO)
	var ok: bool = run.error.is_empty() and not run.entries.is_empty()
	if not ok: print("WORKER DIGESTS FAILED ", _layout, " ", _mode, ": ", run.error if not run.error.is_empty() else "no digest")
	if ok: print("COMMANDS ", _layout, " ", run.commands)
	if ok: print("RUN ", _layout, " mode=", _mode, " ticks=", run.seen, " digests=", run.entries.size(), " depth_max=", run.stats.depth_max, " room_refusals=", run.stats.room_refusals)
	for entry: Dictionary in run.entries: print("DIGEST ", _layout, " tick=", entry.tick, " ", entry.digest, " view=", entry.view)
	return ok

func _report_window() -> bool:
	var inline: Run = _drive("inline", false, _window)
	var worker: Run = _drive("worker", _inject, _window)
	var error: String = inline.error + worker.error
	if not error.is_empty():
		print("WINDOW FAILED ", _layout, ": ", error)
		return false
	for index: int in mini(inline.entries.size(), worker.entries.size()):
		var a: Dictionary = inline.entries[index]
		var b: Dictionary = worker.entries[index]
		if a.digest != b.digest or a.view != b.view:
			_print_difference(a, b)
			return true
	print("WINDOW NO DIFFERENCE ", _layout, " ", _window.x, "..", _window.y, ": the per-tick rerun matches, so the free-running mismatch depends on timing")
	return true

func _print_difference(inline: Dictionary, worker: Dictionary) -> void:
	print("FIRST DIFFERENCE ", _layout, " tick=", inline.tick)
	print("  commands inline ", JSON.stringify(inline.commands).left(600))
	print("  commands worker ", JSON.stringify(worker.commands).left(600))
	print("  digest inline ", inline.digest, " worker ", worker.digest)
	print("  view inline ", inline.view, " worker ", worker.view)
	var field: String = _first_field(inline.snapshot, worker.snapshot, "snapshot")
	print("  field ", field if not field.is_empty() else "none, the snapshots are equal and only the digest or the view differs")

func _first_field(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b): return "%s inline %s worker %s" % [path, str(a).left(80), str(b).left(80)]
	if a is Dictionary:
		for key: Variant in a:
			if not b.has(key): return "%s.%s only inline" % [path, key]
			var found: String = _first_field(a[key], b[key], "%s.%s" % [path, key])
			if not found.is_empty(): return found
		for key: Variant in b:
			if not a.has(key): return "%s.%s only worker" % [path, key]
		return ""
	if a is Array:
		if a.size() != b.size(): return "%s size inline %d worker %d" % [path, a.size(), b.size()]
		for index: int in a.size():
			var found: String = _first_field(a[index], b[index], "%s[%d]" % [path, index])
			if not found.is_empty(): return found
		return ""
	return "" if a == b else "%s inline %s worker %s" % [path, str(a).left(80), str(b).left(80)]
