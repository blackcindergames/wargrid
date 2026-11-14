extends SceneTree

const TeamMatch = preload("res://scripts/debug/team_match.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const Skirmish = preload("res://scripts/simulation/skirmish.gd")

const WARMUP: int = 300
const TOP_SLOW: int = 10

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	quit(0 if _play() else 1)

func _play() -> bool:
	var sim: Simulation = TeamMatch.create()
	var samples := PackedFloat64Array()
	var units_peak: int = 0
	var paths := {"capped_ticks": 0, "max_cells": 0, "max_queue": 0, "max_decisions": 0}
	Profiler.reset()
	Profiler.enabled = true
	for tick in range(TeamMatch.TEAM_TICK_CAP):
		var deciding: int = TeamMatch.SEATS.filter(func(entry: Dictionary) -> bool: return Skirmish.decides(sim.tick(), entry.seat)).size()
		var started: int = Time.get_ticks_usec()
		TeamMatch.step(sim)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		Profiler.end_tick()
		if sim.tick() == WARMUP:
			_report("team_match.warmup")
		var state: Dictionary = sim.snapshot()
		units_peak = maxi(units_peak, state.entities.size())
		if sim.tick() > WARMUP: _count_paths(paths, sim, state, deciding)
		if state.match.status != "ongoing":
			print("TEAM MATCH ", state.match.status, " tick=", state.tick, " winner=", state.match.winner, " units_peak=", units_peak)
			print("TEAM TIMING ", Stats.summary(samples))
			_report("team_match")
			return _paths_ok(paths)
	print("TEAM MATCH cap tick=", sim.tick(), " winner=null units_peak=", units_peak)
	print("TEAM TIMING ", Stats.summary(samples))
	_report("team_match")
	return _paths_ok(paths)

func _report(label: String) -> void:
	for line in Profiler.report(label): print(line)
	var slow: Array = Array(Profiler.slow)
	slow.sort_custom(func(a: String, b: String) -> bool: return a.get_slice(" ", 2).to_float() > b.get_slice(" ", 2).to_float())
	for line: Variant in slow.slice(0, TOP_SLOW): print("PROFILE_SLOW ", label, " ", line)
	print("PROFILE_SLOW_COUNT ", label, " ", slow.size())
	Profiler.reset()
	Profiler.enabled = label.ends_with("warmup")

func _count_paths(paths: Dictionary, sim: Simulation, state: Dictionary, deciding: int) -> void:
	if sim.path_cells() >= Simulation.PATH_CELLS_PER_TICK: paths.capped_ticks += 1
	paths.max_cells = maxi(paths.max_cells, sim.path_cells())
	paths.max_queue = maxi(paths.max_queue, state.path_queue.size())
	paths.max_decisions = maxi(paths.max_decisions, deciding)

func _paths_ok(paths: Dictionary) -> bool:
	print("TEAM PATHS capped_ticks=", paths.capped_ticks, " max_cells=", paths.max_cells, " max_queue=", paths.max_queue, " max_decisions=", paths.max_decisions)
	return true
