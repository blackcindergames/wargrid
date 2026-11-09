extends SceneTree

# Jam harness for the unit avoidance spike. Args after `--`: --mode off|yield|reserve, --only a,b, --trace DIR.
# Reads the avoidance record as `sim._avoid`: per-unit dictionaries (`blocked` consecutive blocked ticks, `ghost_until`) and `stats` counters; absent on main, then every counter is zero.
const Scenarios = preload("res://scripts/debug/avoidance_scenarios.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const StateHash = preload("res://scripts/simulation/state_hash.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Registry = preload("res://scripts/simulation/definitions/definitions.gd")

const AVOIDANCE_PATH := "res://scripts/simulation/avoidance.gd"
const BLOCKED_LIMIT: int = 150
const DEADLOCK_TICKS: int = 900
const DEADLOCK_PROGRESS: float = 0.01
const NEAR_GOAL_CELLS: int = 4
const OFF_GOAL_DISTANCE: float = 2.5
const COUNTERS: Array[String] = ["step_asides", "sidesteps", "nudges", "reroutes", "reroute_fail", "gave_up", "would_crush"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: Dictionary = _args()
	if not _apply_mode(args.mode):
		quit(1)
		return
	var label: String = args.mode if args.mode != "" else "off"
	print("AVOID HARNESS engine=", Engine.get_version_info().string, " os=", OS.get_name(), " cpu=", OS.get_processor_name(),
		" mode=", label, " avoidance_script=", "present" if ResourceLoader.exists(AVOIDANCE_PATH) else "absent")
	var failed: bool = false
	var count: int = 0
	for scenario: String in args.only:
		if _play(scenario, label, args.trace):
			count += 1
		else:
			failed = true
	if failed:
		quit(1)
		return
	print("AVOID HARNESS COMPLETE ", count)
	quit(0)

func _args() -> Dictionary:
	var result := {"mode": "", "only": Scenarios.NAMES.duplicate(), "trace": ""}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		match args[index]:
			"--mode": result.mode = "" if args[index + 1] == "off" else args[index + 1]
			"--only": result.only = Array(args[index + 1].split(","))
			"--trace": result.trace = args[index + 1]
	return result

func _apply_mode(mode: String) -> bool:
	if not ResourceLoader.exists(AVOIDANCE_PATH):
		if mode != "":
			push_error("Mode " + mode + " needs " + AVOIDANCE_PATH)
			return false
		return true
	load(AVOIDANCE_PATH).call("set_mode", mode)
	return true

func _play(scenario: String, label: String, trace_dir: String) -> bool:
	var sim: Simulation = Scenarios.create(scenario)
	if sim == null:
		push_error("Unknown scenario " + scenario)
		return false
	var state: Dictionary = Scenarios.ctx(sim)
	print("AVOID SETUP ", scenario, " ", " | ".join(state.setup))
	var plan: Dictionary = Scenarios.plan(scenario)
	var metrics: Dictionary = _new_metrics()
	var trace: FileAccess = _open_trace(trace_dir, scenario)
	var samples := PackedFloat64Array()
	var tick: int = 0
	var completion: String = "fixed" if plan.kind == "fixed" else "cap"
	while tick < Scenarios.CAP_TICKS and state.errors.is_empty():
		Scenarios.orders(sim, scenario, tick)
		if tick == Scenarios.WINDOW_START:
			metrics.window_start = _counters(sim)
		var started: int = Time.get_ticks_usec()
		sim.step()
		var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
		if tick >= Scenarios.WINDOW_START:
			samples.append(elapsed)
		if tick == Scenarios.FIXED_TICKS - 1:
			metrics.window_end = _counters(sim)
		_observe(sim, metrics)
		if trace != null:
			trace.store_line("%d\t%d\t%d" % [sim.tick(), StateHash.core_check(sim.snapshot()), _sum(_counters(sim))])
		tick += 1
		if _finished(sim, plan.kind, tick):
			if plan.kind != "fixed":
				completion = str(tick)
			break
	for error: String in state.errors:
		push_error(scenario + ": " + error)
	if not state.errors.is_empty():
		return false
	print(_report(sim, label, scenario, completion, tick, samples, metrics))
	return true

func _finished(sim: Simulation, kind: String, tick: int) -> bool:
	match kind:
		"fixed": return tick >= Scenarios.FIXED_TICKS
		"legs": return tick >= Scenarios.FIXED_TICKS and Scenarios.done(sim)
	return tick >= 2 and Scenarios.done(sim)

func _open_trace(dir: String, scenario: String) -> FileAccess:
	if dir == "":
		return null
	DirAccess.make_dir_recursive_absolute(dir)
	return FileAccess.open(dir.path_join(scenario + ".tsv"), FileAccess.WRITE)

func _new_metrics() -> Dictionary:
	return {"blocked_prev": {}, "blocked_units": {}, "episodes": 0, "near_goal": 0, "ghost_seen": {}, "last_resort": {},
		"track": {}, "deadlocks": 0, "overlap_pairs": 0, "overlap_notruck": 0, "overlap_peak": 0, "status_blocked": {},
		"waiting_ticks": 0, "waiting_unit_ticks": 0, "classes": {}, "window_start": null, "window_end": null}

func _counters(sim: Simulation) -> Dictionary:
	var avoid: Variant = sim.get("_avoid")
	if avoid is Dictionary and avoid.get("stats") is Dictionary:
		return avoid.stats.duplicate()
	return {}

func _sum(counters: Dictionary) -> int:
	var total: int = 0
	for key: Variant in counters:
		total += int(counters[key])
	return total

func _observe(sim: Simulation, metrics: Dictionary) -> void:
	var avoid: Variant = sim.get("_avoid")
	var records: Dictionary = avoid if avoid is Dictionary else {}
	var vehicles: Dictionary = {}
	var vehicles_notruck: Dictionary = {}
	var waiting: int = 0
	for id: int in sim._entities:
		var unit: Dictionary = sim._entities[id]
		var record: Dictionary = records.get(id, {})
		if unit.status == "blocked":
			metrics.status_blocked[id] = true
		_track_blocked(unit, record, metrics)
		_track_last_resort(unit, record, metrics)
		_track_progress(unit, sim.tick(), metrics)
		if _is_ground_vehicle(unit, metrics):
			var key: int = floori(unit.position[1]) * 1000 + floori(unit.position[0])
			vehicles[key] = vehicles.get(key, 0) + 1
			if unit.collection == null:
				vehicles_notruck[key] = vehicles_notruck.get(key, 0) + 1
		if unit.collection != null and unit.collection.phase.begins_with("waiting_"):
			waiting += 1
	_tally_overlap(vehicles, vehicles_notruck, metrics)
	if sim.tick() > Scenarios.WINDOW_START and waiting > 0:
		metrics.waiting_ticks += 1
		metrics.waiting_unit_ticks += waiting

func _is_ground_vehicle(unit: Dictionary, metrics: Dictionary) -> bool:
	if unit.has("container_id") or Registry.air_kinds.has(unit.kind):
		return false
	return _class_of(unit.kind, metrics) == "vehicle"

func _class_of(kind: String, metrics: Dictionary) -> String:
	if not metrics.classes.has(kind):
		metrics.classes[kind] = "builder" if Registry.is_builder(kind) else Registry.kind(kind)["class"]
	return metrics.classes[kind]

func _tally_overlap(vehicles: Dictionary, vehicles_notruck: Dictionary, metrics: Dictionary) -> void:
	var pairs: int = _pairs(vehicles)
	metrics.overlap_pairs += pairs
	metrics.overlap_peak = maxi(metrics.overlap_peak, pairs)
	metrics.overlap_notruck += _pairs(vehicles_notruck)

@warning_ignore("integer_division")
func _pairs(counts: Dictionary) -> int:
	var pairs: int = 0
	for key: int in counts:
		pairs += counts[key] * (counts[key] - 1) / 2
	return pairs

func _track_blocked(unit: Dictionary, record: Dictionary, metrics: Dictionary) -> void:
	var now: int = record.get("blocked", 0)
	if now > BLOCKED_LIMIT and metrics.blocked_prev.get(unit.id, 0) <= BLOCKED_LIMIT:
		metrics.episodes += 1
		metrics.blocked_units[unit.id] = true
		if _near_goal(unit):
			metrics.near_goal += 1
	metrics.blocked_prev[unit.id] = now

func _near_goal(unit: Dictionary) -> bool:
	if unit.destination == null:
		return false
	var dx: int = absi(floori(unit.position[0]) - floori(unit.destination[0]))
	var dy: int = absi(floori(unit.position[1]) - floori(unit.destination[1]))
	return dx + dy <= NEAR_GOAL_CELLS

func _track_last_resort(unit: Dictionary, record: Dictionary, metrics: Dictionary) -> void:
	var until: int = record.get("ghost_until", 0)
	if until > metrics.ghost_seen.get(unit.id, 0):
		metrics.ghost_seen[unit.id] = until
		var group: String = _class_of(unit.kind, metrics)
		metrics.last_resort[group] = metrics.last_resort.get(group, 0) + 1

# A deadlock is a unit with an order whose distance to its destination has not shrunk by DEADLOCK_PROGRESS for DEADLOCK_TICKS; units firing at a target are exempt.
func _track_progress(unit: Dictionary, tick: int, metrics: Dictionary) -> void:
	var busy: bool = unit.combat != null and unit.combat.target_id != null
	if unit.order == null or unit.destination == null or busy:
		metrics.track.erase(unit.id)
		return
	var dx: float = unit.destination[0] - unit.position[0]
	var dy: float = unit.destination[1] - unit.position[1]
	var distance: float = sqrt(dx * dx + dy * dy)
	var signature: int = unit.order.hash()
	var entry: Dictionary = metrics.track.get(unit.id, {})
	if entry.get("signature", -1) != signature:
		metrics.track[unit.id] = {"signature": signature, "best": distance, "since": tick, "counted": false}
		return
	if distance < entry.best - DEADLOCK_PROGRESS:
		entry.best = distance
		entry.since = tick
	elif tick - entry.since >= DEADLOCK_TICKS and not entry.counted:
		entry.counted = true
		metrics.deadlocks += 1

func _report(sim: Simulation, label: String, scenario: String, completion: String, ticks: int, samples: PackedFloat64Array, metrics: Dictionary) -> String:
	var summary: Dictionary = Stats.summary(samples)
	var parts: Array[String] = ["AVOID", label, scenario, "ticks=%d" % ticks, "completion_tick=" + completion,
		"blocked150_units=%d" % metrics.blocked_units.size(), "blocked150_episodes=%d" % metrics.episodes, "blocked150_near_goal=%d" % metrics.near_goal,
		"deadlocks=%d" % metrics.deadlocks, "overlap_pair_ticks=%d" % metrics.overlap_pairs, "overlap_peak=%d" % metrics.overlap_peak,
		"overlap_notruck_pair_ticks=%d" % metrics.overlap_notruck, "status_blocked_units=%d" % metrics.status_blocked.size()]
	for group: String in ["vehicle", "infantry", "builder"]:
		parts.append("last_resort_%s=%d" % [group, metrics.last_resort.get(group, 0)])
	var counters: Dictionary = _counters(sim)
	for key: String in _keys(counters):
		parts.append("%s=%d" % [key, counters.get(key, 0)])
	if Scenarios.plan(scenario).window:
		parts.append_array(_window(metrics, counters))
	parts.append_array(_economy(sim, metrics))
	var goals: Dictionary = Scenarios.ctx(sim).goals
	if not goals.is_empty():
		parts.append("off_goal=%d" % _off_goal(sim, goals))
	parts.append("tick_ms_p95=%.3f" % summary.p95)
	parts.append("tick_ms_p99=%.3f" % summary.p99)
	return " ".join(parts)

func _keys(counters: Dictionary) -> Array[String]:
	var keys: Array[String] = COUNTERS.duplicate()
	for key: String in counters:
		if not keys.has(key):
			keys.append(key)
	return keys

func _window(metrics: Dictionary, counters: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	var start: Dictionary = metrics.window_start if metrics.window_start != null else {}
	var end: Dictionary = metrics.window_end if metrics.window_end != null else counters
	for key: String in _keys(end):
		parts.append("window_%s=%d" % [key, end.get(key, 0) - start.get(key, 0)])
	return parts

func _economy(sim: Simulation, metrics: Dictionary) -> Array[String]:
	var trucks: bool = sim._entities.values().any(func(unit: Dictionary) -> bool: return unit.collection != null)
	if not trucks:
		return []
	return ["credits=%d" % sim._players[1].credits, "waiting_ticks=%d" % metrics.waiting_ticks, "waiting_unit_ticks=%d" % metrics.waiting_unit_ticks]

func _off_goal(sim: Simulation, goals: Dictionary) -> int:
	var count: int = 0
	for id: int in goals:
		if not sim._entities.has(id):
			continue
		var position: Array = sim._entities[id].position
		var dx: float = goals[id][0] - position[0]
		var dy: float = goals[id][1] - position[1]
		if sqrt(dx * dx + dy * dy) > OFF_GOAL_DISTANCE:
			count += 1
	return count
