extends "res://scripts/match/match_screen.gd"

signal finished(result: Dictionary)

const TimingStats = preload("res://scripts/debug/timing_stats.gd")
const BenchLoads = preload("res://scripts/debug/bench_loads.gd")
const MISSED_MS: float = 25.0
const LONG_MS: float = 33.3
const ZOOM: float = 0.5
const STALL_USEC: int = 10000000
const MOVE_EVERY: int = 60
const BUILD_EVERY: int = 600
const MOVERS: int = 4
const BUILD_KIND: String = "usa_power_plant"
const PACE_USEC: int = 2000000
# 20 holds of 1 s fit the 1800-tick window: the last starts about 59 s into the 80 s it takes.
const HOLD_FIRST_USEC: int = 2000000
const HOLD_GAP_USEC: int = 2000000
const OFFSETS: Array[Vector2] = [Vector2(6, 0), Vector2(0, 6), Vector2(-6, 0), Vector2(0, -6)]

var bench_sim: RefCounted
var arm: String = "inline"
var load_name: String = "team"
var run_index: int = 0
var build_id: String = "none"
var start_tick: int = 0
var quality: int = GraphicsSettings.HIGH
var quality_param: String = "high"
var smooth: bool = true
var online_cadence: bool = false
var holds := Vector2i.ZERO
var digests := PackedStringArray()

var _long: int = 0
var _open: bool = false
var _done: bool = false
var _t_first: int = 0
var _open_usec: int = 0
var _last_frame: int = 0
var _script_usec: int = 0
var _last_start: int = 0
var _start_ms := PackedFloat64Array()
var _carried_usec: int = 0
var _frame_ms := PackedFloat64Array()
var _cpu_ms := PackedFloat64Array()
var _refresh_ms := PackedFloat64Array()
var _units := PackedFloat64Array()
var _missed: int = 0
var _render_sum: float = 0.0
var _views_shown: int = 0
var _last_view_tick: int = -1
var _shots: int = 0
var _deaths: int = 0
var _commands: int = 0
var _bot_commands: int = 0
var _seen_tick: int = -1
var _seen_usec: int = 0

var _movers: Array[int] = []
var _home := Vector2.ZERO
var _builder: int = -1
var _sites: Array[Vector2i] = []
var _fed_tick: int = -1
var _scripted: int = 0
var _asked: Array[int] = []
var _answer_frames := PackedFloat64Array()
var _frame_notes: int = 0
var _two_plus: int = 0
var _gap_tick: int = -1
var _gap_frame: int = 0
var _gaps: Array[int] = [0, 0, 0]
var _pace_usec := PackedInt64Array()
var _pace_tick := PackedInt64Array()

var _hold_on: bool = false
var _holds_done: int = 0
var _hold_next: int = 0
var _hold_end: int = 0
var _hold_start: int = 0
var _hold_drains := PackedInt64Array()
var _hold_steps := PackedInt64Array()
var _hold_frames := PackedInt64Array()

func _ready() -> void:
	super._ready()
	_start_auto_pick(false)
	_view.set_quality(quality)
	# GraphicsSettings.load_smooth() defaults to on only under High; forced so a stored choice cannot change the row.
	_view.set_smooth(quality == GraphicsSettings.HIGH and smooth)
	_view.time_draws = true
	_camera.zoom = Vector2.ONE * ZOOM
	_view.set_zoom(ZOOM)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

# Main keeps no reference to the simulation once the pump owns it.
func _create_world() -> void:
	_plan_inputs()
	driver.adopt(bench_sim)
	bench_sim = null

func _plan_inputs() -> void:
	for entity: Dictionary in bench_sim.snapshot().entities:
		if entity.owner != 1: continue
		if _movers.is_empty(): _home = Vector2(entity.position[0], entity.position[1])
		if _movers.size() < MOVERS: _movers.append(entity.id)
		if _builder == -1 and Registry.is_builder(entity.kind): _builder = entity.id
	if _builder == -1: return
	var cell := Vector2i(_home)
	for dy: int in range(-12, 13, 4):
		for dx: int in range(-12, 13, 4):
			var origin := cell + Vector2i(dx, dy)
			if _sites.size() < MOVERS and bench_sim.preview_build(1, _builder, BUILD_KIND, origin).ok: _sites.append(origin)
	if _sites.is_empty(): _sites.append(cell)

func _physics_process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	super(delta)
	_script_usec += Time.get_ticks_usec() - started

# The track is keyed to the tick the driver posts next, so both modes issue the same orders on the same ticks.
func _step_frame() -> void:
	if _hold_on:
		_hold_steps.append(Time.get_ticks_usec())
		return
	_feed_inputs(int(driver.get("_next_tick")))
	super()

func _feed_inputs(next: int) -> void:
	if next == _fed_tick or _movers.is_empty() or driver.over(): return
	if next % MOVE_EVERY != 0 and next % BUILD_EVERY != 0: return
	_fed_tick = next
	if next % MOVE_EVERY == 0:
		var target: Vector2 = _home + OFFSETS[floori(float(next) / MOVE_EVERY) % OFFSETS.size()]
		_script({"type": "move", "entity_ids": _movers.duplicate(), "target": [target.x, target.y]})
	if next % BUILD_EVERY == 0 and _builder != -1:
		var origin: Vector2i = _sites[floori(float(next) / BUILD_EVERY) % _sites.size()]
		_script({"type": "build", "builder_id": _builder, "building_kind": BUILD_KIND, "origin": [origin.x, origin.y]})

func _script(payload: Dictionary) -> void:
	driver.submit(payload)
	_asked.append(Engine.get_process_frames() if _open and not _done else -1)
	if _open and not _done: _scripted += 1

func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	if _open and not _done:
		var interval: float = (started - _last_start) / 1000.0
		_start_ms.append(interval)
		if interval > LONG_MS: _long += 1
		if _hold_on: _hold_frames.append(started)
	_last_start = started
	var draws_before: int = _view.draw_usec
	super(delta)
	# advance_frame's blend runs inside super() and also lands in draw_usec; count it once.
	_script_usec += Time.get_ticks_usec() - started - (_view.draw_usec - draws_before)
	if _done: return
	_window()
	if _open: _feel()

func _refresh() -> void:
	var started: int = Time.get_ticks_usec()
	super()
	if _open and not _done: _refresh_ms.append((Time.get_ticks_usec() - started) / 1000.0)

func _show(state: Dictionary, fresh: bool = true) -> void:
	_last_view_tick = state.tick
	if fresh and _open and not _done:
		_views_shown += 1
		_units.append(state.units.size())
	super(state, fresh)

func _collect_note(note: SimPump.Note) -> void:
	_frame_notes += 1
	if _hold_on: _hold_drains.append(Time.get_ticks_usec())
	if not note.digest.is_empty() and note.tick % 300 == 0 and note.tick > start_tick: _digest(note)
	_answered(note)
	if _open and not _done:
		for event: Dictionary in note.events:
			if event.type == "shot": _shots += 1
			else: _deaths += 1
		for result: Dictionary in note.results:
			if result.get("ok", false): _commands += 1
		_bot_commands += note.bot_commands.size()
	super(note)

func _digest(note: SimPump.Note) -> void:
	var entry: String = "%d %s" % [note.tick, note.digest]
	if digests.is_empty() or digests[-1] != entry: digests.append(entry)

func _answered(note: SimPump.Note) -> void:
	for entry: Dictionary in note.issued:
		if _asked.is_empty(): return
		var asked: int = _asked.pop_front()
		if asked >= 0: _answer_frames.append(Engine.get_process_frames() - asked)

func _window() -> void:
	var t: int = driver.current().tick
	var end: int = _window_end()
	var now: int = Time.get_ticks_usec()
	if t != _seen_tick:
		_seen_tick = t
		_seen_usec = now
	elif now - _seen_usec > STALL_USEC: return _close(t, "simulation stalled at tick %d" % t)
	if not _open:
		if t >= start_tick + BenchLoads.WARMUP: _begin(t)
		return
	if driver.over() and t < end: return _close(t, "match ended before the window end")
	_sample_frame()
	if t >= end: _close(t, "")

func _window_end() -> int:
	return _t_first + BenchLoads.WINDOW

func _begin(t: int) -> void:
	_frame_ms.clear()
	_start_ms.clear()
	_long = 0
	_cpu_ms.clear()
	_refresh_ms.clear()
	_units.clear()
	_missed = 0
	_render_sum = 0.0
	_views_shown = 0
	_shots = 0
	_deaths = 0
	_commands = 0
	_bot_commands = 0
	_script_usec = 0
	_carried_usec = 0
	_view.draw_usec = 0
	_view.batch_builds = 0
	_scripted = 0
	_answer_frames.clear()
	_two_plus = 0
	_frame_notes = 0
	_gaps = [0, 0, 0]
	_gap_tick = t
	_gap_frame = Engine.get_process_frames()
	_pace_usec.clear()
	_pace_tick.clear()
	# The warm-up and the start handshake stay out of the queue numbers.
	driver.pump.reset_queue_stats()
	_t_first = t
	_open_usec = Time.get_ticks_usec()
	_last_frame = _open_usec
	_hold_next = _open_usec + HOLD_FIRST_USEC
	_open = true

func _sample_frame() -> void:
	var now: int = Time.get_ticks_usec()
	var interval: float = (now - _last_frame) / 1000.0
	_last_frame = now
	_frame_ms.append(interval)
	if interval > MISSED_MS: _missed += 1
	# Godot draws after _process, so the draw counted here belongs to the previous frame's tick.
	var script_ms: float = (_carried_usec + _view.draw_usec) / 1000.0
	_carried_usec = _script_usec
	_script_usec = 0
	_view.draw_usec = 0
	var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	_render_sum += render_ms
	_cpu_ms.append(script_ms + render_ms + RenderingServer.get_frame_setup_time_cpu())

func _feel() -> void:
	var tick: int = driver.current().tick
	var frame: int = Engine.get_process_frames()
	if _frame_notes >= 2: _two_plus += 1
	_frame_notes = 0
	if tick != _gap_tick:
		_gaps[clampi(frame - _gap_frame, 1, 3) - 1] += 1
		_gap_tick = tick
		_gap_frame = frame
	_pace_usec.append(Time.get_ticks_usec())
	_pace_tick.append(tick)
	_hold_clock()

func _hold_clock() -> void:
	if holds.x == 0: return
	var now: int = Time.get_ticks_usec()
	if _hold_on and now >= _hold_end: _hold_finish()
	elif not _hold_on and _holds_done < holds.x and now >= _hold_next:
		_hold_on = true
		_hold_start = now
		_hold_end = now + holds.y * 1000
		_hold_drains.clear()
		_hold_steps.clear()
		_hold_frames.clear()

# Wall-clock ms: the hold start, the last in-flight drain, the first physics frame after it whose step would take, and the first frame after it.
func _hold_finish() -> void:
	var drained: int = _hold_drains[-1] if not _hold_drains.is_empty() else _hold_start
	var row: Dictionary = {"hold": _holds_done + 1, "start": _hold_start / 1000.0, "drain": drained / 1000.0, "take": _first_after(_hold_steps, drained) / 1000.0, "frame": _first_after(_hold_frames, drained) / 1000.0}
	print("WORKER HOLD " + JSON.stringify(row))
	_hold_on = false
	_holds_done += 1
	_hold_next = Time.get_ticks_usec() + HOLD_GAP_USEC

static func _first_after(stamps: PackedInt64Array, usec: int) -> int:
	for stamp: int in stamps:
		if stamp > usec: return stamp
	return 0

func _close(t: int, reason: String) -> void:
	_done = true
	var failure: String = reason if not reason.is_empty() else _check_run(t)
	finished.emit(_bench_result(t, failure))

func _check_run(t: int) -> String:
	var missing: Array[String] = []
	if _shots == 0 or _deaths == 0: missing.append("shots and deaths")
	if load_name == "team" and _bot_commands == 0: missing.append("bot commands")
	if holds.x > 0 and _holds_done < holds.x: missing.append("holds (%d of %d)" % [_holds_done, holds.x])
	if _scripted == 0: missing.append("scripted inputs")
	if not missing.is_empty(): return "mechanics missing: " + ", ".join(missing)
	if _views_shown == 0 or absi(_last_view_tick - t) > 2: return "screen received no view"
	return ""

func _bench_result(t: int, failure: String) -> Dictionary:
	var wall: float = (Time.get_ticks_usec() - _open_usec) / 1000000.0
	var window_ticks: int = t - _t_first
	var cpu_sum: float = 0.0
	for sample: float in _cpu_ms: cpu_sum += sample
	var gap_total: int = maxi(1, _gaps[0] + _gaps[1] + _gaps[2])
	var result: Dictionary = {"arm": arm, "sim_mode": driver.sim_mode(), "online_cadence": online_cadence, "path": "simpump", "load": load_name, "run": run_index, "export": "threads" if OS.has_feature("threads") else "nothreads",
		"web": OS.has_feature("web"), "isolated": OS.has_feature("web") and bool(JavaScriptBridge.eval("crossOriginIsolated")),
		"start_tick": _t_first, "end_tick": t, "wall_s": wall, "build": build_id, "window_ticks": window_ticks,
		"tick_rate": window_ticks / wall if wall > 0.0 else 0.0,
		"mechanics": {"shots": _shots, "deaths": _deaths, "commands": _commands, "bot_commands": _bot_commands}, "views_shown": _views_shown,
		"frames": _frame_ms.size(), "frame_ms": TimingStats.summary(_frame_ms),
		"missed_share": float(_missed) / maxi(1, _frame_ms.size()), "cpu_ms": TimingStats.summary(_cpu_ms),
		"main_per_tick": cpu_sum / maxi(1, window_ticks), "refresh_ms": TimingStats.summary(_refresh_ms),
		"split_share": _clock.split_share(), "units_median": TimingStats.summary(_units).p50, "units_end": _units[-1] if not _units.is_empty() else 0.0,
		"quality": "high" if _view._quality == GraphicsSettings.HIGH else "low", "quality_param": quality_param, "quality_used": "high" if quality == GraphicsSettings.HIGH else "low", "auto_pick_p95_ms": null, "smooth": _view._interpolating(), "zoom": _camera.zoom.x, "failed": failure,
		"physics_cap": Engine.max_physics_steps_per_frame,
		"harness": "v2-blend-once+long", "start_ms": TimingStats.summary(_start_ms), "frames_per_s": _frame_ms.size() / wall if wall > 0.0 else 0.0,
		"long_frames": _long, "long_per_s": _long / wall if wall > 0.0 else 0.0,
		"pace_worst_2s_tps": _worst_pace(), "tick_gap_frames": {"1": _gaps[0] / float(gap_total), "2": _gaps[1] / float(gap_total), "3": _gaps[2] / float(gap_total)},
		"drains_two_plus_ticks": _two_plus, "answer_latency_frames": TimingStats.summary(_answer_frames), "scripted_inputs": _scripted}
	return result.merged(_queue_rows())

# The slowest stretch of at least two seconds, in ticks per second of wall time.
func _worst_pace() -> float:
	var worst: float = INF
	var j: int = 0
	for i: int in _pace_usec.size():
		while j < _pace_usec.size() and _pace_usec[j] - _pace_usec[i] < PACE_USEC: j += 1
		if j == _pace_usec.size(): break
		worst = minf(worst, (_pace_tick[j] - _pace_tick[i]) * 1000000.0 / (_pace_usec[j] - _pace_usec[i]))
	return worst if worst != INF else 0.0

# Job timings reach the bench only through queue_stats(); inline pumps leave the timing lists empty.
func _queue_rows() -> Dictionary:
	var stats: Dictionary = driver.pump.queue_stats()
	var job := PackedFloat64Array()
	var handoff := PackedFloat64Array()
	var age := PackedFloat64Array()
	var by_tag: Dictionary = {"plain": PackedFloat64Array(), "snapshot+digest": PackedFloat64Array()}
	for row: Dictionary in stats.jobs:
		job.append(row.job_usec / 1000.0)
		handoff.append(row.handoff_usec / 1000.0)
		age.append(row.age_usec / 1000.0)
		by_tag[row.tag].append(row.job_usec / 1000.0)
	stats.erase("jobs")
	return stats.merged({"age_ms": TimingStats.summary(age), "job_ms": TimingStats.summary(job), "handoff_ms": TimingStats.summary(handoff),
		"job_ms_by_tag": {"plain": TimingStats.summary(by_tag.plain), "snapshot+digest": TimingStats.summary(by_tag["snapshot+digest"])}})
