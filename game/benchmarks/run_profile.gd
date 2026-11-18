extends SceneTree

const Profiler = preload("res://scripts/debug/profiler.gd")
const MovementWorkload = preload("res://scripts/debug/movement_workload.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")
const ScriptedHuman = preload("res://scripts/simulation/scripted_human.gd")
const View = preload("res://scripts/presentation/world_view.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const SimPump = preload("res://scripts/match/sim_pump.gd")

const WARMUP: int = 300
const SAMPLES: int = 1800
const MATCH_LIMIT: int = 12000
const TOP_SLOW: int = 10
var _view: Node2D
var _no_selection: Array[int] = []
var _direct_ms: float = 0.0
var _direct_end_tick: int = 0
var _direct_status: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PROFILE HEADLESS engine=", Engine.get_version_info().string, " os=", OS.get_name(), " cpu=", OS.get_processor_name(),
		" warmup_ticks=", WARMUP, " sample_ticks=", SAMPLES, " unpaced=true zones=inclusive")
	_view = View.new()
	var done: int = 0
	# `-- new` runs only the three cases added by the perf spike.
	var only_new: bool = OS.get_cmdline_user_args().has("new")
	if not only_new:
		for layout: String in ["open", "dense"]:
			_movement(layout)
			done += 1
		for layout: String in ["contact", "skirmish3v3", "open"]:
			_fixed("combat_" + layout, CombatWorkload.create(layout))
			done += 1
		_skirmish()
		done += 1
		_large()
		done += 1
	for layout: String in ["dense", "hordes300"]:
		_fixed("combat_" + layout, CombatWorkload.create(layout))
		done += 1
	_team_match()
	done += 1
	_team_match_pump()
	done += 1
	_view.free()
	print("PROFILE COMPLETE ", done)
	quit(0)

# Mirrors one rendered tick: the scene builds the view state once, then the view sorts and batches it.
func _frame(sim: Simulation) -> void:
	_view.set_view(sim.view_state(), _no_selection)
	Profiler.end_tick()

func _harness(workload: Callable) -> Variant:
	Profiler.enabled = false
	var result: Variant = workload.call()
	Profiler.enabled = true
	return result

func _phase(label: String, warmup: bool) -> void:
	for line in Profiler.report(label + (".warmup" if warmup else "")): print(line)
	var slow: Array = Array(Profiler.slow)
	slow.sort_custom(func(a: String, b: String) -> bool: return a.get_slice(" ", 2).to_float() > b.get_slice(" ", 2).to_float())
	for line: Variant in slow.slice(0, TOP_SLOW): print("PROFILE_SLOW ", label, " ", line)
	print("PROFILE_SLOW_COUNT ", label, " ", slow.size())
	Profiler.reset()

func _movement(layout: String) -> void:
	var sim: Simulation = MovementWorkload.create(layout)
	Profiler.reset()
	Profiler.enabled = true
	var leg: int = 0
	for tick in range(WARMUP + SAMPLES):
		if tick == WARMUP: _phase("movement_" + layout, true)
		if tick == 0 or _harness(func() -> bool: return MovementWorkload.settled(sim)):
			_harness(func() -> void: MovementWorkload.issue_leg(sim, leg))
			leg += 1
		sim.step()
		_frame(sim)
	_phase("movement_" + layout, false)
	Profiler.enabled = false
	print("PROFILE_END movement_", layout, " legs=", leg)

func _fixed(label: String, sim: Simulation, edits: Dictionary = {}) -> void:
	Profiler.reset()
	Profiler.enabled = true
	var start_units: int = sim.snapshot().entities.size()
	for tick in range(WARMUP + SAMPLES):
		if tick == WARMUP: _phase(label, true)
		if edits.has(tick): edits[tick].call()
		sim.step()
		_frame(sim)
	_phase(label, false)
	Profiler.enabled = false
	print("PROFILE_END ", label, " units_start=", start_units, " units_end=", sim.snapshot().entities.size())

func _skirmish() -> void:
	var sim: Simulation = Skirmish.create()
	Profiler.reset()
	Profiler.enabled = true
	var peak: int = 0
	while not sim.match_over() and sim.tick() < MATCH_LIMIT:
		if sim.tick() == WARMUP: _phase("skirmish_match", true)
		_harness(func() -> void: ScriptedHuman.issue(sim))
		Skirmish.issue_opponent(sim)
		sim.step()
		_frame(sim)
		peak = maxi(peak, _harness(func() -> int: return sim.snapshot().entities.size()))
	_phase("skirmish_match", false)
	Profiler.enabled = false
	print("PROFILE_END skirmish_match ticks=", sim.tick(), " over=", sim.match_over(), " peak_entities=", peak)

func _large() -> void:
	var sim: Simulation = CombatWorkload.create_large()
	var started: int = Time.get_ticks_usec()
	var route: Array[Vector2] = sim._navigation.route(Vector2(5.5, 98.5), Vector2(190.5, 98.5))
	print("PROFILE_ROUTE large start_to_start_ms=", (Time.get_ticks_usec() - started) / 1000.0, " points=", route.size())
	var obstacle: Array[Vector2i] = []
	for y in range(60, 68):
		for x in range(98, 106): obstacle.append(Vector2i(x, y))
	# Same path as a building placement or death: one full navigation rebuild plus requeue of every mover.
	var add := func() -> void:
		var cells: Array[Vector2i] = sim._union_cells()
		cells.append_array(obstacle)
		sim._replace_union(cells)
	var remove := func() -> void: sim._replace_union(sim._union_cells())
	_fixed("large_196", sim, {600: add, 1200: remove})

func _team_match() -> void:
	var sim: Simulation = TeamMatch.create()
	Profiler.reset()
	Profiler.enabled = true
	var peak: int = 0
	var capped: int = 0
	var max_cells: int = 0
	while not sim.match_over() and sim.tick() < TeamMatch.TEAM_TICK_CAP:
		if sim.tick() == WARMUP: _phase("team_match", true)
		var zone: int = Profiler.begin()
		TeamMatch.step(sim)
		Profiler.end(&"team.tick", zone)
		_frame(sim)
		peak = maxi(peak, sim._entities.size())
		if sim.tick() > WARMUP:
			max_cells = maxi(max_cells, sim.path_cells())
			if sim.path_cells() >= Simulation.PATH_CELLS_PER_TICK: capped += 1
	_direct_ms = _zone_mean(&"team.tick") + _zone_mean(&"view_state")
	_direct_end_tick = sim.tick()
	_direct_status = sim.snapshot().match.status
	_phase("team_match", false)
	Profiler.enabled = false
	print("PROFILE_PATHS team_match capped_ticks=", capped, " max_cells=", max_cells, " budget=", Simulation.PATH_CELLS_PER_TICK)
	print("PROFILE_END team_match ticks=", sim.tick(), " status=", sim.snapshot().match.status, " peak_entities=", peak)

func _zone_mean(zone: StringName) -> float:
	var total: float = 0.0
	for value: float in Profiler.series(zone): total += value
	return total / maxi(Profiler.ticks(), 1)

func _team_match_pump() -> void:
	var pump := SimPump.new(TeamMatch.create())
	pump.start()
	var seats: Array[int] = []
	for entry: Dictionary in TeamMatch.SEATS: seats.append(entry.seat)
	Profiler.reset()
	Profiler.enabled = true
	var notes: int = 0
	var window_ticks: int = 0
	var over: bool = false
	while not over and pump.live().tick() < TeamMatch.TEAM_TICK_CAP:
		var sampled: bool = pump.live().tick() > WARMUP
		if pump.live().tick() == WARMUP: _phase("team_match_pump", true)
		var job := SimPump.Job.new()
		job.bots = seats
		var zone: int = Profiler.begin()
		var posted: bool = pump.post(job)
		Profiler.end(&"pump.post", zone)
		if not posted:
			push_error("pump row: post refused at tick %d" % pump.live().tick())
			break
		zone = Profiler.begin()
		var drained: Array[SimPump.Note] = pump.drain()
		Profiler.end(&"pump.drain", zone)
		_view.set_view(pump.current().view, _no_selection)
		Profiler.end_tick()
		for note: SimPump.Note in drained: over = over or note.over
		if sampled:
			notes += drained.size()
			window_ticks += 1
	var pump_ms: float = _zone_mean(&"pump.post") + _zone_mean(&"pump.drain")
	_phase("team_match_pump", false)
	Profiler.enabled = false
	var end_tick: int = pump.live().tick()
	var status: String = pump.live().snapshot().match.status
	print("PROFILE_PUMP team_match end_tick=", end_tick, " status=", status, " window_ticks=", window_ticks, " notes=", notes,
		" direct_ms=%.4f pump_ms=%.4f extra_ms=%.4f extra_pct=%.2f" % [_direct_ms, pump_ms, pump_ms - _direct_ms, 100.0 * (pump_ms - _direct_ms) / maxf(_direct_ms, 0.0001)])
	if notes != window_ticks: push_error("pump row: %d notes for %d window ticks" % [notes, window_ticks])
	if end_tick != _direct_end_tick or status != _direct_status:
		push_error("pump row ends at tick %d (%s), direct row at %d (%s)" % [end_tick, status, _direct_end_tick, _direct_status])
