extends Node

const Workload = preload("res://scripts/debug/movement_workload.gd")
const Stats = preload("res://scripts/debug/timing_stats.gd")
const Iso = preload("res://scripts/presentation/isometric.gd")
const Profiler = preload("res://scripts/debug/profiler.gd")
const CombatWorkload = preload("res://scripts/debug/combat_workload.gd")
const SoundPlayer = preload("res://scripts/presentation/sound_player.gd")
const VisualDirector = preload("res://scripts/presentation/visual_director.gd")
const Simulation = preload("res://scripts/simulation/simulation.gd")
const ViewRows = preload("res://scripts/simulation/view_rows.gd")
const Hud = preload("res://scripts/match/hud.gd")
# New with the ashfall layout (R2): worst of six rendered runs 3.02 ms plus about 50%. No ceiling exists for the other layouts.
const ASHFALL_FRAME_P95_MS: float = 3.3
# Fixed ceilings on max draw calls per frame in the sample window; never raised to pass.
const DRAW_CALL_CEILINGS: Dictionary = {"open": 50, "dense": 50, "horde": 50, "ashfall": 60}
const LAYOUTS: Array[String] = ["open", "dense", "ashfall", "horde"]
const HUD_LAYOUT: String = "hud_select"
const HUD_SELECTED: int = 120
const SELECTION_LINE_POINTS: int = 8
const DEFAULT_WINDOW := Vector2i(1280, 720)
const GraphicsSettings = preload("res://scripts/presentation/graphics_settings.gd")
const ViewCaps = preload("res://scripts/presentation/view_caps.gd")
# `-- --profile` adds profiling zones and a third, 196x196 combat leg (spike-performance only).
var _profile: bool = OS.get_cmdline_user_args().has("--profile")
# `-- --sound` runs only the horde layout with a SoundPlayer and reports its cost.
var _sound_mode: bool = OS.get_cmdline_user_args().has("--sound")
var _sound: SoundPlayer
var _visuals := VisualDirector.new()
var _sound_state: Dictionary = {}
var _sound_cues: int = 0
var _sound_times := PackedFloat64Array()
var _large: bool = false
var _simulation: Simulation
var _web: bool = OS.has_feature("wargrid_render_bench")
# `-- --hud` runs only hud_select: 120 units selected under the live Hud; `--expect-window=WxH` names the size the row is for.
var _hud_mode: bool = _hud_from(OS.get_cmdline_user_args())
var _expected_window: Vector2i = _expect_window_from(OS.get_cmdline_user_args())
var _hud: Hud
var _hud_ids: Array[int] = []
var _hud_drawn_ticks: int = 0
# The last failure, kept so a test can read it with `_quit_on_failure` off.
var last_failure: String = ""
var _quit_on_failure: bool = true
var _sequence: Array[String] = _layouts_from(OS.get_cmdline_user_args())
var _layout_index: int = 0
var _lines := PackedStringArray()
var _script_usec: int = 0
var _carried_tick_usec: int = 0
var _cpu_script := PackedFloat64Array()
var _cpu_render := PackedFloat64Array()
var _cpu_setup := PackedFloat64Array()
var _cpu_total := PackedFloat64Array()
var _layout_started: int
var _sample_started: int = 0
var _last_frame: int = 0
var _window_started: int = 0
var _window_ticks: int = 0
var _sample_ticks: int = 0
var _leg: int = -1
var _leg_ticks: int = 0
var _completed_legs: int = 0
var _queue_peak: int = 0
var _queue_start: int = -1
var _queue_drain: int = 0
var _tick_times := PackedFloat64Array()
var _frame_times := PackedFloat64Array()
var _command_times := PackedFloat64Array()
var _draw_calls := PackedFloat64Array()
var _sampling_done: bool = false
var _horde_start: Dictionary = {}
var _horde_peak: int = 0
var _horde_marked_ticks: int = 0
@onready var _view: Node2D = $WorldView
@onready var _status: Label = $HUD/Status

func _exit_tree() -> void:
	ViewCaps.release(get_tree().root)

func _ready() -> void:
	ViewCaps.apply(get_tree().root)
	# Vsync would quantize frame intervals to display refresh and hide render cost.
	if not _web: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var zoom: float = _zoom()
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32))
	$Camera2D.zoom = Vector2(zoom, zoom)
	_view.time_draws = true
	_view.set_quality(_quality())
	_view.set_smooth(_interpolation_from(OS.get_cmdline_user_args()))
	_view.set_zoom(zoom)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_emit("M2 RENDERED engine=" + Engine.get_version_info().string + " os=" + OS.get_name()
		+ " cpu=" + OS.get_processor_name() + " resolution=" + str(get_viewport().get_visible_rect().size)
		+ " zoom=" + str(zoom) + " quality=" + ("high" if _quality() == GraphicsSettings.HIGH else "low")
		+ " interpolation=" + ("on" if _interpolation_from(OS.get_cmdline_user_args()) else "off")
		+ (" window=" + _size_text(DisplayServer.window_get_size()) if _hud_mode else "")
		+ " layouts=" + ",".join(_sequence) + " map=64x64 (ashfall layout 194x187) units=" + str(units_run(_units(), _sequence))
		+ " seed=none vsync=" + ("browser" if _web else "off") + " warmup_wall_seconds=10 sample_wall_seconds=60")
	var mismatch: String = window_failure(_expected_window, DisplayServer.window_get_size()) if _hud_mode else ""
	if mismatch != "":
		_fail(mismatch)
		return
	_begin_layout()

func _arg(flag: String, fallback: String) -> String:
	return _arg_of(OS.get_cmdline_user_args(), flag, fallback)

func _arg_of(args: Array, flag: String, fallback: String) -> String:
	for arg: String in args:
		if arg.begins_with(flag + "="): return arg.trim_prefix(flag + "=")
	return fallback

func _layouts_from(args: Array) -> Array[String]:
	if _hud_from(args): return [HUD_LAYOUT] as Array[String]
	var only: String = _arg_of(args, "--layout", "")
	if only != "":
		assert(LAYOUTS.has(only), "unknown layout " + only)
		return [only] as Array[String]
	if int(_arg_of(args, "--units", "300")) == 500 or args.has("--sound"): return ["horde"] as Array[String]
	var all: Array[String] = LAYOUTS.duplicate()
	if _web: all = ["horde", "ashfall"]
	return all

func _units() -> int:
	return int(_arg("--units", "300"))

func _zoom() -> float:
	return float(_arg("--zoom", "0.5"))

func _quality() -> int:
	return GraphicsSettings.LOW if _arg("--quality", "high") == "low" else GraphicsSettings.HIGH

func _emit(line: String) -> void:
	print(line)
	_lines.append(line)

func _begin_layout() -> void:
	_script_usec = 0
	_carried_tick_usec = 0
	_view.draw_usec = 0
	_cpu_script.clear()
	_cpu_render.clear()
	_cpu_setup.clear()
	_cpu_total.clear()
	$Camera2D.position = Iso.world_to_plane(Vector2(32, 32)) if _layout_name() != "ashfall" else Iso.world_to_plane(Vector2(26, 118))
	_visuals.reset()
	_view.set_visuals(_visuals)
	_horde_start.clear()
	_horde_peak = 0
	_horde_marked_ticks = 0
	if _layout_name() == HUD_LAYOUT:
		_begin_hud()
	elif _layout_name() == "horde":
		_simulation = CombatWorkload.create("horde_render_500" if _units() == 500 else "horde_render")
		if _sound_mode and _sound == null:
			_sound = SoundPlayer.new(1)
			add_child(_sound)
		_sound_cues = 0
		_sound_times.clear()
		for unit: Dictionary in _simulation.snapshot().entities:
			if unit.owner == 1: _horde_start[unit.id] = unit.position
	else:
		_simulation = Workload.create(_layout_name())
	_layout_started = Time.get_ticks_usec()
	_sample_started = 0
	_last_frame = 0
	_window_ticks = 0
	_sample_ticks = 0
	_leg = -1
	_leg_ticks = 0
	_completed_legs = 0
	_queue_peak = 0
	_queue_start = -1
	_queue_drain = 0
	_tick_times.clear()
	_frame_times.clear()
	_command_times.clear()
	_draw_calls.clear()
	_sampling_done = false

func _physics_process(_delta: float) -> void:
	if _large:
		_large_tick()
		return
	if _layout_name() == HUD_LAYOUT:
		_hud_tick()
		return
	if _layout_name() == "horde":
		_horde_tick()
		return
	var started: int = Time.get_ticks_usec()
	var command_tick: bool = _leg == -1 or Workload.settled(_simulation)
	if command_tick:
		if _leg >= 0:
			_completed_legs += 1
		_leg += 1
		_leg_ticks = 0
		_queue_start = _simulation.tick()
		Workload.issue_leg(_simulation, _leg, Workload.ASHFALL_ANCHORS if _layout_name() == "ashfall" else Workload.ANCHORS)
	_simulation.step()
	_leg_ticks += 1
	var state: Dictionary = _simulation.view_state()
	var no_selection: Array[int] = []
	_view.set_view(state, no_selection)
	_status.text = "%s | %s | tick %d | leg %d | Esc: quit" % [_layout_name(),
		"draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick, _leg]
	var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append(elapsed)
		_script_usec += Time.get_ticks_usec() - started
	if command_tick:
		_command_times.append(elapsed)
	Profiler.end_tick()
	var queued: int = _simulation._path_queue.size() # the view state omits the queue; a private read keeps the per-tick snapshot out of the timed loop
	_queue_peak = maxi(_queue_peak, queued)
	if queued == 0 and _queue_start >= 0:
		_queue_drain = maxi(_queue_drain, state.tick - _queue_start)
		_queue_start = -1
	if _leg_ticks > 3000:
		_fail("Rendered workload leg exceeded 3000 ticks")
		return
	var blocked: int = state.units.status.find(ViewRows.STATUSES.find("blocked"))
	if blocked >= 0:
		_fail("Rendered workload blocked unit " + str(state.units.id[blocked]))
		return
	if _sampling_done and Workload.settled(_simulation):
		_finish_layout(_simulation.snapshot())

func _process(_delta: float) -> void:
	_view.advance_frame()
	var now: int = Time.get_ticks_usec()
	if _sound != null and _sample_started > 0 and not _sampling_done and not _sound_state.is_empty():
		_sound.update(_sound_state)
		_sound_cues += _sound.last_requests().size()
		_sound_times.append((Time.get_ticks_usec() - now) / 1000.0)
	if _sample_started == 0 and now - _layout_started >= 10000000:
		_sample_started = now
		_window_started = now
		_last_frame = now
		_script_usec = 0
		_carried_tick_usec = 0
		_view.draw_usec = 0
		Profiler.reset()
		Profiler.enabled = _profile
	elif _sample_started > 0 and not _sampling_done:
		_frame_times.append((now - _last_frame) / 1000.0)
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_record_cpu_frame()
		_last_frame = now
		if now - _window_started >= 10000000:
			var seconds: float = (now - _window_started) / 1000000.0
			print("BACKLOG ", _layout_name(), " wall_seconds=", seconds,
				" physics_ticks=", _window_ticks, " expected_ticks=", seconds * 30.0,
				" cumulative_lag_ticks=", (now - _sample_started) / 1000000.0 * 30.0 - _sample_ticks)
			_window_started = now
			_window_ticks = 0
		if now - _sample_started >= 60000000:
			_sampling_done = true
			_emit("RENDERED SAMPLE " + _sample_name() + " wall_seconds=" + str((now - _sample_started) / 1000000.0)
				+ " physics_ticks=" + str(_sample_ticks) + " tick_ms=" + JSON.stringify(Stats.summary(_tick_times))
				+ " frame_interval_ms=" + JSON.stringify(Stats.summary(_frame_times))
				+ " command_tick_ms=" + JSON.stringify(Stats.summary(_command_times))
				+ " draw_calls=" + JSON.stringify(Stats.summary(_draw_calls)))
			_emit("CPU_FRAME " + _layout_name() + " script_ms=" + JSON.stringify(Stats.summary(_cpu_script))
				+ " render_ms=" + JSON.stringify(Stats.summary(_cpu_render))
				+ " setup_ms=" + JSON.stringify(Stats.summary(_cpu_setup))
				+ " total_ms=" + JSON.stringify(Stats.summary(_cpu_total)))
			for line in Profiler.report("rendered_" + _layout_name(), &"draw"): print(line)
			Profiler.enabled = false
			if _large:
				print("RENDERED PROFILE COMPLETE")
				get_tree().quit(0)

func _record_cpu_frame() -> void:
	var script_ms: float = _script_ms()
	var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	var setup_ms: float = RenderingServer.get_frame_setup_time_cpu()
	_cpu_script.append(script_ms)
	_cpu_render.append(render_ms)
	_cpu_setup.append(setup_ms)
	_cpu_total.append(script_ms + render_ms + setup_ms)

# Godot draws after _process, so the draw counted here belongs to the previous frame's tick.
func _script_ms() -> float:
	var script_ms: float = (_carried_tick_usec + _view.draw_usec) / 1000.0
	_carried_tick_usec = _script_usec
	_script_usec = 0
	_view.draw_usec = 0
	return script_ms

# The horde_render_500 workload exists only for the horde layout.
static func units_run(requested: int, layouts: Array[String]) -> int:
	return 500 if requested == 500 and layouts.has("horde") else 300

static func hud_failure(header: String, drawn_lines: int, selected: int, match_started: bool) -> String:
	if not header.begins_with("%d selected" % selected):
		return "hud_select panel header reads '%s', not %d selected" % [header, selected]
	if drawn_lines >= 0 and drawn_lines != selected * SELECTION_LINE_POINTS:
		return "hud_select drew %d selection line points, not %d" % [drawn_lines, selected * SELECTION_LINE_POINTS]
	if match_started: return "hud_select started a match"
	return ""

static func window_failure(expected: Vector2i, actual: Vector2i) -> String:
	if expected == actual: return ""
	return "Window is %s, the run expects %s" % [_size_text(actual), _size_text(expected)]

static func _size_text(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]

static func draw_call_failure(layout: String, max_calls: float) -> String:
	if not DRAW_CALL_CEILINGS.has(layout):
		return "No draw-call ceiling for layout %s" % layout
	if max_calls > DRAW_CALL_CEILINGS[layout]:
		return "Layout %s draws %d calls, ceiling %d" % [layout, int(max_calls), DRAW_CALL_CEILINGS[layout]]
	return ""

# Gated rows run without interpolation so they stay comparable to every earlier row.
func _interpolation_from(args: Array) -> bool:
	return args.has("--interpolation=on")

func _hud_from(args: Array) -> bool:
	return args.has("--hud")

func _expect_window_from(args: Array) -> Vector2i:
	var parts: PackedStringArray = _arg_of(args, "--expect-window", "").split("x")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else DEFAULT_WINDOW

func _report_only_from(args: Array) -> bool:
	for arg: String in args:
		for flag: String in ["--quality", "--zoom", "--units", "--layout"]:
			if arg.begins_with(flag): return true
	return _interpolation_from(args)

func _report_only() -> bool:
	return _web or _report_only_from(OS.get_cmdline_user_args())

func _report_draw_calls(layout: String) -> bool:
	var max_calls: float = Stats.summary(_draw_calls).max
	var failure: String = draw_call_failure(layout, max_calls)
	_emit("DRAW_CALLS " + layout + " max=" + str(int(max_calls)) + " p50=" + str(int(Stats.summary(_draw_calls).p50)) + " ceiling=" + str(DRAW_CALL_CEILINGS.get(layout, -1)) + " over=" + str(failure != ""))
	var gate: String = "" if _report_only() else failure
	if gate != "":
		_fail(gate)
		return false
	return true

func _finish_layout(state: Dictionary) -> void:
	var goals: Dictionary = {}
	for unit: Dictionary in state.entities:
		if unit.destination == null or unit.position != unit.destination:
			_fail("Rendered workload missed destination")
			return
		goals[unit.destination] = true
	if goals.size() != 300 or _tick_times.is_empty() or _frame_times.is_empty():
		_fail("Rendered workload incomplete samples/destinations")
		return
	if _layout_name() == "ashfall":
		var frame_p95: float = Stats.summary(_frame_times).p95
		_emit("ASHFALL map=194x187 units=300 buildings=6 frame_p95_ms=" + str(frame_p95))
		if frame_p95 > ASHFALL_FRAME_P95_MS and not _report_only():
			_fail("Rendered ashfall frame p95 %.3f ms exceeds %.1f ms" % [frame_p95, ASHFALL_FRAME_P95_MS])
			return
	if not _report_draw_calls(_layout_name()): return
	_emit("RENDERED COMPLETE " + _layout_name() + " completed_legs=" + str(_completed_legs + 1)
		+ " queue_peak=" + str(_queue_peak) + " queue_drain_ticks=" + str(_queue_drain) + " arrived=300 unique_destinations=" + str(goals.size()))
	_advance()

func _advance() -> void:
	_layout_index += 1
	if _layout_index < _sequence.size():
		_begin_layout()
		return
	if _hud_mode:
		_emit("RENDERED HUD " + ("CALIBRATION " if _report_only() else "PASSED ") + _size_text(_expected_window))
	else:
		_emit("RENDERED BENCHMARK PASSED " + str(_sequence.size()))
	if _profile:
		_begin_large()
	elif _web:
		_post()
	else:
		get_tree().quit(0)

func _post() -> void:
	set_physics_process(false)
	set_process(false)
	var http := HTTPRequest.new()
	add_child(http)
	var origin: String = str(JavaScriptBridge.eval("location.origin"))
	var body: String = "\n".join(_lines) + "\nUA " + str(JavaScriptBridge.eval("navigator.userAgent")) + "\n"
	http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_status.text = "posted" if code == 204 else "post failed %d" % code)
	if http.request(origin + "/result", ["Content-Type: text/plain"], HTTPClient.METHOD_POST, body) != OK:
		_status.text = "post failed"

# Zoom 0.5 shows the whole fight from a fixed camera; closer zooms follow the owner-1 army so they do not render empty ground.
static func horde_camera(rows: RefCounted, level: float) -> Vector2:
	var fixed: Vector2 = Iso.world_to_plane(Vector2(32, 32))
	if level <= 0.5: return fixed
	var sum := Vector2.ZERO
	var count: int = 0
	for i in range(rows.size()):
		if rows.owner[i] == 1:
			sum += Vector2(rows.x[i], rows.y[i])
			count += 1
	return Iso.world_to_plane(sum / count) if count > 0 else fixed

func _horde_tick() -> void:
	var started: int = Time.get_ticks_usec()
	_simulation.step()
	var state: Dictionary = _simulation.view_state()
	_visuals.collect_step(state.tick, _simulation.combat_events(), _simulation.command_results())
	if _sound != null:
		_sound.collect_step(state.tick, _simulation.combat_events(), _simulation.command_results())
		_sound_state = state
	var no_selection: Array[int] = []
	$Camera2D.position = horde_camera(state.units, $Camera2D.zoom.x)
	_view.set_view(state, no_selection)
	_status.text = "horde | %s | tick %d | Esc: quit" % ["draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick]
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append((Time.get_ticks_usec() - started) / 1000.0)
		_script_usec += Time.get_ticks_usec() - started
		var marks: int = _view.horde_count()
		_horde_peak = maxi(_horde_peak, marks)
		_horde_marked_ticks += 1 if marks > 0 else 0
	Profiler.end_tick()
	if _sampling_done:
		_finish_horde(_simulation.snapshot())

func _finish_horde(state: Dictionary) -> void:
	var moved: int = 0
	for unit: Dictionary in state.entities:
		if _horde_start.has(unit.id) and unit.position != _horde_start[unit.id]: moved += 1
	if _horde_peak == 0 or _horde_marked_ticks == 0 or moved == 0 or _tick_times.is_empty() or _frame_times.is_empty():
		_fail("Rendered horde workload drew no horde marks or no unit moved")
		return
	if not _report_draw_calls("horde"): return
	_emit("RENDERED COMPLETE horde horde_mark_peak=" + str(_horde_peak) + " marked_ticks=" + str(_horde_marked_ticks) + " of " + str(_sample_ticks) + " units_moved=" + str(moved))
	if _sound != null:
		if _sound_cues == 0:
			_fail("RENDERED SOUND cues=0")
			return
		print("RENDERED SOUND cues=", _sound_cues, " update_p95_ms=", Stats.summary(_sound_times).p95)
	_advance()

func _begin_hud() -> void:
	_simulation = Workload.create("open")
	_simulation.add_player(1, 10000)
	_hud_ids.clear()
	var rows: ViewRows = _simulation.view_state().units
	for i in rows.size():
		if rows.owner[i] == 1 and _hud_ids.size() < HUD_SELECTED: _hud_ids.append(rows.id[i])
	_hud_drawn_ticks = 0
	if _hud_ids.size() != HUD_SELECTED:
		_fail("hud_select found %d owner-1 units, not %d" % [_hud_ids.size(), HUD_SELECTED])
		return
	if _hud != null: return
	_hud = Hud.new()
	$HUD.add_child(_hud)
	_hud.setup(null)

func _hud_tick() -> void:
	var started: int = Time.get_ticks_usec()
	_simulation.step()
	var state: Dictionary = _simulation.view_state()
	_view.set_view(state, _hud_ids)
	_hud.update_hud(state, {"ids": _hud_ids, "building_id": -1, "inspected_id": -1, "placement_kind": "", "resume_id": -1, "notice": "", "bright_owners": false, "esc_opens_menu": false, "attack_move": false}, 1, 1)
	var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
	_status.text = "hud_select | %s | tick %d | Esc: quit" % ["draining" if _sampling_done else ("sampling" if _sample_started > 0 else "warmup"), state.tick]
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append(elapsed)
		_script_usec += Time.get_ticks_usec() - started
		var failure: String = hud_failure((_hud.get_node("SelectionPanel/Box/Many/Header") as Label).text, _view.drawn_selection_lines, _hud_ids.size(), state.match != null)
		if failure != "":
			_fail(failure)
			return
		_hud_drawn_ticks += 1 if _view.drawn_selection_lines >= 0 else 0
	Profiler.end_tick()
	if _sampling_done: _finish_hud()

func _finish_hud() -> void:
	if _hud_drawn_ticks == 0 or _tick_times.is_empty() or _frame_times.is_empty():
		_fail("Rendered hud_select drew no selection lines in the sample window")
		return
	if not _report_draw_calls(HUD_LAYOUT): return
	_emit("RENDERED COMPLETE hud_select selected=" + str(_hud_ids.size()) + " drawn_ticks=" + str(_hud_drawn_ticks) + " of " + str(_sample_ticks))
	_advance()

func _fail(message: String) -> void:
	last_failure = message
	if not _quit_on_failure:
		set_physics_process(false)
		set_process(false)
		return
	push_error(message)
	if _web:
		_emit("RENDERED FAILED " + message)
		_post()
		return
	set_physics_process(false)
	set_process(false)
	get_tree().quit(1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("deselect"):
		get_tree().quit(1)

# Only the HUD row is keyed by window size: the same layout at 1280x720 and 2560x1080 is two rows.
func _sample_name() -> String:
	return _layout_name() + "_" + _size_text(_expected_window) if _layout_name() == HUD_LAYOUT else _layout_name()

func _layout_name() -> String:
	return "large_196" if _large else _sequence[_layout_index]

func _begin_large() -> void:
	_large = true
	_simulation = CombatWorkload.create_large()
	$Camera2D.position = Iso.world_to_plane(Vector2(98, 98))
	_layout_started = Time.get_ticks_usec()
	_sample_started = 0
	_sample_ticks = 0
	_window_ticks = 0
	_tick_times.clear()
	_frame_times.clear()
	_draw_calls.clear()
	_sampling_done = false

func _large_tick() -> void:
	var started: int = Time.get_ticks_usec()
	_simulation.step()
	var no_selection: Array[int] = []
	_view.set_view(_simulation.view_state(), no_selection)
	if _sample_started > 0 and not _sampling_done:
		_sample_ticks += 1
		_window_ticks += 1
		_tick_times.append((Time.get_ticks_usec() - started) / 1000.0)
	Profiler.end_tick()
